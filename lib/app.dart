import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'screens/community/widgets/community_floating_preview.dart';
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

class NiarimApp extends StatelessWidget {
  const NiarimApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
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
        child: Stack(
          children: [
            child!,
            const CommunityFloatingPreview(),
          ],
        ),
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
