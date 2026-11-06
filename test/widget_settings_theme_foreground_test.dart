import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/widget_settings_screen.dart';
import 'package:niarim/services/home_widget_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Widget custom-color preview defaults to explicit button text color, not menu background',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      const chosenForeground = Color(0xFF45A1C2);
      const differentMenuBackground = Color(0xFFF1E8DD);
      theme.previewCurrent(
        theme.current.copyWith(
          buttonTextColor: chosenForeground,
          menuBgColor: differentMenuBackground,
        ),
      );

      final settings = SettingsService();
      final widgets = HomeWidgetService();
      await widgets.setBackgroundColor(
        HomeWidgetKind.create,
        const Color(0xFF121212).toARGB32(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeService>.value(value: theme),
            ChangeNotifierProvider<HomeWidgetService>.value(value: widgets),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: theme.themeData,
            home: const WidgetSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text('文字・アイコンの色').first;
      await tester.scrollUntilVisible(
        label,
        100,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await tester.pumpAndSettle();

      final tile = find
          .ancestor(of: label, matching: find.byType(ListTile))
          .first;
      final swatchColors = tester
          .widgetList<Container>(
            find.descendant(of: tile, matching: find.byType(Container)),
          )
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color)
          .toList();

      expect(swatchColors, contains(chosenForeground));
      expect(swatchColors, isNot(contains(differentMenuBackground)));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      widgets.dispose();
      settings.dispose();
      theme.dispose();
    },
  );
}
