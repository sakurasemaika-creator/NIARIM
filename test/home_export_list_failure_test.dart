import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('failed export prefetch is nonfatal and works can retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
    });
    final directory = Directory.systemTemp.createTempSync(
      'export_list_failure_',
    );
    var failDocuments = true;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (failDocuments &&
              call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'a failed background prefetch must not escape',
    );
    await tester.tap(find.text('作品をつくる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品一覧'));
    await tester.pumpAndSettle();
    expect(find.text('作品一覧を読み込めませんでした'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    failDocuments = false;
    await tester.tap(find.text('再試行'));
    // 読み直しは実ファイルの入出力（フォルダの作成・一覧）で、偽の時計の下では
    // pumpだけでは終わらない。実時間を進めては描き直し、失敗の表示が消えるのを待つ。
    for (
      var i = 0;
      i < 100 && find.text('作品一覧を読み込めませんでした').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('書き出した作品がありません'), findsOneWidget);
    expect(find.text('作品一覧を読み込めませんでした'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 保存先を読めなかったとき、プロジェクトの一覧は空に見えるだけで何も
  // 知らされず、読み直すこともできなかった（作品が消えたように見えた）。
  testWidgets('projects that could not be loaded are reported and retried', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
    });
    final directory = Directory.systemTemp.createTempSync(
      'project_list_failure_',
    );
    var failDocuments = false;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (failDocuments &&
              call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    // 保存先が読めるうちに作品を1つ保存しておく。
    await tester.runAsync(() async {
      final service = ProjectService();
      await service.createProject(
        name: '残っている作品',
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      service.dispose();
    });
    failDocuments = true;
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品をつくる'));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトを読み込めませんでした'), findsOneWidget);
    expect(find.text('残っている作品'), findsNothing);

    failDocuments = false;
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('homeProjectsLoadFailed')),
        matching: find.text('再試行'),
      ),
    );
    // 読み直しは実際のファイルを読むので、実時間で待つ。
    for (var i = 0; i < 20 && find.text('残っている作品').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトを読み込めませんでした'), findsNothing);
    expect(find.text('残っている作品'), findsOneWidget);

    // 読み直しても同じ作品が二重にならない。
    final service = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    await tester.runAsync(service.retryLoadProjects);
    await tester.pumpAndSettle();
    expect(service.projects.where((p) => p.name == '残っている作品'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 読み直しは保存先を非同期に読むので、読み終わる前にもう一度読み直すと
  // （「再試行」の二度押し）、どちらも「まだ読んでいない作品」として同じ
  // 作品を一覧へ足していた。
  test('two overlapping retries do not load the same project twice', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final failing = _FailingDocuments('project_retry_overlap_');
    addTearDown(failing.dispose);
    final seed = ProjectService();
    await seed.createProject(
      name: '残っている作品',
      fps: 8,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
    );
    seed.dispose();

    failing.fail = true;
    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.projectsLoadFailed, isTrue);
    expect(service.projects, isEmpty);

    failing.fail = false;
    await Future.wait([
      service.retryLoadProjects(),
      service.retryLoadProjects(),
    ]);
    expect(service.projectsLoadFailed, isFalse);
    expect(service.projects.where((p) => p.name == '残っている作品'), hasLength(1));
  });

  testWidgets('pressing retry twice in a row loads each project once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
    });
    final failing = _FailingDocuments('project_retry_twice_');
    addTearDown(failing.dispose);
    await tester.runAsync(() async {
      final service = ProjectService();
      await service.createProject(
        name: '残っている作品',
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      service.dispose();
    });
    failing.fail = true;
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final notice = find.byKey(const Key('homeProjectsLoadFailed'));
    expect(notice, findsOneWidget);

    failing.fail = false;
    final retry = find.descendant(of: notice, matching: find.text('再試行'));
    await tester.tap(retry);
    await tester.pump();
    // 読み直しの途中にもう一度押しても、同じ読み直しを待つだけ。
    await tester.tap(retry);
    await tester.pump();
    for (var i = 0; i < 20 && find.text('残っている作品').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    // 2回目の読み直しが遅れて終わる分も待つ。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    final service = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    expect(service.projects.where((p) => p.name == '残っている作品'), hasLength(1));
    expect(find.text('残っている作品'), findsOneWidget);
    expect(notice, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // キーボード（PC/DeX）で「再試行」を押したとき。読み直しの途中に
  // 「再試行」を押せなくすると、Flutterはフォーカスを前にフォーカスの
  // あった部品（Tabで「再試行」へ来る途中のゴミ箱のタブ）へ移し、続けて
  // 押したEnterでゴミ箱のタブが開いた。
  testWidgets('keyboard: Retry keeps focus during and after a failing retry', (
    tester,
  ) async {
    final failing = await _pumpFailingHome(tester, 'project_retry_keys_fail_');
    final retry = await _focusRetryWithTab(tester);
    final tabs = _homeTabs(tester);
    expect(tabs.index, 0);

    // 保存先はまだ読めず、読み直しに時間がかかる。
    failing.delay = const Duration(milliseconds: 300);
    final callsBefore = failing.documentCalls;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 16));
    expect(failing.documentCalls, greaterThan(callsBefore));
    expect(_focusInside(retry), isTrue, reason: 'focus left Retry');

    // 読み直しの途中に続けてEnterを押しても、ほかのタブへ移らない。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tabs.index, 0, reason: 'a second Enter switched the Home tab');
    expect(_focusInside(retry), isTrue, reason: 'focus left Retry');

    // 読み直しが失敗して終わっても、フォーカスは「再試行」のまま。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeProjectsLoadFailed')), findsOneWidget);
    expect(_focusInside(retry), isTrue, reason: 'focus left Retry');

    // もう一度Enterを押すと、もう一度読み直す（ゴミ箱のタブは開かない）。
    final callsAfterFirst = failing.documentCalls;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(failing.documentCalls, greaterThan(callsAfterFirst));
    expect(tabs.index, 0, reason: 'Enter switched the Home tab');
    expect(find.byKey(const Key('homeProjectsLoadFailed')), findsOneWidget);
    expect(_focusInside(retry), isTrue, reason: 'focus left Retry');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 読み直せると知らせが消える。フォーカスが「再試行」にあったときは
  // 画面のフォーカスへ戻す（前にフォーカスのあったゴミ箱のタブへ移ると、
  // 次のEnterで読み込めた作品がゴミ箱のタブに隠れた）。
  testWidgets('keyboard: after a successful retry focus returns to Home', (
    tester,
  ) async {
    final failing = await _pumpFailingHome(
      tester,
      'project_retry_keys_ok_',
      seedProject: true,
    );
    await _focusRetryWithTab(tester);
    final tabs = _homeTabs(tester);

    failing.fail = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // 読み直しは実際のファイルを読むので、実時間で待つ。
    for (var i = 0; i < 20 && find.text('残っている作品').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeProjectsLoadFailed')), findsNothing);
    expect(find.text('残っている作品'), findsOneWidget);
    expect(
      _focusInside(find.byType(TabBar)),
      isFalse,
      reason: 'focus fell back to a Home tab',
    );
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Home');

    // 続けてEnterを押しても、ほかのタブへ移らない。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tabs.index, 0, reason: 'Enter switched the Home tab');
    expect(find.text('残っている作品'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 狭い画面・大きな文字・長い言語でも知らせがはみ出さず、「再試行」を
  // 押せる。
  testWidgets('the notice fits a narrow screen with large French text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'fr',
    });
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final failing = _FailingDocuments('project_notice_layout_')..fail = true;
    addTearDown(failing.dispose);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final notice = find.byKey(const Key('homeProjectsLoadFailed'));
    expect(notice, findsOneWidget);
    expect(find.text('Impossible de charger vos projets'), findsOneWidget);
    final retry = find.descendant(of: notice, matching: find.text('Réessayer'));
    expect(retry, findsOneWidget);
    final noticeRect = tester.getRect(notice);
    final retryRect = tester.getRect(retry);
    expect(noticeRect.left, greaterThanOrEqualTo(0));
    expect(noticeRect.right, lessThanOrEqualTo(320));
    expect(
      noticeRect.contains(retryRect.topLeft) &&
          noticeRect.contains(retryRect.bottomRight - const Offset(1, 1)),
      isTrue,
      reason: 'the retry label must stay inside the notice',
    );
    // 押せる（見た目だけで他の部品に覆われていない）。
    final hit = tester.hitTestOnBinding(retryRect.center);
    final retryButton = tester.renderObject(
      find.ancestor(of: retry, matching: find.byType(TextButton)),
    );
    expect(hit.path.any((entry) => entry.target == retryButton), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// 保存先を読めない状態で、PC（1280x800）のホームのプロジェクトタブを
/// 開く。[seedProject]なら、読めるうちに作品を1つ保存しておく。
Future<_FailingDocuments> _pumpFailingHome(
  WidgetTester tester,
  String prefix, {
  bool seedProject = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': 'ja',
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  });
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final failing = _FailingDocuments(prefix);
  addTearDown(failing.dispose);
  if (seedProject) {
    await tester.runAsync(() async {
      final service = ProjectService();
      await service.createProject(
        name: '残っている作品',
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      service.dispose();
    });
  }
  failing.fail = true;
  appRouter.go('/home');
  final providers = await tester.runAsync(buildAppProviders);
  await tester.pumpWidget(
    MultiProvider(providers: providers!, child: const NiarimApp()),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('homeProjectsLoadFailed')), findsOneWidget);
  return failing;
}

/// キーボードのTabで知らせの「再試行」までフォーカスを移す。
Future<Finder> _focusRetryWithTab(WidgetTester tester) async {
  final retry = find.descendant(
    of: find.byKey(const Key('homeProjectsLoadFailed')),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(retry, findsOneWidget);
  for (var i = 0; i < 40 && !_focusInside(retry); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(_focusInside(retry), isTrue, reason: 'Tab never reached Retry');
  return retry;
}

TabController _homeTabs(WidgetTester tester) =>
    tester.widget<TabBarView>(find.byType(TabBarView)).controller!;

/// キーボードのフォーカスが[finder]の部品（またはその中）にあるか。
bool _focusInside(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final targets = finder.evaluate().toSet();
  if (targets.contains(focused)) return true;
  var inside = false;
  focused.visitAncestorElements((element) {
    inside = targets.contains(element);
    return !inside;
  });
  return inside;
}

/// path_providerの書類フォルダを、[fail]が真の間だけ取れなくする。
/// [delay]があれば、答えるまでそれだけ待つ（遅い保存先）。
class _FailingDocuments {
  _FailingDocuments(String prefix)
    : directory = Directory.systemTemp.createTempSync(prefix) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            documentCalls++;
          }
          final wait = delay;
          if (wait != null) await Future<void>.delayed(wait);
          if (fail && call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
  }

  static const _channel = MethodChannel('plugins.flutter.io/path_provider');
  final Directory directory;
  bool fail = false;
  Duration? delay;
  int documentCalls = 0;

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}
