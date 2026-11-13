import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shared-paste-flow-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'home_view_mode': 'medium',
    });
    appRouter.go('/');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 75));
    }
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png!.buffer.asUint8List();
    });
    final output = Directory('build/home-clipboard-captures')
      ..createSync(recursive: true);
    await tester.runAsync(() async {
      await File(output.path + '/' + name + '.png')
          .writeAsBytes(bytes!, flush: true);
    });
  }

  Future<void> awaitVisible(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 45)),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(
      finder,
      findsOneWidget,
      reason: 'Trash entry must actually be rendered before capture/tap',
    );
  }

  Future<void> awaitLibraryState(
    WidgetTester tester,
    bool Function() done,
  ) async {
    for (var i = 0; i < 50 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 45)),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> pumpIo(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 35)),
      );
      await tester.pump(const Duration(milliseconds: 75));
    }
  }

  testWidgets(
    'received folder clipboard moves to Trash and restores with confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await loadAppFonts(tester);
      final captureKey = GlobalKey();
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final service = tester
          .element(find.byType(SplashScreen))
          .read<ProjectService>();
      late String folderId;
      await tester.runAsync(() async {
        final folder = await service.createSharedFolder('受信箱');
        folderId = folder.id;
        final work = await service.importSharedProject(
          NiaproData(
            project: Project(
              id: 'source',
              name: '元の作品',
              fps: 1,
              durationSeconds: 1,
              backgroundColor: 0xFFFFFFFF,
              exportWidth: 64,
              exportHeight: 64,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              totalWorkSeconds: 0,
            ),
            scenes: const [],
            tileData: const {},
          ),
        );
        await service.saveProject(work.id);
        await service.moveToSharedFolder(work.id, folderId);
        final outgoing = await service.createProject(
          name: '共有を書き出す作品',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await service.saveProject(outgoing.id);
        await service.createOutgoingShare(project: outgoing);
      });

      await tester.tap(find.byIcon(Icons.brush_outlined));
      await pumpIo(tester);
      await tester.tap(find.byKey(const ValueKey('home_tab_2')));
      await pumpIo(tester);
      await capture(tester, captureKey, '01_received_share_tab');

      await tester.longPress(find.text('受信箱').first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithIcon(ListTile, Icons.content_copy));
      await pumpIo(tester);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsOneWidget);
      await capture(tester, captureKey, '02_received_folder_copied');

      await tester.tap(find.byKey(const ValueKey('home_tab_3')));
      await pumpIo(tester);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await tester.pump();
      expect(find.byKey(const Key('homePasteToTrashDialog')), findsOneWidget);
      await capture(
        tester,
        captureKey,
        '03_received_folder_trash_confirmation',
      );
      // Cancel must leave all files and folder membership unchanged.
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const Key('homePasteToTrashDialog')),
              matching: find.byType(TextButton),
            )
            .first,
      );
      await pumpIo(tester);
      expect(service.sharedFolders.single.id, folderId);
      expect(service.shared.single.sharedFolderId, folderId);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
      await pumpIo(tester);
      expect(service.sharedFolders, isEmpty);
      expect(service.trashedFolders.single.isShared, isTrue);
      expect(service.trashedFolders.single.projectIds, hasLength(1));
      await capture(tester, captureKey, '04_received_folder_in_trash');

      await tester.tap(find.byKey(ValueKey('trashCopyFolder_$folderId')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home_tab_2')));
      await pumpIo(tester);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await tester.pump();
      expect(find.byKey(const Key('homePasteRestoreDialog')), findsOneWidget);
      await capture(
        tester,
        captureKey,
        '05_received_folder_restore_confirmation',
      );
      // Cancelling restore must keep the archived folder and its children safe.
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const Key('homePasteRestoreDialog')),
              matching: find.byType(TextButton),
            )
            .first,
      );
      await pumpIo(tester);
      expect(service.trashedFolders.single.folder.id, folderId);
      expect(service.shared, isEmpty);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('homePasteRestoreConfirmButton')));
      await pumpIo(tester);
      expect(service.trashedFolders, isEmpty);
      expect(service.sharedFolders.single.id, folderId);
      expect(service.shared.single.sharedFolderId, folderId);
      expect(service.shared.single.name, '元の作品');
      expect(service.trash, isEmpty);
      await capture(tester, captureKey, '06_received_folder_restored');
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await pumpIo(tester);
      expect(service.outgoingShares, isNotEmpty);
      await capture(tester, captureKey, '14_outgoing_share_pill');

      // The outgoing-share pill has a distinct file format but may use Trash.
      final sharePath = service.outgoingShares.single.path;
      await tester.tap(find.byKey(ValueKey('outgoingShareMenu_$sharePath')));
      // PopupMenuRoute blocks hit-testing until its entrance animation finishes.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      final copyOption = find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuItem<String> &&
            widget.value == 'copyToClipboard',
      );
      expect(copyOption, findsOneWidget);
      await tester.tap(copyOption);
      await pumpIo(tester);
      await tester.tap(find.byKey(const ValueKey('home_tab_3')));
      await pumpIo(tester);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('homePasteToTrashDialog')), findsOneWidget);
      await capture(tester, captureKey, '15_outgoing_trash_confirmation');
      AppErrorReporter.recentErrors.clear();
      await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
      await awaitLibraryState(tester, () => service.outgoingShares.isEmpty);
      expect(
        service.outgoingShares,
        isEmpty,
        reason: 'Errors during outgoing move: ${AppErrorReporter.recentErrors}',
      );
      final archived = (await tester.runAsync(LocalFileTrashService.list))!;
      expect(archived, hasLength(1));
      expect(archived.single.kind, LocalTrashKind.outgoingShare);
      final outgoingTrashCopy = find.byKey(
        ValueKey('trashCopyLocal_${archived.single.id}'),
      );
      await awaitVisible(tester, outgoingTrashCopy);
      await capture(tester, captureKey, '16_outgoing_in_trash');

      await tester.tap(outgoingTrashCopy);
      await pumpIo(tester);
      await tester.tap(find.byKey(const ValueKey('home_tab_2')));
      await pumpIo(tester);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('homePasteRestoreDialog')), findsOneWidget);
      await capture(tester, captureKey, '17_outgoing_restore_confirmation');
      await tester.tap(find.byKey(const Key('homePasteRestoreConfirmButton')));
      await awaitLibraryState(tester, () => service.outgoingShares.length == 1);
      expect(
        service.outgoingShares,
        hasLength(1),
        reason:
            'Errors during outgoing restore: ${AppErrorReporter.recentErrors}',
      );
      await capture(tester, captureKey, '18_outgoing_restored');
    },
  );

  testWidgets(
    'empty Works folder with stale file membership may paste into Projects',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await loadAppFonts(tester);
      final captureKey = GlobalKey();
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final splash = tester.element(find.byType(SplashScreen));
      final projects = splash.read<ProjectService>();
      final works = splash.read<WorkFolderService>();
      await tester.runAsync(() async {
        final folder = await works.createFolder('空の書き出し');
        // Metadata remains from a file that is no longer on disk.
        await works.moveFileToFolder('previously-deleted.mp4', folder.id);
      });
      await tester.tap(find.byIcon(Icons.brush_outlined));
      await pumpIo(tester);
      await tester.tap(find.byKey(const ValueKey('home_tab_1')));
      await pumpIo(tester);
      await capture(tester, captureKey, '07_works_empty_folder');
      await tester.longPress(find.text('空の書き出し').first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithIcon(ListTile, Icons.content_copy));
      await pumpIo(tester);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home_tab_0')));
      await pumpIo(tester);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await pumpIo(tester);
      expect(find.byKey(const Key('homePasteRestrictionDialog')), findsNothing);
      expect(projects.folders.map((folder) => folder.name), contains('空の書き出し'));
      expect(works.folders.single.name, '空の書き出し');
      await capture(tester, captureKey, '08_empty_folder_cross_tab_paste');

      // The same exported-work folder can also be archived and restored,
      // including when its stale membership references no existing file.
      await tester.tap(find.byKey(const ValueKey('home_tab_3')));
      await pumpIo(tester);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      // Export listing checks the real filesystem asynchronously before showing
      // the dialog; one synthetic pump is not enough for the result.
      await pumpIo(tester);
      expect(find.byKey(const Key('homePasteToTrashDialog')), findsOneWidget);
      await capture(tester, captureKey, '19_works_folder_trash_confirmation');
      AppErrorReporter.recentErrors.clear();
      await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
      await awaitLibraryState(tester, () => works.folders.isEmpty);
      expect(
        works.folders,
        isEmpty,
        reason:
            'Errors during Works-folder move: ${AppErrorReporter.recentErrors}',
      );
      final archived = (await tester.runAsync(LocalFileTrashService.list))!;
      expect(archived, hasLength(1));
      expect(archived.single.kind, LocalTrashKind.exportedWorkFolder);
      final workTrashCopy = find.byKey(
        ValueKey('trashCopyLocal_${archived.single.id}'),
      );
      await awaitVisible(tester, workTrashCopy);
      await capture(tester, captureKey, '20_works_folder_in_trash');

      await tester.tap(workTrashCopy);
      await pumpIo(tester);
      await tester.tap(find.byKey(const ValueKey('home_tab_1')));
      await pumpIo(tester);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('homePasteRestoreDialog')), findsOneWidget);
      await capture(tester, captureKey, '21_works_folder_restore_confirmation');
      await tester.tap(find.byKey(const Key('homePasteRestoreConfirmButton')));
      await awaitLibraryState(tester, () => works.folders.length == 1);
      expect(
        works.folders.single.name,
        '空の書き出し',
        reason: 'Errors during Works restore: ${AppErrorReporter.recentErrors}',
      );
      expect(await tester.runAsync(LocalFileTrashService.list), isEmpty);
      await capture(tester, captureKey, '22_works_folder_restored');
    },
  );
}
