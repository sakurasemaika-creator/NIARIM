import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/mesh_warp_engine.dart';

/// レイヤー全体の自由変形・メッシュ変形（MeshWarpEngine）のテスト。
void main() {
  Future<ui.Color> pixelAt(ui.Image image, int x, int y, int width) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final idx = (y * width + x) * 4;
    final bytes = byteData!.buffer.asUint8List();
    return ui.Color.fromARGB(
      bytes[idx + 3],
      bytes[idx],
      bytes[idx + 1],
      bytes[idx + 2],
    );
  }

  /// 4象限をそれぞれ別の不透明な色で塗った4x4画像（左上=赤・右上=緑・
  /// 左下=青・右下=白の2x2ブロック、各ブロック2x2px）を作る。
  Future<ui.Image> buildQuadrantImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 2, 2),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(2, 0, 2, 2),
      ui.Paint()..color = const ui.Color(0xFF00FF00),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 2, 2, 2),
      ui.Paint()..color = const ui.Color(0xFF0000FF),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(2, 2, 2, 2),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    final picture = recorder.endRecording();
    return picture.toImage(4, 4);
  }

  group('MeshWarpEngine.regularGrid', () {
    test('1x1分割は4隅のみを返す', () {
      final points = MeshWarpEngine.regularGrid(
        1,
        1,
        const ui.Rect.fromLTWH(0, 0, 100, 200),
      );
      expect(points, [
        const ui.Offset(0, 0),
        const ui.Offset(100, 0),
        const ui.Offset(0, 200),
        const ui.Offset(100, 200),
      ]);
    });

    test('2x2分割は9点（3x3格子）を行優先で返す', () {
      final points = MeshWarpEngine.regularGrid(
        2,
        2,
        const ui.Rect.fromLTWH(0, 0, 4, 4),
      );
      expect(points.length, 9);
      // 中心点（行1・列1）はキャンバス中心(2,2)にあるはず
      expect(points[4], const ui.Offset(2, 2));
    });
  });

  group('MeshWarpEngine.buildVertices', () {
    test('rows×cols分割でも例外を投げずVerticesを構築できる', () async {
      const rows = 3, cols = 2;
      final image = await buildQuadrantImage();
      final points = MeshWarpEngine.regularGrid(
        rows,
        cols,
        const ui.Rect.fromLTWH(0, 0, 4, 4),
      );
      final vertices = MeshWarpEngine.buildVertices(
        image: image,
        rows: rows,
        cols: cols,
        controlPoints: points,
      );
      expect(vertices, isNotNull);
    });
  });

  group('MeshWarpEngine.warp', () {
    test(
      'perspective keeps a line straight across the former diagonal seam',
      () async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawRect(
          const ui.Rect.fromLTWH(31, 0, 3, 64),
          ui.Paint()..color = const ui.Color(0xFF000000),
        );
        final picture = recorder.endRecording();
        final source = await picture.toImage(64, 64);
        picture.dispose();
        final result = await MeshWarpEngine.warp(
          image: source,
          rows: 1,
          cols: 1,
          controlPoints: const [
            ui.Offset(0, 0),
            ui.Offset(64, 0),
            ui.Offset(0, 64),
            ui.Offset(40, 64),
          ],
          outputWidth: 64,
          outputHeight: 64,
        );
        for (final (x, y) in [(29, 16), (26, 32), (23, 48)]) {
          expect(
            (await pixelAt(result, x, y, 64)).a,
            greaterThan(0.6),
            reason: 'perspective line at ($x, $y)',
          );
        }
        expect((await pixelAt(result, 20, 32, 64)).a, 0);
        result.dispose();
        source.dispose();
      },
    );

    test('制御点が規則格子と同じ（恒等変形）場合、元画像と同じ結果になる', () async {
      final image = await buildQuadrantImage();
      final points = MeshWarpEngine.regularGrid(
        1,
        1,
        const ui.Rect.fromLTWH(0, 0, 4, 4),
      );
      final result = await MeshWarpEngine.warp(
        image: image,
        rows: 1,
        cols: 1,
        controlPoints: points,
        outputWidth: 4,
        outputHeight: 4,
      );
      expect(result.width, 4);
      expect(result.height, 4);
      expect(
        await pixelAt(result, 0, 0, 4),
        const ui.Color(0xFFFF0000),
      ); // 左上=赤
      expect(
        await pixelAt(result, 3, 0, 4),
        const ui.Color(0xFF00FF00),
      ); // 右上=緑
      expect(
        await pixelAt(result, 0, 3, 4),
        const ui.Color(0xFF0000FF),
      ); // 左下=青
      expect(
        await pixelAt(result, 3, 3, 4),
        const ui.Color(0xFFFFFFFF),
      ); // 右下=白
    });

    test('制御点を2倍に拡大すると、出力画像も2倍に拡大された内容になる', () async {
      final image = await buildQuadrantImage();
      // 4隅を(0,0)-(8,8)へ拡大（左上を基準に2倍）。
      final points = [
        const ui.Offset(0, 0),
        const ui.Offset(8, 0),
        const ui.Offset(0, 8),
        const ui.Offset(8, 8),
      ];
      final result = await MeshWarpEngine.warp(
        image: image,
        rows: 1,
        cols: 1,
        controlPoints: points,
        outputWidth: 8,
        outputHeight: 8,
      );
      // 2倍に拡大されているため、出力の各象限（4x4px）が元画像の各象限の
      // 色で塗りつぶされているはず。
      expect(
        await pixelAt(result, 1, 1, 8),
        const ui.Color(0xFFFF0000),
      ); // 左上=赤
      expect(
        await pixelAt(result, 6, 1, 8),
        const ui.Color(0xFF00FF00),
      ); // 右上=緑
      expect(
        await pixelAt(result, 1, 6, 8),
        const ui.Color(0xFF0000FF),
      ); // 左下=青
      expect(
        await pixelAt(result, 6, 6, 8),
        const ui.Color(0xFFFFFFFF),
      ); // 右下=白
    });
  });
}
