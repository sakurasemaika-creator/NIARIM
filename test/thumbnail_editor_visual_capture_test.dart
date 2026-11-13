import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/exported_work_thumbnail_dialog.dart';
import 'package:niarim/screens/home/widgets/project_thumbnail_dialog.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  testWidgets('real Flutter screenshots of thumbnail options', (tester) async {
    print('CAPTURE_STAGE 00 begin');
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('niarim_thumb_capture_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.drawRect(
      const Rect.fromLTWH(0, 0, 480, 270),
      Paint()..color = const Color(0xFF8BC5DE),
    );
    c.drawCircle(
      const Offset(352, 76),
      54,
      Paint()..color = const Color(0xFFFFDA76),
    );
    c.drawRect(
      const Rect.fromLTWH(0, 195, 480, 75),
      Paint()..color = const Color(0xFF4B9A91),
    );
    final picture = recorder.endRecording();
    // Image encoding and disk I/O must escape the widget test fake clock.
    final exportedImage = File(temp.path + '/sample_export.png');
    await tester.runAsync(() async {
      final image = await picture.toImage(480, 270);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      await exportedImage.writeAsBytes(data!.buffer.asUint8List());
    });

    print('CAPTURE_STAGE 01 before fonts');
    await loadAppFonts(tester);
    print('CAPTURE_STAGE 02 fonts loaded');
    final service = ProjectService();
    print('CAPTURE_STAGE 03 before service init');
    await tester.runAsync(service.init);
    print('CAPTURE_STAGE 04 after service init');
    addTearDown(service.dispose);
    print('CAPTURE_STAGE 05 before project create');
    final project = await tester.runAsync(
      () => service.createProject(
        name: '第1話 サンプルアニメ',
        fps: 12,
        durationSeconds: 2,
        backgroundColor: 0xFFE8F2FF,
        exportWidth: 480,
        exportHeight: 270,
      ),
    );
    print('CAPTURE_STAGE 06 project created');
    expect(project, isNotNull);
    final boundaryKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final host = RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        navigatorKey: navKey,
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'HakkouMincho',
          fontFamilyFallback: const ['NotoSerifJP'],
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('作品をつくる')),
          body: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text('プロジェクト', style: TextStyle(fontSize: 21)),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.movie_creation_outlined),
                  title: Text(project!.name),
                  subtitle: const Text('12 fps ・ 480 × 270'),
                  trailing: Builder(
                    builder: (context) => IconButton(
                      key: const Key('projectCoverMenuFixture'),
                      tooltip: 'プロジェクトの操作',
                      icon: const Icon(Icons.more_vert),
                      onPressed: () =>
                          showMenu<String>(
                            context: context,
                            position: RelativeRect.fromLTRB(
                              MediaQuery.sizeOf(context).width - 210,
                              110,
                              8,
                              0,
                            ),
                            items: const [
                              PopupMenuItem(
                                value: 'thumbnail',
                                child: Text('サムネイル変更'),
                              ),
                            ],
                          ).then((choice) {
                            if (choice == 'thumbnail' && context.mounted) {
                              showProjectThumbnailDialog(
                                context,
                                project: project,
                                service: service,
                              );
                            }
                          }),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Text('書き出し済み作品', style: TextStyle(fontSize: 21)),
              ),
              ExportedWorkCard(
                name: 'sample_export.png',
                metadata: '2026/11/11 ・ PNG',
                icon: Icons.image_outlined,
                moveLabel: '移動',
                shareLabel: '共有',
                deleteLabel: '削除',
                originalMediaPath: exportedImage.path,
                onOpen: () {},
                onMove: () {},
                onShare: () {},
                onDelete: () {},
                onChangeThumbnail: () {
                  showExportedWorkThumbnailDialog(
                    navKey.currentContext!,
                    file: exportedImage,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    print('CAPTURE_STAGE 07 before pump host');
    await tester.pumpWidget(host);
    print('CAPTURE_STAGE 08 after pump host');
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> capture(String name) async {
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 35)),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: name);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        return data!.buffer.asUint8List();
      });
      final dir = Directory('build/thumbnail-editor-visual-audit')
        ..createSync(recursive: true);
      await tester.runAsync(() async {
        await File(dir.path + '/' + name + '.png')
            .writeAsBytes(png!, flush: true);
      });
    }

    print('CAPTURE_STAGE 09 before first screenshot');
    await capture('01_phone_cards');
    print('CAPTURE_STAGE 10 first screenshot saved');
    await tester.tap(find.byKey(const Key('projectCoverMenuFixture')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('02_phone_project_menu_fixture');
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pump(const Duration(milliseconds: 300));
    await capture('03_phone_project_latest');
    await tester.tap(find.byKey(const Key('projectThumbnailFrame')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('04_phone_project_frame');
    await tester.tap(find.byKey(const Key('projectThumbnailLastFrame')));
    await tester.pump();
    await capture('05_phone_project_last');
    await tester.tap(find.byKey(const Key('projectThumbnailCustom')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('06_phone_project_custom');
    await tester.tap(find.byKey(const Key('projectThumbnailNone')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('07_phone_project_none');
    await tester.tap(find.text('キャンセル').last);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('08_phone_export_menu');
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pump(const Duration(milliseconds: 300));
    await capture('09_phone_export_latest');
    await tester.tap(find.byKey(const Key('exportCoverFrame')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('10_phone_export_image_frame');
    await tester.tap(find.byKey(const Key('exportCoverCustom')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('11_phone_export_custom');
    await tester.tap(find.byKey(const Key('exportCoverNone')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('12_phone_export_none');
    await tester.tap(find.text('キャンセル').last);
    await tester.pump(const Duration(milliseconds: 300));

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pump(const Duration(milliseconds: 300));
    await capture('13_desktop_cards');
    // Phone captures already exercise the three-dot route. Open the same
    // production dialog directly on desktop to keep this evidence focused
    // on its responsive layout, not a popup-menu transition race.
    showProjectThumbnailDialog(
      tester.element(find.byKey(const Key('projectCoverMenuFixture'))),
      project: project,
      service: service,
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.byKey(const Key('projectThumbnailFrame')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('14_desktop_project_frame');
    await tester.tap(find.text('キャンセル').last);
    await tester.pump(const Duration(milliseconds: 300));
    showExportedWorkThumbnailDialog(
      tester.element(find.byKey(const Key('exportedWorkMoreMenu'))),
      file: exportedImage,
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.byKey(const Key('exportCoverFrame')));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('15_desktop_export_image_frame');
  });
}
