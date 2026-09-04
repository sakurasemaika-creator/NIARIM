import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// MaterialTypeはflutter/material.dart（Material widgetの描画種別）と
// models/material_asset.dart（画像/動画/音声の素材種別）の双方に同名の型が
// 存在するため、こちらでは使わないflutter側をhideして曖昧さを解消する。
import 'package:flutter/material.dart' hide MaterialType;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../engine/niapro_serializer.dart';
import '../../engine/niatra_asset_bundle.dart';
import '../../engine/niatra_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/material_asset.dart' show MaterialType;
import '../../services/autofill_preset_service.dart';
import '../../services/brush_service.dart';
import '../../services/font_service.dart';
import '../../services/material_service.dart';
import '../../services/palette_service.dart';
import '../../services/pixel_art_palette_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../services/stamp_service.dart';
import '../../services/theme_service.dart';
import '../../services/tone_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../home/widgets/project_list_widget.dart' show buildFontShareBundle;

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  // キー自体はNiatraSerializer.export()/applyTo()が内部で
  // selectedItems['設定']等と直接照合するための固定識別子であり、
  // UI表示用の文字列ではないため翻訳しない（表示ラベルは_itemLabel()で
  // 別途ローカライズする）。
  final Map<String, bool> _items = {
    '設定': true,
    '素材': true,
    'ブラシ': true,
    'プリセット': true,
    'UIテーマ': true,
    'パレット': true,
  };
  // 制作中プロジェクトは他項目と異なりデフォルトOFF・プロジェクトごとに
  // 個別選択できる別枠のチェックボックス群として扱う（他カテゴリは
  // ON/OFFひとつのみだが、プロジェクトは複数存在し得るため）。
  final Set<String> _selectedProjectIds = {};
  bool _isBusy = false;

  String _itemLabel(AppLocalizations l10n, String key) => switch (key) {
    '設定' => l10n.transferItemSettings,
    '素材' => l10n.transferItemMaterials,
    'ブラシ' => l10n.transferItemBrush,
    'プリセット' => l10n.transferItemPresets,
    'UIテーマ' => l10n.transferItemTheme,
    'パレット' => l10n.transferItemPalette,
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // topicはヘルプ画面側の項目タイトル（日本語固定の内部検索キー）と
      // 一致させる必要があるため翻訳しない。
      appBar: AppBar(
        title: Text(l10n.transferScreenTitle),
        actions: const [HelpButton(topic: '引き継ぎ（.niatra）')],
      ),
      body: desktopCentered(
        context,
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.transferInstructionHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Card(
                    elevation: 1,
                    shadowColor: ThemeService.activeColorScheme.shadow
                        .withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        for (final key in _items.keys) ...[
                          if (key != _items.keys.first)
                            const Divider(height: 1),
                          CheckboxListTile(
                            title: Text(_itemLabel(l10n, key)),
                            value: _items[key],
                            onChanged: (v) => setState(() => _items[key] = v!),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.transferProjectsSectionTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                      l10n.transferProjectsHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Consumer<ProjectService>(
                    builder: (context, projectService, _) {
                      final projects = projectService.projects;
                      if (projects.isEmpty) {
                        return Card(
                          elevation: 1,
                          shadowColor: ThemeService.activeColorScheme.shadow
                              .withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              l10n.transferProjectsEmpty,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }
                      // 削除済みプロジェクトのIDが選択集合に残り続けないよう
                      // 現存プロジェクトのIDのみに絞り込む。
                      _selectedProjectIds.removeWhere(
                        (id) => !projects.any((p) => p.id == id),
                      );
                      return Card(
                        elevation: 1,
                        shadowColor: ThemeService.activeColorScheme.shadow
                            .withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        child: Column(
                          children: [
                            for (final p in projects) ...[
                              if (p != projects.first) const Divider(height: 1),
                              CheckboxListTile(
                                title: Text(p.name),
                                value: _selectedProjectIds.contains(p.id),
                                onChanged: _isBusy
                                    ? null
                                    : (v) => setState(() {
                                        if (v == true) {
                                          _selectedProjectIds.add(p.id);
                                        } else {
                                          _selectedProjectIds.remove(p.id);
                                        }
                                      }),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // OSの文字サイズ設定（textScaler）を大きくすると、4つの
              // ボタンが1行に収まらずRenderFlexオーバーフローになっていた
              // ため、Wrapで折り返せるようにする（Spacerは使えないので、
              // 「読み込み」とそれ以外の間隔はspacingで表現する）。
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: _isBusy ? null : _import,
                    child: Text(l10n.transferImport),
                  ),
                  TextButton(
                    onPressed: _isBusy
                        ? null
                        : () =>
                              setState(() => _items.updateAll((_, _) => true)),
                    child: Text(l10n.homeSelectionAllSelect),
                  ),
                  TextButton(
                    onPressed: _isBusy
                        ? null
                        : () =>
                              setState(() => _items.updateAll((_, _) => false)),
                    child: Text(l10n.homeSelectionAllDeselect),
                  ),
                  FilledButton.icon(
                    onPressed:
                        (!_isBusy &&
                            (_items.values.any((v) => v) ||
                                _selectedProjectIds.isNotEmpty))
                        ? _export
                        : null,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload),
                    label: Text(l10n.transferExport),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 選択されたプロジェクトごとに.niashare（素材・フォント同梱のフルバンドル）
  /// バイト列を生成する。個々のプロジェクトで素材/フォント同梱の要否を都度
  /// 選択させると煩雑になり「同梱を忘れて壊れた引き継ぎ」を招きやすいため、
  /// _createNiashare()（プロジェクト詳細画面の共有）と異なりダイアログは出さず
  /// 常にフルバンドル（全素材種別＋使用中フォント）で書き出す。
  /// 生成した.niashareは一時ファイルとしてしか使わないため、バイト列を
  /// 読み終えたら都度削除する。
  Future<Map<String, Uint8List>> _buildProjectFiles(
    ProjectService projectService,
  ) async {
    if (_selectedProjectIds.isEmpty) return const {};
    final materialService = context.read<MaterialService>();
    final fontService = context.read<FontService>();
    final files = <String, Uint8List>{};
    for (final id in _selectedProjectIds) {
      final project = projectService.projects
          .where((p) => p.id == id)
          .firstOrNull;
      if (project == null) continue;
      final scenes = projectService.scenesOf(id);
      final tileManager = projectService.tileManagerOf(id);
      final bundle = await materialService.buildShareBundle(
        id,
        MaterialType.values.toSet(),
      );
      final fontBundle = await buildFontShareBundle(
        projectService,
        fontService,
        id,
      );
      final file = await NiaproSerializer.saveShare(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        materialFiles: bundle.files.isEmpty ? null : bundle.files,
        materialsManifest: bundle.manifest,
        fontFiles: fontBundle.files.isEmpty ? null : fontBundle.files,
        fontsManifest: fontBundle.manifest,
      );
      try {
        files['$id.niashare'] = await file.readAsBytes();
      } finally {
        if (await file.exists()) await file.delete();
      }
    }
    return files;
  }

  Future<void> _export() async {
    setState(() => _isBusy = true);
    try {
      final projectService = context.read<ProjectService>();
      final brushService = context.read<BrushService>();
      final toneService = context.read<ToneService>();
      final stampService = context.read<StampService>();
      final projectFiles = await _buildProjectFiles(projectService);
      if (!mounted) return;
      // まず既存Serializerで設定・プリセット・プロジェクト等を生成し、そのZIPへ
      // カスタムブラシ／トーン／スタンプ画像本体と完全なモデルJSONを追加する。
      // これにより別端末でも元端末の絶対ファイルパスに依存しない。
      final rawBytes = await NiatraSerializer.export(
        selectedItems: _items,
        settings: context.read<SettingsService>(),
        brush: brushService,
        tone: toneService,
        stamp: stampService,
        autofillPresets: context.read<AutofillPresetService>(),
        theme: context.read<ThemeService>(),
        palette: context.read<PaletteService>(),
        pixelArtPalette: context.read<PixelArtPaletteService>(),
        projectFiles: projectFiles,
      );
      final bytes = await NiatraAssetBundle.enrichExport(
        rawBytes,
        selectedItems: _items,
        brush: brushService,
        tone: toneService,
        stamp: stampService,
      );
      if (!mounted) return;
      final fileName = 'niarim_${DateTime.now().millisecondsSinceEpoch}.niatra';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: fileName,
              mimeType: 'application/octet-stream',
            ),
          ],
        ),
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transferExportSuccessSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.transferExportFailedSnackbar(e.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _import() async {
    // withData: trueでバイト列も取得しておく（Web版はpathがnullになり
    // ファイルパスから読み込めないため、その場合はバイト列側を使う）。
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['niatra'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null && picked.bytes == null) return;
    if (!mounted) return;
    setState(() => _isBusy = true);
    try {
      final data = picked.bytes != null
          ? NiatraSerializer.loadFromBytes(picked.bytes!)
          : await NiatraSerializer.load(picked.path!);
      if (!mounted) return;

      final brushService = context.read<BrushService>();
      final toneService = context.read<ToneService>();
      final stampService = context.read<StampService>();
      // 新形式のカスタム画像を先にアプリ領域へ展開する。処理済みカテゴリは
      // data.rawから除かれるため、その後のapplyTo()で二重追加されない。
      await NiatraAssetBundle.restoreEmbeddedAssets(
        data,
        brush: brushService,
        tone: toneService,
        stamp: stampService,
      );
      if (!mounted) return;
      NiatraSerializer.applyTo(
        data,
        settings: context.read<SettingsService>(),
        brush: brushService,
        tone: toneService,
        stamp: stampService,
        autofillPresets: context.read<AutofillPresetService>(),
        theme: context.read<ThemeService>(),
        palette: context.read<PaletteService>(),
        pixelArtPalette: context.read<PixelArtPaletteService>(),
      );
      // プロジェクトの復元はファイルI/Oを伴う非同期処理のため、他項目の
      // 同期的なapplyTo()とは別にawaitする。
      await NiatraSerializer.restoreProjects(
        data,
        context.read<ProjectService>(),
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transferImportSuccessSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.transferImportFailedSnackbar(e.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
