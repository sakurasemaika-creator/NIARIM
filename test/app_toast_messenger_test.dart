import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_toast_messenger.dart';

/// アプリ全体の知らせの出し先（[AppToastMessenger]）を、1フレームずつ
/// 不透明度・高さを取って確かめる。実際のアプリを通した確かめは
/// `toast_contract_test.dart`。
void main() {
  const frame = Duration(milliseconds: 16);

  late GlobalKey<ScaffoldMessengerState> messengerKey;
  late GoRouter router;
  late ValueNotifier<bool> screenReader;
  late ThemeData theme;

  setUp(() {
    messengerKey = GlobalKey<ScaffoldMessengerState>();
    screenReader = ValueNotifier<bool>(false);
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _Page('home')),
        GoRoute(path: '/next', builder: (_, _) => const _Page('next')),
      ],
    );
    final themes = ThemeService();
    theme = themes.themeData;
    themes.dispose();
  });

  tearDown(() {
    screenReader.dispose();
    router.dispose();
  });

  /// [central]が偽なら、比べるための素のScaffoldMessenger。
  Widget app({bool central = true, bool reduceMotion = false}) {
    return MaterialApp.router(
      routerConfig: router,
      scaffoldMessengerKey: central ? null : messengerKey,
      theme: theme,
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: screenReader,
        builder: (context, assistive, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            accessibleNavigation: assistive,
          ),
          child: central
              ? AppToastMessenger(key: messengerKey, child: child!)
              : child!,
        ),
      ),
    );
  }

  ScaffoldMessengerState messenger(WidgetTester tester) =>
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last));

  /// 見えている知らせ[text]の不透明度（祖先のFadeTransition・Opacityの積）。
  /// ツリーに無ければnull。
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

  /// 知らせが画面で占めている高さ（出るときは下から伸びる）。無ければnull。
  double? heightOf(WidgetTester tester) {
    final found = find.byType(SnackBar);
    if (found.evaluate().isEmpty) return null;
    return tester.getSize(found.first).height;
  }

  String show(double? value) => value == null ? '--' : value.toStringAsFixed(2);

  /// 1フレームずつ[frames]回進めて、毎フレームの不透明度を返す。
  Future<List<double?>> sample(
    WidgetTester tester,
    String text, {
    int frames = 32,
  }) async {
    final samples = <double?>[];
    for (var i = 0; i < frames; i++) {
      await tester.pump(frame);
      samples.add(opacityOf(text));
    }
    return samples;
  }

  /// [text]が出切る（不透明度1・動いていない）まで進める。
  Future<void> untilShown(WidgetTester tester, String text) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (opacityOf(text) == 1.0 && !tester.hasRunningAnimations) return;
    }
    fail('$text never became fully visible');
  }

  /// [text]がツリーから無くなるまでの時間（[step]刻み）。[limit]まで待っても
  /// 残っていればnull。
  Future<Duration?> timeUntilGone(
    WidgetTester tester,
    String text, {
    Duration step = frame,
    Duration limit = const Duration(seconds: 20),
  }) async {
    var elapsed = Duration.zero;
    while (find.text(text).evaluate().isNotEmpty) {
      if (elapsed >= limit) return null;
      await tester.pump(step);
      elapsed += step;
    }
    return elapsed;
  }

  /// [text]がツリーに入るまでの時間。
  Future<Duration> timeUntilInTree(WidgetTester tester, String text) async {
    var elapsed = Duration.zero;
    while (find.text(text).evaluate().isEmpty) {
      expect(elapsed, lessThan(const Duration(seconds: 10)));
      await tester.pump(frame);
      elapsed += frame;
    }
    return elapsed;
  }

  /// 少しずつ薄くなっているか：消え切るまで濃くならず、途中の濃さが
  /// [atLeast]フレーム以上あり、1フレームで[maxStep]より大きく落ちない。
  void expectGradual(
    List<double?> samples, {
    int atLeast = 20,
    double maxStep = 0.07,
  }) {
    final shown = samples.map(show).join(' ');
    final values = [1.0, ...samples.map((s) => s ?? 0.0)];
    var between = 0;
    for (var i = 1; i < values.length; i++) {
      expect(
        values[i],
        lessThanOrEqualTo(values[i - 1] + 1e-9),
        reason: 'opacity went up at frame $i: $shown',
      );
      expect(
        values[i - 1] - values[i],
        lessThanOrEqualTo(maxStep),
        reason: 'opacity jumped at frame $i: $shown',
      );
      if (values[i] > 0.02 && values[i] < 0.98) between++;
    }
    expect(
      between,
      greaterThanOrEqualTo(atLeast),
      reason: 'only $between frames in between: $shown',
    );
    expect(samples.last, isNull, reason: 'still in the tree: $shown');
  }

  SnackBar actionToast(
    String text, {
    Duration duration = const Duration(seconds: 6),
    VoidCallback? onPressed,
  }) => SnackBar(
    content: Text(text),
    duration: duration,
    action: SnackBarAction(label: 'UNDO', onPressed: onPressed ?? () {}),
  );

  group('one place for every toast', () {
    testWidgets('key, page, dialog, sheet and navigator contexts agree', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final fromKey = messengerKey.currentState;
      expect(fromKey, isA<AppToastMessengerState>());
      final page = tester.element(find.text('page home'));
      expect(ScaffoldMessenger.of(page), same(fromKey));
      late BuildContext dialogContext;
      showDialog<void>(
        context: page,
        builder: (context) {
          dialogContext = context;
          return const AlertDialog(content: Text('dialog'));
        },
      );
      await tester.pumpAndSettle();
      expect(ScaffoldMessenger.of(dialogContext), same(fromKey));
      Navigator.of(dialogContext).pop();
      await tester.pumpAndSettle();
      late BuildContext sheetContext;
      showModalBottomSheet<void>(
        context: page,
        builder: (context) {
          sheetContext = context;
          return const SizedBox(height: 80, child: Text('sheet'));
        },
      );
      await tester.pumpAndSettle();
      expect(ScaffoldMessenger.of(sheetContext), same(fromKey));
      // 画面の外（builderの層）からも。
      expect(
        ScaffoldMessenger.of(tester.element(find.byType(Navigator).first)),
        same(fromKey),
      );
    });

    testWidgets('a messenger captured on a screen that has gone still obeys', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      router.push('/next');
      await tester.pumpAndSettle();
      final captured = ScaffoldMessenger.of(
        tester.element(find.text('page next')),
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('page next'), findsNothing);
      captured.showSnackBar(
        actionToast('late', duration: const Duration(seconds: 30)),
      );
      await untilShown(tester, 'late');
      expect(
        await timeUntilGone(tester, 'late'),
        lessThan(kToastMaxLifetime - kToastEntrance),
      );
    });
  });

  group('lifetime', () {
    testWidgets('an action toast asking for 6 s is gone within 5 s', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      var pressed = 0;
      final reasons = <SnackBarClosedReason>[];
      messengerKey.currentState!
          .showSnackBar(actionToast('undo me', onPressed: () => pressed++))
          .closed
          .then(reasons.add);
      // 出始めから数える。
      final entered = await timeUntilInTree(tester, 'undo me');
      final gone = await timeUntilGone(tester, 'undo me');
      debugPrint('action + 6 s: in the tree for ${gone!.inMilliseconds} ms');
      expect(entered + gone, lessThanOrEqualTo(kToastMaxLifetime));
      // 読める時間は削りすぎない（出切ってから4秒以上）。
      expect(gone, greaterThan(const Duration(milliseconds: 4500)));
      expect(reasons, [SnackBarClosedReason.timeout]);
      expect(pressed, 0);
    });

    testWidgets('shorter durations are kept; persist: true is not', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      // 既定（4秒）は4秒のまま。
      messenger(tester).showSnackBar(const SnackBar(content: Text('plain')));
      await untilShown(tester, 'plain');
      final plain = await timeUntilGone(tester, 'plain');
      debugPrint('default: gone ${plain!.inMilliseconds} ms after shown');
      expect(plain.inMilliseconds, inInclusiveRange(4000, 4000 + 450));

      messenger(tester).showSnackBar(
        const SnackBar(content: Text('short'), duration: Duration(seconds: 2)),
      );
      await untilShown(tester, 'short');
      final short = await timeUntilGone(tester, 'short');
      expect(short!.inMilliseconds, inInclusiveRange(2000, 2000 + 450));

      messenger(tester).showSnackBar(
        const SnackBar(
          content: Text('sticky'),
          persist: true,
          duration: Duration(minutes: 1),
        ),
      );
      await untilShown(tester, 'sticky');
      final sticky = await timeUntilGone(tester, 'sticky');
      expect(sticky!.inMilliseconds, inInclusiveRange(4250, 4250 + 450));
    });

    testWidgets('once fully shown, the time runs on even if frames stall', (
      tester,
    ) async {
      // 出切った後は、フレームが飛んでも（重い処理・テストの長いpump）
      // 期限どおりに消える。
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(actionToast('after a stall'));
      await untilShown(tester, 'after a stall');
      await tester.pump(const Duration(seconds: 7));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('after a stall'), findsNothing);
    });

    /// [text]が出切って（不透明度1で）見えていた時間と、ツリーから無くなる
    /// までの時間（20秒待っても残っていればnull）。
    Future<({Duration readable, Duration? gone})> readableUntilGone(
      WidgetTester tester,
      String text,
    ) async {
      var readable = Duration.zero;
      var elapsed = Duration.zero;
      while (find.text(text).evaluate().isNotEmpty) {
        if (elapsed >= const Duration(seconds: 20)) {
          return (readable: readable, gone: null);
        }
        await tester.pump(frame);
        elapsed += frame;
        if ((opacityOf(text) ?? 0.0) >= 0.99) readable += frame;
      }
      return (readable: readable, gone: elapsed);
    }

    for (final central in [false, true]) {
      final who = central ? 'AppToastMessenger' : 'plain messenger';

      testWidgets('$who: a stall while it comes in does not eat its time', (
        tester,
      ) async {
        // 出てくる途中で描画が止まった（重い処理）。止まっている間は
        // 見えていないので、出切ってから数える。
        await tester.pumpWidget(app(central: central));
        messenger(
          tester,
        ).showSnackBar(const SnackBar(content: Text('stalled')));
        await tester.pump();
        await tester.pump(frame);
        await tester.pump(const Duration(milliseconds: 4600));
        final life = await readableUntilGone(tester, 'stalled');
        debugPrint(
          '$who, 4.6 s stall 16 ms into the entrance: fully shown for '
          '${life.readable.inMilliseconds} ms, gone after ${life.gone}',
        );
        expect(life.readable, greaterThanOrEqualTo(const Duration(seconds: 4)));
        expect(life.gone, isNotNull);
        expect(life.gone!, lessThan(kToastMaxLifetime));
      });

      for (final away in [16, 96, 160, 240]) {
        testWidgets('$who: the app leaves $away ms into the entrance', (
          tester,
        ) async {
          // 出てくる途中でアプリが裏へ回った（ホームボタン・画面のロック・
          // 電話）。見ないうちに消えず、戻ってから読める。
          await tester.pumpWidget(app(central: central));
          messenger(
            tester,
          ).showSnackBar(const SnackBar(content: Text('left early')));
          // 初めて描かれたフレーム。
          await tester.pump();
          for (var t = 0; t < away; t += 16) {
            await tester.pump(frame);
          }
          final then = opacityOf('left early');
          final binding = tester.binding;
          binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          addTearDown(
            () => binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            ),
          );
          await tester.pump(const Duration(seconds: 6));
          binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          final life = await readableUntilGone(tester, 'left early');
          debugPrint(
            '$who, away $away ms into the entrance (opacity then '
            '${show(then)}): fully shown for ${life.readable.inMilliseconds} '
            'ms after coming back, gone after ${life.gone}',
          );
          expect(
            life.readable,
            greaterThanOrEqualTo(const Duration(seconds: 4)),
          );
          expect(life.gone, isNotNull);
          expect(life.gone!, lessThan(kToastMaxLifetime));
        });
      }
    }

    testWidgets('a toast shown while the app is away waits to be seen', (
      tester,
    ) async {
      // 裏にある間（描画が止まっている間）は数えない。戻ってから読める。
      await tester.pumpWidget(app());
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      messenger(tester).showSnackBar(actionToast('while away'));
      await tester.pump(const Duration(seconds: 10));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final entered = await timeUntilInTree(tester, 'while away');
      await untilShown(tester, 'while away');
      final gone = await timeUntilGone(tester, 'while away');
      debugPrint('shown after coming back: gone ${gone!.inMilliseconds} ms');
      expect(entered, lessThanOrEqualTo(frame));
      expect(gone, greaterThan(const Duration(milliseconds: 4400)));
      expect(gone, lessThan(kToastMaxLifetime));
    });

    testWidgets('a queue shows one at a time, in order, each within 5 s', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      const names = ['one', 'two', 'three'];
      final visible = <String>[];
      for (final name in names) {
        messenger(tester).showSnackBar(
          SnackBar(
            content: Text(name),
            duration: const Duration(seconds: 9),
            onVisible: () => visible.add(name),
          ),
        );
      }
      final seen = <String>[];
      var longest = Duration.zero;
      var current = '';
      var since = Duration.zero;
      for (
        var now = Duration.zero;
        now < const Duration(seconds: 20);
        now += frame
      ) {
        await tester.pump(frame);
        final inTree = [
          for (final name in names)
            if (find.text(name).evaluate().isNotEmpty) name,
        ];
        expect(inTree.length, lessThanOrEqualTo(1));
        final name = inTree.isEmpty ? '' : inTree.single;
        if (name != current) {
          if (name.isNotEmpty) seen.add(name);
          current = name;
          since = now;
        } else if (name.isNotEmpty && now - since > longest) {
          longest = now - since;
        }
      }
      debugPrint('queue: $seen, longest in the tree $longest');
      expect(seen, names);
      expect(visible, names);
      expect(longest, lessThanOrEqualTo(kToastMaxLifetime));
    });
  });

  group('leaving is a gradual fade', () {
    for (final way in ['timer', 'action', 'hide', 'remove', 'clear', 'close']) {
      testWidgets('by $way', (tester) async {
        await tester.pumpWidget(app());
        var pressed = 0;
        final reasons = <SnackBarClosedReason>[];
        final controller = messenger(tester).showSnackBar(
          actionToast(
            'bye',
            duration: const Duration(seconds: 2),
            onPressed: () => pressed++,
          ),
        );
        controller.closed.then(reasons.add);
        // 後ろで待っている知らせは、clearで捨てられる。
        if (way == 'clear') {
          messenger(
            tester,
          ).showSnackBar(const SnackBar(content: Text('waiting')));
        }
        await untilShown(tester, 'bye');
        final height = heightOf(tester);
        switch (way) {
          case 'timer':
            await tester.pump(const Duration(milliseconds: 1980));
          case 'action':
            await tester.tap(find.text('UNDO'));
          case 'hide':
            messenger(tester).hideCurrentSnackBar();
          case 'remove':
            messenger(tester).removeCurrentSnackBar();
          case 'clear':
            messenger(tester).clearSnackBars();
          case 'close':
            controller.close();
        }
        final samples = <double?>[];
        for (var i = 0; i < 32; i++) {
          await tester.pump(frame);
          samples.add(opacityOf('bye'));
          // 消えるまで高さは変わらない（切り取られない・縮まない）。
          if (samples.last != null) expect(heightOf(tester), height);
        }
        debugPrint(
          'exit by ${way.padRight(6)}: ${samples.map(show).join(' ')}',
        );
        expectGradual(samples);
        expect(reasons.single.name, switch (way) {
          'timer' => 'timeout',
          'action' => 'action',
          'remove' => 'remove',
          _ => 'hide',
        });
        expect(pressed, way == 'action' ? 1 : 0);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets('a swipe takes the toast away at once', (tester) async {
      await tester.pumpWidget(app());
      final reasons = <SnackBarClosedReason>[];
      messenger(tester)
          .showSnackBar(const SnackBar(content: Text('swipe me')))
          .closed
          .then(reasons.add);
      await untilShown(tester, 'swipe me');
      await tester.drag(find.text('swipe me'), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(find.text('swipe me'), findsNothing);
      expect(reasons, [SnackBarClosedReason.swipe]);
      // 次の知らせは普通に出て、普通に消える。
      messenger(tester).showSnackBar(const SnackBar(content: Text('after')));
      await untilShown(tester, 'after');
      final after = await timeUntilGone(tester, 'after');
      expect(after!.inMilliseconds, inInclusiveRange(4000, 4450));
    });

    testWidgets('a swipe during the fade does not break the next toast', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(const SnackBar(content: Text('fading')));
      await untilShown(tester, 'fading');
      messenger(tester).hideCurrentSnackBar();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 100));
      // 読み上げの「閉じる」と同じ入口（その場で消える）。
      messenger(
        tester,
      ).removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
      await tester.pump(frame);
      expect(find.text('fading'), findsNothing);
      messenger(tester).showSnackBar(const SnackBar(content: Text('after')));
      await untilShown(tester, 'after');
      expect(opacityOf('after'), 1.0);
      final after = await timeUntilGone(tester, 'after');
      expect(after!.inMilliseconds, inInclusiveRange(4000, 4450));
    });

    testWidgets('a route change during the exit keeps fading', (tester) async {
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(const SnackBar(content: Text('moving')));
      await untilShown(tester, 'moving');
      // 画面が変わっても、出ている知らせは付いていく。
      router.push('/next');
      await tester.pumpAndSettle();
      expect(find.text('page next'), findsOneWidget);
      expect(opacityOf('moving'), 1.0);

      messenger(tester).hideCurrentSnackBar();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 64));
      router.pop();
      final samples = await sample(tester, 'moving', frames: 40);
      debugPrint('exit across a pop: ${samples.map(show).join(' ')}');
      final values = samples.map((s) => s ?? 0.0).toList();
      for (var i = 1; i < values.length; i++) {
        expect(
          values[i],
          lessThanOrEqualTo(values[i - 1] + 1e-9),
          reason: samples.map(show).join(' '),
        );
      }
      expect(values.first, lessThan(0.85));
      await tester.pumpAndSettle();
      expect(find.text('moving'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('one toast replacing another', () {
    testWidgets('the next toast does not wait noticeably longer than before', (
      tester,
    ) async {
      // 素のメッセンジャーで待つ時間。
      await tester.pumpWidget(app(central: false));
      messenger(tester).showSnackBar(const SnackBar(content: Text('old')));
      await untilShown(tester, 'old');
      messenger(tester)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('new')));
      final before = await timeUntilInTree(tester, 'new');
      await tester.pumpWidget(const SizedBox());

      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(const SnackBar(content: Text('old')));
      await untilShown(tester, 'old');
      messenger(tester)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('new')));
      final old = <double?>[];
      var waited = Duration.zero;
      while (find.text('new').evaluate().isEmpty) {
        await tester.pump(frame);
        old.add(opacityOf('old'));
        waited += frame;
      }
      debugPrint(
        'hide→show: next after ${waited.inMilliseconds} ms '
        '(plain messenger ${before.inMilliseconds} ms); '
        'old: ${old.map(show).join(' ')}',
      );
      expect(
        waited - before,
        lessThanOrEqualTo(const Duration(milliseconds: 64)),
      );
      expectGradual(old, atLeast: 15, maxStep: 0.09);

      // 「すぐ消す」で入れ替えても同じ。
      await untilShown(tester, 'new');
      messenger(tester)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('newer')));
      old.clear();
      waited = Duration.zero;
      while (find.text('newer').evaluate().isEmpty) {
        await tester.pump(frame);
        old.add(opacityOf('new'));
        waited += frame;
      }
      debugPrint('remove→show: next after ${waited.inMilliseconds} ms');
      expect(
        waited - before,
        lessThanOrEqualTo(const Duration(milliseconds: 64)),
      );
      expectGradual(old, atLeast: 15, maxStep: 0.09);

      // 薄くなり始めてから次が来たとき：そこから急ぐ。
      await untilShown(tester, 'newer');
      messenger(tester).hideCurrentSnackBar();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 84));
      messenger(tester).showSnackBar(const SnackBar(content: Text('newest')));
      waited = await timeUntilInTree(tester, 'newest');
      debugPrint('show 100 ms into an exit: next after $waited');
      // 薄くなり始めてからでも、素のメッセンジャーの入れ替えより待たせない。
      expect(waited, lessThanOrEqualTo(before));
      await untilShown(tester, 'newest');
      final newest = await timeUntilGone(tester, 'newest');
      expect(newest!.inMilliseconds, inInclusiveRange(4000, 4450));
    });

    testWidgets('pressing again and again keeps one toast, never stuck', (
      tester,
    ) async {
      // ロックしたレイヤーへ描こうとしたとき等：押すたびに出し直す。
      await tester.pumpWidget(app());
      for (var press = 0; press < 12; press++) {
        messenger(tester)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('locked $press')));
        await tester.pump(Duration(milliseconds: 40 + press * 23));
        expect(find.byType(SnackBar).evaluate().length, lessThanOrEqualTo(1));
      }
      // 最後に出したものが、待たずに出て、5秒ほどで消える（押した数だけ
      // 順に出し直さない）。
      var elapsed = const Duration(milliseconds: 40 + 11 * 23);
      Duration? newestShown;
      while (find.byType(SnackBar).evaluate().isNotEmpty &&
          elapsed < const Duration(seconds: 60)) {
        if (newestShown == null && opacityOf('locked 11') == 1.0) {
          newestShown = elapsed;
        }
        await tester.pump(frame);
        elapsed += frame;
      }
      debugPrint(
        'pressed 12 times: newest fully shown ${newestShown?.inMilliseconds} '
        'ms after the last press, all gone after ${elapsed.inMilliseconds} ms',
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(newestShown, lessThanOrEqualTo(const Duration(milliseconds: 600)));
      expect(elapsed, lessThanOrEqualTo(kToastMaxLifetime + _replaceSlack));
      expect(tester.takeException(), isNull);
    });

    /// 「消して出す」を[gap]おきに[presses]回続けたとき：最後の知らせが
    /// 押してから出切るまで・それぞれが出切っていた時間・全部消えるまで。
    Future<
      ({Duration? newestShown, Map<String, int> shownMs, Duration allGone})
    >
    replaceRepeatedly(
      WidgetTester tester, {
      required bool central,
      required bool remove,
      int presses = 3,
      Duration gap = const Duration(milliseconds: 120),
    }) async {
      await tester.pumpWidget(app(central: central));
      messenger(tester).showSnackBar(const SnackBar(content: Text('t0')));
      await untilShown(tester, 't0');
      final shownMs = <String, int>{};
      void count() {
        for (var i = 0; i <= presses; i++) {
          if (opacityOf('t$i') == 1.0) {
            shownMs['t$i'] = (shownMs['t$i'] ?? 0) + frame.inMilliseconds;
          }
        }
      }

      for (var press = 1; press <= presses; press++) {
        final state = messenger(tester);
        if (remove) {
          state.removeCurrentSnackBar();
        } else {
          state.hideCurrentSnackBar();
        }
        state.showSnackBar(SnackBar(content: Text('t$press')));
        if (press == presses) break;
        for (var waited = Duration.zero; waited < gap; waited += frame) {
          await tester.pump(frame);
          count();
        }
      }
      var elapsed = Duration.zero;
      Duration? newestShown;
      while (find.byType(SnackBar).evaluate().isNotEmpty &&
          elapsed < const Duration(seconds: 30)) {
        await tester.pump(frame);
        elapsed += frame;
        count();
        if (newestShown == null && opacityOf('t$presses') == 1.0) {
          newestShown = elapsed;
        }
      }
      debugPrint(
        '${central ? 'app  ' : 'plain'} ${remove ? 'remove' : 'hide  '}→show '
        '×$presses, ${gap.inMilliseconds} ms apart: newest fully shown '
        '${newestShown?.inMilliseconds} ms after the last press, all gone '
        'after ${elapsed.inMilliseconds} ms, fully shown $shownMs',
      );
      await tester.pumpWidget(const SizedBox());
      return (newestShown: newestShown, shownMs: shownMs, allGone: elapsed);
    }

    for (final gap in const [
      Duration(milliseconds: 120),
      Duration(milliseconds: 250),
    ]) {
      testWidgets('remove→show again during the fade: only the newest stays '
          '(${gap.inMilliseconds} ms apart)', (tester) async {
        // ホームの貼り付け・コピーの知らせ（removeCurrentSnackBar→
        // showSnackBar）を続けて押したとき。素のメッセンジャーは押すたびに
        // その場で入れ替える。
        final plain = await replaceRepeatedly(
          tester,
          central: false,
          remove: true,
          gap: gap,
        );
        final ours = await replaceRepeatedly(
          tester,
          central: true,
          remove: true,
          gap: gap,
        );
        expect(plain.newestShown, isNotNull);
        expect(ours.newestShown, isNotNull);
        // 前の知らせが薄くなる分（300ms）と、出てくる途中なら伸び切るまでの
        // 分（100ms以内）より長く待たせない。
        expect(
          ours.newestShown! - plain.newestShown!,
          lessThanOrEqualTo(
            kToastFadeOutWhenReplaced + const Duration(milliseconds: 150),
          ),
        );
        // 途中の知らせが5秒近く出続けない。
        for (var i = 1; i < 3; i++) {
          expect(ours.shownMs['t$i'] ?? 0, lessThanOrEqualTo(200));
        }
        expect(
          ours.allGone,
          lessThanOrEqualTo(kToastMaxLifetime + _replaceSlack),
        );
      });
    }

    testWidgets('hide→show again during the fade: only the newest stays', (
      tester,
    ) async {
      // ロックしたレイヤーへ続けて描こうとしたとき（hideCurrentSnackBar→
      // showSnackBar）。素のメッセンジャーは押した数だけ順に出し直し、
      // 同じ知らせが押した数×4秒ほど残る。
      final ours = await replaceRepeatedly(
        tester,
        central: true,
        remove: false,
      );
      expect(
        ours.newestShown,
        lessThanOrEqualTo(const Duration(milliseconds: 450)),
      );
      for (var i = 1; i < 3; i++) {
        expect(ours.shownMs['t$i'] ?? 0, lessThanOrEqualTo(200));
      }
      expect(
        ours.allGone,
        lessThanOrEqualTo(kToastMaxLifetime + _replaceSlack),
      );
    });

    testWidgets('a toast queued before the fade is not dropped', (
      tester,
    ) async {
      // 出ている間に（入れ替えではなく）後ろに並んだ知らせは、入れ替えが
      // 続いても捨てずに順に出す。
      await tester.pumpWidget(app());
      messenger(tester)
        ..showSnackBar(const SnackBar(content: Text('first')))
        ..showSnackBar(const SnackBar(content: Text('waiting')));
      await untilShown(tester, 'first');
      for (var press = 1; press <= 2; press++) {
        messenger(tester)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('again $press')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final appeared = <String>[];
      for (var i = 0; i < 1000; i++) {
        await tester.pump(frame);
        final found = find.byType(SnackBar).evaluate();
        if (found.isEmpty) break;
        final text = ((found.single.widget as SnackBar).content as Text).data!;
        if (appeared.isEmpty || appeared.last != text) appeared.add(text);
      }
      debugPrint('queued before the fade: $appeared');
      expect(find.byType(SnackBar), findsNothing);
      expect(appeared, containsAllInOrder(['waiting', 'again 2']));
    });

    /// 知らせが無くなるまで1フレームずつ進め、出た順と、それぞれが出切って
    /// いた時間・ツリーにあった時間を返す。
    Future<
      ({
        List<String> appeared,
        Map<String, Duration> fullyShown,
        Map<String, Duration> inTree,
      })
    >
    watchUntilAllGone(WidgetTester tester) async {
      final appeared = <String>[];
      final fullyShown = <String, Duration>{};
      final inTree = <String, Duration>{};
      for (var i = 0; i < 1500; i++) {
        await tester.pump(frame);
        final found = find.byType(SnackBar).evaluate();
        if (found.isEmpty) break;
        for (final element in found) {
          final text = ((element.widget as SnackBar).content as Text).data!;
          if (!appeared.contains(text)) appeared.add(text);
          inTree[text] = (inTree[text] ?? Duration.zero) + frame;
          if (opacityOf(text) == 1.0) {
            fullyShown[text] = (fullyShown[text] ?? Duration.zero) + frame;
          }
        }
      }
      String ms(Map<String, Duration> times) => {
        for (final MapEntry(key: text, value: time) in times.entries)
          text: time.inMilliseconds,
      }.toString();
      debugPrint(
        '  appeared $appeared, fully shown ${ms(fullyShown)} ms, '
        'in the tree ${ms(inTree)} ms',
      );
      return (appeared: appeared, fullyShown: fullyShown, inTree: inTree);
    }

    SnackBar movedToTrash(String text) => SnackBar(
      content: Text(text),
      persist: false,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'UNDO', onPressed: () {}),
    );

    for (final remove in [false, true]) {
      final call = remove ? 'remove' : 'hide';
      testWidgets('a lone $call during the fade keeps the replacement', (
        tester,
      ) async {
        // ゴミ箱へ移した知らせ（隠して「元に戻す」付きを出す）が、前の知らせが
        // 薄くなる後ろで待っている間に、別の操作が始めに知らせを隠す
        // （runProjectAction：成功したら何も出さない。お気に入りの切り替え）。
        // 素のメッセンジャーでも「元に戻す」は出る。
        await tester.pumpWidget(app());
        messenger(
          tester,
        ).showSnackBar(const SnackBar(content: Text('earlier')));
        await untilShown(tester, 'earlier');
        messenger(tester)
          ..hideCurrentSnackBar()
          ..showSnackBar(movedToTrash('moved'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(frame);
        }
        if (remove) {
          messenger(tester).removeCurrentSnackBar();
        } else {
          messenger(tester).hideCurrentSnackBar();
        }
        debugPrint('lone $call 96 ms into the replacement fade:');
        final watched = await watchUntilAllGone(tester);
        expect(watched.appeared, contains('moved'));
        expect(
          watched.fullyShown['moved'] ?? Duration.zero,
          greaterThanOrEqualTo(const Duration(seconds: 4)),
        );
        expect(watched.inTree['moved'], lessThanOrEqualTo(kToastMaxLifetime));
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets('a notice shown after a lone hide waits its turn', (
      tester,
    ) async {
      // runProjectActionが隠してから保存に失敗し、awaitの後で失敗の知らせを
      // 出す。待っていた「元に戻す」も失敗の知らせも捨てない（素の
      // メッセンジャーと同じ順）。
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(const SnackBar(content: Text('earlier')));
      await untilShown(tester, 'earlier');
      messenger(tester)
        ..hideCurrentSnackBar()
        ..showSnackBar(movedToTrash('moved'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(frame);
      }
      messenger(tester).hideCurrentSnackBar();
      await tester.pump(frame);
      messenger(tester).showSnackBar(const SnackBar(content: Text('failed')));
      debugPrint('lone hide, then a failure notice one frame later:');
      final watched = await watchUntilAllGone(tester);
      expect(watched.appeared, ['earlier', 'moved', 'failed']);
      for (final text in ['moved', 'failed']) {
        expect(
          watched.fullyShown[text] ?? Duration.zero,
          greaterThanOrEqualTo(const Duration(milliseconds: 3500)),
          reason: text,
        );
        expect(watched.inTree[text], lessThanOrEqualTo(kToastMaxLifetime));
      }
    });

    testWidgets('a replacement drops only the replacement it overtakes', (
      tester,
    ) async {
      // 入れ替えの途中に、入れ替えではない知らせ（失敗の知らせ等）が並び、
      // さらに入れ替えが来た。追い越された入れ替えだけを下げ、失敗の
      // 知らせは出す。
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(const SnackBar(content: Text('earlier')));
      await untilShown(tester, 'earlier');
      messenger(tester)
        ..hideCurrentSnackBar()
        ..showSnackBar(movedToTrash('replaced 1'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(frame);
      }
      messenger(tester).showSnackBar(const SnackBar(content: Text('failed')));
      for (var i = 0; i < 3; i++) {
        await tester.pump(frame);
      }
      messenger(tester)
        ..hideCurrentSnackBar()
        ..showSnackBar(movedToTrash('replaced 2'));
      debugPrint('replacement, plain notice, replacement within one fade:');
      final watched = await watchUntilAllGone(tester);
      expect(watched.appeared, ['earlier', 'failed', 'replaced 2']);
      for (final text in ['failed', 'replaced 2']) {
        expect(
          watched.fullyShown[text] ?? Duration.zero,
          greaterThanOrEqualTo(const Duration(milliseconds: 3500)),
          reason: text,
        );
        expect(watched.inTree[text], lessThanOrEqualTo(kToastMaxLifetime));
      }
    });
  });

  group('the entrance is unchanged', () {
    Future<List<(double?, double?)>> entrance(
      WidgetTester tester, {
      required bool central,
    }) async {
      await tester.pumpWidget(app(central: central));
      messenger(tester).showSnackBar(actionToast('hello'));
      final frames = <(double?, double?)>[];
      for (var i = 0; i < 24; i++) {
        await tester.pump(frame);
        frames.add((opacityOf('hello'), heightOf(tester)));
      }
      await tester.pumpWidget(const SizedBox());
      return frames;
    }

    testWidgets('same opacity and height on every frame', (tester) async {
      final plain = await entrance(tester, central: false);
      final ours = await entrance(tester, central: true);
      expect(ours, plain);
      expect(ours.last.$1, 1.0);
    });

    for (final (after, what) in [
      (80, 'before it is visible'),
      (120, 'while it is appearing'),
      (200, 'opaque but still growing'),
    ]) {
      testWidgets('hidden $what ($after ms in): no flash, no jump', (
        tester,
      ) async {
        await tester.pumpWidget(app());
        messenger(tester).showSnackBar(const SnackBar(content: Text('quick')));
        await tester.pump();
        await tester.pump(Duration(milliseconds: after));
        final opacityBefore = opacityOf('quick')!;
        final heightBefore = heightOf(tester)!;
        messenger(tester).hideCurrentSnackBar();
        final opacities = <double?>[];
        final heights = <double?>[];
        for (var i = 0; i < 40; i++) {
          await tester.pump(frame);
          opacities.add(opacityOf('quick'));
          heights.add(heightOf(tester));
        }
        debugPrint(
          'hide $after ms in (opacity ${show(opacityBefore)}): '
          '${opacities.map(show).join(' ')}',
        );
        expect(opacities.last, isNull);
        expect(tester.takeException(), isNull);
        final values = [opacityBefore, ...opacities.map((o) => o ?? 0.0)];
        for (var i = 1; i < values.length; i++) {
          // 見えていた濃さより濃くならない。出切っていたなら、そこから
          // 少しずつ。
          expect(values[i], lessThanOrEqualTo(values[i - 1] + 1e-9));
          expect(values[i - 1] - values[i], lessThanOrEqualTo(0.12));
        }
        final sizes = [heightBefore, ...heights.whereType<double>()];
        for (var i = 1; i < sizes.length; i++) {
          // 高さが1フレームで大きく跳ばない（出てくる動きの続きだけ）。
          expect((sizes[i] - sizes[i - 1]).abs(), lessThanOrEqualTo(8.0));
        }
      });
    }
  });

  group('reduced motion and assistive use', () {
    testWidgets('reduced motion: no fade, still within 5 s', (tester) async {
      await tester.pumpWidget(app(reduceMotion: true));
      messenger(tester).showSnackBar(actionToast('calm'));
      await untilShown(tester, 'calm');
      final gone = await timeUntilGone(tester, 'calm');
      // 初めて描かれてから4.5秒（出てくる250ms＋4.25秒）で、その場で消える。
      expect(gone!.inMilliseconds, inInclusiveRange(4150, 4300));
      messenger(tester).showSnackBar(const SnackBar(content: Text('calm 2')));
      await untilShown(tester, 'calm 2');
      messenger(tester).hideCurrentSnackBar();
      await tester.pump(frame);
      expect(find.text('calm 2'), findsNothing);
    });

    testWidgets('screen reader: a plain toast leaves, an action toast waits', (
      tester,
    ) async {
      screenReader.value = true;
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(const SnackBar(content: Text('plain')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final plain = await timeUntilGone(tester, 'plain');
      expect(plain, lessThan(kToastMaxLifetime));

      var pressed = 0;
      final reasons = <SnackBarClosedReason>[];
      messenger(tester)
          .showSnackBar(actionToast('undo me', onPressed: () => pressed++))
          .closed
          .then(reasons.add);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final held = await timeUntilGone(
        tester,
        'undo me',
        step: const Duration(milliseconds: 500),
        limit: const Duration(seconds: 30),
      );
      expect(held, isNull, reason: 'the action toast left by itself');
      // 押せば消える。
      await tester.tap(find.text('UNDO'));
      await tester.pump(frame);
      expect(find.text('undo me'), findsNothing);
      expect(pressed, 1);
      expect(reasons, [SnackBarClosedReason.action]);
    });

    testWidgets(
      'screen reader: an action toast asked to leave leaves on time',
      (tester) async {
        // `persist: false`を付けた操作ボタン付きの知らせ（ゴミ箱へ移した
        // 知らせ・キャンバスの不足素材）は、素のメッセンジャーでも読み上げ中に
        // 時間で消える。残さない。
        for (final central in [false, true]) {
          screenReader.value = true;
          await tester.pumpWidget(app(central: central));
          messenger(tester).showSnackBar(
            SnackBar(
              content: const Text('moved'),
              persist: false,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(label: 'UNDO', onPressed: () {}),
            ),
          );
          await tester.pump();
          expect(find.text('moved'), findsOneWidget);
          final gone = await timeUntilGone(
            tester,
            'moved',
            step: const Duration(milliseconds: 100),
          );
          debugPrint(
            '${central ? 'app  ' : 'plain'} screen reader, persist: false: '
            'gone after ${gone?.inMilliseconds} ms',
          );
          expect(gone, isNotNull, reason: central ? 'app' : 'plain');
          if (central) expect(gone!, lessThanOrEqualTo(kToastMaxLifetime));
          await tester.pumpWidget(const SizedBox());
          screenReader.value = false;
        }
      },
    );

    testWidgets('screen reader: a held toast yields to the next one', (
      tester,
    ) async {
      screenReader.value = true;
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(actionToast('undo me'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('undo me'), findsOneWidget);
      messenger(tester).showSnackBar(const SnackBar(content: Text('next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('undo me'), findsNothing);
      expect(find.text('next'), findsOneWidget);
      expect(await timeUntilGone(tester, 'next'), lessThan(kToastMaxLifetime));
    });

    testWidgets('screen reader: an action toast with others waiting leaves', (
      tester,
    ) async {
      screenReader.value = true;
      await tester.pumpWidget(app());
      messenger(tester)
        ..showSnackBar(actionToast('first'))
        ..showSnackBar(const SnackBar(content: Text('second')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await timeUntilGone(tester, 'first'), lessThan(kToastMaxLifetime));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('turning the screen reader off releases a held toast', (
      tester,
    ) async {
      screenReader.value = true;
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(actionToast('undo me'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('undo me'), findsOneWidget);
      screenReader.value = false;
      await tester.pump();
      final gone = await timeUntilGone(tester, 'undo me');
      expect(gone, isNotNull);
      expect(gone!, lessThan(const Duration(seconds: 1)));
    });
  });

  group('nothing else about a toast changes', () {
    Future<Map<String, Object?>> describe(
      WidgetTester tester, {
      required bool central,
    }) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(central: central));
      messenger(tester).showSnackBar(actionToast('saved the drawing'));
      await untilShown(tester, 'saved the drawing');
      // 知らせの面（一番外側のMaterial。中には操作ボタンのMaterialもある）。
      final surfaceFinder = find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first;
      final surface = tester.widget<Material>(surfaceFinder);
      final text = tester.renderObject<RenderParagraph>(
        find.text('saved the drawing'),
      );
      final action = tester.renderObject<RenderParagraph>(find.text('UNDO'));
      final result = <String, Object?>{
        'bar': tester.getRect(find.byType(SnackBar)),
        'surface': tester.getRect(surfaceFinder),
        'colour': surface.color,
        'shape': surface.shape,
        'elevation': surface.elevation,
        'text rect': tester.getRect(find.text('saved the drawing')),
        'text style': text.text.style,
        'action rect': tester.getRect(find.text('UNDO')),
        'action style': action.text.style,
        'above the button':
            tester.getRect(find.byType(SnackBar)).bottom <=
            tester.getRect(find.byType(FloatingActionButton)).top,
        'semantics': tester
            .getSemantics(find.text('saved the drawing'))
            .toStringDeep(),
      };
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      return result;
    }

    testWidgets('same place, colours, font and semantics as before', (
      tester,
    ) async {
      final plain = await describe(tester, central: false);
      final ours = await describe(tester, central: true);
      String withoutIds(Object? tree) =>
          '$tree'.replaceAll(RegExp(r'SemanticsNode#\d+'), 'SemanticsNode');
      expect(
        withoutIds(ours.remove('semantics')),
        withoutIds(plain.remove('semantics')),
      );
      expect(ours, plain);
      expect(ours['above the button'], isTrue);
    });
  });

  group('robustness', () {
    testWidgets('an animation style from the caller cannot strand a toast', (
      tester,
    ) async {
      // 素のメッセンジャーは、前と違う指定を受けると出ている知らせの
      // アニメーションを作り直し、その知らせが消えなくなる。
      await tester.pumpWidget(app());
      messenger(tester).showSnackBar(const SnackBar(content: Text('first')));
      await untilShown(tester, 'first');
      messenger(tester).showSnackBar(
        const SnackBar(content: Text('second')),
        snackBarAnimationStyle: const AnimationStyle(
          reverseDuration: Duration(seconds: 3),
        ),
      );
      expect(await timeUntilGone(tester, 'first'), lessThan(kToastMaxLifetime));
      await untilShown(tester, 'second');
      messenger(tester).showSnackBar(
        const SnackBar(content: Text('third')),
        snackBarAnimationStyle: AnimationStyle.noAnimation,
      );
      final second = await timeUntilGone(tester, 'second');
      expect(second, lessThan(kToastMaxLifetime));
      await untilShown(tester, 'third');
      expect(await timeUntilGone(tester, 'third'), lessThan(kToastMaxLifetime));
      expect(tester.takeException(), isNull);
    });

    for (final replacing in [false, true]) {
      testWidgets('any order of show, hide, remove, clear, press and swipe'
          '${replacing ? ', with replacements' : ''}', (tester) async {
        await tester.pumpWidget(app());
        final random = math.Random(20261111);
        final shown = <String>[];
        final appeared = <String>[];
        final closed = <String, SnackBarClosedReason>{};
        var cleared = 0;
        String? current() {
          final found = find.byType(SnackBar).evaluate();
          expect(found.length, lessThanOrEqualTo(1));
          if (found.isEmpty) return null;
          return ((found.single.widget as SnackBar).content as Text).data;
        }

        for (var step = 0; step < 400; step++) {
          final state = messenger(tester);
          switch (random.nextInt(9)) {
            case 0 || 1 || 2:
              final name = 'toast ${shown.length}';
              shown.add(name);
              state
                  .showSnackBar(
                    random.nextBool()
                        ? actionToast(
                            name,
                            duration: Duration(
                              milliseconds: 200 + random.nextInt(9000),
                            ),
                          )
                        : SnackBar(content: Text(name)),
                  )
                  .closed
                  .then((reason) => closed[name] = reason);
            case 3:
              state.hideCurrentSnackBar();
            case 4:
              state.removeCurrentSnackBar();
            case 5:
              if (random.nextInt(4) == 0) {
                state.clearSnackBars();
                cleared++;
              }
            case 6:
              final button = find.text('UNDO');
              if (button.evaluate().isNotEmpty && opacityOf('UNDO')! > 0.5) {
                await tester.tap(button, warnIfMissed: false);
              }
            case 7:
              state.removeCurrentSnackBar(reason: SnackBarClosedReason.swipe);
            case 8:
              // 「隠して（すぐ消して）出す」。
              if (!replacing) break;
              final name = 'toast ${shown.length}';
              shown.add(name);
              if (random.nextBool()) {
                state.hideCurrentSnackBar();
              } else {
                state.removeCurrentSnackBar();
              }
              state
                  .showSnackBar(actionToast(name))
                  .closed
                  .then((reason) => closed[name] = reason);
          }
          await tester.pump(Duration(milliseconds: random.nextInt(700)));
          final name = current();
          if (name != null && (appeared.isEmpty || appeared.last != name)) {
            appeared.add(name);
          }
          expect(tester.takeException(), isNull);
        }
        // 残りは時間で順に消える。
        for (var i = 0; i < 2000 && current() != null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final name = current();
          if (name != null && appeared.last != name) appeared.add(name);
        }
        expect(current(), isNull);
        // 出た順は出した順（clearで捨てたものは出ない）。
        final order = appeared.map(shown.indexOf).toList();
        expect(order, [...order]..sort());
        expect(appeared.toSet().length, appeared.length);
        // 出た知らせはすべて閉じた理由が返っている。
        await tester.pump();
        expect(closed.keys.toSet().containsAll(appeared), isTrue);
        debugPrint(
          'fuzz: shown ${shown.length}, appeared ${appeared.length}, '
          'cleared $cleared times, reasons '
          '${closed.values.map((r) => r.name).toSet().toList()..sort()}',
        );
        expect(appeared.length, greaterThan(40));
      });
    }
  });

  group('what this relies on in the Flutter SDK', () {
    String sdkSource(String file) {
      // `flutter test`はFLUTTER_ROOTを渡す。無ければ実行ファイルの場所
      // （bin/cache/artifacts/engine/<platform>/flutter_tester）からたどる。
      var root = Platform.environment['FLUTTER_ROOT'];
      if (root == null || root.isEmpty) {
        var directory = File(Platform.resolvedExecutable).parent;
        for (var i = 0; i < 5; i++) {
          directory = directory.parent;
        }
        root = directory.path;
      }
      final source = File('$root/packages/flutter/lib/src/material/$file');
      expect(source.existsSync(), isTrue, reason: 'no SDK source at $source');
      return source.readAsStringSync();
    }

    test('the copy of a SnackBar keeps every constructor argument', () {
      // SDKがSnackBarへ引数を足したら、_Toastの写しにも足す。
      final source = sdkSource('snack_bar.dart');
      final start = source.indexOf('const SnackBar({');
      final end = source.indexOf('})', start);
      final names = RegExp(r'(?:this\.|bool\? )(\w+)')
          .allMatches(source.substring(start, end))
          .map((match) => match.group(1)!)
          .toSet();
      expect(names, {
        'content',
        'backgroundColor',
        'elevation',
        'margin',
        'padding',
        'width',
        'shape',
        'hitTestBehavior',
        'behavior',
        'action',
        'actionOverflowThreshold',
        'showCloseIcon',
        'closeIconColor',
        'duration',
        'persist',
        'animation',
        'onVisible',
        'dismissDirection',
        'clipBehavior',
      });
    });

    test('the floating Material 3 SnackBar fades on the curve we invert', () {
      final source = sdkSource(
        'snack_bar.dart',
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        source,
        contains(
          'const Curve _snackBarM3FadeInCurve = '
          'Interval(0.4, 0.6, curve: Curves.easeInCirc);',
        ),
      );
      expect(
        source,
        contains(
          'const Duration _snackBarTransitionDuration = '
          'Duration(milliseconds: 250);',
        ),
      );
    });

    testWidgets('the app theme shows floating Material 3 toasts', (
      tester,
    ) async {
      expect(theme.useMaterial3, isTrue);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });
  });
}

/// 続けて入れ替えたとき、最後の知らせが出始めるまでに待つ分（前の知らせが
/// 薄くなる300ms＋出てくる途中なら伸び切るまでの100ms＋描画のずれ）。
const Duration _replaceSlack = Duration(milliseconds: 500);

class _Page extends StatelessWidget {
  const _Page(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('bar $name')),
      body: Center(child: Text('page $name')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
