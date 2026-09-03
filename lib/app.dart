import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'screens/community/widgets/community_floating_preview.dart';
import 'screens/settings/widget_settings_screen.dart';
import 'services/home_widget_bridge.dart';
import 'services/home_widget_service.dart';
import 'services/project_service.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';

/// タッチだけでなくマウス・トラックパッドのドラッグでもスクロール・
/// PageViewのスワイプができるようにする（Flutterの既定のScrollBehaviorは
/// マウスドラッグを対象外にしており、Chrome等デスクトップ環境でTipsの
/// 詳細ポップアップ（PageView）を横スワイプできなくなっていた不具合の
/// 原因だった）。
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

class NiarimApp extends StatefulWidget {
  const NiarimApp({super.key});

  @override
  State<NiarimApp> createState() => _NiarimAppState();
}

class _NiarimAppState extends State<NiarimApp> {
  final _homeWidgetBridge = HomeWidgetBridge();
  int? _lastPushedThemeColor;

  @override
  void initState() {
    super.initState();
    // ホーム画面ウィジェットのタップで指定されたルートを開く。
    // go()ではなくpush()を使う（go()は履歴を丸ごと置き換えるため、
    // ウィジェット経由で入った画面から戻れなくなる）。
    _homeWidgetBridge.onRoute = (route) {
      if (mounted) appRouter.push(route);
    };
    // Routerが最初のルートを構築し終える前にpush()すると遷移が失われる
    // ため、最初のフレームが出てから起動時ルートを取りに行く。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeWidgetBridge.init();
    });
  }

  /// テーマカラーが変わったらウィジェットの色も追従させる
  /// （HomeWidgetServiceが「テーマ追従」設定のときだけ見た目が変わる）。
  void _syncHomeWidgets(BuildContext context, ThemeService themeService) {
    final color = themeService.current.accentColor.toARGB32();
    if (_lastPushedThemeColor == color) return;
    _lastPushedThemeColor = color;
    final widgets = context.read<HomeWidgetService>();
    final projects = context.read<ProjectService>();
    // build中に非同期処理を始めないよう、フレーム確定後に回す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshHomeWidgets(
        widgets: widgets,
        projects: projects,
        theme: themeService,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    _syncHomeWidgets(context, themeService);
    // 表示言語（日本語・English・简体中文・한국어・繁體中文・Français・Españolの7言語対応）。
    final language = context.watch<SettingsService>().language;
    return MaterialApp.router(
      title: 'NIARIM',
      debugShowCheckedModeBanner: false,
      theme: themeService.themeData,
      scrollBehavior: _AppScrollBehavior(),
      routerConfig: appRouter,
      locale: _localeFromCode(language),
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
      builder: (context, child) => Listener(
        onPointerDown: (e) =>
            context.read<SettingsService>().notifyPointerDeviceSeen(e.kind),
        onPointerHover: (e) =>
            context.read<SettingsService>().notifyPointerDeviceSeen(e.kind),
        behavior: HitTestBehavior.translucent,
        child: Stack(children: [child!, const CommunityFloatingPreview()]),
      ),
    );
  }
}

/// SettingsService.languageに保存されている言語コードからLocaleを組み立てる。
/// 繁体字中国語（'zh_Hant'）はscriptCodeを伴うロケールのため、単純な
/// Locale(code)コンストラクタでは正しく解決できず、
/// Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')で
/// 明示的に組み立てる必要がある。他の言語はlanguageCodeのみで解決できる。
Locale _localeFromCode(String code) {
  if (code == 'zh_Hant') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  return Locale(code);
}
