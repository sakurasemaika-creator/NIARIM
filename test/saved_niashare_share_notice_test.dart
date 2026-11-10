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
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// いま出ている通知を消した後、後ろに積まれた通知が出てこないこと。
  Future<void> expectNoQueuedSnackBar(WidgetTester tester) async {
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
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
    final shareAction = find.text(l10n.projectDetailShareQuickAction);
    // 共有のボタンに出る進行中の印（作成・共有の途中だけ）。
    final shareBusy = find.descendant(
      of: find.ancestor(of: shareAction, matching: find.byType(InkWell)).first,
      matching: find.byType(CircularProgressIndicator),
    );
    await tester.tap(shareAction);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsNothing, reason: '一覧で始めた作成・共有の途中');
    expect(share.calls, 1);
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing, reason: '閉じただけなら何も出さない');

    // 共有の仕組みが無い端末。作成はできていて「自分が作成したもの」に残る。
    final recorded = AppErrorReporter.recentErrors.length;
    // 一覧のメニューで作った分（作品のフォルダの中）も「作成したもの」に入る。
    await tester.runAsync(service.refreshOutgoingShares);
    final savedBefore = service.outgoingShares.length;
    share.failure = MissingPluginException(mockText);
    await tester.tap(shareAction);
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
    await tester.tap(shareAction);
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
    await tester.tap(shareAction);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await confirmAndWait(tester);
    expect(share.calls, 4);
    expect(shareBusy, findsOneWidget, reason: '作成・共有の途中だと分かる');
    await tester.tap(shareAction, warnIfMissed: false);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsNothing, reason: '二度目は始めない');
    expect(share.calls, 4);
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(shareBusy, findsNothing, reason: '終わったら元のアイコンへ戻る');
    expect(find.byType(SnackBar), findsNothing);

    // 同梱の確認を取り消したら、次はまた始められる。
    await tester.tap(shareAction);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsOneWidget);
    // 確認の間は、まだ何も作っていないので進行中の印を出さない。
    expect(shareBusy, findsNothing);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await tester.tap(shareAction);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(includeDialog, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(share.calls, 4);
    expect(tester.takeException(), isNull);
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
    expect(share.calls, 2);
    expect(share.lastPaths, [saved.path], reason: '保存したそのファイルを渡す');
    expect(service.outgoingShares.length, 2, reason: '作り直さない');
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    await clearSnackBars(tester);

    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await tapRow();
    expect(tester.takeException(), isNull);
    expect(share.calls, 3);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    await clearSnackBars(tester);

    // 共有シートを閉じただけなら何も出さない。
    share
      ..failure = null
      ..result = '';
    await tapRow();
    expect(share.calls, 4);
    expect(find.byType(SnackBar), findsNothing);

    // 共有シートが開いている間の二度目は共有を呼ばず、失敗の知らせも1つだけ。
    share.pending = Completer<String>();
    await tapRow();
    await tapRow();
    expect(share.calls, 5, reason: '二度押しで共有を二重に呼ばない');
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
    expect(share.calls, 5, reason: '無いファイルは共有へ渡さない');
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
