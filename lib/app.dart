import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'router.dart';
import 'screens/community/widgets/community_floating_preview.dart';
import 'services/home_widget_refresh.dart';
import 'services/home_widget_bridge.dart';
import 'services/home_widget_service.dart';
import 'services/ad_placement_policy.dart';
import 'services/ad_modal_visibility_observer.dart';
import 'services/brush_service.dart';
import 'services/project_service.dart';
import 'services/google_auth_service.dart';
import 'services/community_service.dart';
import 'services/push_notification_service.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';
import 'utils/app_locale.dart';
import 'widgets/app_scroll_behavior.dart';
import 'widgets/app_chip_theme.dart';
import 'widgets/ad_banner_mock_widget.dart';

class _AdPlacementNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class NiarimApp extends StatefulWidget {
  const NiarimApp({super.key});

  @override
  State<NiarimApp> createState() => _NiarimAppState();
}

class _NiarimAppState extends State<NiarimApp> with WidgetsBindingObserver {
  final _homeWidgetBridge = HomeWidgetBridge();
  final _AdPlacementNotifier _adPlacementRefresh = _AdPlacementNotifier();
  bool _adRefreshQueued = false;
  PushNotificationService? _pushNotifications;

  /// Router delegates may notify while a child widget is building.
  /// Rebuilding the root ad frame synchronously in that phase throws a
  /// Flutter "markNeedsBuild called during build" assertion.
  /// Coalesce route/modal updates into the next post-frame callback.
  void _scheduleAdPlacementRefresh() {
    if (_adRefreshQueued || !mounted) return;
    _adRefreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adRefreshQueued = false;
      if (mounted) _adPlacementRefresh.refresh();
    });
  }

  /// 直近にウィジェットへ書き出した「テーマ色＋表示言語」。ウィジェットの
  /// 意匠はテーマ配色と文言の両方を焼き込んだ画像なので、どちらが変わっても
  /// 焼き直す必要がある。
  String? _lastPushedWidgetKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routerDelegate.addListener(_scheduleAdPlacementRefresh);
    adModalVisibilityObserver.isModalVisible.addListener(
      _scheduleAdPlacementRefresh,
    );
    // ホーム画面ウィジェットのタップで指定されたルートを開く。
    // go()ではなくpush()を使う（go()は履歴を丸ごと置き換えるため、
    // ウィジェット経由で入った画面から戻れなくなる）。
    _homeWidgetBridge.onRoute = (route) {
      if (!mounted) return;
      // 作品ウィジェットの行き先は起動画面（'/'）＝Routerの初期位置なので、
      // 冷たい起動では既にそこに居る。そのままpushすると起動画面が二重に
      // 積まれるため、今いる場所と同じなら何もしない。
      final current = appRouter.routerDelegate.currentConfiguration.uri
          .toString();
      if (current == route) return;
      appRouter.push(route);
    };
    // Routerが最初のルートを構築し終える前にpush()すると遷移が失われる
    // ため、最初のフレームが出てから起動時ルートを取りに行く。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _homeWidgetBridge.init();
      if (PushNotificationService.firebaseAvailable) {
        _pushNotifications = PushNotificationService(
          auth: context.read<GoogleAuthService>(),
          community: context.read<CommunityService>(),
        )..start();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // An unfocused/backgrounded editor is not active creative time.
    // Short sessions are flushed and the optional pilot sends stop=true.
    final projects = context.read<ProjectService>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      projects.pauseWorkTracking();
      // 裏へ回ったまま終わらされても、変えたブラシの太さを失わない。
      context.read<BrushService?>()?.commitRememberedValues();
    } else if (state == AppLifecycleState.resumed) {
      projects.resumeWorkTracking();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouter.routerDelegate.removeListener(_scheduleAdPlacementRefresh);
    adModalVisibilityObserver.isModalVisible.removeListener(
      _scheduleAdPlacementRefresh,
    );
    _pushNotifications?.dispose();
    _adPlacementRefresh.dispose();
    super.dispose();
  }

  /// テーマカラー・表示言語が変わったらウィジェットの見た目も追従させる
  /// （HomeWidgetServiceが「テーマ追従」設定のときだけ配色が変わるが、
  /// ショートカットウィジェットの文言はどちらの設定でも言語に追従する）。
  ///
  /// ここの`context`は`MaterialApp.router`より**上**にいるため
  /// `AppLocalizations.of(context)`はnullになる。表示言語はアプリ自身の
  /// 設定（`SettingsService.language`）で決まるので、そのロケールから
  /// 直接引く。
  void _syncHomeWidgets(
    BuildContext context,
    ThemeService themeService,
    Locale locale,
  ) {
    final key = '${themeService.current.accentColor.toARGB32()}/$locale';
    if (_lastPushedWidgetKey == key) return;
    _lastPushedWidgetKey = key;
    final widgets = context.read<HomeWidgetService>();
    final projects = context.read<ProjectService>();
    // build中に非同期処理を始めないよう、フレーム確定後に回す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshHomeWidgets(
        widgets: widgets,
        projects: projects,
        theme: themeService,
        l10n: lookupAppLocalizations(locale),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    // 表示言語（日本語・English・简体中文・한국어・繁體中文・Français・Españolの7言語対応）。
    final language = context.watch<SettingsService>().language;
    _syncHomeWidgets(context, themeService, localeFromLanguageCode(language));
    return MaterialApp.router(
      title: 'NIARIM',
      scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: themeService.themeData,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: appRouter,
      locale: localeFromLanguageCode(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 画面全体を覆う一番外側でポインターイベントの種類を監視し、
      // マウス・スタイラス（ペンタブ等）の接続をSettingsServiceへ伝える。
      // CommunityFloatingPreview（コミュニティのフローティング動画
      // プレビュー）は、ルーティングされる画面（child）の外側・
      // 画面遷移をまたいで常に生き続ける層にStackでかぶせることで、
      // 「他の画面を見ながら再生し続けられる」という要件を満たしている。
      builder: (context, child) => AppChipTheme(
        child: Listener(
          onPointerDown: (e) =>
              context.read<SettingsService>().notifyPointerDeviceSeen(e.kind),
          onPointerHover: (e) =>
              context.read<SettingsService>().notifyPointerDeviceSeen(e.kind),
          behavior: HitTestBehavior.translucent,
          // Keep one anchored banner on content-bearing routes, including
          // creative canvas and timeline. Menu-only, empty, legal, paywall
          // and modal alert states remain excluded for ad quality.
          child: ListenableBuilder(
            listenable: _adPlacementRefresh,
            builder: (context, _) {
              final route =
                  appRouter.routerDelegate.currentConfiguration.uri.path;
              final projects = context.watch<ProjectService>();
              final community = context.watch<CommunityService>();
              final hasLocalContent = switch (route) {
                '/home' =>
                  projects.projects.isNotEmpty ||
                      projects.shared.isNotEmpty ||
                      projects.trash.isNotEmpty,
                '/shared' => projects.shared.isNotEmpty,
                '/trash' => projects.trash.isNotEmpty,
                '/community' => community.discoverableWorks.isNotEmpty,
                _ when route.startsWith('/community/work/') =>
                  community.byId(route.substring('/community/work/'.length)) !=
                      null,
                _ => true,
              };
              return AdPersistentRootFrame(
                coinPlacementKey: coinAdBenefitForRoute(route),
                allowBanner:
                    isBannerEligibleRoute(
                      route,
                      hasLocalContent: hasLocalContent,
                    ) &&
                    // A popup route leaves only an alert/confirmation visible.
                    // Never serve live release ads on low-content modal views.
                    (!kReleaseMode ||
                        !adModalVisibilityObserver.isModalVisible.value),
                child: Stack(
                  children: [child!, const CommunityFloatingPreview()],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
