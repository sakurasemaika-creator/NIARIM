import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'utils/app_error_reporter.dart';

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
import 'services/custom_automation_service.dart';
import 'services/shortcut_service.dart';
import 'services/workspace_preset_service.dart';
import 'services/watermark_service.dart';
import 'services/share_intent_service.dart';
import 'services/font_service.dart';
import 'services/first_use_tooltip_service.dart';
import 'services/palette_service.dart';
import 'services/pixel_art_palette_service.dart';
import 'services/work_folder_service.dart';
import 'services/api/niarim_api_config.dart';
import 'services/community_service.dart';
import 'services/community_preview_service.dart';
import 'services/google_auth_service.dart';
import 'services/home_widget_service.dart';

/// アプリ全体で使う各Serviceを初期化し、`MultiProvider`へ渡す
/// プロバイダー一覧を組み立てる。main()と、アプリ全体を実際に起動して
/// 動作確認する自動テスト（test/app_smoke_test.dart）の両方から
/// 呼び出せるよう共通化している（2箇所で初期化手順が個別に食い違う
/// のを防ぐため）。
Future<List<SingleChildWidget>> buildAppProviders() async =>
    (await buildAppServices()).providers;

/// Owns every service created by one startup attempt, including resources that
/// were allocated before a later initializer failed. Value providers leave
/// disposal to this owner so a cancelled startup can also release unmounted
/// services.
class AppServices {
  AppServices(this.providers, this._disposers);

  final List<SingleChildWidget> providers;
  final List<VoidCallback> _disposers;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final dispose in _disposers.reversed) {
      try {
        dispose();
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
  }
}

Future<AppServices> buildAppServices() async {
  final disposers = <VoidCallback>[];
  T own<T extends ChangeNotifier>(T service) {
    disposers.add(service.dispose);
    return service;
  }

  try {
    final settingsService = own(SettingsService());
    await settingsService.init();

    final performanceService = own(PerformanceService());
    await performanceService.detectDeviceCapability();

    final premiumService = own(PremiumService());
    await premiumService.init();
    premiumService.addListener(() {
      if (!premiumService.isPremium &&
          settingsService.endCardDefaultHiddenForPremium) {
        settingsService.setEndCardDefaultHiddenForPremium(false);
      }
    });

    final advertisingService = own(
      AdvertisingService(premiumService: premiumService),
    );
    await advertisingService.init();

    final projectService = own(ProjectService());
    projectService.configureTileCacheBudget(
      switch (performanceService.qualityLevel) {
        QualityLevel.low => 6,
        QualityLevel.medium => 10,
        QualityLevel.high => 16,
        QualityLevel.custom => 10,
      },
    );
    await projectService.init();

    final brushService = own(BrushService());
    await brushService.init();

    final toneService = own(ToneService());
    await toneService.init();

    final stampService = own(StampService());
    await stampService.init();

    final filterService = own(FilterService());
    await filterService.init();

    final themeService = own(ThemeService());
    await themeService.init();

    final autosaveService = own(AutosaveService());
    await autosaveService.init();
    final saveTreeService = own(SaveTreeService());
    final autofillPresetService = own(AutofillPresetService());
    await autofillPresetService.init();
    final materialService = own(MaterialService());
    final quickToolService = own(QuickToolService());
    await quickToolService.init();
    final customAutomationService = own(CustomAutomationService());
    await customAutomationService.init();
    final shortcutService = own(ShortcutService());
    await shortcutService.init();

    final workspacePresetService = own(WorkspacePresetService());
    await workspacePresetService.init();

    final watermarkService = own(WatermarkService());
    await watermarkService.init();

    final fontService = own(FontService());
    await fontService.init();

    final firstUseTooltipService = own(FirstUseTooltipService());
    await firstUseTooltipService.init();

    final paletteService = own(PaletteService());
    await paletteService.init();

    final pixelArtPaletteService = own(PixelArtPaletteService());
    await pixelArtPaletteService.init();

    final workFolderService = own(WorkFolderService());
    await workFolderService.init();

    final homeWidgetService = own(HomeWidgetService());
    await homeWidgetService.init();

    final googleAuthService = own(GoogleAuthService());
    await googleAuthService.init();

    final communityService = own(
      CommunityService(
        api: NiarimApiConfig.createApi(
          tokenProvider: googleAuthService.backendIdToken,
        ),
      ),
    );
    final communityPreviewService = own(CommunityPreviewService());

    final shareIntentService = ShareIntentService();
    disposers.add(shareIntentService.dispose);
    final undoManager = own(app_undo.UndoManager());
    undoManager.setMaxUndoCount(settingsService.undoLimit);
    projectService.setUndoManager(undoManager);
    if (performanceService.saveMode == SaveMode.slot) {
      saveTreeService.setSlotMax(performanceService.slotCount);
    }
    saveTreeService.setTreeMode(performanceService.saveMode == SaveMode.tree);

    await projectService.sweepExpiredTrash(settingsService.trashAutoDeleteDays);
    await shareIntentService.init();

    return AppServices([
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
      ChangeNotifierProvider.value(value: customAutomationService),
      ChangeNotifierProvider.value(value: shortcutService),
      ChangeNotifierProvider.value(value: workspacePresetService),
      ChangeNotifierProvider.value(value: watermarkService),
      ChangeNotifierProvider.value(value: fontService),
      ChangeNotifierProvider.value(value: firstUseTooltipService),
      ChangeNotifierProvider.value(value: paletteService),
      ChangeNotifierProvider.value(value: pixelArtPaletteService),
      ChangeNotifierProvider.value(value: workFolderService),
      ChangeNotifierProvider.value(value: homeWidgetService),
      ChangeNotifierProvider.value(value: googleAuthService),
      ChangeNotifierProvider.value(value: communityService),
      ChangeNotifierProvider.value(value: communityPreviewService),
      Provider<ShareIntentService>.value(value: shareIntentService),
      ChangeNotifierProvider<app_undo.UndoManager>.value(value: undoManager),
    ], disposers);
  } catch (error, stack) {
    AppServices(const [], disposers).dispose();
    Error.throwWithStackTrace(error, stack);
  }
}
