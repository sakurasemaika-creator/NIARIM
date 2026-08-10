import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';

class NiarimApp extends StatelessWidget {
  const NiarimApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    // OSのbrightnessをThemeServiceに注入（BaseTheme.system対応）
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    themeService.updateSystemBrightness(platformBrightness);
    // 表示言語（設定画面「言語」、仕様書08）。日本語/Englishの2言語対応。
    final language = context.watch<SettingsService>().language;
    return MaterialApp.router(
      title: 'NIARIM',
      debugShowCheckedModeBanner: false,
      theme: themeService.themeData,
      routerConfig: appRouter,
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
