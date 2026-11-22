import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final pc in [false, true]) {
    final mode = pc ? 'PC' : 'SP';
    late ProjectService projects;
    late AppLocalizations l10n;

    Future<void> open(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'en',
        'force_pc_mode': pc ? 1 : 0,
        'home.projectViewMode.v1': 'detail',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final dir = Directory.systemTemp.createTempSync('home-back-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = pc
          ? const Size(1440, 900)
          : const Size(390, 844);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        messenger.setMockMethodCallHandler(channel, null);
        dir.deleteSync(recursive: true);
      });
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pumpAndSettle();
      final home = tester.element(find.byType(HomeScreen));
      projects = home.read<ProjectService>();
      l10n = AppLocalizations.of(home)!;
      await tester.runAsync(() async {
        final parent = await projects.createFolder('Parent');
        final child = await projects.createFolder(
          'Child',
          parentFolderId: parent.id,
        );
        final project = await projects.createProject(
          name: 'Nested take',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 32,
          exportHeight: 18,
        );
        await projects.moveToFolder(project.id, child.id);
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Child'));
      await tester.pumpAndSettle();
      expect(find.text('Nested take'), findsOneWidget);
    }

    Future<void> back(WidgetTester tester) async {
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    }

    testWidgets('$mode back returns one folder level at a time', (
      tester,
    ) async {
      await open(tester);
      final archives = projects.projects.map((p) => p.id).toList();
      await back(tester);
      expect(find.text('Nested take'), findsNothing);
      expect(find.text('Child'), findsOneWidget);
      expect(find.byTooltip(l10n.projectListFolderRootOption), findsOneWidget);
      await back(tester);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Child'), findsNothing);
      expect(find.byTooltip(l10n.projectListFolderRootOption), findsNothing);
      expect(projects.projects.map((p) => p.id).toList(), archives);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      '$mode navigator back preserves the page while leaving a folder',
      (tester) async {
        await open(tester);
        final home = tester.element(find.byType(HomeScreen));
        expect(await Navigator.of(home).maybePop(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Nested take'), findsNothing);
        expect(find.text('Child'), findsOneWidget);
        expect(
          find.byTooltip(l10n.projectListFolderRootOption),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('$mode back closes selection before search before folders', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byTooltip(l10n.commonSearch));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nested take');
      await tester.pumpAndSettle();
      await tester.longPress(
        find.descendant(
          of: find.byType(ProjectListWidget),
          matching: find.text('Nested take'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.homeMoveToTrash), findsOneWidget);
      await back(tester);
      expect(find.byTooltip(l10n.homeMoveToTrash), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nested take',
      );
      await back(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Nested take'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);
      await back(tester);
      expect(find.text('Nested take'), findsNothing);
      expect(find.text('Child'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$mode drawer and pushed routes close before folder back', (
      tester,
    ) async {
      await open(tester);
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      await tester.tap(find.byKey(const Key('homeMenuButton')));
      await tester.pumpAndSettle();
      expect(scaffold.isEndDrawerOpen, isTrue);
      await back(tester);
      expect(scaffold.isEndDrawerOpen, isFalse);
      expect(find.text('Nested take'), findsOneWidget);
      final home = tester.element(find.byType(HomeScreen));
      GoRouter.of(home).push('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
      await back(tester);
      expect(find.text('Nested take'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      '$mode modal back cancels while the launch arrow still leaves',
      (tester) async {
        await open(tester);
        await tester.tap(find.byTooltip(l10n.commonAdd));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.homeAddSheetNewFolder));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Uncommitted folder');
        await back(tester);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Nested take'), findsOneWidget);
        expect(projects.folders.length, 2);
        await tester.tap(find.byKey(const Key('homeBackToSplashButton')));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsNothing);
        expect(projects.projects.single.name, 'Nested take');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
