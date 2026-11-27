// 作品ファイルが壊れていた（見つからなかった）ため、起動時に最新の自動保存から
// 復元した作品を開くと、何が起きたかと日時をダイアログで説明し、
// 「キャンセル」「読み込むデータを選ぶ」「この内容で続ける」を選べる。
// 「キャンセル」は作品を開いた元の画面へ戻る（作品詳細から開いたキャンバスなら
// 作品詳細。以前の「プロジェクト一覧に戻る」は作品詳細から開いたときに合わな
// かった。所有者の指摘、2026-11-27）。
//
// 以前は「作品ファイルを読み込めなかったため、自動保存から復旧しました。」の
// 短い知らせが出るだけで、いつの自動保存か・ほかの保存を選べることが
// 分からなかった（所有者の指摘、2026-11-27）。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/project_autosave_notice.dart';
import 'package:provider/provider.dart';

class _RecoveredProjects extends ProjectService {
  _RecoveredProjects(this.recoveredAt);

  DateTime? recoveredAt;

  @override
  DateTime? takeAutosaveRecovery(String projectId) {
    final at = recoveredAt;
    recoveredAt = null;
    return at;
  }
}

class _Opened extends StatefulWidget {
  const _Opened();

  @override
  State<_Opened> createState() => _OpenedState();
}

class _OpenedState extends State<_Opened> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => settleOpenedWork(context, 'p1', saveEntry: 'projectDetail'),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('作品の詳細'));
}

void main() {
  Future<GoRouter> show(
    WidgetTester tester,
    ProjectService projects, {
    String initialLocation = '/project/p1',
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('一覧')),
        ),
        GoRoute(
          path: '/before',
          builder: (_, _) => const Scaffold(body: Text('前の画面')),
        ),
        GoRoute(path: '/project/:id', builder: (_, _) => const _Opened()),
        GoRoute(
          path: '/save-tree/:id',
          builder: (_, state) => Scaffold(body: Text('保存 ${state.uri}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectService>.value(
        value: projects,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ja'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  final recoveredAt = DateTime(2026, 11, 27, 1, 3);

  testWidgets('explains the restore with its time and offers the three '
      'choices', (tester) async {
    final projects = _RecoveredProjects(recoveredAt);
    addTearDown(projects.dispose);
    await show(tester, projects);
    expect(find.text('作品ファイルを読み込めませんでした'), findsOneWidget);
    expect(
      find.textContaining('最新の自動保存（2026/11/27 1:03）から復元しました'),
      findsOneWidget,
    );
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('読み込むデータを選ぶ'), findsOneWidget);
    expect(find.text('この内容で続ける'), findsOneWidget);
    // Tapping outside does not close it.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('autosaveRecoveredContinue')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('作品の詳細'), findsOneWidget);
  });

  testWidgets('「キャンセル」 goes back to the screen the work was opened '
      'from', (tester) async {
    final projects = _RecoveredProjects(null);
    addTearDown(projects.dispose);
    final router = await show(tester, projects, initialLocation: '/before');
    projects.recoveredAt = recoveredAt;
    router.push('/project/p1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('autosaveRecoveredCancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('前の画面'), findsOneWidget);
  });

  testWidgets('「キャンセル」 with nothing to go back to goes to the list', (
    tester,
  ) async {
    final projects = _RecoveredProjects(recoveredAt);
    addTearDown(projects.dispose);
    await show(tester, projects);
    await tester.tap(find.byKey(const ValueKey('autosaveRecoveredCancel')));
    await tester.pumpAndSettle();
    expect(find.text('一覧'), findsOneWidget);
  });

  testWidgets('「読み込むデータを選ぶ」 opens the saves on the automatic saves', (
    tester,
  ) async {
    final projects = _RecoveredProjects(recoveredAt);
    addTearDown(projects.dispose);
    await show(tester, projects);
    await tester.tap(find.byKey(const ValueKey('autosaveRecoveredChooseData')));
    await tester.pumpAndSettle();
    expect(
      find.text('保存 /save-tree/p1?entry=projectDetail&source=autosave'),
      findsOneWidget,
    );
  });

  testWidgets('a work that was read normally shows nothing', (tester) async {
    final projects = _RecoveredProjects(null);
    addTearDown(projects.dispose);
    await show(tester, projects);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
