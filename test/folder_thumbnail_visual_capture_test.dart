import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/folder_thumbnail.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture folder thumbnails and all four selector modes on phone and desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final temp = Directory.systemTemp.createTempSync('niarim_folder_visual_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Future<String> thumbnail(String name, Color color) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 180),
          Paint()..color = color);
      canvas.drawCircle(const Offset(158, 78), 53,
          Paint()..color = const Color(0xFFEFF4FF));
      canvas.drawRect(const Rect.fromLTWH(18, 135, 284, 22),
          Paint()..color = const Color(0x9935485E));
      final picture = recorder.endRecording();
      final image = await picture.toImage(320, 180);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final file = File('${temp.path}/$name.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      return file.path;
    }

    final pictures = <String>[];
    for (final (name, color) in [
      ('pink', const Color(0xFFE792AD)),
      ('blue', const Color(0xFF7594DA)),
      ('green', const Color(0xFF78BCAA)),
      ('gold', const Color(0xFFEAB76D)),
      ('violet', const Color(0xFFB18BD7)),
    ]) {
      pictures.add((await tester.runAsync(() => thumbnail(name, color)))!);
    }
    final works = List.generate(36, (i) => FolderThumbnailChoice(
      id: 'work_$i',
      name: i == 0 ? '第1話 ラフ' : i == 1 ? '第2話 色塗り' : '作品 ${i + 1}',
      imagePath: pictures[i % pictures.length],
      updatedAt: DateTime.utc(2026, 11, 11)
          .subtract(Duration(hours: i)),
    ));
    final folder = ProjectFolder(
      id: 'folder_visual',
      name: 'オリジナルアニメ',
      thumbnailImagePath: pictures[4],
    );
    final boundaryKey = GlobalKey();
    final applied = <String>[];

    await loadAppFonts(tester);
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          appBar: AppBar(title: const Text('作品をつくる')),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('プロジェクト', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                SizedBox(height: 180, child: Row(children: [
                  Expanded(child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      Expanded(child: FolderThumbnail(
                        folder: folder, choices: works,
                      )),
                      const Padding(padding: EdgeInsets.all(5),
                          child: Text('オリジナルアニメ')),
                    ]),
                  )),
                  Expanded(child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      Expanded(child: Image.file(File(pictures[0]),
                          fit: BoxFit.cover)),
                      const Padding(padding: EdgeInsets.all(5),
                          child: Text('第1話 ラフ')),
                    ]),
                  )),
                ])),
                const SizedBox(height: 18),
                Builder(builder: (context) => FilledButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('サムネイル変更'),
                  onPressed: () => showFolderThumbnailDialog(
                    context, folder: folder, choices: works,
                    onSave: ({required mode, sourceId, imagePath}) async {
                      applied.add('$mode:$sourceId');
                    },
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1)))!;
      final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png)))!;
      image.dispose();
      final dir = Directory('build/save-slot-visual-audit')
        ..createSync(recursive: true);
      await tester.runAsync(() async =>
          File('${dir.path}/$name.png')
              .writeAsBytes(bytes.buffer.asUint8List()));
    }

    await capture('folder_01_folder_and_work_same_tile_size');
    await tester.tap(find.text('サムネイル変更'));
    await tester.pumpAndSettle();
    await capture('folder_02_radio_order_default');
    await tester.tap(find.byKey(const Key('folderCoverItem')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folderCoverWorkGrid')), findsOneWidget);
    await capture('folder_03_work_thumbnail_tiles');
    await tester.tap(find.byKey(const Key('folderCoverSelect_work_1')));
    await tester.pumpAndSettle();
    await capture('folder_04_selected_work_thumbnail');
    await tester.drag(find.byKey(const Key('folderCoverWorkGrid')),
        const Offset(0, -265));
    await tester.pumpAndSettle();
    await capture('folder_05_large_work_grid_scrolled');
    await tester.tap(find.byKey(const Key('folderCoverCustom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folderCoverChooseImage')), findsOneWidget);
    await capture('folder_06_custom_image_preview');
    await tester.tap(find.byKey(const Key('folderCoverNone')));
    await tester.pumpAndSettle();
    await capture('folder_07_disable_thumbnail_last');
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(applied, isEmpty);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    await tester.tap(find.text('サムネイル変更'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folderCoverItem')));
    await tester.pumpAndSettle();
    await capture('folder_08_desktop_work_picker');
  });
}
