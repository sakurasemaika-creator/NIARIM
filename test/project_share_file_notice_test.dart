import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_share_channel.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 作品の共有ファイル（.niashare）の作成と共有（ホームの一覧のメニュー）。
///
/// 以前は、作成と共有を1つの`catch`で受けて「共有ファイルの作成に失敗しました:
/// MissingPluginException(…)」と出し（作成はできている）、作成中にもう一度
/// 押すと同じファイルを同時に書き始めた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = FakeShareChannel();
  const mockText = 'no share on this device 4711';

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

  testWidgets('home menu: one archive and one share at a time, and a share '
      'problem is not a creation failure', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final home = tester.element(find.byType(ProjectListWidget));
    final service = home.read<ProjectService>();
    final l10n = AppLocalizations.of(home)!;
    await tester.runAsync(
      () => service.createProject(
        name: '共有する作品',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 32,
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final createFailed = failureLead(l10n.projectDetailNiashareFailedSnackbar);
    expect(createFailed, isNotEmpty);
    final includeDialog = find.text(l10n.projectListMaterialIncludeTitle);

    /// 同梱の確認で「作成」を押し、共有が呼ばれるまで（作成が終わるまで）待つ。
    Future<void> confirmAndWait() async {
      expect(includeDialog, findsOneWidget);
      final before = share.calls;
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonCreate));
      for (var i = 0; i < 100 && share.calls == before; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
    }

    List<String> snackBarTexts() => [
      for (final text in tester.widgetList<Text>(
        find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
      ))
        text.data ?? '',
    ];

    Future<void> clearSnackBars() async {
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).clearSnackBars();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    // ── ホームの一覧のメニュー ─────────────────────────────────────
    Future<void> chooseShareInHomeMenu() async {
      await tester.tap(
        find
            .descendant(
              of: find.byType(ProjectListWidget),
              matching: find.byType(PopupMenuButton<String>),
            )
            .first,
      );
      // メニューが開ききってから選ぶ（開く途中は項目が画面の外にある）。
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
      await tester.tap(
        find.text(l10n.projectListCreateShareAction),
        warnIfMissed: false,
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
    }

    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    await chooseShareInHomeMenu();
    await confirmAndWait();
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(share.lastPaths.single, endsWith('.niashare'));
    expect(snackBarTexts(), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    await clearSnackBars();

    // 共有シートが開いている間、メニューの「共有ファイルを作成」は押せない。
    share
      ..failure = null
      ..pending = Completer<String>();
    await chooseShareInHomeMenu();
    await confirmAndWait();
    expect(share.calls, 2);
    await chooseShareInHomeMenu();
    expect(includeDialog, findsNothing, reason: '二度目は始めない');
    expect(share.calls, 2);
    // 押せない項目ではメニューが残るので閉じる。
    await tester.tapAt(const Offset(2, 2));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));

    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing, reason: '閉じただけなら何も出さない');

    // 終わったので、また共有できる。失敗は共有の文で知らせる。
    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await chooseShareInHomeMenu();
    await confirmAndWait();
    expect(tester.takeException(), isNull);
    expect(share.calls, 3);
    expect(snackBarTexts(), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, createFailed]);
    await clearSnackBars();

    // 同梱の確認を取り消したら、次はまた始められる。
    share.failure = null;
    await chooseShareInHomeMenu();
    expect(includeDialog, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await chooseShareInHomeMenu();
    expect(includeDialog, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(share.calls, 3);
    expect(tester.takeException(), isNull);
  });
}
