import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
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
import 'services/workspace_preset_service.dart';
import 'services/watermark_service.dart';
import 'services/share_intent_service.dart';
import 'services/font_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final settingsService = SettingsService();
  await settingsService.init();

  final performanceService = PerformanceService();
  await performanceService.detectDeviceCapability();

  final premiumService = PremiumService();
  await premiumService.init();

  final advertisingService = AdvertisingService(premiumService: premiumService);
  await advertisingService.init();

  final projectService = ProjectService();
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
  final materialService = MaterialService();
  final quickToolService = QuickToolService();
  await quickToolService.init();

  final workspacePresetService = WorkspacePresetService();
  await workspacePresetService.init();

  final watermarkService = WatermarkService();
  await watermarkService.init();

  final fontService = FontService();
  await fontService.init();

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

  runApp(
    MultiProvider(
      providers: [
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
        ChangeNotifierProvider.value(value: workspacePresetService),
        ChangeNotifierProvider.value(value: watermarkService),
        ChangeNotifierProvider.value(value: fontService),
        Provider<ShareIntentService>.value(value: shareIntentService),
        ChangeNotifierProvider<app_undo.UndoManager>.value(value: undoManager),
      ],
      child: const MiranimaApp(),
    ),
  );
}
