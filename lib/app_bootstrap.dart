import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'engine/undo_manager.dart' as app_undo;
import 'services/advertising_service.dart';
import 'services/premium_service.dart';
import 'services/project_service.dart';
import 'services/settings_service.dart';
import 'services/performance_service.dart';
import 'services/brush_service.dart';
import 'services/autosave_service.dart';
import 'services/tone_service.dart';
import 'services/stamp_service.dart';
import 'services/filter_service.dart';
import 'services/theme_service.dart';
import 'services/save_tree_service.dart';
import 'services/autofill_preset_service.dart';
import 'services/material_service.dart';
import 'services/quick_tool_service.dart';
import 'services/shortcut_service.dart';
import 'services/workspace_preset_service.dart';
import 'services/watermark_service.dart';
import 'services/share_intent_service.dart';
import 'services/font_service.dart';
import 'services/first_use_tooltip_service.dart';
import 'services/palette_service.dart';
import 'services/work_folder_service.dart';

/// アプリ全体で使う各Serviceを初期化し、`MultiProvider`へ渡す
/// プロバイダー一覧を組み立てる。main()と、アプリ全体を実際に起動して
/// 動作確認する自動テスト（test/app_smoke_test.dart）の両方から
/// 呼び出せるよう共通化している（2箇所で初期化手順が個別に食い違う
/// のを防ぐため）。
Future<List<SingleChildWidget>> buildAppProviders() async {
  final settingsService = SettingsService();
  await settingsService.init();

  final performanceService = PerformanceService();
  await performanceService.detectDeviceCapability();

  final premiumService = PremiumService();
  await premiumService.init();
  // エンドカードのプレミアム既定設定（デフォルトで非表示にする）は
  // プレミアム限定の設定のため、権限が切れて無料会員に戻った時点で
  // 自動的にOFFへリセットする（無料会員に戻ってもこっそり非表示のまま
  // にはならないようにする）。
  premiumService.addListener(() {
    if (!premiumService.isPremium &&
        settingsService.endCardDefaultHiddenForPremium) {
      settingsService.setEndCardDefaultHiddenForPremium(false);
    }
  });

  final advertisingService = AdvertisingService(premiumService: premiumService);
  await advertisingService.init();

  final projectService = ProjectService();
  // 端末性能判定に応じて、TileManagerの合成キャッシュ上限を絞る。見た目・
  // 機能は変わらず、低スペック端末でのメモリ使用量のみを抑える（init()より
  // 前に設定し、起動時読み込み分のTileManagerにも反映させる）。
  projectService.configureTileCacheBudget(
    switch (performanceService.qualityLevel) {
      QualityLevel.low => 6, // 最大概算約48MB程度
      QualityLevel.medium => 10, // 最大概算約80MB程度
      QualityLevel.high => 16, // 従来通り（最大概算約130MB程度）
      QualityLevel.custom => 10,
    },
  );
  await projectService.init();
  // ゴミ箱の自動削除設定（設定画面：OFF/30日/60日/90日）に基づき、
  // 保持期限を過ぎたプロジェクトを起動時に完全削除する
  await projectService.sweepExpiredTrash(settingsService.trashAutoDeleteDays);

  final brushService = BrushService();
  await brushService.init();

  final toneService = ToneService();
  await toneService.init();

  final stampService = StampService();
  await stampService.init();

  final filterService = FilterService();
  await filterService.init();

  final themeService = ThemeService();
  await themeService.init();

  final autosaveService = AutosaveService();
  await autosaveService.init();
  final saveTreeService = SaveTreeService();
  final autofillPresetService = AutofillPresetService();
  await autofillPresetService.init();
  final materialService = MaterialService();
  final quickToolService = QuickToolService();
  await quickToolService.init();
  final shortcutService = ShortcutService();
  await shortcutService.init();

  final workspacePresetService = WorkspacePresetService();
  await workspacePresetService.init();

  final watermarkService = WatermarkService();
  await watermarkService.init();

  final fontService = FontService();
  await fontService.init();

  final firstUseTooltipService = FirstUseTooltipService();
  await firstUseTooltipService.init();

  final paletteService = PaletteService();
  await paletteService.init();

  final workFolderService = WorkFolderService();
  await workFolderService.init();

  final shareIntentService = ShareIntentService();
  await shareIntentService.init();
  final undoManager = app_undo.UndoManager();
  undoManager.setMaxUndoCount(settingsService.undoLimit);
  projectService.setUndoManager(undoManager);
  // 品質設定に応じてスロット数・保存方式を初期設定
  // ツリー方式の場合はスロット数設定不要
  if (performanceService.saveMode == SaveMode.slot) {
    saveTreeService.setSlotMax(performanceService.slotCount);
  }
  saveTreeService.setTreeMode(performanceService.saveMode == SaveMode.tree);

  return [
    ChangeNotifierProvider.value(value: settingsService),
    ChangeNotifierProvider.value(value: performanceService),
    ChangeNotifierProvider.value(value: premiumService),
    ChangeNotifierProvider.value(value: advertisingService),
    ChangeNotifierProvider.value(value: projectService),
    ChangeNotifierProvider.value(value: brushService),
    ChangeNotifierProvider.value(value: toneService),
    ChangeNotifierProvider.value(value: stampService),
    ChangeNotifierProvider.value(value: filterService),
    ChangeNotifierProvider.value(value: themeService),
    ChangeNotifierProvider.value(value: autosaveService),
    ChangeNotifierProvider.value(value: saveTreeService),
    ChangeNotifierProvider.value(value: autofillPresetService),
    ChangeNotifierProvider.value(value: materialService),
    ChangeNotifierProvider.value(value: quickToolService),
    ChangeNotifierProvider.value(value: shortcutService),
    ChangeNotifierProvider.value(value: workspacePresetService),
    ChangeNotifierProvider.value(value: watermarkService),
    ChangeNotifierProvider.value(value: fontService),
    ChangeNotifierProvider.value(value: firstUseTooltipService),
    ChangeNotifierProvider.value(value: paletteService),
    ChangeNotifierProvider.value(value: workFolderService),
    Provider<ShareIntentService>.value(value: shareIntentService),
    ChangeNotifierProvider<app_undo.UndoManager>.value(value: undoManager),
  ];
}
