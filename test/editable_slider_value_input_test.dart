import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/editable_slider_value.dart';

/// スライダーの数値をタップして直接打つ欄。範囲の中の数だけを受け付け、
/// それ以外は欄を開いたまま範囲を知らせる。以前は「NaN」「Infinity」が
/// そのまま通って値が数でなくなり、数字でない入力は黙って閉じ、範囲外の
/// 値は黙って丸めていた。
void main() {
  Future<List<num>> pump(
    WidgetTester tester, {
    required num min,
    required num max,
    required bool isInt,
  }) async {
    final changes = <num>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: EditableSliderValue(
              text: 'value',
              value: min,
              min: min,
              max: max,
              isInt: isInt,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('value'));
    await tester.pumpAndSettle();
    return changes;
  }

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('integers: only numbers in the range are taken', (tester) async {
    final changes = await pump(tester, min: 1, max: 500, isInt: true);
    final l10n = AppLocalizations.of(tester.element(find.byType(TextField)))!;
    final range = l10n.numberInputRangeError('1', '500');
    expect(find.text(range), findsOneWidget, reason: '範囲を最初から見せる');

    for (final bad in ['abc', '', '9999', '0', '-5', '1.5']) {
      await submit(tester, bad);
      expect(find.byType(TextField), findsOneWidget, reason: '「$bad」で閉じない');
      expect(find.text(range), findsOneWidget);
      expect(changes, isEmpty, reason: bad);
    }
    // 全角の数字も受け付ける。
    await submit(tester, '２５');
    expect(find.byType(TextField), findsNothing);
    expect(changes, [25]);
  });

  testWidgets('decimals: NaN and Infinity are not numbers here', (
    tester,
  ) async {
    final changes = await pump(tester, min: 0, max: 1, isInt: false);
    for (final bad in ['NaN', 'Infinity', '-Infinity', '1.5']) {
      await submit(tester, bad);
      expect(find.byType(TextField), findsOneWidget, reason: bad);
      expect(changes, isEmpty, reason: bad);
    }
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget, reason: 'OKでも同じ');
    await submit(tester, '0.55');
    expect(changes.single, closeTo(0.55, 1e-9));
  });
}
