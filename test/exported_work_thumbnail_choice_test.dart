import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_codec;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/exported_work_thumbnail_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Export covers persist without modifying source file bytes', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('export_cover_test_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final original = File('${temp.path}/animation.png')
      ..writeAsBytesSync([1, 2, 3, 4]);
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
    await ExportedWorkCoverStore.write(
      original, mode: 'none');
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'none');
    expect(await ExportedWorkCoverStore.displayPath(original), isNull);
    expect(await original.readAsBytes(), [1, 2, 3, 4]);
    await ExportedWorkCoverStore.write(
      original, mode: 'latest');
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
    expect(await ExportedWorkCoverStore.displayPath(original), original.path);
    // An external overwrite must not retain an obsolete selected cover.
    original.writeAsBytesSync([1, 2, 3, 4, 5]);
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
  });

  test('Exported raster covers are downscaled, cached and deleted safely',
      () async {
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('cover_cache_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final source = image_codec.Image(width: 1000, height: 600);
    image_codec.fill(source, color: image_codec.ColorRgba8(16, 122, 188, 255));
    final originalBytes = image_codec.encodePng(source);
    final file = File('${temp.path}/original.png');
    await file.writeAsBytes(originalBytes, flush: true);

    final setting = await ExportedWorkCoverStore.ensureCached(file);
    expect(setting['mode'], 'latest');
    expect(setting['frameIndex'], 0);
    final path = setting['imagePath'] as String;
    expect(path, isNot(file.path));
    final cover = File(path);
    expect(await cover.exists(), isTrue);
    final rendered = image_codec.decodeImage(await cover.readAsBytes())!;
    expect(rendered.width, lessThanOrEqualTo(420));
    expect(rendered.height, lessThanOrEqualTo(420));
    expect(await file.readAsBytes(), originalBytes);
    await ExportedWorkCoverStore.write(file, mode: 'none');
    expect(await cover.exists(), isFalse);
    expect(await file.readAsBytes(), originalBytes);
  });

  testWidgets('Exported card exposes a three-dot thumbnail action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: Scaffold(body:
      ExportedWorkCard(
        name: 'movie.mp4',
        metadata: '2026/11/11',
        icon: Icons.movie,
        moveLabel: '移動',
        shareLabel: '共有',
        deleteLabel: '削除',
        onOpen: () {},
        onMove: () {},
        onShare: () {},
        onDelete: () {},
        onChangeThumbnail: () {},
      ),
    )));
    final menu = find.byKey(const Key('exportedWorkMoreMenu'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('サムネイル変更'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
