import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/theme_service.dart';

/// The AppBar title starts on the same 16dp content gutter used by the
/// shared input and page-layout system. Keep this invariant for every locale.
void main() {
  test('AppBar title spacing follows the shared 16dp content gutter', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final theme = ThemeService().themeDataFor(locale);
      expect(
        theme.appBarTheme.titleSpacing,
        16,
        reason: locale.toLanguageTag(),
      );
    }
  });
}
