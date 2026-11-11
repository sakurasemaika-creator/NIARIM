import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    c.drawRect(const Rect.fromLTWH(0, 0, 480, 270),
        Paint()..color = const Color(0xFF8BC5DE));
    c.drawCircle(const Offset(352, 76), 54,
        Paint()..color = const Color(0xFFFFDA76));
    c.drawRect(const Rect.fromLTWH(0, 195, 480, 75),
        Paint()..color = const Color(0xFF4B9A91));
    final picture = recorder.endRecording();
    final image = await picture.toImage(480, 270);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final exportedImage = File(temp.path + '/sample_export.png');
    await exportedImage.writeAsBytes(data!.buffer.asUint8List());

    await loadAppFonts(tester);
    final service = ProjectService();
    await tester.runAsync(service.init);
    addTearDown(service.dispose);
    final project = await tester.runAsync(() => service.createProject(
      name: '第1話 サンプルアニメ', fps: 12, durationSeconds: 2,
      backgroundColor: 0xFFE8F2FF,
      exportWidth: 480, exportHeight: 270,
    ));
    expect(project, isNotNull);
    final boundaryKey = GlobalKey();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final host = RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        locale: const Locale('ja'),
        theme: ThemeData(useMaterial3: true,
          fontFamily: 'HakkouMincho',
          fontFamilyFallback: const ['NotoSerifJP']),
        home: Scaffold(
          appBar: AppBar(title: const Text('作品をつくる')),
          body: ListView(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text('プロジェクト', style: TextStyle(fontSize: 21))),
            Card(
              child: ListTile(
                leading: const Icon(Icons.movie_creation_outlined),
                title: Text(project!.name),
                subtitle: const Text('12 fps ・ 480 × 270'),
                trailing: Builder(builder: (context) => IconButton(
                  key: const Key('projectCoverMenuFixture'),
                  tooltip: 'プロジェクトの操作',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => showMenu<String>(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      MediaQuery.sizeOf(context).width - 210, 110, 8, 0),
                    items: const [PopupMenuItem(
                      value: 'thumbnail',
                      child: Text('サムネイル変更'))],
                  ).then((choice) {
                    if (choice == 'thumbnail' && context.mounted) {
                      showProjectThumbnailDialog(context,
                        project: project, service: service);
                    }
                  }),
                )),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Text('書き出し済み作品', style: TextStyle(fontSize: 21))),
            ExportedWorkCard(
              name: 'sample_export.png',
              metadata: '2026/11/11 ・ PNG',
              icon: Icons.image_outlined,
              moveLabel: '移動', shareLabel: '共有', deleteLabel: '削除',
              originalMediaPath: exportedImage.path,
              onOpen: () {}, onMove: () {},
              onShare: () {}, onDelete: () {},
              onChangeThumbnail: () {
                showExportedWorkThumbnailDialog(
                  boundaryKey.currentContext!, file: exportedImage);
              },
            ),
          ]),
        ),
      ),
    );
    await tester.pumpWidget(host);
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 35)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: name);
      final boundary = boundaryKey.currentContext!.findRenderObject()!
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

    await capture('01_phone_cards');
    await tester.tap(find.byKey(const Key('projectCoverMenuFixture')));
    await tester.pumpAndSettle();
    await capture('02_phone_project_menu_fixture');
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pumpAndSettle();
    await capture('03_phone_project_latest');
    await tester.tap(find.byKey(const Key('projectThumbnailFrame')));
    await tester.pumpAndSettle();
    await capture('04_phone_project_frame');
    await tester.tap(find.byKey(const Key('projectThumbnailLastFrame')));
    await tester.pump();
    await capture('05_phone_project_last');
    await tester.tap(find.byKey(const Key('projectThumbnailCustom')));
    await tester.pumpAndSettle();
    await capture('06_phone_project_custom');
    await tester.tap(find.byKey(const Key('projectThumbnailNone')));
    await tester.pumpAndSettle();
    await capture('07_phone_project_none');
    await tester.tap(find.text('キャンセル').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
    await tester.pumpAndSettle();
    await capture('08_phone_export_menu');
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pumpAndSettle();
    await capture('09_phone_export_latest');
    await tester.tap(find.byKey(const Key('exportCoverFrame')));
    await tester.pumpAndSettle();
    await capture('10_phone_export_image_frame');
    await tester.tap(find.byKey(const Key('exportCoverCustom')));
    await tester.pumpAndSettle();
    await capture('11_phone_export_custom');
    await tester.tap(find.byKey(const Key('exportCoverNone')));
    await tester.pumpAndSettle();
    await capture('12_phone_export_none');
    await tester.tap(find.text('キャンセル').last);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    await capture('13_desktop_cards');
    await tester.tap(find.byKey(const Key('projectCoverMenuFixture')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('projectThumbnailFrame')));
    await tester.pumpAndSettle();
    await capture('14_desktop_project_frame');
    await tester.tap(find.text('キャンセル').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サムネイル変更').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exportCoverFrame')));
    await tester.pumpAndSettle();
    await capture('15_desktop_export_image_frame');
  });
}
