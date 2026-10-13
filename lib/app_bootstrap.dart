import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// 起動処理のどこかが失敗したことを表す。[step]は失敗した初期化処理の
/// 名前で、起動失敗画面の詳細とエラー記録に出す。
class AppStartupException implements Exception {
  AppStartupException({
    required this.step,
    required this.error,
    required this.stackTrace,
    this.languageCode,
  });

  final String step;
  final Object error;
  final StackTrace stackTrace;

  /// 失敗する前に読めていた表示言語の設定。読めていなければnull
  /// （起動失敗画面は端末の言語で出す）。
  final String? languageCode;

  @override
  String toString() => 'Startup failed at $step: $error';
}

/// 各初期化処理の直前に、その処理の名前で呼ばれる。テストとデバッグ
/// ビルドが特定の処理を失敗させ、それまでに作ったServiceが片付くことと
/// 起動失敗画面からやり直せることを確かめるために使う。
typedef StartupStepHook = FutureOr<void> Function(String step);

/// アプリ全体で使う各Serviceを初期化し、`MultiProvider`へ渡す
/// プロバイダー一覧を組み立てる。main()と、アプリ全体を実際に起動して
/// 動作確認する自動テスト（test/app_smoke_test.dart）の両方から
/// 呼び出せるよう共通化している（2箇所で初期化手順が個別に食い違う
/// のを防ぐため）。
///
/// 途中の初期化が例外を投げた場合は、それまでに作ったServiceを作った順の
/// 逆に破棄してから[AppStartupException]を投げる。破棄しないまま
/// 起動をやり直すと、課金の購入通知の購読やService間のリスナーが
/// 二重に残り、同じ購入を二度処理する等の副作用が出るため。
Future<List<SingleChildWidget>> buildAppProviders({
  StartupStepHook? beforeStep,
  @visibleForTesting void Function(ChangeNotifier service)? debugOnCreated,
}) async {
  final disposers = <void Function()>[];
  T own<T extends ChangeNotifier>(T service) {
    disposers.add(service.dispose);
    debugOnCreated?.call(service);
    return service;
  }

  var step = 'settings';
  String? languageCode;
  Future<void> enter(String name) async {
    step = name;
    final hook = beforeStep?.call(name);
    if (hook is Future<void>) await hook;
  }

  try {
    return await _buildAppProviders(own, enter, disposers, (code) {
      languageCode = code;
    });
  } catch (error, stackTrace) {
    for (final dispose in disposers.reversed) {
      try {
        dispose();
      } catch (disposeError, disposeStack) {
        debugPrint(
          'Could not dispose a service after startup failed: '
          '$disposeError',
        );
        debugPrintStack(stackTrace: disposeStack);
      }
    }
    throw AppStartupException(
      step: step,
      error: error,
      stackTrace: stackTrace,
      languageCode: languageCode,
    );
  }
}

Future<List<SingleChildWidget>> _buildAppProviders(
  T Function<T extends ChangeNotifier>(T service) own,
  Future<void> Function(String step) enter,
  List<void Function()> disposers,
  void Function(String languageCode) languageLoaded,
) async {
  await enter('settings');
  final settingsService = own(SettingsService());
  await settingsService.init();
  languageLoaded(settingsService.language);

  await enter('performance');
  final performanceService = own(PerformanceService());
  await performanceService.detectDeviceCapability();

  await enter('premium');
  final premiumService = own(PremiumService());
  await premiumService.init();
  premiumService.addListener(() {
    if (!premiumService.isPremium &&
        settingsService.endCardDefaultHiddenForPremium) {
      settingsService.setEndCardDefaultHiddenForPremium(false);
    }
  });

  await enter('advertising');
  final advertisingService = own(
    AdvertisingService(premiumService: premiumService),
  );
  await advertisingService.init();

  await enter('project');
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
  await projectService.sweepExpiredTrash(settingsService.trashAutoDeleteDays);

  await enter('brush');
  final brushService = own(BrushService());
  await brushService.init();

  await enter('tone');
  final toneService = own(ToneService());
  await toneService.init();

  await enter('stamp');
  final stampService = own(StampService());
  await stampService.init();

  await enter('filter');
  final filterService = own(FilterService());
  await filterService.init();

  await enter('theme');
  final themeService = own(ThemeService());
  await themeService.init();

  await enter('autosave');
  final autosaveService = own(AutosaveService());
  await autosaveService.init();
  await enter('save_tree');
  final saveTreeService = own(SaveTreeService());
  await enter('autofill_preset');
  final autofillPresetService = own(AutofillPresetService());
  await autofillPresetService.init();
  await enter('material');
  final materialService = own(MaterialService());
  await enter('quick_tool');
  final quickToolService = own(QuickToolService());
  await quickToolService.init();
  await enter('custom_automation');
  final customAutomationService = own(CustomAutomationService());
  await customAutomationService.init();
  await enter('shortcut');
  final shortcutService = own(ShortcutService());
  await shortcutService.init();

  await enter('workspace_preset');
  final workspacePresetService = own(WorkspacePresetService());
  await workspacePresetService.init();

  await enter('watermark');
  final watermarkService = own(WatermarkService());
  await watermarkService.init();

  await enter('font');
  final fontService = own(FontService());
  await fontService.init();

  await enter('first_use_tooltip');
  final firstUseTooltipService = own(FirstUseTooltipService());
  await firstUseTooltipService.init();

  await enter('palette');
  final paletteService = own(PaletteService());
  await paletteService.init();

  await enter('pixel_art_palette');
  final pixelArtPaletteService = own(PixelArtPaletteService());
  await pixelArtPaletteService.init();

  await enter('work_folder');
  final workFolderService = own(WorkFolderService());
  await workFolderService.init();

  await enter('home_widget');
  final homeWidgetService = own(HomeWidgetService());
  await homeWidgetService.init();

  await enter('google_auth');
  final googleAuthService = own(GoogleAuthService());
  await googleAuthService.init();

  await enter('community');
  final communityService = own(
    CommunityService(
      api: NiarimApiConfig.createApi(
        tokenProvider: googleAuthService.backendIdToken,
      ),
    ),
  );
  await enter('community_preview');
  final communityPreviewService = own(CommunityPreviewService());
  // The poster's identity follows the signed-in Google account: signing out
  // or switching accounts forgets it, and signing in learns it again.
  String? signedInAccountId = googleAuthService.account?.id;
  // The remembered poster id is restored first so their own works and
  // settings are theirs from the start; GET /me/works then confirms it, and
  // their bookmarks, follows and reposts follow.
  Future<void> learnPoster(String accountId) async {
    try {
      await communityService.restoreOwner(accountId);
      await communityService.loadOwnWorks(accountKey: accountId);
      await communityService.loadSocial();
    } catch (error) {
      debugPrint('Could not load the poster\'s community data: $error');
    }
  }

  void followSignedInAccount() {
    final accountId = googleAuthService.account?.id;
    if (accountId == signedInAccountId) return;
    signedInAccountId = accountId;
    communityService.forgetOwner();
    if (accountId != null && communityService.isBackendConnected) {
      learnPoster(accountId);
    }
  }

  googleAuthService.addListener(followSignedInAccount);
  if (signedInAccountId case final accountId?
      when communityService.isBackendConnected) {
    learnPoster(accountId);
  }

  await enter('share_intent');
  final shareIntentService = ShareIntentService();
  disposers.add(shareIntentService.dispose);
  await shareIntentService.init();
  final undoManager = app_undo.UndoManager();
  undoManager.setMaxUndoCount(settingsService.undoLimit);
  projectService.setUndoManager(undoManager);
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
  ];
}
