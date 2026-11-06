import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

Project _project({
  int exportWidth = 1920,
  int exportHeight = 1080,
  double drawingAreaScale = 1.0,
}) {
  final now = DateTime(2026, 1, 1);
  return Project(
    id: 'p',
    name: 'p',
    fps: 12,
    durationSeconds: 5,
    backgroundColor: 0xFFFFFFFF,
    createdAt: now,
    updatedAt: now,
    totalWorkSeconds: 0,
    exportWidth: exportWidth,
    exportHeight: exportHeight,
    drawingAreaScale: drawingAreaScale,
  );
}

/// widgetLocal（ズーム・パン適用後、_transformControllerの逆行列を通した
/// 後のウィジェット内座標）をプロジェクトのピクセル座標へ変換する。
/// _CanvasAreaState._widgetLocalToCanvasPixelと同じ計算式
/// （タスク#141の重大バグ修正で追加したロジック）をテスト用に再現する。
Offset _toCanvasPixel(Offset widgetLocal, Size size, Project? project) {
  final rect = canvasDrawingRectFor(size, project);
  final canvas = canvasPixelSizeOf(project);
  return Offset(
    (widgetLocal.dx - rect.left) * canvas.width / rect.width,
    (widgetLocal.dy - rect.top) * canvas.height / rect.height,
  );
}

void main() {
  group('canvasDrawingRectFor（タスク#141：タップ位置と描画位置がずれる重大バグの修正）', () {
    test('ウィジェットとプロジェクトのアスペクト比が一致する場合はフルサイズ', () {
      final project = _project(exportWidth: 1920, exportHeight: 1080);
      const size = Size(960, 540); // 16:9、プロジェクトと同じ比率
      final rect = canvasDrawingRectFor(size, project);
      expect(rect, const Rect.fromLTWH(0, 0, 960, 540));
    });

    test('ウィジェットが横長すぎる場合は左右にレターボックスが入り中央揃えになる', () {
      // 縦長プロジェクト（9:16）を横長ウィジェット（16:9相当）に表示するケース。
      final project = _project(exportWidth: 1080, exportHeight: 1920);
      const size = Size(800, 450);
      final rect = canvasDrawingRectFor(size, project);
      // 高さいっぱい(450)を基準に、幅は 450 * (1080/1920) = 253.125
      expect(rect.height, closeTo(450, 0.001));
      expect(rect.width, closeTo(253.125, 0.001));
      // 中央揃え：左右の余白が均等
      expect(rect.left, closeTo((800 - rect.width) / 2, 0.001));
      expect(rect.top, closeTo(0, 0.001));
    });

    test('ウィジェットが縦長すぎる場合は上下にレターボックスが入り中央揃えになる', () {
      final project = _project(exportWidth: 1920, exportHeight: 1080);
      const size = Size(400, 800);
      final rect = canvasDrawingRectFor(size, project);
      // 幅いっぱい(400)を基準に、高さは 400 * (1080/1920) = 225
      expect(rect.width, closeTo(400, 0.001));
      expect(rect.height, closeTo(225, 0.001));
      expect(rect.top, closeTo((800 - rect.height) / 2, 0.001));
      expect(rect.left, closeTo(0, 0.001));
    });

    test('拡張表示範囲ONでも描画範囲をアスペクト比フィットさせる', () {
      // 拡張ONのときにウィジェット全体へ引き伸ばすと、（1）描画範囲の縦横比と
      // ウィジェットの縦横比が違えば画が歪み、（2）座標変換が書き出しサイズ
      // 基準のままだったためタップ位置がdrawingAreaScale倍ずれていた。
      // 描画範囲（書き出し×倍率）は書き出しと同じ縦横比なので、結果として
      // 拡張OFFのときと同じ矩形になるのが正しい。
      final project = _project(
        exportWidth: 1920,
        exportHeight: 1080,
        drawingAreaScale: 1.5,
      );
      const size = Size(500, 300);
      final rect = canvasDrawingRectFor(size, project);
      // 16:9を500x300へフィット → 幅500・高さ281.25、上下中央揃え。
      expect(rect.width, closeTo(500, 0.001));
      expect(rect.height, closeTo(281.25, 0.001));
      expect(rect.top, closeTo((300 - rect.height) / 2, 0.001));
      expect(
        rect,
        canvasDrawingRectFor(size, _project()),
        reason: '倍率が変わっても表示矩形そのものは変わらない（中身の解像度が上がるだけ）',
      );
    });

    test('拡張表示範囲ONでは、キャンバス座標系が描画範囲サイズになる', () {
      final project = _project(
        exportWidth: 320,
        exportHeight: 320,
        drawingAreaScale: 2.0,
      );
      expect(canvasPixelSizeOf(project), const Size(640, 640));

      const size = Size(400, 800);
      final rect = canvasDrawingRectFor(size, project);
      // 描画矩形の中心をタップ → 描画範囲の中心(320,320)になること。
      // ここが書き出しサイズ基準（=160,160）だと、タップ位置と実際に描かれる
      // 位置がdrawingAreaScale倍ずれる（実際にそうなっていた）。
      final center = _toCanvasPixel(rect.center, size, project);
      expect(center.dx, closeTo(320, 0.01));
      expect(center.dy, closeTo(320, 0.01));
      // 右下は(640,640)。
      final br = _toCanvasPixel(rect.bottomRight, size, project);
      expect(br.dx, closeTo(640, 0.01));
      expect(br.dy, closeTo(640, 0.01));
    });

    test('書き出し範囲の警告枠は、描画矩形の中央1/倍率', () {
      final project = _project(
        exportWidth: 320,
        exportHeight: 320,
        drawingAreaScale: 2.0,
      );
      const size = Size(400, 800);
      final rect = canvasDrawingRectFor(size, project);
      final export = exportWarningRectFor(rect, project);
      expect(export.width, closeTo(rect.width / 2, 0.001));
      expect(export.height, closeTo(rect.height / 2, 0.001));
      expect(export.center, rect.center);
      // 拡張OFFなら描画矩形そのもの。
      expect(exportWarningRectFor(rect, _project()), rect);
    });

    test('プロジェクト未指定時はデフォルト1920x1080として扱う', () {
      const size = Size(960, 540);
      final rect = canvasDrawingRectFor(size, null);
      expect(rect, const Rect.fromLTWH(0, 0, 960, 540));
    });
  });

  group('ウィジェット座標→プロジェクトピクセル座標変換（タスク#141）', () {
    test('レターボックス無しなら中心タップは中心ピクセルに一致する', () {
      final project = _project(exportWidth: 1920, exportHeight: 1080);
      const size = Size(960, 540);
      final canvasPos = _toCanvasPixel(const Offset(480, 270), size, project);
      expect(canvasPos.dx, closeTo(960, 0.001));
      expect(canvasPos.dy, closeTo(540, 0.001));
    });

    test('レターボックスがある場合、余白部分のタップも正しい方向へ外挿される', () {
      // 縦長プロジェクトを横長ウィジェットに表示。左右に余白が出る。
      final project = _project(exportWidth: 1080, exportHeight: 1920);
      const size = Size(800, 450);
      final rect = canvasDrawingRectFor(size, project);
      // 描画矩形の左上をタップ→プロジェクトピクセル座標の(0,0)になるはず。
      final topLeft = _toCanvasPixel(rect.topLeft, size, project);
      expect(topLeft.dx, closeTo(0, 0.01));
      expect(topLeft.dy, closeTo(0, 0.01));
      // 描画矩形の右下をタップ→プロジェクトピクセル座標の(1080,1920)になるはず。
      final bottomRight = _toCanvasPixel(rect.bottomRight, size, project);
      expect(bottomRight.dx, closeTo(1080, 0.01));
      expect(bottomRight.dy, closeTo(1920, 0.01));
    });

    test('修正前の実装（矩形変換を行わない）ではズレが生じることを確認する', () {
      // 【回帰確認用】以前の_canvasPositionは単にscreenPosをそのまま
      // 返していた（ズーム・パンの逆行列適用のみ）。レターボックスがある
      // 場合、そのままの値はプロジェクトピクセル座標として誤りであり、
      // 本来の正しい値（_toCanvasPixel）とは異なることを示す。
      final project = _project(exportWidth: 1080, exportHeight: 1920);
      const size = Size(800, 450);
      const tapPoint = Offset(400, 225); // ウィジェット中心
      final buggyResult = tapPoint; // 旧実装：変換なし
      final fixedResult = _toCanvasPixel(tapPoint, size, project);
      expect(fixedResult, isNot(equals(buggyResult)));
      // 正しい変換ではウィジェット中心はプロジェクトの中心に一致するはず。
      expect(fixedResult.dx, closeTo(540, 0.01));
      expect(fixedResult.dy, closeTo(960, 0.01));
    });
  });
}
