import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../services/theme_service.dart';
import '../utils/app_locale.dart';
import 'app_toast_messenger.dart';

/// 全データを削除して起動し直す間だけ、アプリ本体の代わりに出す画面。
///
/// この間はServiceを止めているので、Providerには一切依存しない。配色・
/// フォントは既定テーマ、表示言語は削除の前の言語設定（無ければ端末の言語）。
class AppResetProgressApp extends StatelessWidget {
  const AppResetProgressApp({super.key, this.languageCode});

  /// 削除の前の表示言語の設定。nullなら端末の言語。
  final String? languageCode;

  @override
  Widget build(BuildContext context) {
    final code =
        languageCode ??
        appLanguageCodeFor(WidgetsBinding.instance.platformDispatcher.locales);
    final locale = localeFromLanguageCode(code);
    return MaterialApp(
      title: 'NIARIM',
      debugShowCheckedModeBanner: false,
      theme: _defaultTheme(locale),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 知らせ（SnackBar）はアプリ本体と同じ決まりで出す。
      builder: (context, child) => AppToastMessenger(child: child!),
      home: const _ResetProgressScreen(),
    );
  }

  static ThemeData _defaultTheme(Locale locale) {
    final themes = ThemeService();
    try {
      return themes.themeDataFor(locale);
    } finally {
      themes.dispose();
    }
  }
}

class _ResetProgressScreen extends StatelessWidget {
  const _ResetProgressScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // 戻る操作で閉じない（途中で閉じても削除は続く。閉じると何も出ない
    // まま起動し直す）。
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.storageEraseAllInProgress,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
