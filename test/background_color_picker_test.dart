import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/background_color_picker.dart';

void main() {
  test('background presets contain only white, black and transparent', () {
    expect(kProjectBackgroundColorChoices,
        [Colors.white, Colors.black, Colors.transparent]);
    expect(kProjectBackgroundColorChoices, isNot(contains(const Color(0xFFF5F5DC))));
  });

  testWidgets('selected white swatch stays pure white with no pink inside',
      (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFFF557A));
    var current = Colors.white;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.from(colorScheme: scheme),
      home: Scaffold(body: StatefulBuilder(
        builder: (context, update) => BackgroundColorSwatchPicker(
          selectedColor: current,
          onChanged: (color) => update(() => current = color),
        ),
      )),
    ));

    final white = find.byKey(const ValueKey<Color>(Colors.white));
    final black = find.byKey(const ValueKey<Color>(Colors.black));
    final transparent = find.byKey(const ValueKey<Color>(Colors.transparent));
    expect(white, findsOneWidget);
    expect(black, findsOneWidget);
    expect(transparent, findsOneWidget);

    final fill = tester.widget<ColoredBox>(
      find.descendant(of: white, matching: find.byType(ColoredBox)));
    expect(fill.color, Colors.white);
    expect(find.descendant(of: white, matching: find.byIcon(Icons.check)),
        findsNothing, reason: 'The inside of the white swatch must stay white');
    final swatch = tester.widget<Container>(
      find.descendant(of: white, matching: find.byType(Container)).first);
    final outline = (swatch.decoration! as BoxDecoration).border! as Border;
    expect(outline.top.color, scheme.onSurfaceVariant);
    expect(outline.top.color, isNot(scheme.primary));

    await tester.tap(black);
    await tester.pump();
    expect(current, Colors.black);
    expect(find.descendant(of: black, matching: find.byIcon(Icons.check)),
        findsOneWidget);
    await tester.tap(transparent);
    await tester.pump();
    expect(current, Colors.transparent);
    expect(find.descendant(of: transparent,
        matching: find.byType(CustomPaint)), findsWidgets);
    await tester.tap(white);
    await tester.pump();
    expect(current, Colors.white);
    expect(find.descendant(of: white, matching: find.byIcon(Icons.check)),
        findsNothing);
  });
}
