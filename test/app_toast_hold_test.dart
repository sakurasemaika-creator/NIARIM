import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_toast_messenger.dart';

/// 知らせに触れている間（マウスを載せている・指で押さえている・キーボードの
/// フォーカスが「元に戻す」等にある間）は消さない（所有者の判断、
/// 2026-11-22「触れている間は消さない」、DISC125）。離したら残りの時間
/// （短くても[kToastResumeAfterHold]）で消える。触れていない知らせは
/// 今までどおり5秒以内に消える（`app_toast_messenger_test.dart`）。
void main() {
  const frame = Duration(milliseconds: 16);
  late ThemeData theme;
  late GlobalKey<ScaffoldMessengerState> messengerKey;

  setUp(() {
    messengerKey = GlobalKey<ScaffoldMessengerState>();
    final themes = ThemeService();
    theme = themes.themeData;
    themes.dispose();
  });

  Widget app() => MaterialApp(
    theme: theme,
    builder: (context, child) =>
        AppToastMessenger(key: messengerKey, child: child!),
    home: const Scaffold(body: Center(child: Text('page'))),
  );

  var undone = 0;

  SnackBar toast(String text) => SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(label: 'Undo', onPressed: () => undone++),
  );

  /// 見えている知らせ[text]の不透明度（祖先のFadeTransitionの積）。無ければ
  /// null。
  double? opacityOf(String text) {
    double? best;
    for (final element in find.text(text).evaluate()) {
      var opacity = 1.0;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is FadeTransition) opacity *= widget.opacity.value;
        if (widget is Opacity) opacity *= widget.opacity;
        return true;
      });
      if (best == null || opacity > best) best = opacity;
    }
    return best;
  }

  /// [text]が出切るまで（濃さに加えて高さも伸び切り、期限を数え始める
  /// まで）1フレームずつ進める。
  Future<void> untilShown(WidgetTester tester, String text) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(frame);
      if ((opacityOf(text) ?? 0) >= 1.0) {
        for (var j = 0; j < 20; j++) {
          await tester.pump(frame);
        }
        return;
      }
    }
    fail('$text was not shown');
  }

  /// [text]が消え切るまでの時間（[limit]を過ぎたらnull）。
  Future<Duration?> timeUntilGone(
    WidgetTester tester,
    String text, {
    Duration limit = const Duration(seconds: 30),
  }) async {
    var elapsed = Duration.zero;
    while (elapsed < limit) {
      await tester.pump(frame);
      elapsed += frame;
      if (opacityOf(text) == null) return elapsed;
    }
    return null;
  }

  /// [duration]の間、1フレームずつ進めて、[text]が出切ったままか確かめる。
  Future<void> staysShown(
    WidgetTester tester,
    String text,
    Duration duration,
  ) async {
    var elapsed = Duration.zero;
    while (elapsed < duration) {
      await tester.pump(frame);
      elapsed += frame;
      expect(
        opacityOf(text),
        1.0,
        reason: '$text faded after ${elapsed.inMilliseconds} ms',
      );
    }
  }

  Offset toastCenter(WidgetTester tester) => tester.getCenter(
    find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first,
  );

  setUp(() => undone = 0);

  testWidgets('a mouse resting on the toast keeps it; leaving lets it go', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    addTearDown(mouse.removePointer);
    messengerKey.currentState!.showSnackBar(toast('hover'));
    await untilShown(tester, 'hover');
    // 1秒見てからマウスを載せる。
    await tester.pump(const Duration(seconds: 1));
    await mouse.moveTo(toastCenter(tester));
    await staysShown(tester, 'hover', const Duration(seconds: 12));
    // 離すと、残り（4.25秒−1秒）で消える。すぐには消えない。
    await mouse.moveTo(const Offset(5, 5));
    final gone = await timeUntilGone(tester, 'hover');
    expect(gone, isNotNull);
    // 載せる前に見ていた1秒ほどは数え直さない（出切るまでの0.1秒ほどの
    // ずれを見込む）。
    expect(gone!, greaterThan(const Duration(milliseconds: 3200)));
    expect(
      gone,
      lessThan(
        kToastLongestShown + kToastFadeOut - const Duration(milliseconds: 700),
      ),
    );
    expect(undone, 0);
  });

  testWidgets('moving onto the toast late still leaves at least a second', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    addTearDown(mouse.removePointer);
    messengerKey.currentState!.showSnackBar(toast('late'));
    await untilShown(tester, 'late');
    await tester.pump(const Duration(milliseconds: 4100));
    await mouse.moveTo(toastCenter(tester));
    await staysShown(tester, 'late', const Duration(seconds: 2));
    await mouse.moveTo(const Offset(5, 5));
    // 残りは0.15秒だが、離してから1秒は見せる。
    await staysShown(tester, 'late', const Duration(milliseconds: 900));
    final gone = await timeUntilGone(tester, 'late');
    expect(gone, isNotNull);
    expect(gone!, lessThan(kToastFadeOut + const Duration(milliseconds: 300)));
  });

  testWidgets(
    'a toast that started fading comes back when the mouse is on it',
    (tester) async {
      await tester.pumpWidget(app());
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 5));
      addTearDown(mouse.removePointer);
      messengerKey.currentState!.showSnackBar(toast('fading'));
      await untilShown(tester, 'fading');
      // 期限が来て薄くなり始めた所。
      var elapsed = Duration.zero;
      while ((opacityOf('fading') ?? 0) >= 1.0) {
        await tester.pump(frame);
        elapsed += frame;
        expect(elapsed, lessThan(const Duration(seconds: 6)));
      }
      final faded = opacityOf('fading')!;
      expect(faded, greaterThan(0.0));
      await mouse.moveTo(toastCenter(tester));
      await tester.pump(kToastFadeOut);
      await tester.pump(frame);
      expect(opacityOf('fading'), 1.0);
      await staysShown(tester, 'fading', const Duration(seconds: 5));
      await mouse.moveTo(const Offset(5, 5));
      expect(await timeUntilGone(tester, 'fading'), isNotNull);
    },
  );

  testWidgets('holding a finger on the toast keeps it until released', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    messengerKey.currentState!.showSnackBar(toast('press'));
    await untilShown(tester, 'press');
    // 文の所を押さえる（操作ボタンは押さない）。
    final finger = await tester.startGesture(
      tester.getCenter(find.text('press')),
    );
    await staysShown(tester, 'press', const Duration(seconds: 8));
    await finger.up();
    await staysShown(tester, 'press', const Duration(milliseconds: 900));
    expect(await timeUntilGone(tester, 'press'), isNotNull);
    expect(undone, 0);
  });

  testWidgets('keyboard focus on the Undo button keeps the toast', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    messengerKey.currentState!.showSnackBar(toast('keys'));
    await untilShown(tester, 'keys');
    // ページには押せる物が無いので、Tabで「元に戻す」へ届く。
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<SnackBar>(),
      isNotNull,
      reason: 'Tab reaches the Undo button',
    );
    await staysShown(tester, 'keys', const Duration(seconds: 10));
    // Enterで押せる（押すと消える）。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(await timeUntilGone(tester, 'keys'), isNotNull);
    expect(undone, 1);
  });

  testWidgets('a toast nobody touches still goes within 5 s', (tester) async {
    await tester.pumpWidget(app());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    addTearDown(mouse.removePointer);
    messengerKey.currentState!.showSnackBar(toast('alone'));
    await untilShown(tester, 'alone');
    // マウスは知らせの外で動かす。
    await mouse.moveTo(const Offset(20, 20));
    final gone = await timeUntilGone(tester, 'alone');
    expect(gone, isNotNull);
    expect(
      gone!,
      lessThan(
        kToastLongestShown + kToastFadeOut + const Duration(milliseconds: 200),
      ),
    );
    expect(gone, greaterThan(kToastLongestShown));
  });

  testWidgets('toastContentOf returns the content the app passed', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    messengerKey.currentState!.showSnackBar(toast('content'));
    await untilShown(tester, 'content');
    final shown = tester.widget<SnackBar>(find.byType(SnackBar).first);
    expect((toastContentOf(shown) as Text).data, 'content');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
