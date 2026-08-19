import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/layer_keyframe.dart';

/// レイヤー単位の位置・拡大縮小・回転をキーフレーム間で補間し、合成時に
/// 適用するエンジン。CameraEngineと同じ補間方式だが、対象は画面全体では
/// なく個々のレイヤー1枚。レイヤーのピクセル内容自体は変更せず、
/// 合成（表示・書き出し）時の配置だけを変える非破壊な変形。
class LayerKeyframeEngine {
  /// [keyframes]から[frame]時点の値を補間する。キーフレームが無い場合は
  /// 変化なし（x=0,y=0,scale=1,rotation=0）を返す。キーフレームより前は
  /// 先頭、後ろは末尾の値でクランプする。
  LayerKeyframe valueAt(List<LayerKeyframe> keyframes, int frame) {
    if (keyframes.isEmpty) return const LayerKeyframe(frameIndex: 0);
    final sorted = [...keyframes]..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    if (frame <= sorted.first.frameIndex) return sorted.first;
    if (frame >= sorted.last.frameIndex) return sorted.last;
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (frame >= a.frameIndex && frame <= b.frameIndex) {
        final span = b.frameIndex - a.frameIndex;
        final t = span == 0 ? 0.0 : (frame - a.frameIndex) / span;
        return LayerKeyframe.lerp(a, b, t);
      }
    }
    return sorted.last;
  }

  /// キーフレームが実質的に無変形（誰も動かしていない）かどうか。呼び出し側が
  /// 変形の要不要を判定して余計なcanvas.save/restoreを避けるために使う。
  bool isIdentity(LayerKeyframe kf) => kf.x == 0 && kf.y == 0 && kf.scale == 1.0 && kf.rotation == 0;

  /// [width]x[height]の中心を基準にレイヤーの変形を[canvas]へ適用する。
  /// 呼び出し側は事前に`canvas.save()`し、描画後に`canvas.restore()`すること。
  void apply(ui.Canvas canvas, LayerKeyframe kf, double width, double height) {
    final cx = width / 2;
    final cy = height / 2;
    canvas.translate(cx + kf.x, cy + kf.y);
    canvas.rotate(kf.rotation * math.pi / 180.0);
    final scale = kf.scale == 0 ? 1.0 : kf.scale;
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);
  }
}
