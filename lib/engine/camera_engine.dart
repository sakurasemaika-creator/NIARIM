import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/camera_keyframe.dart';

/// カメラのXY移動・拡大・回転をキーフレーム間で補間し、表示へ適用する
/// エンジン。カメラは表示のみを変更し、レイヤー自体の座標は
/// 変更しない。
class CameraEngine {
  /// [keyframes]から[frame]時点の値を補間する。キーフレームが無い場合は
  /// 変化なし（x=0,y=0,zoom=1,rotation=0）を返す。キーフレームより前は先頭、
  /// 後ろは末尾の値でクランプする。
  CameraKeyframe valueAt(List<CameraKeyframe> keyframes, int frame) {
    if (keyframes.isEmpty) return const CameraKeyframe(frameIndex: 0);
    final sorted = [...keyframes]
      ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    if (frame <= sorted.first.frameIndex) return sorted.first;
    if (frame >= sorted.last.frameIndex) return sorted.last;
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (frame >= a.frameIndex && frame <= b.frameIndex) {
        final span = b.frameIndex - a.frameIndex;
        final t = span == 0 ? 0.0 : (frame - a.frameIndex) / span;
        return CameraKeyframe.lerp(a, b, t);
      }
    }
    return sorted.last;
  }

  /// [width]x[height]の中心を基準にカメラ変換を[canvas]へ適用する。
  /// 呼び出し側は事前に`canvas.save()`し、描画後に`canvas.restore()`すること。
  /// [kf.rotation]は度数法（UI編集単位に合わせる）。
  void apply(ui.Canvas canvas, CameraKeyframe kf, double width, double height) {
    final cx = width / 2;
    final cy = height / 2;
    canvas.translate(cx, cy);
    canvas.rotate(kf.rotation * math.pi / 180.0);
    final zoom = kf.zoom == 0 ? 1.0 : kf.zoom;
    canvas.scale(zoom, zoom);
    canvas.translate(-cx - kf.x, -cy - kf.y);
  }
}
