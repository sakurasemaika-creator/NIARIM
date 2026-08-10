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
    // 表示言語（設定画面「言語」、仕様書08＋タスク#102）。
    // 日本語・English・简体中文・한국어・繁體中文・Français・Españolの7言語対応。
    final language = context.watch<SettingsService>().language;
    return MaterialApp.router(
      title: 'NIARIM',
      debugShowCheckedModeBanner: false,
      theme: themeService.themeData,
      routerConfig: appRouter,
      locale: _localeFromCode(language),
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
