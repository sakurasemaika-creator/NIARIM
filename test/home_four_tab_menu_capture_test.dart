import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// Capture the production Home UI, never a mock reproduction.
/// The Trash tab has direct actions and no three-dot popup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('four home tabs and contextual operations', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      'home.projectViewMode.v1': 'small',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('four-tab-captures-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    late String workPath;
    await tester.runAsync(() async {
      final exports = await ExportEngine.exportsDir();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 480, 270),
        Paint()..color = const Color(0xFFE8ECF7),
      );
      canvas.drawCircle(
        const Offset(220, 135),
        85,
        Paint()..color = const Color(0xFF7A94D8),
      );
      canvas.drawCircle(
        const Offset(232, 112),
        43,
        Paint()..color = const Color(0xFFFFD3B3),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(480, 270);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final work = File(exports.path + '/ANIME_EP01.png');
      workPath = work.path;
      await work.writeAsBytes(data!.buffer.asUint8List(), flush: true);
      final deleted = File(exports.path + '/ANIME_OLD.png');
      await deleted.writeAsBytes(await work.readAsBytes(), flush: true);
      await LocalFileTrashService.move(deleted, LocalTrashKind.exportedWork);
      await ExportEngine.listExportedFiles(forceRefresh: true);
    });

    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 130));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 35)),
        );
      }
      await tester.pump();
    }

    await settle();
    expect(find.byType(HomeScreen), findsOneWidget);
    final projects = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: '第1話 サンプルアニメ',
        fps: 12,
        durationSeconds: 2,
        backgroundColor: 0xFFF1F5FF,
        exportWidth: 480,
        exportHeight: 270,
      ),
    ))!;
    final deleted = (await tester.runAsync(
      () => projects.createProject(
        name: '削除した練習作品',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFF5EE,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    await tester.runAsync(() => projects.deleteProject(deleted.id));
    final archive = (await tester.runAsync(
      () => projects.createOutgoingShare(project: project),
    ))!;
    final sharedData = await tester.runAsync(
      () => NiaproSerializer.loadShare(archive.path),
    );
    await tester.runAsync(() => projects.importSharedProject(sharedData!));
    expect(projects.shared, isNotEmpty);
    await settle();

    Future<void> shot(String name) async {
      await settle();
      expect(tester.takeException(), isNull, reason: name);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final folder = Directory('build/home-four-tab-captures')
        ..createSync(recursive: true);
      await tester.runAsync(
        () => File(
          folder.path + '/' + name + '.png',
        ).writeAsBytes(bytes!, flush: true),
      );
      // ignore: avoid_print
      print('FOUR_TAB_CAPTURE: ' + name);
    }

    Future<void> tab(int index) async {
      final target = find.byKey(ValueKey('home_tab_' + index.toString()));
      expect(target, findsOneWidget);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await settle();
    }

    Future<void> closeMenu() async {
      await tester.tapAt(const Offset(365, 710));
      await settle();
    }

    await shot('01_projects');
    final projectsFabY = tester
        .getCenter(
          find.byWidgetPredicate(
            (widget) =>
                widget is FloatingActionButton &&
                widget.heroTag == 'home-add-project',
          ),
        )
        .dy;
    final projectMenu = find
        .descendant(
          of: find.byType(ProjectListWidget),
          matching: find.byType(PopupMenuButton<String>),
        )
        .first;
    await tester.tap(projectMenu);
    await settle();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    expect(find.text('プロジェクトを共有'), findsOneWidget);
    expect(find.text('フォルダへ移動'), findsNothing);
    await shot('02_projects_menu');
    await closeMenu();

    await tab(1);
    final worksFabY = tester
        .getCenter(
          find.byWidgetPredicate(
            (widget) =>
                widget is FloatingActionButton &&
                widget.heroTag == 'home-add-work-folder',
          ),
        )
        .dy;
    expect(worksFabY, closeTo(projectsFabY, 1));
    expect(find.byType(ExportedWorkCard), findsWidgets);
    await shot('03_works');
    await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')).first);
    await settle();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    expect(find.text('ゴミ箱へ移動'), findsWidgets);
    expect(find.text('フォルダへ移動'), findsNothing);
    await shot('04_works_menu');
    await closeMenu();

    await tab(2);
    final sharedFabY = tester
        .getCenter(
          find.byWidgetPredicate(
            (widget) =>
                widget is FloatingActionButton &&
                widget.heroTag == 'shared-add-folder',
          ),
        )
        .dy;
    expect(sharedFabY, closeTo(projectsFabY, 1));
    expect(projects.shared, isNotEmpty);
    await shot('05_shared');
    final shareMenu = find.byKey(
      Key('collectionMenu_' + projects.shared.first.id),
    );
    expect(shareMenu, findsOneWidget);
    await tester.tap(shareMenu);
    await settle();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    expect(find.text('プロジェクトを共有'), findsOneWidget);
    expect(find.text('フォルダへ移動'), findsNothing);
    await shot('06_shared_menu');
    await closeMenu();

    await tab(3);
    expect(find.text('削除した練習作品'), findsWidgets);
    await shot('07_trash');
    await tester.tap(find.text('復元').first);
    await settle();
    expect(
      find.byKey(const Key('homeTrashRestoreConfirmation')),
      findsOneWidget,
    );
    await shot('08_trash_restore_confirmation');
    await tester.tap(find.text('キャンセル').last);
    await settle();

    // Capture the actual long-press selection mode, not a simulated card.
    await tester.longPress(find.text('削除した練習作品').first);
    await settle();
    expect(find.byKey(const Key('home-selection-count')), findsOneWidget);
    expect(
      find.byKey(Key('homeSelectedMarker_trash_project:${deleted.id}')),
      findsOneWidget,
    );
    await shot('12_trash_selected');

    await tab(0);
    await tester.longPress(find.text('第1話 サンプルアニメ').first);
    await settle();
    expect(find.byKey(const Key('home-selection-count')), findsOneWidget);
    await shot('09_projects_selected');

    await tab(1);
    await tester.longPress(find.text('ANIME_EP01.png').first);
    await settle();
    expect(
      find.byKey(Key('homeSelectedMarker_work_file:$workPath')),
      findsOneWidget,
    );
    await shot('10_works_selected');

    await tab(2);
    await tester.longPress(find.text('第1話 サンプルアニメ').first);
    await settle();
    expect(
      find.byKey(
        Key('homeSelectedMarker_shared_file:${projects.shared.first.id}'),
      ),
      findsOneWidget,
    );
    await shot('11_shared_selected');

    // Capture selected folders using real cards on every tab.
    final folders = (await tester.runAsync(() async {
      final projectFolder = await projects.createFolder('プロジェクト資料フォルダ');
      final works = tester
          .element(find.byType(HomeScreen))
          .read<WorkFolderService>();
      final worksFolder = await works.createFolder('作品整理フォルダ');
      final sharedFolder = await projects.createSharedFolder('共有整理フォルダ');
      final deletedFolder = await LocalFileTrashService.moveWorkFolder(
        folderName: '削除した作品フォルダ',
        files: <File>[],
      );
      return (projectFolder, worksFolder, sharedFolder, deletedFolder);
    }))!;
    // Folder creation is a prerequisite: fail explicitly instead of
    // accidentally testing markers for null IDs.
    expect(folders.$2, isNotNull);
    expect(folders.$3, isNotNull);
    expect(folders.$4, isNotNull);
    await settle();
    await tab(0);
    await tester.longPress(find.text('プロジェクト資料フォルダ').first);
    await settle();
    expect(find.byKey(const Key('home-selection-count')), findsOneWidget);
    await shot('13_projects_folder_selected');
    await tab(1);
    await tester.longPress(find.text('作品整理フォルダ').first);
    await settle();
    expect(
      find.byKey(Key('homeSelectedMarker_work_folder:${folders.$2.id}')),
      findsOneWidget,
    );
    await shot('14_works_folder_selected');
    await tab(2);
    await tester.longPress(find.text('共有整理フォルダ').first);
    await settle();
    expect(
      find.byKey(Key('homeSelectedMarker_shared_folder:${folders.$3.id}')),
      findsOneWidget,
    );
    await shot('15_shared_folder_selected');
    await tab(3);
    // The folder is archived while another tab is active. Confirm the real
    // on-disk entry, then refresh the Trash tab's asynchronous list.
    final localTrash = await tester.runAsync(LocalFileTrashService.list);
    expect(localTrash, isNotNull);
    expect(
      localTrash!.any((entry) => entry.id == folders.$4.id && entry.isFolder),
      isTrue,
    );
    LocalFileTrashService.changes.value++;
    await settle();
    // A second settling pass lets the Trash FutureBuilder finish reading
    // the newly archived folder before the widget finder searches the list.
    await settle();
    final trashedFolder = find.text('削除した作品フォルダ');
    if (trashedFolder.evaluate().isEmpty) {
      // The Trash list is lazy, and a new record can be outside its viewport.
      await tester.scrollUntilVisible(
        trashedFolder,
        160,
        scrollable: find
            .descendant(
              of: find.byType(TrashScreen),
              matching: find.byType(Scrollable),
            )
            .last,
        maxScrolls: 15,
      );
      await settle();
    }
    expect(trashedFolder, findsWidgets);
    await tester.longPress(trashedFolder.first);
    await settle();
    expect(
      find.byKey(Key('homeSelectedMarker_trash_local:${folders.$4.id}')),
      findsOneWidget,
    );
    await shot('16_trash_folder_selected');

    // Capture the real paste toolbar immediately below the tabs after copying.
    Future<void> copyCurrentSelection() async {
      final copyButton = find.descendant(
        of: find.byType(HomeSelectionToolbar),
        matching: find.byIcon(Icons.content_copy),
      );
      expect(copyButton, findsOneWidget);
      await tester.tap(copyButton);
      await settle();
      final toolbar = find.byKey(const Key('homeClipboardToolbar'));
      final paste = find.byKey(const Key('homeCrossTabPasteButton'));
      final clear = find.byKey(const Key('homeClearClipboardButton'));
      expect(toolbar, findsOneWidget);
      expect(paste, findsOneWidget);
      expect(clear, findsOneWidget);
      expect(find.descendant(of: toolbar, matching: paste), findsOneWidget);
      expect(find.descendant(of: toolbar, matching: clear), findsOneWidget);
      expect(find.ancestor(of: paste, matching: find.byType(AppBar)), findsNothing);
      expect(
        tester.getTopLeft(toolbar).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(const ValueKey('home_tab_0'))).dy - 1,
        ),
      );
    }

    await tab(0);
    await tester.longPress(find.text('第1話 サンプルアニメ').first);
    await settle();
    await copyCurrentSelection();
    await shot('17_projects_paste_ready');

    await tab(1);
    await tester.longPress(find.text('ANIME_EP01.png').first);
    await settle();
    await copyCurrentSelection();
    await shot('18_works_paste_ready');

    await tab(2);
    await tester.longPress(find.text('第1話 サンプルアニメ').first);
    await settle();
    await copyCurrentSelection();
    await shot('19_shared_paste_ready');

    // Trash accepts a copied source from another tab as a move-to-Trash
    // destination. A copied Trash item itself is restored via its source tab.
    await tab(0);
    await tester.longPress(find.text('第1話 サンプルアニメ').first);
    await settle();
    await copyCurrentSelection();
    await tab(3);
    expect(find.byKey(const Key('homeCrossTabPasteButton')), findsOneWidget);
    await shot('20_trash_paste_ready');

    // Clearing after cross-tab copy removes all clipboard references and
    // hides the toolbar immediately, including when switching tabs again.
    await tester.tap(find.byKey(const Key('homeClearClipboardButton')));
    await settle();
    expect(find.byKey(const Key('homeClipboardToolbar')), findsNothing);
    expect(find.byKey(const Key('homeCrossTabPasteButton')), findsNothing);
    await tab(0);
    expect(find.byKey(const Key('homeClipboardToolbar')), findsNothing);

    // Cutting and clearing must not move or delete the original project.
    await tester.longPress(find.text('第1話 サンプルアニメ').first);
    await settle();
    final cutButton = find.descendant(
      of: find.byType(HomeSelectionToolbar),
      matching: find.byIcon(Icons.content_cut),
    );
    await tester.tap(cutButton);
    await settle();
    expect(find.byKey(const Key('homeClipboardToolbar')), findsOneWidget);
    expect(find.textContaining('切り取り中'), findsOneWidget);
    await tester.tap(find.byKey(const Key('homeClearClipboardButton')));
    await settle();
    expect(find.byKey(const Key('homeClipboardToolbar')), findsNothing);
    expect(projects.projects.any((p) => p.id == project.id), isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
