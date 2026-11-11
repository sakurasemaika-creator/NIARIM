import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_asset_bundle.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/first_use_tooltip_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/services/watermark_service.dart';
import 'package:niarim/services/workspace_preset_service.dart';
import 'package:niarim/utils/transfer_merge.dart';

/// 引き継ぎ画面の既定（すべての項目にチェック）。
const kAllTransferItems = {
  '設定': true,
  '端末保存データ': true,
  '素材': true,
  'ブラシ': true,
  'プリセット': true,
  'UIテーマ': true,
  'パレット': true,
};

/// 引き継ぎ（.niatra）が扱うサービス一式（1台の端末）。
///
/// [start]は今の保存（SharedPreferences）から各サービスを作って`init`する
/// （アプリの起動・起動し直しと同じ）。[import]は引き継ぎ画面の「読み込み」と
/// 同じ順（画像の展開→各項目→端末保存データ）で、引き継ぎ画面と同じ
/// サービスを渡して取り込む。
class TransferDevice {
  TransferDevice._(
    this.settings,
    this.brush,
    this.tone,
    this.stamp,
    this.autofill,
    this.theme,
    this.palette,
    this.pixelArt,
    this.workspace,
    this.automation,
    this.quickTool,
    this.shortcut,
    this.filter,
    this.firstUse,
    this.watermark,
  );

  final SettingsService settings;
  final BrushService brush;
  final ToneService tone;
  final StampService stamp;
  final AutofillPresetService autofill;
  final ThemeService theme;
  final PaletteService palette;
  final PixelArtPaletteService pixelArt;

  /// 端末保存データの中の、利用者が作った物の一覧を持つサービス。
  final WorkspacePresetService workspace;
  final CustomAutomationService automation;
  final QuickToolService quickTool;
  final ShortcutService shortcut;
  final FilterService filter;
  final FirstUseTooltipService firstUse;

  /// 透かし（画像の透かしの画像は、書類フォルダ〔path_provider〕の中）。
  final WatermarkService watermark;

  static Future<TransferDevice> start() async {
    final device = TransferDevice._(
      SettingsService(),
      BrushService(),
      ToneService(),
      StampService(),
      AutofillPresetService(),
      ThemeService(),
      PaletteService(),
      PixelArtPaletteService(),
      WorkspacePresetService(),
      CustomAutomationService(),
      QuickToolService(),
      ShortcutService(),
      FilterService(),
      FirstUseTooltipService(),
      WatermarkService(),
    );
    await device.settings.init();
    await device.brush.init();
    await device.tone.init();
    await device.stamp.init();
    await device.autofill.init();
    await device.theme.init();
    await device.palette.init();
    await device.pixelArt.init();
    await device.workspace.init();
    await device.automation.init();
    await device.quickTool.init();
    await device.shortcut.init();
    await device.filter.init();
    await device.firstUse.init();
    await device.watermark.init();
    return device;
  }

  /// [projectFiles]は引き継ぎ画面と同じく、選んだ作品の.niashare
  /// （`<作品のID>.niashare` → バイト列）。
  Future<Uint8List> export({
    Map<String, bool> items = kAllTransferItems,
    bool bundleImages = true,
    Map<String, Uint8List>? projectFiles,
  }) async {
    final raw = await NiatraSerializer.export(
      selectedItems: items,
      settings: settings,
      brush: brush,
      tone: tone,
      stamp: stamp,
      autofillPresets: autofill,
      theme: theme,
      palette: palette,
      pixelArtPalette: pixelArt,
      projectFiles: projectFiles,
    );
    if (!bundleImages) return raw;
    final bytes = await NiatraAssetBundle.enrichExport(
      raw,
      selectedItems: items,
      brush: brush,
      tone: tone,
      stamp: stamp,
      watermarks: watermark,
    );
    await settleTransfer();
    return bytes;
  }

  /// [l10n]は複製の名前の言語（画面の言語。省略すると日本語）。足した
  /// 複製の名前は[report]へ書き留める。[projects]を渡すと、引き継ぎ画面と
  /// 同じく最後にファイルの作品をその一覧へ足す。
  Future<void> import(
    Uint8List bytes,
    Directory documents, {
    AppLocalizations? l10n,
    TransferImportReport? report,
    ProjectService? projects,
  }) => importData(
    NiatraSerializer.loadFromBytes(bytes),
    documents,
    l10n: l10n,
    report: report,
    projects: projects,
  );

  Future<void> importData(
    NiatraData data,
    Directory documents, {
    AppLocalizations? l10n,
    TransferImportReport? report,
    ProjectService? projects,
  }) async {
    await NiatraAssetBundle.restoreEmbeddedAssets(
      data,
      brush: brush,
      tone: tone,
      stamp: stamp,
      autofillPresets: autofill,
      restoreBasePath: documents.path,
      l10n: l10n,
      report: report,
    );
    // 戻り値の無い処理だった版でも待てるように包む。
    await Future<void>.sync(
      () => NiatraSerializer.applyTo(
        data,
        settings: settings,
        brush: brush,
        tone: tone,
        stamp: stamp,
        autofillPresets: autofill,
        theme: theme,
        palette: palette,
        pixelArtPalette: pixelArt,
        l10n: l10n,
        report: report,
      ),
    );
    await NiatraSerializer.restoreLocalPreferences(
      data,
      lists: TransferredSavedLists(
        workspacePresets: workspace,
        customAutomations: automation,
        quickTools: quickTool,
        shortcuts: shortcut,
        settings: settings,
        filters: filter,
        firstUseTooltips: firstUse,
        watermarks: watermark,
      ),
      l10n: l10n,
      report: report,
    );
    if (projects != null) {
      await NiatraSerializer.restoreProjects(
        data,
        projects,
        l10n: l10n,
        report: report,
      );
    }
    await settleTransfer();
  }
}

/// 待たずに始めた保存を終わらせる。
Future<void> settleTransfer() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

/// 画像1枚の自作ブラシ。
Brush customTransferBrush(
  String id,
  String name,
  String? imagePath, {
  double size = 17,
}) => Brush(
  id: id,
  name: name,
  size: size,
  opacity: 73,
  spacing: 12,
  stabilization: true,
  stabilizationStrength: 41,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  customImagePath: imagePath,
);
