import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/background_color_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('background presets are white and transparent; any other colour comes '
      'from the colour picker', () {
    expect(kProjectBackgroundColorChoices, [Colors.white, Colors.transparent]);
    expect(
      kProjectBackgroundColorChoices,
      isNot(contains(const Color(0xFFF5F5DC))),
    );
  });

  testWidgets('selected white swatch stays pure white with no pink inside', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFFF557A));
    var current = Colors.white;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.from(colorScheme: scheme),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => BackgroundColorSwatchPicker(
              selectedColor: current,
              onChanged: (color) => update(() => current = color),
            ),
          ),
        ),
      ),
    );

    final white = find.byKey(const ValueKey<Color>(Colors.white));
    final other = find.byKey(kBackgroundColorOtherKey);
    final transparent = find.byKey(const ValueKey<Color>(Colors.transparent));
    expect(white, findsOneWidget);
    expect(other, findsOneWidget);
    expect(transparent, findsOneWidget);

    final fill = tester.widget<ColoredBox>(
      find.descendant(of: white, matching: find.byType(ColoredBox)),
    );
    expect(fill.color, Colors.white);
    expect(
      find.descendant(of: white, matching: find.byIcon(Icons.check)),
      findsNothing,
      reason: 'The inside of the white swatch must stay white',
    );
    final swatch = tester.widget<Container>(
      find.descendant(of: white, matching: find.byType(Container)).first,
    );
    final outline = (swatch.decoration! as BoxDecoration).border! as Border;
    expect(outline.top.color, scheme.onSurfaceVariant);
    expect(outline.top.color, isNot(scheme.primary));
    final whiteFill = find.descendant(
      of: white,
      matching: find.byType(ClipOval),
    );
    expect(whiteFill, findsOneWidget);
    expect(tester.getSize(whiteFill), const Size(40, 40));

    expect(tester.getSemantics(white).label, 'White');
    expect(
      tester.getSemantics(white).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(tester.getSemantics(transparent).label, 'Transparent');
    expect(tester.getSize(other), const Size(48, 48));
    expect(tester.getSemantics(other).label, 'Other color');
    expect(
      find.descendant(of: other, matching: find.byIcon(Icons.palette_outlined)),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(current, Colors.transparent);
    expect(
      find.descendant(of: transparent, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    final transparentContainer = tester.widget<Container>(
      find.descendant(of: transparent, matching: find.byType(Container)).first,
    );
    final transparentOutline =
        (transparentContainer.decoration! as BoxDecoration).border! as Border;
    expect(transparentOutline.top.color, scheme.onSurfaceVariant);
    expect(transparentOutline.top.color, isNot(scheme.primary));
    expect(
      tester.getSize(
        find.descendant(of: transparent, matching: find.byType(ClipOval)),
      ),
      const Size(40, 40),
    );
    expect(
      find.descendant(of: transparent, matching: find.byType(CustomPaint)),
      findsWidgets,
    );
    await tester.tap(white);
    await tester.pump();
    expect(current, Colors.white);
    expect(
      find.descendant(of: white, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets('“other color” opens the colour picker without opacity and '
      'hands over one opaque colour when it closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final palettes = PaletteService();
    var current = Colors.white;
    final changes = <Color>[];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PaletteService>.value(value: palettes),
          ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => BackgroundColorSwatchPicker(
                selectedColor: current,
                onChanged: (color) => update(() {
                  current = color;
                  changes.add(color);
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(kBackgroundColorOtherKey));
    await tester.pumpAndSettle();
    final panel = find.byType(ColorPickerPanel);
    expect(panel, findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      find.descendant(
        of: panel,
        matching: find.text(l10n.colorPickerOpacityLabel),
      ),
      findsNothing,
    );
    // A colour typed with an opacity is kept opaque.
    await tester.enterText(
      find.descendant(of: panel, matching: find.byType(TextField)).first,
      '11223380',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, isEmpty, reason: 'nothing is handed over while open');
    Navigator.of(tester.element(panel)).pop();
    await tester.pumpAndSettle();
    expect(changes, [const Color(0xFF112233)]);
    final other = find.byKey(kBackgroundColorOtherKey);
    expect(
      find.descendant(of: other, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<ColoredBox>(
            find.descendant(of: other, matching: find.byType(ColoredBox)),
          )
          .map((box) => box.color),
      contains(const Color(0xFF112233)),
    );
    // Opening it again and closing without a change hands over nothing.
    await tester.tap(other);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ColorPickerPanel))).pop();
    await tester.pumpAndSettle();
    expect(changes, hasLength(1));
  });
}
