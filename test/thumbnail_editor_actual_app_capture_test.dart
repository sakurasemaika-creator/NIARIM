import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/home/widgets/project_thumbnail_dialog.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

class _CancelledFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;
}

/// Uses the production app root, router, HomeScreen, real project/menu
/// and real exported-work card. No imitation Scaffold, theme, card or menu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Production home thumbnail screens', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      'home.projectViewMode.v1': 'medium',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    FilePicker.platform = _CancelledFilePicker();
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    final temp = Directory.systemTemp.createTempSync('niarim_real_home_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProvider, (_) async => temp.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathProvider, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    appRouter.go('/home');

    final exported = await tester.runAsync(() async {
      final dir = await ExportEngine.exportsDir();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 480, 270),
          Paint()..color = const Color(0xFFF3E6F5));
      canvas.drawCircle(const Offset(240, 130), 83,
          Paint()..color = const Color(0xFF6B8CC8));
      canvas.drawCircle(const Offset(245, 120), 45,
          Paint()..color = const Color(0xFFFFCA89));
      final picture = recorder.endRecording();
      final img = await picture.toImage(480, 270);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      picture.dispose();
      final file = File(dir.path + '/sample_export.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      await ExportEngine.listExportedFiles(forceRefresh: true);
      return file;
    });
    expect(exported, isNotNull);
    final boundaryKey = GlobalKey();
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: MultiProvider(providers: providers!, child: const NiarimApp()),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(HomeScreen), findsOneWidget);
    final projects = tester.element(find.byType(HomeScreen))
        .read<ProjectService>();
    final created = await tester.runAsync(() => projects.createProject(
      name: '第1話 サンプルアニメ', fps: 12, durationSeconds: 2,
      backgroundColor: 0xFFE8F2FF, exportWidth: 480, exportHeight: 270,
    ));
    expect(created, isNotNull);
    await tester.pump(const Duration(milliseconds: 700));

    Future<void> capture(String name) async {
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        await tester.runAsync(() =>
            Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: name);
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        return bytes!.buffer.asUint8List();
      });
      final output = Directory('build/thumbnail-editor-actual-app')
        ..createSync(recursive: true);
      await tester.runAsync(() =>
        File(output.path + '/' + name + '.png').writeAsBytes(png!, flush: true));
      print('ACTUAL_APP_CAPTURE: ' + name);
    }

    Finder projectMenu() => find.descendant(
      of: find.byType(ProjectListWidget),
      matching: find.byWidgetPredicate((w) => w is PopupMenuButton<String>),
    ).hitTestable();
    Future<void> closeDialog() async {
      await tester.tap(find.text('キャンセル').last);
      await tester.pump(const Duration(milliseconds: 450));
    }
    Future<void> openProjectDialog() async {
      expect(projectMenu(), findsWidgets);
      await tester.tap(projectMenu().first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('サムネイル変更').last);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byKey(const Key('projectThumbnailLatest')), findsOneWidget);
    }

    await capture('01_phone_real_projects');
    await tester.tap(projectMenu().first);
    await tester.pump(const Duration(milliseconds: 350));
    await capture('02_phone_real_project_menu');
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pump(const Duration(milliseconds: 450));
    await capture('03_phone_project_last_saved');
    await tester.tap(find.byKey(const Key('projectThumbnailFrame')));
    await tester.pump(const Duration(milliseconds: 380));
    await capture('04_phone_project_select_frame');
    await tester.tap(find.byKey(const Key('projectThumbnailLastFrame')));
    await tester.pump(const Duration(milliseconds: 250));
    await capture('05_phone_project_frame_last');
    await tester.tap(find.byKey(const Key('projectThumbnailCustom')));
    await tester.pump(const Duration(milliseconds: 350));
    await capture('06_phone_project_load_image');
    await tester.tap(find.byKey(const Key('projectThumbnailNone')));
    await tester.pump(const Duration(milliseconds: 350));
    await capture('07_phone_project_hide');
    await closeDialog();

    final worksTab = find.byKey(const ValueKey('home_tab_1'));
    await tester.ensureVisible(worksTab);
    expect(worksTab, findsOneWidget);
    await tester.tap(worksTab);
    await tester.pump(const Duration(milliseconds: 750));
    print('DEBUG_WORKS_FILES: ' + (await tester.runAsync(() => ExportEngine.listExportedFiles(forceRefresh: true)))!.map((e) => e.path).join(', '));
    print('DEBUG_WORKS_MENU: ' + find.byKey(const Key('exportedWorkMoreMenu')).evaluate().length.toString());
    print('DEBUG_WORKS_PROJECT_VISIBLE: ' + find.byType(ProjectListWidget).evaluate().length.toString());
    await capture('08_phone_real_exported_works');
    expect(find.byKey(const Key('exportedWorkMoreMenu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
    await tester.pump(const Duration(milliseconds: 350));
    await capture('09_phone_real_export_menu');
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pump(const Duration(milliseconds: 450));
    await capture('10_phone_export_last_saved');
    await tester.tap(find.byKey(const Key('exportCoverFrame')));
    await tester.pump(const Duration(milliseconds: 350));
    await capture('11_phone_export_select_frame');
    await tester.tap(find.byKey(const Key('exportCoverCustom')));
    await tester.pump(const Duration(milliseconds: 350));
    await capture('12_phone_export_load_image');
    await tester.tap(find.byKey(const Key('exportCoverNone')));
    await tester.pump(const Duration(milliseconds: 350));
    await capture('13_phone_export_hide');
    await closeDialog();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pump(const Duration(milliseconds: 700));
    await capture('14_desktop_real_exported_works');
    await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
    await tester.pump(const Duration(milliseconds: 350));
    await capture('15_desktop_real_export_menu');
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.runAsync(() =>
        Future<void>.delayed(const Duration(milliseconds: 90)));
    await tester.pump();
    for (var attempt = 0;
        attempt < 4 &&
            find.byKey(const Key('exportCoverFramePanel')).evaluate().isEmpty;
        attempt++) {
      await tester.tap(find.byKey(const Key('exportCoverFrame')));
      await tester.pump(const Duration(milliseconds: 320));
      await tester.runAsync(() =>
          Future<void>.delayed(const Duration(milliseconds: 45)));
      await tester.pump();
    }
    expect(find.byKey(const Key('exportCoverFramePanel')), findsOneWidget);
    await capture('16_desktop_export_select_frame');
    await closeDialog();

    final projectTab = find.byKey(const ValueKey('home_tab_0'));
    await tester.ensureVisible(projectTab);
    expect(projectTab, findsOneWidget);
    await tester.tap(projectTab);
    await tester.pump(const Duration(milliseconds: 650));
    await capture('17_desktop_real_projects');
    await tester.tap(projectMenu().first);
    await tester.pump(const Duration(milliseconds: 500));
    await capture('18_desktop_real_project_menu');
    // The popup is genuine. Open the production dialog on the same actual
    // HomeScreen directly to avoid test-only desktop popup route hit races.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 500));
    showProjectThumbnailDialog(
      tester.element(find.byType(ProjectListWidget)),
      project: created!, service: projects,
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.byKey(const Key('projectThumbnailFrame')));
    await tester.pump(const Duration(milliseconds: 360));
    await capture('19_desktop_project_select_frame');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
