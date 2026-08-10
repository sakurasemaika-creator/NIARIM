import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/models/layer.dart';

Layer _layer(String id, {bool hasClipping = false, String? parentFolderId}) => Layer(
      id: id,
      name: id,
      type: LayerType.normal,
      hasClipping: hasClipping,
      parentFolderId: parentFolderId,
    );

void main() {
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
      final layers = [
        _layer('a', hasClipping: true),
      ];
      expect(findClipSourceLayerId(layers, 0), isNull);
    });
  });
}
