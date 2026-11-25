import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/signal_colors.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/confirm_delete.dart';

/// 削除の確かめのボタンはテーマの警告色で塗り（取り消せない操作）、ほかの
/// 塗りのボタンは差し色のまま（警告色を主な操作に使わない）。
void main() {
  for (final preset in [
    AppThemePreset.defaultLight,
    AppThemePreset.defaultDark,
    // 赤い差し色のテーマで、自分の警告色を選んだもの。
    AppThemePreset.defaultLight.copyWith(
      id: 'own_warning',
      accentColor: const Color(0xFFE53935),
      warningColor: const Color(0xFF6A1B9A),
    ),
  ]) {
    testWidgets('${preset.id}: confirmDelete uses the warning colour', (
      tester,
    ) async {
      final service = ThemeService();
      addTearDown(service.dispose);
      service.previewCurrent(preset);
      final theme = service.themeData;
      final signals = theme.extension<SignalColors>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  FilledButton(
                    key: const Key('plainFilled'),
                    onPressed: () {},
                    child: const Text('Save'),
                  ),
                  TextButton(
                    onPressed: () => confirmDelete(context, itemName: 'A'),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('ja'));

      Material fillOf(Finder button) => tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      final confirm = find.ancestor(
        of: find.text(l10n.commonDelete).last,
        matching: find.byType(FilledButton),
      );
      expect(confirm, findsOneWidget);
      expect(fillOf(confirm).color, signals.warning);
      expect(fillOf(confirm).textStyle?.color, signals.onWarning);
      expect(signals.warning, preset.warningColor);

      final plain = find.byKey(const Key('plainFilled'));
      expect(fillOf(plain).color, theme.colorScheme.primary);
      expect(fillOf(plain).color, isNot(signals.warning));
    });
  }
}
