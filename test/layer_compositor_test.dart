import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';

Layer _layer(String id, {bool hasClipping = false, String? parentFolderId}) =>
    Layer(
      id: id,
      name: id,
      type: LayerType.normal,
      hasClipping: hasClipping,
      parentFolderId: parentFolderId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'nested folder visibility and opacity affect the composited pixels',
    () async {
      final manager = TileManager(canvasWidth: 1, canvasHeight: 1);
      addTearDown(manager.dispose);
      manager.replaceLayerPixels('paint', Uint8List.fromList([255, 0, 0, 255]));
      const top = Layer(
        id: 'top',
        name: 'top',
        type: LayerType.folder,
        opacity: 50,
      );
      const sub = Layer(
        id: 'sub',
        name: 'sub',
        type: LayerType.folder,
        parentFolderId: 'top',
        opacity: 50,
      );
      final paint = _layer('paint', parentFolderId: 'sub');
      Future<int> alpha(List<Layer> layers) async {
        final image = await LayerCompositor.composite(
          manager,
          layers,
          (layer) => layer.id,
          1,
          1,
        );
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.getUint8(3);
        } finally {
          image.dispose();
        }
      }

      expect(await alpha([top, sub, paint]), closeTo(64, 1));
      expect(await alpha([top.copyWith(isVisible: false), sub, paint]), 0);
    },
  );

  group('findClipSourceLayerId（仕様書16：クリッピング）', () {
    test('同一階層内では直下の非クリッピングレイヤーを返す', () {
      final layers = [
        _layer('a', hasClipping: true),
        _layer('b', hasClipping: true),
        _layer('c'),
      ];
      expect(findClipSourceLayerId(layers, 0), 'c');
    });

    test('フォルダを跨ぐクリッピングは禁止（フォルダ内→トップレベルへは辿らない）', () {
      final layers = [
        _layer('a', hasClipping: true, parentFolderId: 'folder1'),
        _layer('b', hasClipping: true, parentFolderId: 'folder1'),
        // ここでフォルダ境界（トップレベルへ復帰）
        _layer('c'),
      ];
      expect(findClipSourceLayerId(layers, 0), isNull);
    });

    test('別フォルダへも跨がない', () {
      final layers = [
        _layer('a', hasClipping: true, parentFolderId: 'folder1'),
        _layer('b', parentFolderId: 'folder2'),
      ];
      expect(findClipSourceLayerId(layers, 0), isNull);
    });

    test('フォルダ内で完結するクリッピングは正しく解決する', () {
      final layers = [
        _layer('a', hasClipping: true, parentFolderId: 'folder1'),
        _layer('b', hasClipping: true, parentFolderId: 'folder1'),
        _layer('c', parentFolderId: 'folder1'),
        _layer('d'),
      ];
      expect(findClipSourceLayerId(layers, 0), 'c');
    });

    test('クリッピング元が見つからない場合はnull', () {
      final layers = [_layer('a', hasClipping: true)];
      expect(findClipSourceLayerId(layers, 0), isNull);
    });
  });
}
