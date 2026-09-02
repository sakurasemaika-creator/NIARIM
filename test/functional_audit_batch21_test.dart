import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('実PNG書き出し→再デコードで寸法・透明度・全RGBAが一致する', () async {
    final temp = Directory.systemTemp.createTempSync('niarim_export_audit_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    final projects = ProjectService();
    await projects.init();
    final project = await projects.createProject(
      name: 'export-functional',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0x00000000,
      exportWidth: 32,
      exportHeight: 24,
    );
    final scene = projects.scenesOf(project.id).first;
    final layer = projects.layersOf(project.id, scene.id, 0).first;
    final key = projects.tileKeyFor(project.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(project.id);

    final source = Uint8List(32 * 24 * 4);
    void put(int x, int y, int r, int g, int b, int a) {
      final i = (y * 32 + x) * 4;
      source[i] = r;
      source[i + 1] = g;
      source[i + 2] = b;
      source[i + 3] = a;
    }

    // 完全不透明・半透明・低alpha・色の異なる点を混在させる。
    put(2, 3, 255, 20, 30, 255);
    put(10, 8, 40, 220, 60, 128);
    put(20, 15, 30, 70, 240, 64);
    for (var y = 18; y < 22; y++) {
      for (var x = 24; x < 30; x++) {
        put(x, y, 180, 90, 210, (80 + (x - 24) * 20).clamp(0, 255));
      }
    }
    tm.replaceLayerPixels(key, source);

    final engine = ExportEngine();
    final outputPath = await engine.exportFrameImage(
      scenes: projects.scenesOf(project.id),
      tileManager: tm,
      sceneId: scene.id,
      frameIndex: 0,
      drawingWidth: 32,
      drawingHeight: 24,
      width: 32,
      height: 24,
      backgroundColor: 0x00000000,
      asJpeg: false,
    );

    final file = File(outputPath);
    expect(file.existsSync(), isTrue, reason: '実PNGファイルが作成されること');
    final decoded = img.decodePng(await file.readAsBytes());
    expect(decoded, isNotNull, reason: '生成PNGを再デコードできること');
    expect(decoded!.width, 32);
    expect(decoded.height, 24);

    final actual = Uint8List.fromList(
      decoded.getBytes(order: img.ChannelOrder.rgba),
    );
    expect(actual.length, source.length);

    // 透明背景への通常描画なので、PNG再デコード後もRGBAが完全一致する。
    // （PNGは可逆。色値やalphaがファイル化の段階で変化してはならない。）
    expect(actual, orderedEquals(source),
        reason: 'PNG書き出し→再デコード後も全RGBAが1byte単位で一致すること');

    // 特に半透明画素が勝手に不透明化・premultiplyされたままになっていないこと。
    int alphaAt(int x, int y) => actual[(y * 32 + x) * 4 + 3];
    expect(alphaAt(10, 8), 128);
    expect(alphaAt(20, 15), 64);
  });
}
