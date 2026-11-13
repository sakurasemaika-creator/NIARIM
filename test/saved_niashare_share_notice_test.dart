import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/widgets/share_project_file_action.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_share_channel.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 保存した共有ファイル（.niashare）を作って共有する入口と、保存済みのものを
/// そのまま共有する入口（`share_project_file_action.dart`）。プロジェクト詳細の
/// 「共有」、共有タブの受け取った作品のメニュー、「自分が作成したもの」の一覧。
///
/// 共有できない端末・共有の失敗を「.niashareの作成に失敗しました:
/// MissingPluginException(…)」と出し（作成はできている）、保存したファイルが
/// 無くなっているときも同じ文に例外の文を付けて出していた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = FakeShareChannel();
  const mockText = 'no share on this device 4711';
  const missingFileText = 'Saved share file is missing';

  setUp(() {
    share.install();
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });
  tearDown(share.remove);

  late AppLocalizations l10n;
  late ProjectService service;

  Future<Project> openHomeWithProject(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final home = tester.element(find.byType(HomeScreen));
    service = home.read<ProjectService>();
    l10n = AppLocalizations.of(home)!;
    final project = (await tester.runAsync(
      () => service.createProject(
        name: '共有する作品',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 32,
      ),
    ))!;
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    return project;
  }

  List<String> snackBarTexts(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    ))
      text.data ?? '',
  ];

  Future<void> clearSnackBars(WidgetTester tester) async {
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// いま出ている通知を消した後、後ろに積まれた通知が出てこないこと。
  Future<void> expectNoQueuedSnackBar(WidgetTester tester) async {
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .hideCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SnackBar), findsNothing, reason: '知らせを2つ積まない');
  }

  /// 同梱の確認で「作成」を押し、共有が呼ばれるまで（作成が終わるまで）待つ。
  Future<void> confirmAndWait(WidgetTester tester) async {
    expect(find.text(l10n.projectListMaterialIncludeTitle), findsOneWidget);
    final before = share.calls;
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonCreate));
    for (var i = 0; i < 100 && share.calls == before; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
  }

  /// 同梱の確認で「作成」を押し、作成の失敗が知らされるまで待つ。
  Future<void> confirmAndWaitForNotice(WidgetTester tester) async {
    expect(find.text(l10n.projectListMaterialIncludeTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonCreate));
    for (var i = 0; i < 100 && find.byType(SnackBar).evaluate().isEmpty; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
  }

  /// 共有ファイルの作成の失敗の通知：「作成に失敗」の文が1つだけで、共有
  /// できないことの文ではない。
  Future<void> expectCreationFailure(WidgetTester tester) async {
    final lead = failureLead(l10n.projectDetailNiashareFailedSnackbar);
    expect(tester.takeException(), isNull);
    final shown = snackBarTexts(tester);
    expect(shown, hasLength(1), reason: '作成の失敗を知らせる');
    expect(shown.single, startsWith(lead));
    expect(shown.single, isNot(contains(l10n.communityErrorUnsupported)));
    expect(shown.single, isNot(contains(l10n.communityErrorGeneric)));
    await expectNoQueuedSnackBar(tester);
  }

  /// プロジェクト詳細の「共有」のボタン（作成・共有の途中は、文言が
  /// 「処理中…」に、アイコンが進行中の印に替わる）。
  Finder detailShare() {
    final keyed = find.byKey(const Key('projectDetailShareAction'));
    return keyed.evaluate().isNotEmpty
        ? find.descendant(of: keyed, matching: find.byType(InkWell))
        : find
              .ancestor(
                of: find.text(l10n.projectDetailShareQuickAction),
                matching: find.byType(InkWell),
              )
              .first;
  }

  bool detailShareEnabled(WidgetTester tester) =>
      tester.widget<InkWell>(detailShare()).onTap != null;

  Finder detailShareBusy() => find.descendant(
    of: detailShare(),
    matching: find.byType(CircularProgressIndicator),
  );

  /// 偽の時計だけを進める（本物のファイルの読み書き＝共有ファイルの作成は
  /// 進まないので、「作成の途中」の画面を確かめられる）。
  Future<void> pumpFake(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// ホームの一覧の、作品のメニューを開く。
  Future<void> openHomeRowMenu(WidgetTester tester) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(ProjectListWidget),
            matching: find.byType(PopupMenuButton<String>),
          )
          .first,
    );
    await pumpFake(tester);
  }

  /// 開いているメニューの[label]の項目が選べるか。
  bool menuItemEnabled(WidgetTester tester, String label) => tester
      .widget<PopupMenuItem<String>>(
        find
            .ancestor(
              of: find.text(label).last,
              matching: find.byWidgetPredicate(
                (w) => w is PopupMenuItem<String>,
              ),
            )
            .first,
      )
      .enabled;

  testWidgets('leaving while the snapshot is built: the busy look follows the '
      'project on every screen, and the share still happens', (tester) async {
    final project = await openHomeWithProject(tester);
    final createFailed = failureLead(l10n.projectDetailNiashareFailedSnackbar);
    final includeDialog = find.text(l10n.projectListMaterialIncludeTitle);
    await tester.runAsync(service.refreshOutgoingShares);
    final savedBefore = service.outgoingShares.length;

    // 詳細で「共有」→同梱の確認→作成が始まる（本物の読み書きは進めない）。
    appRouter.push('/project/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    expect(detailShareEnabled(tester), isTrue);
    await tester.tap(detailShare());
    await pumpFake(tester);
    expect(includeDialog, findsOneWidget);
    expect(detailShareBusy(), findsNothing, reason: '確認の間はまだ作っていない');
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonCreate));
    await pumpFake(tester);
    expect(includeDialog, findsNothing);
    expect(share.calls, 0, reason: '作成の途中');
    expect(detailShareEnabled(tester), isFalse, reason: '作成の途中は押せない');
    expect(detailShareBusy(), findsOneWidget, reason: '作成の途中だと分かる');

    // 作成の途中で画面を離れる。ホームの一覧のメニューでも選べない。
    appRouter.pop();
    await pumpFake(tester);
    expect(find.byType(ProjectDetailScreen), findsNothing);
    expect(share.calls, 0);
    await openHomeRowMenu(tester);
    expect(
      menuItemEnabled(tester, l10n.projectListCreateShareAction),
      isFalse,
      reason: '詳細で始めた作成・共有の途中',
    );
    await tester.tapAt(const Offset(2, 2));
    await pumpFake(tester);
    // 入口は止めてあるが、それでも届いた操作は黙って捨てない（確認も開かず、
    // 「処理中…」と知らせる）。
    unawaited(
      createAndShareProjectNiashare(
        tester.element(find.byType(HomeScreen)),
        service,
        project,
      ),
    );
    await pumpFake(tester);
    expect(includeDialog, findsNothing);
    expect(snackBarTexts(tester), [l10n.homeTrashWorking]);
    await clearSnackBars(tester);
    expect(share.calls, 0);

    // 同じ作品をもう一度開く：押せそうに見えて押しても何も起きない、に
    // しない（進行中の見た目のまま）。
    appRouter.push('/project/${project.id}');
    await pumpFake(tester);
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    expect(detailShareEnabled(tester), isFalse, reason: '開き直しても進行中');
    expect(detailShareBusy(), findsOneWidget, reason: '開き直しても進行中だと分かる');
    expect(
      find.descendant(
        of: detailShare(),
        matching: find.text(l10n.homeTrashWorking),
      ),
      findsOneWidget,
      reason: '文言でも進行中だと分かる',
    );
    await tester.tap(detailShare(), warnIfMissed: false);
    await pumpFake(tester);
    expect(includeDialog, findsNothing);
    expect(share.calls, 0);

    // 作成が終わる：始めた画面はもう無いが、共有は行われ、できなかったことも
    // いまの画面で知らせる（黙って止めない）。
    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    for (var i = 0; i < 100 && share.calls == 0; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(share.calls, 1, reason: '作成が終わったら共有する');
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    await tester.runAsync(service.refreshOutgoingShares);
    expect(service.outgoingShares.length, savedBefore + 1);
    expect(
      service.outgoingShares.map((saved) => saved.path),
      contains(share.lastPaths.single),
      reason: '保存したそのファイルを共有する',
    );
    // 終わったら、また押せる。
    expect(detailShareEnabled(tester), isTrue);
    expect(detailShareBusy(), findsNothing);
    expect(
      find.descendant(
        of: detailShare(),
        matching: find.text(l10n.projectDetailShareQuickAction),
      ),
      findsOneWidget,
    );
    await clearSnackBars(tester);

    // 作成に失敗したときも、始めた画面が無くなっていても知らせる。
    share.breakWrites();
    await tester.tap(detailShare());
    await pumpFake(tester);
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonCreate));
    await pumpFake(tester);
    appRouter.pop();
    await pumpFake(tester);
    expect(find.byType(ProjectDetailScreen), findsNothing);
    for (var i = 0; i < 100 && find.byType(SnackBar).evaluate().isEmpty; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    expect(share.calls, 1, reason: '作れなかったものは共有しない');
    await expectCreationFailure(tester);
    share.fixWrites();
  });

  testWidgets('project detail: one snapshot and one share at a time, and a '
      'share problem is not a creation failure', (tester) async {
    final project = await openHomeWithProject(tester);
    final createFailed = failureLead(l10n.projectDetailNiashareFailedSnackbar);
    expect(createFailed, isNotEmpty);
    final includeDialog = find.text(l10n.projectListMaterialIncludeTitle);

    // ホームの一覧のメニューで同じ作品の共有を始め、共有シートを開いたままにする。
    share.pending = Completer<String>();
    await tester.tap(
      find
          .descendant(
            of: find.byType(ProjectListWidget),
            matching: find.byType(PopupMenuButton<String>),
          )
          .first,
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text(l10n.projectListCreateShareAction));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await confirmAndWait(tester);
    expect(share.calls, 1);

    // ── プロジェクト詳細（一覧の共有が終わるまで、同じ作品は始めない）──
    appRouter.push('/project/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    // 一覧のメニューと同じく、詳細の「共有」も進行中の見た目で押せない
    // （押せそうに見えて、押しても何も起きない、にしない）。
    expect(detailShareEnabled(tester), isFalse, reason: '一覧で始めた作成・共有の途中');
    expect(detailShareBusy(), findsOneWidget, reason: '一覧で始めた作成・共有の途中');
    await tester.tap(detailShare(), warnIfMissed: false);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsNothing, reason: '一覧で始めた作成・共有の途中');
    expect(share.calls, 1);
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing, reason: '閉じただけなら何も出さない');
    expect(detailShareEnabled(tester), isTrue, reason: '終わったら押せる');
    expect(detailShareBusy(), findsNothing);

    // 共有の仕組みが無い端末。作成はできていて「自分が作成したもの」に残る。
    final recorded = AppErrorReporter.recentErrors.length;
    // 一覧のメニューで作った分（作品のフォルダの中）も「作成したもの」に入る。
    await tester.runAsync(service.refreshOutgoingShares);
    final savedBefore = service.outgoingShares.length;
    share.failure = MissingPluginException(mockText);
    await tester.tap(detailShare());
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await confirmAndWait(tester);
    expect(tester.takeException(), isNull);
    expect(share.calls, 2);
    expect(service.outgoingShares.length, savedBefore + 1);
    expect(File(share.lastPaths.single).existsSync(), isTrue);
    expect(
      service.outgoingShares.map((saved) => saved.path),
      contains(share.lastPaths.single),
      reason: '保存したそのファイルを共有する',
    );
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    await clearSnackBars(tester);

    // それ以外の失敗。
    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await tester.tap(detailShare());
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await confirmAndWait(tester);
    expect(tester.takeException(), isNull);
    expect(share.calls, 3);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    await clearSnackBars(tester);

    // 詳細の共有シートが開いている間、もう一度押しても始めない。
    share
      ..failure = null
      ..pending = Completer<String>();
    await tester.tap(detailShare());
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await confirmAndWait(tester);
    expect(share.calls, 4);
    expect(detailShareBusy(), findsOneWidget, reason: '作成・共有の途中だと分かる');
    await tester.tap(detailShare(), warnIfMissed: false);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsNothing, reason: '二度目は始めない');
    expect(share.calls, 4);
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(detailShareBusy(), findsNothing, reason: '終わったら元のアイコンへ戻る');
    expect(find.byType(SnackBar), findsNothing);

    // 同梱の確認を取り消したら、次はまた始められる。
    await tester.tap(detailShare());
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsOneWidget);
    // 確認の間は、まだ何も作っていないので進行中の印を出さない。
    expect(detailShareBusy(), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await tester.tap(detailShare());
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(share.calls, 4);
    expect(tester.takeException(), isNull);

    // 共有ファイルそのものを作れなかったときは「作成に失敗」の文で知らせ、
    // 共有は呼ばない。進行中の見た目も残らず、その後も共有できる。
    share.breakWrites();
    await tester.tap(detailShare());
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await confirmAndWaitForNotice(tester);
    expect(share.calls, 4, reason: '作れなかったものは共有しない');
    await expectCreationFailure(tester);
    expect(detailShareEnabled(tester), isTrue, reason: '失敗の後も押せる');
    expect(detailShareBusy(), findsNothing);
    share.fixWrites();
    share.result = '';
    await tester.tap(detailShare());
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await confirmAndWait(tester);
    expect(share.calls, 5, reason: '失敗の後も共有できる');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('saved share files: a share problem, a missing file and a '
      'creation failure are told apart, without the exception text', (
    tester,
  ) async {
    final project = await openHomeWithProject(tester);
    final createFailed = failureLead(l10n.projectDetailNiashareFailedSnackbar);
    final saved = (await tester.runAsync(
      () => service.createOutgoingShare(project: project),
    ))!;
    final received = (await tester.runAsync(
      () => NiaproSerializer.loadShare(saved.path),
    ))!;
    await tester.runAsync(() => service.importSharedProject(received));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('home_tab_2')));
    await pumpRealAsync(tester, const Duration(milliseconds: 700));

    // ── 受け取った作品のメニューの「共有」（新しく作って共有する）──
    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    await tester.tap(
      find.byKey(ValueKey('receivedShareMenu_${service.shared.single.id}')),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text(l10n.projectDetailShareQuickAction).last);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await confirmAndWait(tester);
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(service.outgoingShares.length, 2, reason: '作成はできている');
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    await clearSnackBars(tester);

    // 共有シートが開いている間、同じ作品のメニューの「共有」は選べない
    // （選べそうに見えて、選んでも何も起きない、にしない）。
    final receivedMenu = find.byKey(
      ValueKey('receivedShareMenu_${service.shared.single.id}'),
    );
    share
      ..failure = null
      ..pending = Completer<String>();
    await tester.tap(receivedMenu);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(menuItemEnabled(tester, l10n.projectDetailShareQuickAction), isTrue);
    await tester.tap(find.text(l10n.projectDetailShareQuickAction).last);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await confirmAndWait(tester);
    expect(share.calls, 2);
    await tester.tap(receivedMenu);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(
      menuItemEnabled(tester, l10n.projectDetailShareQuickAction),
      isFalse,
      reason: '作成・共有の途中',
    );
    await tester.tapAt(const Offset(2, 2));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    share.pending!.completeError(
      PlatformException(code: 'Share failed', message: mockText),
    );
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    await expectNoQueuedSnackBar(tester);
    expect(service.outgoingShares.length, 3);

    // 共有ファイルそのものを作れなかったときは「作成に失敗」の文で知らせ、
    // 共有は呼ばない。その後もメニューから選べる。
    share.breakWrites();
    await tester.tap(receivedMenu);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text(l10n.projectDetailShareQuickAction).last);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await confirmAndWaitForNotice(tester);
    expect(share.calls, 2, reason: '作れなかったものは共有しない');
    await expectCreationFailure(tester);
    share.fixWrites();
    await tester.runAsync(service.refreshOutgoingShares);
    expect(service.outgoingShares.length, 3);
    await tester.tap(receivedMenu);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(
      menuItemEnabled(tester, l10n.projectDetailShareQuickAction),
      isTrue,
      reason: '失敗の後も選べる',
    );
    await tester.tapAt(const Offset(2, 2));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));

    // ── 「自分が作成したもの」の一覧（保存したファイルをそのまま共有する）──
    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await pumpRealAsync(tester, const Duration(milliseconds: 700));
    final row = find.descendant(
      of: find.ancestor(
        of: find.byKey(ValueKey('outgoingShareMenu_${saved.path}')),
        matching: find.byType(ListTile),
      ),
      matching: find.byIcon(Icons.insert_drive_file_outlined),
    );
    expect(row, findsOneWidget);

    Future<void> tapRow() async {
      await tester.tap(row);
      await pumpRealAsync(tester, const Duration(milliseconds: 500));
    }

    share.failure = MissingPluginException(mockText);
    await tapRow();
    expect(tester.takeException(), isNull);
    expect(share.calls, 3);
    expect(share.lastPaths, [saved.path], reason: '保存したそのファイルを渡す');
    expect(service.outgoingShares.length, 3, reason: '作り直さない');
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    await clearSnackBars(tester);

    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await tapRow();
    expect(tester.takeException(), isNull);
    expect(share.calls, 4);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    await clearSnackBars(tester);

    // 共有シートを閉じただけなら何も出さない。
    share
      ..failure = null
      ..result = '';
    await tapRow();
    expect(share.calls, 5);
    expect(find.byType(SnackBar), findsNothing);

    // 共有シートが開いている間の二度目は共有を呼ばず、失敗の知らせも1つだけ。
    share.pending = Completer<String>();
    await tapRow();
    await tapRow();
    expect(share.calls, 6, reason: '二度押しで共有を二重に呼ばない');
    share.pending!.completeError(
      PlatformException(code: 'Share failed', message: mockText),
    );
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    await expectNoQueuedSnackBar(tester);

    // 保存したファイルが無くなっている：共有できない端末とも、作成の失敗とも
    // 言わない。例外の文も出さない。
    await tester.runAsync(() => File(saved.path).delete());
    final recordedBeforeMissing = AppErrorReporter.recentErrors.length;
    await tapRow();
    expect(tester.takeException(), isNull);
    expect(share.calls, 6, reason: '無いファイルは共有へ渡さない');
    expect(snackBarTexts(tester), [l10n.communityErrorNotFound]);
    expect(
      l10n.communityErrorNotFound,
      isNot(anyOf(l10n.communityErrorUnsupported, l10n.communityErrorGeneric)),
    );
    expectNoInternalText(
      tester,
      also: [missingFileText, 'FileSystemException', createFailed],
    );
    expect(
      AppErrorReporter.recentErrors.length,
      greaterThan(recordedBeforeMissing),
    );
    await expectNoQueuedSnackBar(tester);
  });
}
