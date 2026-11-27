// 大きな作品も、保存した後に起動し直して開ける。
//
// 実際に使ってみたとき（2026-11-27）、絵の多い作品（1080×1080・3シーン・
// 55コマ）を保存してアプリを起動し直すと、ホームに「プロジェクトを読み込め
// ませんでした」と出て作品が一覧から消えた。作品のファイルの展開後の大きさが
// 288 MiBで、外から受け取るファイル（.niashare・.niatra）のための上限
// （256 MiB）を作品のファイルにも当てていた。保存には上限が無いので、保存は
// できるのに読めなかった（自動保存も同じ大きさで読めなかった）。
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/archive_security.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _size = TileManager.tileSize;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-large-work-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a work larger than a received archive may be is listed and opened '
      'after a restart', () async {
    final service = ProjectService();
    await service.init();
    final project = await service.createProject(
      name: '大きな作品',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 640,
      exportHeight: 360,
    );
    final scene = service.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.firstWhere(
      (l) => l.type == LayerType.normal,
    );
    final painted = Uint8List(_size * _size * 4)
      ..fillRange(0, _size * _size * 4, 200);
    service.tileManagerOf(project.id).importAll({
      frameLayerKey(scene.id, 0, layer.id): {'0,0': painted},
    });
    await service.saveProject(project.id);
    service.dispose();

    // The saved file grows past 256 MiB expanded, as a long work's pictures
    // do (here padding entries the reader skips, so the test keeps little in
    // memory; the size checks see every entry alike).
    final file = File(
      '${temp.path}/niarim/projects/${project.id}/${project.id}.niapro',
    );
    final saved = ZipDecoder().decodeBytes(file.readAsBytesSync());
    final grown = Archive();
    for (final entry in saved.files) {
      grown.addFile(entry);
    }
    final padding = Uint8List(_size * _size * 4);
    for (var i = 0; i < 1100; i++) {
      grown.addFile(
        ArchiveFile(
          'Tiles/${scene.id}/pad/pad_$i.bin',
          padding.length,
          padding,
        ),
      );
    }
    final bytes = ZipEncoder().encode(grown)!;
    file.writeAsBytesSync(bytes);
    expect(
      1100 * padding.length,
      greaterThan(ArchiveSecurity.maxExpandedBytes),
    );

    final next = ProjectService();
    await next.init();
    addTearDown(next.dispose);
    expect(next.projects.map((p) => p.id), contains(project.id));
    expect(next.projectsLoadFailed, isFalse);
    final tiles = next.tileManagerOf(project.id).exportAll();
    expect(next.tilesUnreadable(project.id), isFalse);
    expect(tiles[frameLayerKey(scene.id, 0, layer.id)]?['0,0'], painted);

    // A file received from outside keeps the limits (a ZIP bomb is refused).
    expect(
      () => ArchiveSecurity.decodeZip(bytes),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      NiaproSerializer.loadShare(file.path),
      throwsA(isA<FormatException>()),
    );
  });
}
