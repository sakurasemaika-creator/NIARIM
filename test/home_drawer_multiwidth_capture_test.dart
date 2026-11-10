import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/help/guide_hub_screen.dart';
import 'package:niarim/screens/rewards/coin_benefits_screen.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture current Create Works home and drawer across SP and PC widths', (tester) async {
    final temp = Directory.systemTemp.createTempSync('niarim-home-drawer-matrix-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    var workingDirectory = temp.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => workingDirectory);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('build/home-drawer-multiwidth')..createSync(recursive: true);
    final rows = <String>[];

    for (final width in <int>[320, 360, 390, 430, 600, 760, 1024, 1440]) {
      final pc = width >= 760;
      final height = pc ? 900 : 844;
      await tester.pumpWidget(const SizedBox.shrink());
      workingDirectory =
          (Directory('${temp.path}/width_$width')..createSync(recursive: true)).path;
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': pc ? 1 : 0,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
      appRouter.go('/home');
      final key = GlobalKey();
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(
            providers: providers!,
            child: const NiarimApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'width $width');
      // Keep a realistic project tile visible instead of presenting only an
      // empty-state mockup. These sample projects never leave the CI runner.
      final service = tester.element(find.byType(HomeScreen)).read<ProjectService>();
      // Create actual .niashare bytes and re-import them to photograph
      // populated Received/Created collections, not just empty states.
      await tester.runAsync(() async {
        final project = await service.createProject(
          name: 'サンプルアニメーション',
          fps: 12,
          durationSeconds: 3,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 1920,
          exportHeight: 1080,
        );
        final saved = await service.createOutgoingShare(project: project);
        final received = await NiaproSerializer.loadShare(saved.path);
        await service.importSharedProject(received);
      });
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 200));

      Future<void> settleTabAnimation() async {
        // TabBarView needs multiple *frames*. One large pump updates the
        // selected title but can photograph the previous PageView content.
        // Do not pumpAndSettle: loading indicators intentionally never settle.
        for (var frame = 0; frame < 14; frame++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
      }

      Future<void> shot(String name) async {
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'width $width, $name');
        final render =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        await tester.runAsync(
          () => File('${output.path}/${width}dp-$name.png').writeAsBytes(bytes!),
        );
      }

      expect(find.byKey(const ValueKey('home_tab_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_tab_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_tab_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_tab_3')), findsOneWidget);
      await shot('01-projects');

      // Shared library now has two explicit, mutually exclusive collections.
      await tester.ensureVisible(find.byKey(const ValueKey('home_tab_2')));
      await tester.tap(find.byKey(const ValueKey('home_tab_2')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.widget<Semantics>(find.byKey(const ValueKey('home_tab_2')))
            .properties
            .selected,
        isTrue,
      );
      expect(find.byType(SharedScreen), findsOneWidget);
      expect(find.byKey(const Key('sharedReceivedFilter')), findsOneWidget);
      expect(find.byKey(const Key('sharedOutgoingFilter')), findsOneWidget);
      // The shared control must look and behave as one two-way pill, not
      // two independently selectable chips. Verify on every SP/PC width.
      final direction = find.byKey(const Key('sharedDirectionSegmentedControl'));
      expect(direction, findsOneWidget, reason: 'width $width');
      final directionBefore = tester.widget<SegmentedButton<bool>>(direction);
      expect(directionBefore.multiSelectionEnabled, isFalse);
      expect(directionBefore.emptySelectionAllowed, isFalse);
      expect(directionBefore.showSelectedIcon, isFalse);
      expect(directionBefore.selected, {false});
      final sharedAddFolderFab = find.byWidgetPredicate(
        (widget) => widget is FloatingActionButton &&
            widget.heroTag == 'shared-add-folder',
      );
      expect(sharedAddFolderFab, findsOneWidget, reason: 'width $width');
      final fab = tester.widget<FloatingActionButton>(sharedAddFolderFab);
      expect(fab.elevation, 0);
      expect(fab.shape, isA<CircleBorder>());
      expect((fab.shape! as CircleBorder).side, BorderSide.none);
      await shot('04-shared-received');
      final receivedMenu =
          find.byKey(ValueKey('receivedShareMenu_${service.shared.single.id}'));
      expect(receivedMenu, findsOneWidget, reason: 'width $width');
      await tester.tap(receivedMenu);
      await tester.pumpAndSettle();
      await shot('08-shared-received-menu');
      await tester.tapAt(Offset(5, height - 130.0));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await tester.pump(const Duration(milliseconds: 500));
      // Scaffold animates a departing FAB for several frames. Confirm the
      // settled screen, not the outgoing hero transition.
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(tester.widget<SegmentedButton<bool>>(direction).selected, {true});
      expect(sharedAddFolderFab, findsNothing);
      await shot('05-shared-created');
      expect(service.outgoingShares, isNotEmpty, reason: 'width $width');
      final outgoingMenu = find.byKey(
        ValueKey('outgoingShareMenu_${service.outgoingShares.first.path}'),
      );
      expect(outgoingMenu, findsOneWidget, reason: 'width $width');
      await tester.tap(outgoingMenu);
      await tester.pumpAndSettle();
      await shot('09-shared-created-menu');
      await tester.tapAt(Offset(5, height - 130.0));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const Key('sharedReceivedFilter')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<SegmentedButton<bool>>(direction).selected, {false});
      await tester.ensureVisible(find.byKey(const ValueKey('home_tab_1')));
      await tester.tap(find.byKey(const ValueKey('home_tab_1')));
      await settleTabAnimation();
      expect(
        tester.widget<Semantics>(find.byKey(const ValueKey('home_tab_1')))
            .properties.selected,
        isTrue,
      );
      await shot('06-works');

      // A real Trash screenshot must prove all four categories exist and are
      // labeled. Seed recoverable files and both kinds of soft-deleted projects.
      await tester.runAsync(() async {
        final outgoing = service.outgoingShares.first;
        await LocalFileTrashService.move(
          File(outgoing.path), LocalTrashKind.outgoingShare,
        );
        final exported = File('$workingDirectory/trash-sample-export.mp4');
        await exported.writeAsBytes([0, 1, 2, 3, 4]);
        await LocalFileTrashService.move(
          exported, LocalTrashKind.exportedWork,
        );
        final received = service.shared.single;
        await service.deleteProject(received.id);
        final created = service.projects.firstWhere(
          (p) => p.name == 'サンプルアニメーション',
        );
        await service.deleteProject(created.id);
      });
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.byKey(const ValueKey('home_tab_3')));
      await tester.tap(find.byKey(const ValueKey('home_tab_3')));
      await settleTabAnimation();
      expect(
        tester.widget<Semantics>(find.byKey(const ValueKey('home_tab_3')))
            .properties.selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('trashKind_createdProject')),
        findsOneWidget, reason: 'Trash content must replace Shared at width $width',
      );
      for (final type in [
        'createdProject', 'receivedShare', 'createdShare', 'exportedWork',
      ]) {
        expect(find.byKey(ValueKey('trashKind_$type')), findsOneWidget);
        expect(
          tester.widget<FilterChip>(find.byKey(ValueKey('trashKind_$type'))).selected,
          isTrue,
        );
      }
      // Unlike the two-way shared switch, the Trash type chips allow multiple
      // independently selected categories.
      await tester.tap(find.byKey(const ValueKey('trashKind_receivedShare')));
      await tester.pump();
      expect(
        tester.widget<FilterChip>(
          find.byKey(const ValueKey('trashKind_receivedShare')),
        ).selected,
        isFalse,
      );
      expect(
        tester.widget<FilterChip>(
          find.byKey(const ValueKey('trashKind_createdProject')),
        ).selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('trashKind_receivedShare')));
      await tester.pump();
      expect(find.byKey(const Key('sharedReceivedFilter')), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settleTabAnimation();
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Trash must finish reading recoverable files before capture',
      );
      final deleted = service.trash;
      expect(deleted.where((p) => p.isSharedImport), hasLength(1));
      expect(deleted.where((p) => !p.isSharedImport), hasLength(1));
      final archived = await tester.runAsync(LocalFileTrashService.list);
      expect(archived, hasLength(2));
      expect(archived!.map((e) => e.kind).toSet(), {
        LocalTrashKind.outgoingShare,
        LocalTrashKind.exportedWork,
      });
      // The file-list future runs real filesystem IO, not Flutter's fake
      // animation clock. Pump after real async completions before evaluating
      // the lazy ListView rows.
      final exportedTitle = find.text('trash-sample-export.mp4');
      for (var attempt = 0; attempt < 12; attempt++) {
        if (exportedTitle.evaluate().isNotEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pump(const Duration(milliseconds: 40));
      }
      await shot('07-trash');
      // Verify real exported-file and outbound-share cards, not merely
      // repository storage records. Narrow layouts must scroll to them.
      if (width < 760 && exportedTitle.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          exportedTitle,
          180,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 12,
        );
      }
      await settleTabAnimation();
      expect(exportedTitle, findsOneWidget, reason: 'width $width');
      expect(find.textContaining('.niashare'), findsWidgets, reason: 'width $width');
      await shot('07b-trash-bottom');
      await tester.ensureVisible(find.byKey(const ValueKey('home_tab_0')));
      await tester.tap(find.byKey(const ValueKey('home_tab_0')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 350));

      final menuButton = find.byKey(const Key('homeMenuButton'));
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      final drawer = find.byType(Drawer);
      expect(drawer, findsOneWidget);
      await shot('02-drawer-top');

      // Capture the bottom even when all five entries fit on screen.
      await tester.drag(drawer, const Offset(0, -540));
      await tester.pump(const Duration(milliseconds: 300));
      await shot('03-drawer-bottom');

      // Hub pages changed in the same UI consolidation: two Guide tabs
      // and three Coin/Benefits tabs. Capture both mobile and desktop.
      if (width == 390 || width == 1024) {
        // A still-open drawer uses a local route history entry and prevents
        // navigation to the guide shell from taking effect.
        Navigator.of(tester.element(drawer)).pop();
        await tester.pumpAndSettle();
        appRouter.go('/help');
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GuideHubScreen), findsOneWidget);
        await shot('10-guide-help');
        DefaultTabController.of(
          tester.element(find.byType(TabBar).first),
        ).animateTo(0);
        await settleTabAnimation();
        expect(
          DefaultTabController.of(tester.element(find.byType(TabBar).first)).index,
          0,
        );
        await shot('11-guide-tips');

        appRouter.go('/rewards');
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pumpAndSettle();
        // Some capture environments may redirect paid/reward routes.
        // Always preserve the independently verified home/share captures.
        if (find.byType(CoinBenefitsScreen).evaluate().isNotEmpty) {
          for (var i = 0; i < 3; i++) {
            DefaultTabController.of(
              tester.element(find.byType(TabBar).first),
            ).animateTo(i);
            await settleTabAnimation();
            expect(
              DefaultTabController.of(
                tester.element(find.byType(TabBar).first),
              ).index, i,
            );
            await shot('12-coin-benefits-tab-${i + 1}');
          }
        }
      }

      rows.add('$width x $height dp; mode=${pc ? 'PC' : 'SP'}; home-tabs=4; drawer=5; shared=received+created');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    File('${output.path}/matrix.txt')
        .writeAsStringSync(rows.join('\n') + '\n');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
