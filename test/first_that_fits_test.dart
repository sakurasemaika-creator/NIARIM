// FirstThatFits（入る形を測った幅で選ぶ行）の、幅が変わったときの振る舞いを
// 見張る（DISC112・DISC113 のレビュー指摘）。
//
// （1）前に選ばれて並べられ、今は隠れている形の中で何かが変わると、デバッグの
//     並べ方の検査（_debugRelayoutBoundaryAlreadyMarkedNeedsLayout）に掛かり、
//     続けて部品の木が壊れた（'child._parent == this'・'_owner != null'）。
//     ドックの窓を狭めて星を押し、広げてからチップを押すと起きた。
// （2）形が替わると、キーボードのフォーカスが行の外の関係ない操作（前に
//     フォーカスを持っていた操作）へ移り、次の Space・Enter がその操作を
//     動かした（パネルでは「読み込み」、自動塗りでは検索）。同じ操作の
//     新しい形へ移ること。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/first_that_fits.dart';

/// 押した操作の名前を記録する、2つの形の行（文字のボタン／アイコン）と、
/// 行の前の関係ない操作「outside」。
class _Harness extends StatelessWidget {
  const _Harness({
    required this.width,
    required this.selected,
    required this.pressed,
  });

  final ValueNotifier<double> width;
  final ValueNotifier<bool> selected;
  final List<String> pressed;

  @override
  Widget build(BuildContext context) {
    Widget chip({required bool labelled}) => ValueListenableBuilder<bool>(
      valueListenable: selected,
      builder: (_, on, _) => FilterChip(
        key: const ValueKey('chip'),
        avatar: labelled ? const Icon(Icons.star, size: 16) : null,
        label: labelled
            ? const Text('Favourites only')
            : const Icon(Icons.star, size: 16, semanticLabel: 'Favourites'),
        selected: on,
        onSelected: (v) {
          pressed.add('chip');
          selected.value = v;
        },
      ),
    );
    Widget actions() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy),
          onPressed: () => pressed.add('copy'),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete),
          onPressed: () => pressed.add('delete'),
        ),
      ],
    );
    return MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              onPressed: () => pressed.add('outside'),
              child: const Text('Outside'),
            ),
            ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (_, w, child) => SizedBox(width: w, child: child),
              child: FirstThatFits(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [chip(labelled: true), actions()],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [chip(labelled: false), actions()],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

bool _labelShown(WidgetTester tester) =>
    find.text('Favourites only').evaluate().isNotEmpty;

void main() {
  testWidgets('（1）一度並べて隠した形の中が変わっても、並べ方の検査に掛からず'
      '部品の木も壊れない', (tester) async {
    final width = ValueNotifier<double>(600);
    final selected = ValueNotifier<bool>(false);
    final pressed = <String>[];
    addTearDown(width.dispose);
    addTearDown(selected.dispose);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) =>
        errors.add(details.exceptionAsString().split('\n').first);
    try {
      await tester.pumpWidget(
        _Harness(width: width, selected: selected, pressed: pressed),
      );
      await _settle(tester);
      expect(_labelShown(tester), isTrue);
      final chip = find.byKey(const ValueKey('chip'));

      // 狭める（星だけ）→星を押す→広げる（名前つき）→チップを押す。
      width.value = 200;
      await _settle(tester);
      expect(_labelShown(tester), isFalse);
      await tester.tap(chip);
      await _settle(tester);
      width.value = 600;
      await _settle(tester);
      expect(_labelShown(tester), isTrue);
      await tester.tap(chip);
      await _settle(tester);
      // もう一度、狭めて押し、広げて押す。
      width.value = 200;
      await _settle(tester);
      await tester.tap(chip);
      await _settle(tester);
      width.value = 600;
      await _settle(tester);
      await tester.tap(chip);
      await _settle(tester);
    } finally {
      FlutterError.onError = previous;
    }
    expect(errors, isEmpty, reason: errors.join('\n'));
    expect(find.byType(ErrorWidget), findsNothing);
    expect(pressed, ['chip', 'chip', 'chip', 'chip']);
    expect(selected.value, isFalse);
  });

  for (final (from, to) in const [(600.0, 200.0), (200.0, 600.0)]) {
    testWidgets('（2）幅が ${from.round()}→${to.round()} に変わって形が替わっても、'
        'キーボードのフォーカスは同じ操作に残り、次の Space・Enter はその操作を動かす', (tester) async {
      final width = ValueNotifier<double>(from);
      final selected = ValueNotifier<bool>(false);
      final pressed = <String>[];
      addTearDown(width.dispose);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _Harness(width: width, selected: selected, pressed: pressed),
      );
      await _settle(tester);

      Future<void> tabTo(String tooltip) async {
        for (var i = 0; i < 12; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              find
                  .ancestor(
                    of: find.byWidgetPredicate(
                      (w) => w is Focus && identical(w, focused.widget),
                    ),
                    matching: find.byTooltip(tooltip),
                  )
                  .evaluate()
                  .isNotEmpty) {
            return;
          }
        }
        fail('$tooltip にフォーカスが来ない');
      }

      // 行の外の操作を先に一度フォーカスさせる（以前はここへ戻っていた）。
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tabTo('Delete');
      width.value = to;
      await _settle(tester);
      expect(_labelShown(tester), to > from);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(pressed, ['delete']);

      // チップでも同じ（Space で切り替わる）。
      pressed.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        final focused = FocusManager.instance.primaryFocus?.context;
        final onChip =
            focused != null &&
            find
                .ancestor(
                  of: find.byWidgetPredicate(
                    (w) => w is Focus && identical(w, focused.widget),
                  ),
                  matching: find.byKey(const ValueKey('chip')),
                )
                .evaluate()
                .isNotEmpty;
        if (onChip) break;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      width.value = from;
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(pressed, ['chip']);
      expect(selected.value, isTrue);
    });
  }
}
