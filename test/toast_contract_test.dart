import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/push_notification_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/widgets/export_share_feedback.dart';
import 'package:niarim/widgets/moved_to_trash_snack_bar.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';
import 'package:niarim/widgets/startup_failure_app.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 画面下の知らせ（トースト＝SnackBar）の決まり。
///
/// * どこから出しても、出始めてから5秒以内に自分で消える（操作ボタンが
///   あっても、長い時間を指定しても、時間で消えないと指定しても）。
/// * 消えるときは突然消えず、少しずつ薄くなる。
/// * 上の2つを避けて通る書き方がlib配下に無い。
///
/// 実際のアプリ（`NiarimApp`）を起動画面から入って確かめる。部品の単体の
/// 確かめは`app_toast_messenger_test.dart`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('ja'));

  /// 出始めてから消え切るまでの上限。
  const longestLife = Duration(seconds: 5);

  /// 1フレーム（60Hz）。
  const frame = Duration(milliseconds: 16);

  Finder toast() => find.byType(SnackBar);

  /// 出ている知らせの不透明度（祖先の`FadeTransition`・`Opacity`の積）。
  /// ツリーに無ければnull。
  double? toastOpacity() {
    double? best;
    final surfaces = find.descendant(
      of: toast(),
      matching: find.byType(Material),
    );
    for (final element in surfaces.evaluate()) {
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

  String show(double value) => value.toStringAsFixed(2);

  /// 知らせがツリーに入るのを待ち（ファイルの読み書きは実時間で進める）、
  /// 入った最初のフレームから消え切るまでを1フレームずつ見る。
  Future<_ToastLife> watchToast(
    WidgetTester tester, {
    Duration giveUpAfter = const Duration(seconds: 12),
  }) async {
    for (var i = 0; i < 600 && toastOpacity() == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(toastOpacity(), isNotNull, reason: '知らせが出なかった');
    final hadAction = find
        .descendant(of: toast(), matching: find.byType(SnackBarAction))
        .evaluate()
        .isNotEmpty;
    var elapsed = Duration.zero;
    var fullyShown = false;
    final exit = <double>[];
    while (toastOpacity() != null && elapsed < giveUpAfter) {
      await tester.pump(frame);
      elapsed += frame;
      final now = toastOpacity();
      if (now == null) break;
      if (now >= 1.0 && exit.isEmpty) {
        fullyShown = true;
      } else if (fullyShown) {
        exit.add(now);
      }
    }
    return _ToastLife(
      total: elapsed,
      leftByItself: toastOpacity() == null,
      fullyShown: fullyShown,
      hadAction: hadAction,
      exit: exit,
    );
  }

  /// 5秒以内に自分で消えたこと。
  void expectWithinFiveSeconds(_ToastLife life, String what) {
    debugPrint(
      '$what: ${life.leftByItself ? '${life.total.inMilliseconds} msで消えた' : '${life.total.inMilliseconds} ms待っても残っている'}'
      '、薄くなる間の不透明度 ${life.exit.map(show).join(' ')}',
    );
    expect(life.fullyShown, isTrue, reason: '$what：一度も出切らなかった');
    expect(
      life.leftByItself,
      isTrue,
      reason: '$what：${life.total.inSeconds}秒待っても消えない',
    );
    expect(
      life.total,
      lessThanOrEqualTo(longestLife),
      reason: '$what：出始めてから消え切るまでが5秒を超えた',
    );
  }

  /// 少しずつ薄くなって消えたこと：濃くならない・1フレームで大きく
  /// 落ちない・途中の濃さのフレームが十分ある・0.3〜0.6秒かける・見えない
  /// まま残る時間が無い。
  void expectGradualExit(_ToastLife life, String what) {
    final samples = life.exit.map(show).join(' ');
    final values = [1.0, ...life.exit, 0.0];
    var inBetween = 0;
    var largestDrop = 0.0;
    for (var i = 1; i < values.length; i++) {
      final drop = values[i - 1] - values[i];
      expect(
        drop,
        greaterThanOrEqualTo(-1e-9),
        reason: '$what：濃くなった（$samples）',
      );
      if (drop > largestDrop) largestDrop = drop;
      if (values[i] > 0.02 && values[i] < 0.98) inBetween++;
    }
    expect(
      largestDrop,
      lessThanOrEqualTo(0.12),
      reason: '$what：1フレームで${show(largestDrop)}落ちた（$samples）',
    );
    expect(
      inBetween,
      greaterThanOrEqualTo(12),
      reason: '$what：途中の濃さが$inBetweenフレームしか無い（$samples）',
    );
    final exitTime = frame * (life.exit.length + 1);
    expect(
      exitTime.inMilliseconds,
      inInclusiveRange(300, 600),
      reason: '$what：薄くなる時間（$samples）',
    );
    final invisible = life.exit.where((value) => value <= 0.0).length;
    expect(
      invisible,
      lessThanOrEqualTo(1),
      reason: '$what：見えないまま$invisibleフレーム残った（次の知らせが待つ）',
    );
  }

  group('実際のアプリ', () {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('niarim_toast_contract_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
      appRouter.go('/');
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'home_view_mode': 'medium',
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<ProjectService> boot(
      WidgetTester tester, {
      List<String> names = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(providers: providers, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final service = tester
          .element(find.byType(SplashScreen))
          .read<ProjectService>();
      await tester.runAsync(() async {
        for (final name in names) {
          await service.createProject(
            name: name,
            fps: 12,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
          );
          await Future<void>.delayed(const Duration(milliseconds: 3));
        }
      });
      await tester.tap(find.byIcon(Icons.brush_outlined));
      await settle(tester);
      return service;
    }

    Finder card(String name) => find.descendant(
      of: find.byType(ProjectListWidget),
      matching: find.text(name),
    );

    BuildContext home(WidgetTester tester) =>
        tester.element(find.byType(ProjectListWidget));

    testWidgets('ホーム：メニューからゴミ箱へ移した知らせ（「元に戻す」付き）', (tester) async {
      final service = await boot(tester, names: ['apple']);
      await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.tap(find.text(l10n.homeMoveToTrash));
      final life = await watchToast(tester);
      expect(service.projects, isEmpty);
      expect(life.hadAction, isTrue);
      expectWithinFiveSeconds(life, 'ゴミ箱へ移した知らせ');
      expectGradualExit(life, 'ゴミ箱へ移した知らせ');
    });

    testWidgets('ホーム：切り取りの知らせ（「元に戻す」付き）', (tester) async {
      await boot(tester, names: ['apple']);
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.commonCut));
      final life = await watchToast(tester);
      expect(life.hadAction, isTrue);
      expectWithinFiveSeconds(life, '切り取りの知らせ');
      expectGradualExit(life, '切り取りの知らせ');
    });

    testWidgets('ホーム：コピーの知らせ（文だけ）', (tester) async {
      await boot(tester, names: ['apple']);
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.commonCopy));
      final life = await watchToast(tester);
      expect(life.hadAction, isFalse);
      expectWithinFiveSeconds(life, 'コピーの知らせ');
      expectGradualExit(life, 'コピーの知らせ');
    });

    for (final away in [16, 100, 200]) {
      testWidgets('ホーム：コピーの知らせが出てくる途中（$away ms）でアプリが裏へ回っても、戻ってから読める', (
        tester,
      ) async {
        await boot(tester, names: ['apple']);
        await tester.longPress(card('apple'));
        await settle(tester);
        await tester.tap(find.byTooltip(l10n.commonCopy));
        // 知らせが初めて描かれたフレーム。
        for (var i = 0; i < 200 && toastOpacity() == null; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(toastOpacity(), isNotNull, reason: '知らせが出なかった');
        for (var t = 0; t < away; t += 16) {
          await tester.pump(frame);
        }
        final then = toastOpacity();
        // ホームボタン・画面のロック・電話等で裏へ回り、6秒後に戻る。
        final binding = tester.binding;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        addTearDown(
          () =>
              binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
        );
        await tester.pump(const Duration(seconds: 6));
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        var readable = Duration.zero;
        var elapsed = Duration.zero;
        while (toastOpacity() != null &&
            elapsed < const Duration(seconds: 12)) {
          await tester.pump(frame);
          elapsed += frame;
          if ((toastOpacity() ?? 0.0) >= 0.99) readable += frame;
        }
        debugPrint(
          'コピーの知らせ：出てきて$away ms（不透明度${show(then ?? 0.0)}）で'
          '裏へ回り、戻ってから出切っていた時間 ${readable.inMilliseconds} ms、'
          '${elapsed.inMilliseconds} msで消えた',
        );
        expect(
          readable,
          greaterThanOrEqualTo(const Duration(seconds: 4)),
          reason: '戻ってから読めなかった',
        );
        expect(toastOpacity(), isNull, reason: '戻ってから12秒待っても残っている');
        expect(elapsed, lessThanOrEqualTo(longestLife));
      });
    }

    /// ホームの一覧で、表示している作品が「apple」だけになるようにする。
    final onlyApple =
        <String, Future<void> Function(WidgetTester, ProjectService)>{
          '一覧の最後の作品': (tester, service) async {},
          'フォルダの中の最後の作品': (tester, service) async {
            await tester.runAsync(() async {
              final folder = await service.createFolder('box');
              final apple = service.projects.firstWhere(
                (p) => p.name == 'apple',
              );
              await service.moveToFolder(apple.id, folder.id);
            });
            await settle(tester);
            await tester.tap(card('box'));
            await settle(tester);
          },
          '検索で絞った最後の作品': (tester, service) async {
            await tester.tap(find.byTooltip(l10n.commonSearch));
            await settle(tester);
            await tester.enterText(find.byType(TextField), 'apple');
            await settle(tester);
          },
        };

    for (final MapEntry(key: what, value: narrow) in onlyApple.entries) {
      testWidgets('ホーム：$whatをメニューからゴミ箱へ移し、「元に戻す」で戻る', (tester) async {
        final service = await boot(
          tester,
          names: what == '一覧の最後の作品' ? ['apple'] : ['apple', 'banana'],
        );
        await narrow(tester, service);
        expect(card('apple'), findsOneWidget);
        expect(card('banana'), findsNothing);
        await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
        await settle(tester);
        await tester.tap(find.text(l10n.homeMoveToTrash));
        final undo = find.descendant(
          of: toast(),
          matching: find.text(l10n.homeUndoAction),
        );
        for (var i = 0; i < 400 && undo.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(frame);
        }
        expect(undo, findsOneWidget, reason: '「元に戻す」の知らせが出なかった');
        expect(service.trash.map((p) => p.name), ['apple']);
        await settle(tester);
        await tester.tap(undo);
        for (
          var i = 0;
          i < 400 && service.projects.every((p) => p.name != 'apple');
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(frame);
        }
        await settle(tester);
        debugPrint(
          '$what：「元に戻す」の後 作品 '
          '${service.projects.map((p) => p.name).toList()}、ゴミ箱 '
          '${service.trash.map((p) => p.name).toList()}、失敗の知らせ '
          '${find.text(l10n.homeTrashOperationFailed).evaluate().length}件',
        );
        expect(service.projects.map((p) => p.name), contains('apple'));
        expect(service.trash, isEmpty);
        expect(card('apple'), findsOneWidget);
      });
    }

    /// 同じ知らせを続けて出し直した後、[text]が画面にあった時間と、
    /// 全部消えるまでの時間。
    Future<({Duration onScreen, Duration allGone})> afterRepeats(
      WidgetTester tester,
      String text,
    ) async {
      var elapsed = Duration.zero;
      var onScreen = Duration.zero;
      while (toastOpacity() != null && elapsed < const Duration(seconds: 30)) {
        await tester.pump(frame);
        elapsed += frame;
        if (find.text(text).evaluate().isNotEmpty) onScreen += frame;
      }
      debugPrint(
        '$text：画面に${onScreen.inMilliseconds} ms、最後に押してから'
        '${elapsed.inMilliseconds} msで全部消えた',
      );
      return (onScreen: onScreen, allGone: elapsed);
    }

    testWidgets('ホーム：続けて貼り付けた知らせ（すぐ消して入れ替える）', (tester) async {
      final service = await boot(tester, names: ['apple']);
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.commonCopy));
      await settle(tester);
      await settle(tester);
      expect(toast(), findsOneWidget);

      Future<void> paste(int expected) async {
        await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
        for (var i = 0; i < 400 && service.projects.length < expected; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(service.projects.length, expected);
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
        }
        await tester.pump(frame);
      }

      // 2回目は、1回目の知らせへ入れ替わる途中で押す。
      await paste(2);
      await tester.pump(frame);
      await paste(3);
      final life = await afterRepeats(tester, l10n.homePasteSnackbar);
      expect(life.onScreen, lessThanOrEqualTo(longestLife));
      expect(
        life.allGone,
        lessThanOrEqualTo(longestLife + const Duration(milliseconds: 500)),
      );
    });

    testWidgets('エラーの記録：続けてコピーした知らせ（隠して入れ替える）', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      AppErrorReporter.recentErrors.add('[2026-11-13 00:00:00] Bad state');
      addTearDown(AppErrorReporter.recentErrors.clear);
      await boot(tester);
      appRouter.push('/settings/error-log');
      await settle(tester);
      await settle(tester);
      // 1回目の知らせが出切ってから、続けて2回押す（2回目の知らせへ
      // 入れ替わる途中で3回目）。
      await tester.tap(find.byKey(const Key('errorLogCopyAll')));
      await settle(tester);
      expect(toastOpacity(), 1.0);
      for (var press = 0; press < 2; press++) {
        await tester.tap(find.byKey(const Key('errorLogCopyAll')));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 15));
        }
      }
      final life = await afterRepeats(tester, l10n.errorLogCopied);
      expect(life.onScreen, lessThanOrEqualTo(longestLife));
      expect(
        life.allGone,
        lessThanOrEqualTo(longestLife + const Duration(milliseconds: 500)),
      );
    });

    /// ファイルの読み書きを実時間で進める（アニメーションの時計は進めない。
    /// 速い端末で、保存が知らせの薄くなる間に終わるときの形）。
    Future<void> untilSaved(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 400 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(done(), isTrue, reason: '保存が終わらなかった');
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
    }

    /// 「元に戻す」が出切っていた時間を、知らせが全部消えるまで数える。
    Future<Duration> undoFullyShown(WidgetTester tester) async {
      var elapsed = Duration.zero;
      var shown = Duration.zero;
      while (toastOpacity() != null && elapsed < const Duration(seconds: 12)) {
        await tester.pump(frame);
        elapsed += frame;
        final undo = find.descendant(
          of: toast(),
          matching: find.text(l10n.homeUndoAction),
        );
        if (undo.evaluate().isNotEmpty && toastOpacity() == 1.0) {
          shown += frame;
        }
        // 保存の続き（お気に入りの書き込み等）も止めない。
        if (elapsed.inMilliseconds % 160 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
      }
      debugPrint(
        '「${l10n.homeUndoAction}」が出切っていた時間 ${shown.inMilliseconds} ms、'
        '${elapsed.inMilliseconds} msで全部消えた',
      );
      expect(toastOpacity(), isNull, reason: '12秒待っても知らせが残っている');
      return shown;
    }

    testWidgets('作品の詳細の流れ：ゴミ箱へ移した直後にお気に入りを切り替えても「元に戻す」が出る', (tester) async {
      final service = await boot(tester, names: ['apple', 'cherry']);
      final appleId = service.projects.firstWhere((p) => p.name == 'apple').id;
      final cherryId = service.projects
          .firstWhere((p) => p.name == 'cherry')
          .id;
      final context = home(tester);
      final messenger = ScaffoldMessenger.of(context);
      // 前の知らせ（コピーした等）が出ている。
      messenger.showSnackBar(const SnackBar(content: Text('前の知らせ')));
      for (var i = 0; i < 60; i++) {
        await tester.pump(frame);
      }
      // project_detail_screen.dartのゴミ箱へ移す流れ（同じ部品）。
      var saved = false;
      final trashed = runProjectTrashAction(
        context,
        () => service.deleteProject(appleId),
      ).then((value) => saved = value);
      await untilSaved(tester, () => saved);
      await trashed;
      showMovedToTrashSnackBar(messenger, l10n, service, [appleId]);
      for (var i = 0; i < 6; i++) {
        await tester.pump(frame);
      }
      // 星のonPressedと同じ（project_list_widget.dartのonFavorite）。
      final favorite = runProjectAction(
        context,
        () => service.toggleFavorite(cherryId),
      );
      await untilSaved(
        tester,
        () => service.projects.firstWhere((p) => p.id == cherryId).isFavorite,
      );
      expect(await favorite, isTrue);
      final shown = await undoFullyShown(tester);
      expect(service.trash.map((p) => p.name).toList(), ['apple']);
      expect(
        shown,
        greaterThanOrEqualTo(const Duration(seconds: 4)),
        reason: '「元に戻す」が出なかった',
      );
    });

    Finder star(String id) => find.descendant(
      of: find.byKey(Key('collectionFavorite_$id')),
      matching: find.byType(IconButton),
    );

    /// 作品の保存（.niapro）を書けなくする。同じ名前のフォルダを置くので、
    /// rootで動かしても置き換えに失敗する。戻す関数を返す。
    Future<void Function()> breakSave(WidgetTester tester, String id) async {
      final base = (await tester.runAsync(NiaproSerializer.projectsBasePath))!;
      final file = File('$base/$id/$id.niapro');
      final aside = File('${file.path}.aside');
      file.renameSync(aside.path);
      Directory(file.path).createSync();
      File('${file.path}/keep').writeAsStringSync('x');
      return () {
        Directory(file.path).deleteSync(recursive: true);
        aside.renameSync(file.path);
      };
    }

    /// [watched]の知らせ（文）ごとに、出切っていた時間とツリーにあった時間を
    /// 足しながら[by]だけ描く。ファイルの読み書き（お気に入りの保存等）も
    /// 実時間で進める。
    Future<void> step(
      WidgetTester tester,
      Map<String, _Noticed> watched, [
      Duration by = frame,
    ]) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(by);
      for (final MapEntry(key: text, value: times) in watched.entries) {
        final mine = find.descendant(of: toast(), matching: find.text(text));
        if (mine.evaluate().isEmpty) continue;
        times.inTree += by;
        if (toastOpacity() == 1.0) times.fullyShown += by;
      }
    }

    /// 知らせが全部消えるまで（[stopText]が[stopAfter]出切ったら、そこまで）
    /// 1フレームずつ数える。
    Future<void> follow(
      WidgetTester tester,
      Map<String, _Noticed> watched, {
      String? stopText,
      Duration? stopAfter,
    }) async {
      var elapsed = Duration.zero;
      while (toastOpacity() != null && elapsed < const Duration(seconds: 15)) {
        await step(tester, watched);
        elapsed += frame;
        if (stopText != null && watched[stopText]!.fullyShown >= stopAfter!) {
          break;
        }
      }
      for (final MapEntry(key: text, value: times) in watched.entries) {
        debugPrint(
          '「$text」：出切っていた時間 ${times.fullyShown.inMilliseconds} ms、'
          'ツリーにあった時間 ${times.inTree.inMilliseconds} ms',
        );
      }
    }

    // ホームの星はカードがダブルタップ（キャンバスを開く）を待つので、
    // 押してから約0.3秒後に動く。作品の操作の始めに出ている知らせを種類を
    // 見ずに隠していたので、ゴミ箱へ移した直後に星を押すと「元に戻す」が
    // 出る前（または出てすぐ）に消え、ゴミ箱へ移した作品を戻せなかった。
    for (final via in ['カードのメニュー', '選択のバー']) {
      for (final delay in [100, 400]) {
        testWidgets('ホーム：$viaからゴミ箱へ移して$delay ms後に別の作品の星を押しても、'
            '「元に戻す」が4秒出ていて押すと戻る', (tester) async {
          final service = await boot(tester, names: ['apple', 'banana']);
          final bananaId = service.projects
              .firstWhere((p) => p.name == 'banana')
              .id;
          bool favorite() =>
              service.projects.firstWhere((p) => p.id == bananaId).isFavorite;
          if (via == 'カードのメニュー') {
            await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
            await settle(tester);
            await tester.tap(find.text(l10n.homeMoveToTrash));
          } else {
            await tester.longPress(card('apple'));
            await settle(tester);
            await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
            await settle(tester);
            await tester.tap(
              find.widgetWithText(FilledButton, l10n.commonMove),
            );
          }
          final moved = l10n.homeMovedToTrashSnackbar(1);
          final watched = {moved: _Noticed()};
          // ゴミ箱へ移す保存は実時間で進め、知らせが出たフレームから数える。
          for (
            var i = 0;
            i < 400 && watched[moved]!.inTree == Duration.zero;
            i++
          ) {
            await step(tester, watched, const Duration(milliseconds: 1));
          }
          expect(
            watched[moved]!.inTree,
            greaterThan(Duration.zero),
            reason: 'ゴミ箱へ移した知らせが出なかった',
          );
          expect(service.trash.map((p) => p.name), ['apple']);
          for (var t = 0; t < delay; t += 20) {
            await step(tester, watched, const Duration(milliseconds: 20));
          }
          await tester.tap(star(bananaId));
          await follow(
            tester,
            watched,
            stopText: moved,
            stopAfter: const Duration(seconds: 4),
          );
          expect(
            watched[moved]!.fullyShown,
            greaterThanOrEqualTo(const Duration(seconds: 4)),
            reason: '星を押したら「元に戻す」が消えた',
          );
          expect(favorite(), isTrue, reason: '星が効かなかった');
          // まだ出ている「元に戻す」を押すと戻る。
          await tester.tap(
            find.descendant(
              of: toast(),
              matching: find.text(l10n.homeUndoAction),
            ),
          );
          for (
            var i = 0;
            i < 400 && service.projects.every((p) => p.name != 'apple');
            i++
          ) {
            await step(tester, watched);
          }
          await settle(tester);
          expect(service.projects.map((p) => p.name), contains('apple'));
          expect(service.trash, isEmpty);
          expect(card('apple'), findsOneWidget);
        });
      }
    }

    /// ホームで「apple」をコピーし、コピーの知らせが出切るまで数える。
    Future<String> copyApple(
      WidgetTester tester,
      Map<String, _Noticed> watched,
    ) async {
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.commonCopy));
      final copied = l10n.homeCopiedSnackbar(1);
      watched[copied] = _Noticed();
      for (
        var i = 0;
        i < 100 && watched[copied]!.fullyShown == Duration.zero;
        i++
      ) {
        await step(tester, watched);
      }
      expect(
        watched[copied]!.fullyShown,
        greaterThan(Duration.zero),
        reason: 'コピーの知らせが出なかった',
      );
      return copied;
    }

    // 作品の操作（お気に入り等）を始めるときは、前の操作の失敗の知らせだけを
    // 閉じる（やり直したのに前の失敗が出たままにならない）。他の機能の知らせ
    // （コピーの知らせ等）は閉じない。
    testWidgets('ホーム：前の操作の失敗の知らせは次の操作で閉じ、コピーの知らせは閉じない', (tester) async {
      final service = await boot(tester, names: ['apple', 'banana']);
      final bananaId = service.projects
          .firstWhere((p) => p.name == 'banana')
          .id;
      bool favorite() =>
          service.projects.firstWhere((p) => p.id == bananaId).isFavorite;
      final failed = l10n.homeTrashOperationFailed;
      final watched = {failed: _Noticed()};
      final restore = await breakSave(tester, bananaId);
      await tester.tap(star(bananaId));
      for (
        var i = 0;
        i < 400 && watched[failed]!.fullyShown == Duration.zero;
        i++
      ) {
        await step(tester, watched);
      }
      expect(
        watched[failed]!.fullyShown,
        greaterThan(Duration.zero),
        reason: 'お気に入りを保存できなかったと知らせなかった',
      );
      expect(favorite(), isFalse);

      // もう一度押す（今度は保存できる）と、前の失敗の知らせは閉じる。
      restore();
      await tester.tap(star(bananaId));
      final failure = find.descendant(of: toast(), matching: find.text(failed));
      var waited = Duration.zero;
      while (failure.evaluate().isNotEmpty &&
          waited < const Duration(seconds: 6)) {
        await step(tester, watched);
        waited += frame;
      }
      debugPrint('前の失敗の知らせは、もう一度押してから${waited.inMilliseconds} msで消えた');
      expect(
        waited,
        lessThanOrEqualTo(const Duration(milliseconds: 1200)),
        reason: '前の失敗の知らせが、もう一度押した後も出続けた',
      );
      for (var i = 0; i < 400 && !favorite(); i++) {
        await step(tester, watched);
      }
      expect(favorite(), isTrue);

      // コピーの知らせが出ているときにお気に入りを外しても、コピーの知らせは
      // 自分の時間だけ出ている。
      final copied = await copyApple(tester, watched);
      await tester.tap(star(bananaId));
      await follow(tester, watched);
      expect(
        watched[copied]!.fullyShown,
        greaterThanOrEqualTo(const Duration(milliseconds: 3900)),
        reason: 'お気に入りを外したらコピーの知らせが消えた',
      );
      for (var i = 0; i < 400 && favorite(); i++) {
        await step(tester, watched);
      }
      expect(favorite(), isFalse, reason: '星が効かなかった');
    });

    /// 読み上げの木に、[text]を読み上げる知らせ（liveRegion）があるか。
    bool announced(String text) => find.semantics
        .byPredicate(
          (node) =>
              node.label.contains(text) && node.flagsCollection.isLiveRegion,
        )
        .evaluate()
        .isNotEmpty;

    /// 星を押してお気に入りの保存を失敗させる（失敗の知らせが並ぶ）。
    Future<void> failingStar(
      WidgetTester tester,
      String id,
      Map<String, _Noticed> watched,
    ) async {
      final errors = AppErrorReporter.recentErrors.length;
      await tester.tap(star(id));
      for (
        var i = 0;
        i < 400 && AppErrorReporter.recentErrors.length == errors;
        i++
      ) {
        await step(tester, watched);
      }
      expect(
        AppErrorReporter.recentErrors.length,
        errors + 1,
        reason: '保存が失敗しなかった',
      );
      await step(tester, watched);
    }

    // 失敗の知らせが前の知らせの後ろで待っている間に次の操作が始まったら、
    // 前の知らせはそのまま出し、失敗の知らせは出さずに下げる（押し直して
    // 保存できた後で、前の失敗を出さない）。
    testWidgets('ホーム：待っている失敗の知らせは、押し直して保存できたら出さずに下げる。前に出ている知らせは閉じない', (
      tester,
    ) async {
      final service = await boot(tester, names: ['apple', 'banana']);
      final bananaId = service.projects
          .firstWhere((p) => p.name == 'banana')
          .id;
      bool favorite() =>
          service.projects.firstWhere((p) => p.id == bananaId).isFavorite;
      AppErrorReporter.recentErrors.clear();
      addTearDown(AppErrorReporter.recentErrors.clear);
      final failed = l10n.homeTrashOperationFailed;
      final restore = await breakSave(tester, bananaId);

      // 押し直さなければ、失敗の知らせはコピーの知らせの後に出る（並んで
      // いることの確かめ）。
      var watched = {failed: _Noticed()};
      var copied = await copyApple(tester, watched);
      await failingStar(tester, bananaId, watched);
      await follow(tester, watched);
      expect(
        watched[failed]!.fullyShown,
        greaterThan(Duration.zero),
        reason: '失敗の知らせが並ばなかった',
      );
      expect(favorite(), isFalse);

      // 並んでいる間に押し直して保存できたら、失敗の知らせは出さない。
      watched = {failed: _Noticed()};
      copied = await copyApple(tester, watched);
      await failingStar(tester, bananaId, watched);
      restore();
      await tester.tap(star(bananaId));
      for (var i = 0; i < 400 && !favorite(); i++) {
        await step(tester, watched);
      }
      expect(favorite(), isTrue);
      await follow(tester, watched);
      expect(
        watched[copied]!.fullyShown,
        greaterThanOrEqualTo(const Duration(milliseconds: 3900)),
        reason: 'お気に入りを押したらコピーの知らせが消えた',
      );
      expect(
        watched[failed]!.inTree,
        Duration.zero,
        reason: '押し直して保存できたのに、前の失敗の知らせが出た',
      );
      expect(toast(), findsNothing);
    });

    // 読み上げ（TalkBack）の利用者にも、押し直して保存できた後で前の失敗を
    // 読み上げない。
    testWidgets('ホーム（読み上げ）：「元に戻す」の後ろで待っている失敗の知らせは、押し直して保存できたら読み上げない', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final service = await boot(tester, names: ['apple', 'banana', 'cherry']);
      final bananaId = service.projects
          .firstWhere((p) => p.name == 'banana')
          .id;
      bool favorite() =>
          service.projects.firstWhere((p) => p.id == bananaId).isFavorite;
      AppErrorReporter.recentErrors.clear();
      addTearDown(AppErrorReporter.recentErrors.clear);
      final moved = l10n.homeMovedToTrashSnackbar(1);
      final failed = l10n.homeTrashOperationFailed;
      final restore = await breakSave(tester, bananaId);

      Future<Map<String, _Noticed>> trash(String name) async {
        final watched = {moved: _Noticed(), failed: _Noticed()};
        await tester.tap(card(name), buttons: kSecondaryMouseButton);
        await settle(tester);
        await tester.tap(find.text(l10n.homeMoveToTrash));
        for (
          var i = 0;
          i < 400 && watched[moved]!.fullyShown == Duration.zero;
          i++
        ) {
          await step(tester, watched, const Duration(milliseconds: 4));
        }
        expect(
          watched[moved]!.fullyShown,
          greaterThan(Duration.zero),
          reason: 'ゴミ箱へ移した知らせが出なかった',
        );
        return watched;
      }

      /// 知らせが全部消えるまで進め、その間に[failed]を読み上げたか。
      Future<bool> untilQuiet(Map<String, _Noticed> watched) async {
        var heard = announced(failed);
        for (
          var t = Duration.zero;
          t < const Duration(seconds: 12) && toastOpacity() != null;
          t += frame
        ) {
          await step(tester, watched);
          heard |= announced(failed);
        }
        expect(toast(), findsNothing);
        return heard;
      }

      // 押し直さなければ、「元に戻す」の後に失敗の知らせを読み上げる（並んで
      // いることの確かめ）。
      var watched = await trash('apple');
      await failingStar(tester, bananaId, watched);
      expect(await untilQuiet(watched), isTrue, reason: '失敗の知らせが並ばなかった');

      // 並んでいる間に押し直して保存できたら、失敗の知らせは読み上げない。
      watched = await trash('cherry');
      await failingStar(tester, bananaId, watched);
      restore();
      await tester.tap(star(bananaId));
      var heard = false;
      for (var i = 0; i < 400 && !favorite(); i++) {
        await step(tester, watched);
        heard |= announced(failed);
      }
      expect(favorite(), isTrue);
      heard |= await untilQuiet(watched);
      expect(heard, isFalse, reason: '押し直して保存できたのに、前の失敗を読み上げた');
      expect(watched[failed]!.inTree, Duration.zero);
      expect(
        watched[moved]!.fullyShown,
        greaterThanOrEqualTo(const Duration(milliseconds: 3900)),
        reason: 'お気に入りを押したら「元に戻す」が消えた',
      );
      semantics.dispose();
    });

    // 失敗の知らせが待っている間に切り取ると、切り取りの知らせをすぐ出す
    // ためにホームが待っている知らせを下げる（clearSnackBars）。下げられた
    // 知らせは閉じた知らせとして終わらないので、覚えたまま残さない。
    testWidgets('ホーム：待っている失敗の知らせが切り取りで下げられても、覚えたまま残らない', (tester) async {
      final service = await boot(tester, names: ['apple', 'banana', 'cherry']);
      final bananaId = service.projects
          .firstWhere((p) => p.name == 'banana')
          .id;
      AppErrorReporter.recentErrors.clear();
      addTearDown(AppErrorReporter.recentErrors.clear);
      final failed = l10n.homeTrashOperationFailed;
      final watched = {failed: _Noticed()};
      final messenger = ScaffoldMessenger.of(home(tester));
      final restore = await breakSave(tester, bananaId);
      for (var round = 0; round < 3; round++) {
        await copyApple(tester, watched);
        await failingStar(tester, bananaId, watched);
        await tester.longPress(card('cherry'));
        await settle(tester);
        await tester.tap(find.byTooltip(l10n.commonCut));
        await follow(tester, watched);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await follow(tester, watched);
        await settle(tester);
      }
      restore();
      expect(toast(), findsNothing);
      expect(
        debugProjectActionFailuresTracked(messenger),
        0,
        reason: '下げられた失敗の知らせを覚えたまま残した',
      );
    });

    testWidgets('アプリ全体のキーから出す知らせ（通知を受けたときの形）', (tester) async {
      await boot(tester);
      // PushNotificationService._showForegroundと同じ出し方・同じ形。
      PushNotificationService.scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: const Text('お知らせ'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '開く', onPressed: () {}),
        ),
      );
      final life = await watchToast(tester);
      expect(life.hadAction, isTrue);
      expectWithinFiveSeconds(life, 'キーから出した知らせ');
      expectGradualExit(life, 'キーから出した知らせ');
    });

    testWidgets('画面を離れる前に取っておいた出し先から出す知らせ', (tester) async {
      await boot(tester);
      // 共有の前に取っておく出し先（ExportShareHandles）と、画面のcontextから
      // 取ったメッセンジャーそのもの。
      final handles = ExportShareHandles.of(home(tester));
      final captured = ScaffoldMessenger.of(home(tester));
      appRouter.push('/settings');
      await settle(tester);
      await settle(tester);

      handles.tell('共有できませんでした');
      var life = await watchToast(tester);
      expectWithinFiveSeconds(life, '取っておいた出し先の知らせ');
      expectGradualExit(life, '取っておいた出し先の知らせ');

      // 決まりを考えずに書かれた呼び出し：長い時間・時間で消えない指定。
      captured.showSnackBar(
        SnackBar(
          content: const Text('あとから'),
          duration: const Duration(seconds: 30),
          persist: true,
          action: SnackBarAction(label: '開く', onPressed: () {}),
        ),
      );
      life = await watchToast(tester);
      expectWithinFiveSeconds(life, '時間で消えないと指定した知らせ');
      expectGradualExit(life, '時間で消えないと指定した知らせ');
    });

    testWidgets('ダイアログの中から出す知らせ', (tester) async {
      await boot(tester);
      late BuildContext dialogContext;
      showDialog<void>(
        context: home(tester),
        builder: (context) {
          dialogContext = context;
          return const AlertDialog(content: Text('確かめ'));
        },
      );
      await settle(tester);
      // 画面・ダイアログ・アプリ全体のキーは同じ1つの出し先。
      final viaKey = PushNotificationService.scaffoldMessengerKey.currentState;
      expect(ScaffoldMessenger.of(dialogContext), same(viaKey));
      expect(ScaffoldMessenger.of(home(tester)), same(viaKey));
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: const Text('ダイアログから'),
          action: SnackBarAction(label: '開く', onPressed: () {}),
        ),
      );
      final life = await watchToast(tester);
      expectWithinFiveSeconds(life, 'ダイアログから出した知らせ');
      expectGradualExit(life, 'ダイアログから出した知らせ');
    });
  });

  testWidgets('起動に失敗した画面（別のMaterialApp）の知らせ', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      StartupFailureApp(
        details: 'step: brush\nerror: Bad state: boom',
        languageCode: 'ja',
        onRetry: () async {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.startupFailedCopyDetails));
    var life = await watchToast(tester);
    expectWithinFiveSeconds(life, '詳細をコピーした知らせ');
    expectGradualExit(life, '詳細をコピーした知らせ');

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).showSnackBar(
      SnackBar(
        content: const Text('あとから'),
        duration: const Duration(seconds: 30),
        action: SnackBarAction(label: '開く', onPressed: () {}),
      ),
    );
    life = await watchToast(tester);
    expectWithinFiveSeconds(life, '起動に失敗した画面の操作ボタン付きの知らせ');
    expectGradualExit(life, '起動に失敗した画面の操作ボタン付きの知らせ');
  });

  // 素のScaffoldMessenger（アプリの外・部品だけのテスト）でも、作品の操作を
  // 始めるときは前の失敗の知らせだけを閉じる。closeは出ている知らせにしか
  // 使えないので、待っているものは出た所で閉じる。下げられた（clearSnackBars）
  // 知らせは閉じた知らせとして終わらないので、覚えたまま残さない。
  testWidgets('素のScaffoldMessenger：待っている失敗の知らせは出た所で閉じ、下げられた知らせは覚えたまま残さない', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    final failed = l10n.homeTrashOperationFailed;
    Finder shown(String text) =>
        find.descendant(of: toast(), matching: find.text(text));
    Future<bool> fails() =>
        runProjectAction(context, () async => throw StateError('rejected'));

    // 前の知らせの後ろで失敗の知らせが待っている間に、次の操作が始まって
    // 成功する。前の知らせは自分の時間だけ出て、失敗の知らせは出た所で閉じる。
    messenger.showSnackBar(const SnackBar(content: Text('front')));
    await tester.pump();
    expect(await fails(), isFalse);
    expect(await runProjectAction(context, () async {}), isTrue);
    var front = Duration.zero;
    var failure = Duration.zero;
    for (
      var t = Duration.zero;
      t < const Duration(seconds: 12) && toast().evaluate().isNotEmpty;
      t += frame
    ) {
      await tester.pump(frame);
      if (shown('front').evaluate().isNotEmpty) front += frame;
      if (shown(failed).evaluate().isNotEmpty) failure += frame;
    }
    debugPrint(
      '素のメッセンジャー：前の知らせ ${front.inMilliseconds} ms、'
      '待っていた失敗の知らせ ${failure.inMilliseconds} ms',
    );
    expect(toast(), findsNothing);
    expect(
      front,
      greaterThanOrEqualTo(const Duration(milliseconds: 3900)),
      reason: '次の操作で前の知らせが閉じた',
    );
    expect(failure, greaterThan(Duration.zero), reason: '失敗の知らせが並ばなかった');
    expect(
      failure,
      lessThanOrEqualTo(const Duration(milliseconds: 700)),
      reason: '成功した後で前の失敗の知らせが出続けた',
    );

    // 待っている失敗の知らせが下げられる（clearSnackBars）のを3回。
    for (var round = 0; round < 3; round++) {
      messenger.showSnackBar(const SnackBar(content: Text('front')));
      await tester.pump();
      expect(await fails(), isFalse);
      messenger.clearSnackBars();
      await tester.pumpAndSettle();
      expect(toast(), findsNothing);
    }
    expect(
      debugProjectActionFailuresTracked(messenger),
      0,
      reason: '下げられた失敗の知らせを覚えたまま残した',
    );

    // 出ている失敗の知らせは、時間で消えたら覚えたまま残さない。
    expect(await fails(), isFalse);
    await tester.pumpAndSettle(frame);
    expect(shown(failed), findsOneWidget);
    expect(debugProjectActionFailuresTracked(messenger), 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle(frame);
    expect(toast(), findsNothing);
    expect(debugProjectActionFailuresTracked(messenger), 0);

    // 出ている失敗の知らせは、次の操作で閉じる。
    expect(await fails(), isFalse);
    await tester.pumpAndSettle(frame);
    expect(shown(failed), findsOneWidget);
    expect(await runProjectAction(context, () async {}), isTrue);
    await tester.pumpAndSettle(frame);
    expect(toast(), findsNothing);
    expect(debugProjectActionFailuresTracked(messenger), 0);
  });

  group('lib配下に決まりを避けて通る書き方が無い', () {
    const central = 'lib/widgets/app_toast_messenger.dart';

    /// 行コメントを除いたソース（行の数は変えない）。
    Map<String, String> sources() {
      final result = <String, String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.startsWith('lib/l10n/app_localizations')) continue;
        result[path] = entity
            .readAsLinesSync()
            .map((line) => line.trimLeft().startsWith('//') ? '' : line)
            .join('\n');
      }
      return result;
    }

    String where(String path, String source, int offset) {
      final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
      final start = source.lastIndexOf('\n', offset) + 1;
      final end = source.indexOf('\n', offset);
      final text = source.substring(start, end < 0 ? source.length : end);
      return '$path:$line: ${text.trim()}';
    }

    /// [start]（引用符）から始まる文字列リテラルの、次の位置。
    /// 文字列の中の括弧・コンマを引数の区切りと取り違えないために飛ばす。
    int endOfString(String source, int start) {
      int endOfInterpolation(int i) {
        var depth = 1;
        while (i < source.length && depth > 0) {
          final char = source[i];
          if (char == "'" || char == '"') {
            i = endOfString(source, i);
            continue;
          }
          if (char == '{') depth++;
          if (char == '}') depth--;
          i++;
        }
        return i;
      }

      final quote = source[start];
      final close = source.startsWith(quote * 3, start) ? quote * 3 : quote;
      final raw = start > 0 && source[start - 1] == 'r';
      var i = start + close.length;
      while (i < source.length) {
        if (!raw && source[i] == r'\') {
          i += 2;
        } else if (!raw && source.startsWith(r'${', i)) {
          i = endOfInterpolation(i + 2);
        } else if (source.startsWith(close, i)) {
          return i + close.length;
        } else {
          i++;
        }
      }
      return i;
    }

    /// [open]（開き括弧の次の位置）から、対応する閉じ括弧までの中身。
    String insideParentheses(String source, int open) {
      var depth = 1;
      var i = open;
      while (i < source.length && depth > 0) {
        final char = source[i];
        if (char == "'" || char == '"') {
          i = endOfString(source, i);
          continue;
        }
        if (char == '(') depth++;
        if (char == ')') depth--;
        i++;
      }
      return source.substring(open, i - 1);
    }

    /// 引数の並び[arguments]の、一番外側にある[name]の値（無ければnull）。
    String? topLevelArgument(String arguments, String name) {
      var depth = 0;
      var i = 0;
      while (i < arguments.length) {
        final char = arguments[i];
        if (char == "'" || char == '"') {
          i = endOfString(arguments, i);
          continue;
        }
        if ('([{'.contains(char)) depth++;
        if (')]}'.contains(char)) depth--;
        final named =
            depth == 0 &&
            arguments.startsWith('$name:', i) &&
            (i == 0 || !RegExp(r'\w').hasMatch(arguments[i - 1]));
        if (!named) {
          i++;
          continue;
        }
        final valueStart = i + name.length + 1;
        var end = valueStart;
        var inner = 0;
        while (end < arguments.length) {
          final c = arguments[end];
          if (c == "'" || c == '"') {
            end = endOfString(arguments, end);
            continue;
          }
          if ('([{'.contains(c)) inner++;
          if (')]}'.contains(c)) inner--;
          if ((c == ',' && inner == 0) || inner < 0) break;
          end++;
        }
        return arguments
            .substring(valueStart, end)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
      return null;
    }

    /// `const Duration(seconds: 3)`のように数字で書いた長さ（読めなければnull）。
    /// `条件 ? const Duration(...) : const Duration(...)`は長い方。
    /// `Duration(seconds: 条件 ? 5 : 4)`のように項目の値を条件で選ぶときは、
    /// 項目ごとに大きい方を足す（実際より長く見積もることはあっても、短く
    /// 見積もることはない）。
    Duration? literalDuration(String text) {
      final choice = RegExp(
        r'^[^?]*\?\s*((?:const )?Duration\([^()]*\))\s*:\s*'
        r'((?:const )?Duration\([^()]*\))$',
      ).firstMatch(text);
      if (choice != null) {
        final first = literalDuration(choice.group(1)!);
        final second = literalDuration(choice.group(2)!);
        if (first == null || second == null) return null;
        return first > second ? first : second;
      }
      final match = RegExp(
        r'^(?:const )?Duration\(([^()]*)\)$',
      ).firstMatch(text);
      if (match == null) return null;
      var total = Duration.zero;
      for (final part in match.group(1)!.split(',')) {
        if (part.trim().isEmpty) continue;
        final field = RegExp(
          r'^\s*(\w+):\s*(?:(\d+)|[^?:]+\?\s*(\d+)\s*:\s*(\d+))\s*$',
        ).firstMatch(part);
        if (field == null) return null;
        final choices = [
          for (final group in [2, 3, 4])
            if (field.group(group) != null) int.parse(field.group(group)!),
        ];
        final amount = choices.reduce((a, b) => a > b ? a : b);
        total += switch (field.group(1)) {
          'days' => Duration(days: amount),
          'hours' => Duration(hours: amount),
          'minutes' => Duration(minutes: amount),
          'seconds' => Duration(seconds: amount),
          'milliseconds' => Duration(milliseconds: amount),
          'microseconds' => Duration(microseconds: amount),
          _ => throw StateError('unknown Duration field in $text'),
        };
      }
      return total;
    }

    /// 知らせの長さ・残し方の決まりを破っている所と、見た知らせの数。
    ({List<String> offenders, int seen, int timed}) lengthRule(
      Map<String, String> sources,
    ) {
      final offenders = <String>[];
      var seen = 0;
      var timed = 0;
      for (final MapEntry(key: path, value: source) in sources.entries) {
        for (final match in RegExp(
          r'\bSnackBar(?:\.new)?\(',
        ).allMatches(source)) {
          seen++;
          final arguments = insideParentheses(source, match.end);
          final duration = topLevelArgument(arguments, 'duration');
          if (duration != null) {
            timed++;
            final length = literalDuration(duration);
            if (length == null) {
              offenders.add(
                '${where(path, source, match.start)} … duration: $duration'
                '（数字で書いた`Duration(...)`にする）',
              );
            } else if (length > longestLife) {
              offenders.add(
                '${where(path, source, match.start)} … duration: $duration'
                '（5秒を超えている）',
              );
            }
          }
          final persist = topLevelArgument(arguments, 'persist');
          if (persist != null && persist != 'false') {
            offenders.add(
              '${where(path, source, match.start)} … persist: $persist'
              '（残し続ける知らせが要るなら所有者に確かめる）',
            );
          }
        }
      }
      return (offenders: offenders, seen: seen, timed: timed);
    }

    /// 知らせの出し先を増やす・避ける書き方と、見たアプリの数。
    ({List<String> offenders, int apps}) routingRule(
      Map<String, String> sources,
    ) {
      final offenders = <String>[];
      var apps = 0;
      final appPattern = RegExp(
        r'\b(?:MaterialApp|CupertinoApp|WidgetsApp)(?:\.router|\.new)?\(',
      );
      final forbidden = <RegExp, String>{
        RegExp(r'\bScaffoldMessenger(?:\.new)?\s*\('):
            '別のScaffoldMessengerを置いている',
        RegExp(r'\bextends\s+ScaffoldMessenger(?:State)?\b'):
            '別のScaffoldMessengerを作っている',
        RegExp(r'\bscaffoldMessengerKey\s*:'):
            'MaterialApp自身のメッセンジャーへキーを渡している'
            '（キーはAppToastMessengerへ渡す）',
        RegExp(r'\bsnackBarAnimationStyle\b'): '知らせごとにアニメーションを指定している',
        RegExp(r'\bSnackBarBehavior\.fixed\b'): '下端に付く知らせ（薄くなる消え方は浮かぶ知らせだけ）',
        RegExp(r'\bshowMaterialBanner\s*\('): '時間で消えない帯をメッセンジャーから出している',
        RegExp(r'\bextends\s+SnackBar\b'): 'SnackBarを作り替えている',
      };
      for (final MapEntry(key: path, value: source) in sources.entries) {
        for (final match in appPattern.allMatches(source)) {
          apps++;
          // そのアプリ自身のbuilderが包んでいるか（同じファイルの別の
          // アプリが包んでいても足りない）。
          final builder = topLevelArgument(
            insideParentheses(source, match.end),
            'builder',
          );
          if (builder == null || !builder.contains('AppToastMessenger(')) {
            offenders.add(
              '${where(path, source, match.start)} … builderで'
              'AppToastMessengerを通していない',
            );
          }
        }
        if (path == central) continue;
        for (final MapEntry(key: pattern, value: why) in forbidden.entries) {
          for (final match in pattern.allMatches(source)) {
            offenders.add('${where(path, source, match.start)} … $why');
          }
        }
      }
      return (offenders: offenders, apps: apps);
    }

    /// Overlayへ直接重ねている所（ファイルごとの数）。
    Map<String, int> overlayUses(Map<String, String> sources) {
      final found = <String, int>{};
      for (final MapEntry(key: path, value: source) in sources.entries) {
        final count = RegExp(
          r'\bOverlayEntry\(|\bOverlayPortal(?:\.\w+)?\(',
        ).allMatches(source).length;
        if (count > 0) found[path] = count;
      }
      return found;
    }

    /// タイマー（Timer・Timer.periodic・Timer.run・Future.delayed・
    /// Stream.periodic）を使う所（ファイルごとの数）。自作の知らせは
    /// 「出して、時間が来たら消す」ので必ずどれかを使う。消し方（閉じる・
    /// 逆再生する・一覧から外す・空の文にする・不透明度を0にする…）は
    /// 書き方が多く、中身では見分けきれないので、タイマーそのものを数える。
    Map<String, int> timerUses(Map<String, String> sources) {
      final timer = RegExp(
        r'\bTimer(?:\.periodic|\.run)?\(|'
        r'\bFuture(?:<[^>()]*>)?\.delayed\(|'
        r'\bStream(?:<[^>()]*>)?\.periodic\(',
      );
      final found = <String, int>{};
      for (final MapEntry(key: path, value: source) in sources.entries) {
        final count = timer.allMatches(source).length;
        if (count > 0) found[path] = count;
      }
      return found;
    }

    test('知らせの長さは数字で書き、5秒を超えない。時間で消えない指定をしない', () {
      final rule = lengthRule(sources());
      expect(rule.offenders, isEmpty, reason: rule.offenders.join('\n'));
      // 見張りが空振りしていないこと。
      expect(rule.seen, greaterThan(100));
      expect(rule.timed, greaterThan(3));
    });

    test('知らせの出し先はアプリに1つ（どのMaterialAppもそれを通す）', () {
      final rule = routingRule(sources());
      expect(rule.offenders, isEmpty, reason: rule.offenders.join('\n'));
      expect(rule.apps, greaterThanOrEqualTo(2));
      expect(File(central).existsSync(), isTrue);
    });

    test('自作の知らせ（Overlayへ重ねる・タイマーで消すもの・トーストのパッケージ）が無い', () {
      // いまOverlayへ直接重ねているのは、自動操作の記録を止めるボタン
      // （キャンバス・タイムライン）だけ。知らせではない。
      const overlayUsers = {
        'lib/screens/canvas/canvas_screen.dart': 1,
        'lib/screens/timeline/timeline_screen.dart': 1,
      };
      final lib = sources();
      expect(
        overlayUses(lib),
        overlayUsers,
        reason:
            'OverlayEntry・OverlayPortalを使う所が変わった。知らせは'
            'ScaffoldMessengerのshowSnackBarで出す（5秒以内に薄くなって'
            '消える）。知らせでなければこの一覧へ足す。',
      );
      // タイマーを使う所はすべて、知らせではない理由と一緒にここへ書く。
      // 自作の知らせは必ずタイマーで消すので、タイマーを足すときは、
      // 知らせならScaffoldMessengerのshowSnackBarで出し、知らせでなければ
      // 理由を1行足す。
      const timerUsers = <String, (int, String)>{
        'lib/app_bootstrap.dart': (1, 'コインの特典の貸し出しを10分ごとに取り直す'),
        'lib/screens/canvas/widgets/canvas_area.dart': (
          3,
          '外で変わったレイヤーをまとめて描き直す・長押しのスポイト',
        ),
        'lib/screens/canvas/widgets/canvas_preview_navigator.dart': (
          1,
          'ナビゲーターの縮小画像を0.9秒ごとに作り直す',
        ),
        'lib/screens/canvas/widgets/filter_panel.dart': (
          1,
          '進み具合のダイアログを描いてから重い処理を始める',
        ),
        'lib/screens/community/community_screen.dart': (
          2,
          '作品広場の経過時間を2分ごとに進める・名前のダイアログが閉じ切ってから'
              '入力欄を片付ける',
        ),
        'lib/screens/home/widgets/exported_work_thumbnail_dialog.dart': (
          1,
          '書き出した動画の再生位置をコマ番号へ写す',
        ),
        'lib/screens/home/widgets/project_thumbnail_dialog.dart': (
          1,
          'サムネイルを選ぶダイアログのコマ送り再生',
        ),
        'lib/screens/project/project_detail_screen.dart': (1, 'プレビューのコマ送り再生'),
        'lib/screens/rewards/reward_unlock_screen.dart': (
          1,
          '広告を見た後、サーバーの確認を間を空けて問い合わせる',
        ),
        'lib/screens/settings/storage_screen.dart': (
          2,
          '集計・空き容量の問い合わせを待つ時間の上限',
        ),
        'lib/screens/settings/widget_artwork_picker_screen.dart': (
          1,
          'ウィジェットの絵を選ぶ画面のコマ送り再生',
        ),
        'lib/screens/timeline/timeline_screen.dart': (
          2,
          'タイムラインの再生・進み具合のダイアログを描いてから処理を始める',
        ),
        'lib/screens/timeline/widgets/material_edit_panel.dart': (
          1,
          '打ち終わってから文字の素材を描き直す',
        ),
        'lib/services/api/niarim_api_client.dart': (1, '通信をやり直すまでの間'),
        'lib/services/autosave_service.dart': (2, '自動保存の間隔と、変更の後のまとめ'),
        'lib/services/creator_edit_session_reporter.dart': (
          1,
          '制作時間の記録の途中経過を送る',
        ),
        'lib/services/premium_service.dart': (4, '購入・特典の期限の取り直しと終わり'),
        'lib/services/project_service.dart': (2, '制作時間を数える'),
        'lib/services/youtube_thumbnail_service.dart': (
          1,
          'YouTubeの処理が終わったかを問い合わせる間',
        ),
        'lib/services/youtube_upload_service.dart': (1, 'アップロードをやり直すまでの間'),
        'lib/widgets/app_toast_messenger.dart': (1, '知らせの期限（この決まりそのもの）'),
        'lib/widgets/first_use_tooltip.dart': (1, '長押しかどうかの判定'),
        'lib/widgets/progress_dialog.dart': (1, '待っている間のひとことを10秒ごとに替える'),
      };
      final timers = timerUses(lib);
      expect(
        timers,
        {
          for (final MapEntry(key: path, value: (count, _))
              in timerUsers.entries)
            path: count,
        },
        reason:
            'タイマーを使う所が変わった（$timers）。知らせは'
            'ScaffoldMessengerのshowSnackBarで出す（5秒以内に薄くなって'
            '消える）。知らせでなければtimerUsersの数と理由を直す。',
      );
      final packages = RegExp(
        r'^\s+(fluttertoast|toast|oktoast|bot_toast|toastification|'
        r'another_flushbar|flushbar|flash|overlay_support|motion_toast|'
        r'delightful_toast|cherry_toast|elegant_notification|'
        r'top_snackbar_flutter|awesome_snackbar_content)\s*:',
        multiLine: true,
      );
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        packages.allMatches(pubspec).map((match) => match.group(1)).toList(),
        isEmpty,
        reason: 'トースト用のパッケージは、5秒・薄くなる決まりの外で動く',
      );
    });

    test('避けて通る書き方を、見張りが見逃さない', () {
      // 新しく書かれうる形を、lib配下にあるものとして見張りに通す。
      const rogue = 'lib/zz_rogue.dart';
      const material = "import 'package:flutter/material.dart';\n";
      final cases = <String, String>{
        '長い時間・操作ボタン':
            '${material}void f(BuildContext c) => ScaffoldMessenger.of(c)'
            ".showSnackBar(SnackBar(content: const Text('x'), "
            'duration: const Duration(seconds: 30), '
            "action: SnackBarAction(label: 'a', onPressed: () {})));\n",
        '時間で消えない指定':
            '${material}void f(BuildContext c) => ScaffoldMessenger.of(c)'
            ".showSnackBar(const SnackBar(content: Text('x'), persist: true));\n",
        'ミリ秒で書いた長い時間':
            '${material}void f(BuildContext c) => ScaffoldMessenger.of(c)'
            ".showSnackBar(const SnackBar(content: Text('x'), "
            'duration: Duration(milliseconds: 30000)));\n',
        '条件で選ぶ長い時間':
            '${material}void f(BuildContext c, bool long) => '
            'ScaffoldMessenger.of(c).showSnackBar(SnackBar('
            "content: const Text('x'), duration: long "
            '? const Duration(seconds: 10) : const Duration(seconds: 4)));\n',
        '項目の値を条件で選ぶ長い時間（秒）':
            '${material}void f(BuildContext c, bool long) => '
            'ScaffoldMessenger.of(c).showSnackBar(SnackBar('
            "content: const Text('x'), "
            'duration: Duration(seconds: long ? 10 : 4)));\n',
        '項目の値を条件で選ぶ長い時間（ミリ秒、後ろが長い）':
            '${material}void f(BuildContext c, bool long) => '
            'ScaffoldMessenger.of(c).showSnackBar(SnackBar('
            "content: const Text('x'), "
            'duration: const Duration(milliseconds: long ? 4000 : 6000)));\n',
        '数字で書いていない長さ':
            '${material}const long = Duration(seconds: 30);\n'
            'void f(BuildContext c) => ScaffoldMessenger.of(c)'
            ".showSnackBar(const SnackBar(content: Text('x'), duration: long));\n",
        'SnackBar.newで作った知らせ':
            '${material}void f(BuildContext c) => ScaffoldMessenger.of(c)'
            ".showSnackBar(SnackBar.new(content: const Text('x'), "
            'duration: const Duration(seconds: 30), persist: true));\n',
        '2つ目のScaffoldMessenger':
            '${material}Widget f(Widget child) => '
            'ScaffoldMessenger(child: child);\n',
        '同じファイルの2つ目のMaterialApp':
            "${material}import 'widgets/app_toast_messenger.dart';\n"
            'Widget a() => MaterialApp(builder: (c, child) => '
            'AppToastMessenger(child: child!), home: const SizedBox());\n'
            'Widget b() => MaterialApp(home: Builder(builder: (c) {\n'
            '  ScaffoldMessenger.of(c).showSnackBar(\n'
            "    const SnackBar(content: Text('x')),\n"
            '  );\n'
            '  return const Scaffold();\n'
            '}));\n',
        'OverlayPortalとタイマーで出す知らせ':
            "import 'dart:async';\n$material"
            '''
class RogueToast extends StatefulWidget {
  const RogueToast({super.key, required this.child});
  final Widget child;
  @override
  State<RogueToast> createState() => RogueToastState();
}
class RogueToastState extends State<RogueToast> {
  final _portal = OverlayPortalController();
  void show() {
    _portal.show();
    Timer(const Duration(seconds: 30), _portal.hide);
  }
  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (_) => const Material(child: Text('saved')),
    child: widget.child,
  );
}
''',
        'タイマーで閉じるダイアログの知らせ':
            "import 'dart:async';\n$material"
            '''
void rogue(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      Timer(const Duration(seconds: 30), () => Navigator.of(dialogContext).pop());
      return const Material(child: Text('saved'));
    },
  );
}
''',
        '待ってから見えなくする帯':
            '$material'
            '''
class RogueBanner extends StatefulWidget {
  const RogueBanner({super.key});
  @override
  State<RogueBanner> createState() => _RogueBannerState();
}
class _RogueBannerState extends State<RogueBanner> {
  bool _visible = false;
  Future<void> show() async {
    setState(() => _visible = true);
    await Future<void>.delayed(const Duration(seconds: 30));
    if (mounted) setState(() => _visible = false);
  }
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _visible ? 1 : 0,
    duration: const Duration(milliseconds: 300),
    child: const Material(child: Text('saved')),
  );
}
''',
        'タイマーから呼ぶメソッドで消す帯':
            "import 'dart:async';\n$material"
            '''
class RogueBanner extends StatefulWidget {
  const RogueBanner({super.key});
  @override
  State<RogueBanner> createState() => _RogueBannerState();
}
class _RogueBannerState extends State<RogueBanner> {
  String? _message;
  void show(String message) {
    setState(() => _message = message);
    Timer(const Duration(seconds: 30), _clear);
  }
  void _clear() {
    if (!mounted) return;
    setState(() {
      _message = null;
    });
  }
  @override
  Widget build(BuildContext context) =>
      Visibility(visible: _message != null, child: Text(_message ?? ''));
}
''',
        'タイマーで逆再生して消す帯（reverse）':
            "import 'dart:async';\n$material"
            '''
class RogueToast extends StatefulWidget {
  const RogueToast({super.key});
  @override
  State<RogueToast> createState() => _RogueToastState();
}
class _RogueToastState extends State<RogueToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  void show() {
    _fade.forward();
    Timer(const Duration(seconds: 30), () => _fade.reverse());
  }
  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: const Text('saved'));
}
''',
        'タイマーで一覧から外す知らせ':
            "import 'dart:async';\n$material"
            '''
class RogueToasts extends StatefulWidget {
  const RogueToasts({super.key});
  @override
  State<RogueToasts> createState() => _RogueToastsState();
}
class _RogueToastsState extends State<RogueToasts> {
  final _messages = <String>[];
  void show(String message) {
    setState(() => _messages.add(message));
    Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _messages.remove(message));
    });
  }
  @override
  Widget build(BuildContext context) =>
      Column(children: [for (final m in _messages) Text(m)]);
}
''',
        '待ってから空の文にする帯':
            '$material'
            '''
class RogueBanner extends StatefulWidget {
  const RogueBanner({super.key});
  @override
  State<RogueBanner> createState() => _RogueBannerState();
}
class _RogueBannerState extends State<RogueBanner> {
  String _message = '';
  Future<void> show(String message) async {
    setState(() => _message = message);
    await Future<void>.delayed(const Duration(seconds: 30));
    if (mounted) setState(() => _message = '');
  }
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: Text(_message, key: ValueKey(_message)),
  );
}
''',
        'ScaffoldMessenger.newで置いた2つ目の出し先':
            '${material}Widget f(Widget child) => '
            'ScaffoldMessenger.new(child: child);\n',
        'builderの無いMaterialApp.new':
            '${material}Widget f() => MaterialApp.new(home: const SizedBox());\n',
        'タイマーで0へ動かして消す帯（animateTo）':
            "import 'dart:async';\n$material"
            '''
class RogueToast extends StatefulWidget {
  const RogueToast({super.key});
  @override
  State<RogueToast> createState() => _RogueToastState();
}
class _RogueToastState extends State<RogueToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this);
  void show() {
    _fade.value = 1;
    Timer(const Duration(seconds: 30), () {
      _fade.animateTo(0, duration: const Duration(milliseconds: 300));
    });
  }
  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: const Text('saved'));
}
''',
        'タイマーで不透明度を0にする帯':
            "import 'dart:async';\n$material"
            '''
class RogueBanner extends StatefulWidget {
  const RogueBanner({super.key});
  @override
  State<RogueBanner> createState() => _RogueBannerState();
}
class _RogueBannerState extends State<RogueBanner> {
  double _opacity = 0;
  void show() {
    setState(() => _opacity = 1);
    Timer(const Duration(seconds: 30), () => setState(() => _opacity = 0));
  }
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _opacity,
    duration: const Duration(milliseconds: 300),
    child: const Text('saved'),
  );
}
''',
      };
      final missed = <String>[];
      for (final MapEntry(key: what, value: source) in cases.entries) {
        final sources = {rogue: source};
        final found = [
          ...lengthRule(sources).offenders,
          ...routingRule(sources).offenders,
          ...overlayUses(sources).keys,
          ...timerUses(sources).keys,
        ];
        if (found.isEmpty) missed.add(what);
      }
      expect(missed, isEmpty, reason: '見逃した：${missed.join('、')}');
      // ふつうの書き方は引っかからない。
      final fine = {
        rogue:
            "${material}import 'widgets/app_toast_messenger.dart';\n"
            'Widget a() => MaterialApp(builder: (c, child) => '
            'AppToastMessenger(child: child!), home: const SizedBox());\n'
            'void f(BuildContext c) => ScaffoldMessenger.of(c)'
            ".showSnackBar(SnackBar(content: const Text('x'), "
            'duration: const Duration(seconds: 3), '
            "action: SnackBarAction(label: 'a', onPressed: () {})));\n"
            'void g(BuildContext c, bool long) => ScaffoldMessenger.of(c)'
            ".showSnackBar(SnackBar(content: const Text('x'), duration: long "
            '? const Duration(seconds: 5) : const Duration(seconds: 4)));\n'
            'void h(BuildContext c, bool long) => ScaffoldMessenger.of(c)'
            ".showSnackBar(SnackBar(content: const Text('x'), "
            'duration: Duration(seconds: long ? 5 : 4)));\n'
            'void i(BuildContext c, bool long) => ScaffoldMessenger.of(c)'
            ".showSnackBar(SnackBar(content: const Text('x'), "
            'duration: Duration(milliseconds: long ? 4000 : 5000)));\n',
      };
      expect([
        ...lengthRule(fine).offenders,
        ...routingRule(fine).offenders,
        ...overlayUses(fine).keys,
        ...timerUses(fine).keys,
      ], isEmpty);
    });
  });
}

class _ToastLife {
  const _ToastLife({
    required this.total,
    required this.leftByItself,
    required this.fullyShown,
    required this.hadAction,
    required this.exit,
  });

  /// ツリーに入った最初のフレームから、消え切る（または待つのをやめる）まで。
  final Duration total;

  /// 待つのをやめる前に自分で消えたか。
  final bool leftByItself;

  /// 一度でも不透明度1で出たか。
  final bool fullyShown;

  /// 操作ボタン付きだったか。
  final bool hadAction;

  /// 出切った後、薄くなり始めてから消え切るまでの毎フレームの不透明度。
  final List<double> exit;
}

/// 知らせ1つの、出切っていた時間とツリーにあった時間。
class _Noticed {
  Duration fullyShown = Duration.zero;
  Duration inTree = Duration.zero;
}
