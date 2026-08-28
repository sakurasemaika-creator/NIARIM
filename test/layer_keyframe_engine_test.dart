import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_keyframe_engine.dart';
import 'package:niarim/models/layer_keyframe.dart';

/// レイヤー単位のキーフレーム補間（LayerKeyframeEngine）の単体テスト。
/// Task#137で追加したイージング（layer_keyframe.dartのLayerKeyframeEasing）
/// を中心に検証する。等速（linear）の基本挙動自体は以前から実装済み
/// だったが、テストが無かったため合わせて整備した。
void main() {
  final engine = LayerKeyframeEngine();

  group('valueAt（等速・従来の挙動）', () {
    test('キーフレームが無い場合は無変形（x=0,y=0,scale=1,rotation=0）', () {
      final v = engine.valueAt(const [], 5);
      expect(v.x, 0);
      expect(v.y, 0);
      expect(v.scale, 1.0);
      expect(v.rotation, 0);
    });

    test('先頭より前・末尾より後はクランプする', () {
      final keyframes = [
        const LayerKeyframe(frameIndex: 10, x: 100),
        const LayerKeyframe(frameIndex: 20, x: 200),
      ];
      expect(engine.valueAt(keyframes, 0).x, 100);
      expect(engine.valueAt(keyframes, 999).x, 200);
    });

    test('linearでは区間の中間点で単純な線形補間になる', () {
      final keyframes = [
        const LayerKeyframe(frameIndex: 0, x: 0),
        const LayerKeyframe(frameIndex: 10, x: 100),
      ];
      expect(engine.valueAt(keyframes, 5).x, closeTo(50, 0.001));
      expect(engine.valueAt(keyframes, 2).x, closeTo(20, 0.001));
    });
  });

  group('valueAt（イージング、Task#137）', () {
    test('easeInは区間前半で線形補間より遅れて進む（値が小さい）', () {
      final keyframes = [
        const LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.easeIn),
        const LayerKeyframe(frameIndex: 100, x: 100),
      ];
      // t=0.25時点：linearなら25、easeIn（t*t）なら6.25。
      final x = engine.valueAt(keyframes, 25).x;
      expect(x, lessThan(25));
      expect(x, closeTo(6.25, 0.5));
    });

    test('easeOutは区間前半で線形補間より先行して進む（値が大きい）', () {
      final keyframes = [
        const LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.easeOut),
        const LayerKeyframe(frameIndex: 100, x: 100),
      ];
      // t=0.25時点：linearなら25、easeOut（1-(1-t)^2）なら43.75。
      final x = engine.valueAt(keyframes, 25).x;
      expect(x, greaterThan(25));
      expect(x, closeTo(43.75, 0.5));
    });

    test('easeInOutは中間点(t=0.5)でlinearと一致し、前半は遅れ・後半は追いつく', () {
      final keyframes = [
        const LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.easeInOut),
        const LayerKeyframe(frameIndex: 100, x: 100),
      ];
      expect(engine.valueAt(keyframes, 50).x, closeTo(50, 0.5));
      expect(engine.valueAt(keyframes, 25).x, lessThan(25));
      expect(engine.valueAt(keyframes, 75).x, greaterThan(75));
    });

    test('bounceOutは開始・終了の値そのものは変えず、途中経過だけを変える', () {
      final keyframes = [
        const LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.bounceOut),
        const LayerKeyframe(frameIndex: 100, x: 100),
      ];
      expect(engine.valueAt(keyframes, 0).x, closeTo(0, 0.001));
      expect(engine.valueAt(keyframes, 100).x, closeTo(100, 0.001));
      // 弾む動きのため、単調増加ではない区間が存在する
      // （t方向に進んでも値が一時的に減る箇所がある）ことを確認する。
      final samples = List.generate(101, (f) => engine.valueAt(keyframes, f).x);
      final hasDecrease = List.generate(
        samples.length - 1,
        (i) => samples[i + 1] < samples[i] - 0.01,
      ).any((e) => e);
      expect(hasDecrease, isTrue, reason: 'bounceOutは途中で値が揺れ戻るはず');
    });

    test('イージングは区間の開始側（a）のキーフレームの設定が使われる', () {
      // aがeaseIn、bがlinearでも意味を持たない（bは終端キーフレームで
      // 「次への」つなぎ方は使われないため）: a側の設定のみが効く。
      final keyframes = [
        const LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.easeIn),
        const LayerKeyframe(frameIndex: 100, x: 100, easing: LayerKeyframeEasing.bounceOut),
      ];
      final x = engine.valueAt(keyframes, 25).x;
      expect(x, closeTo(6.25, 0.5), reason: 'aのeaseInが使われ、bのbounceOutは無視されるはず');
    });

    test('未指定（デフォルト）はlinear扱い', () {
      const kf = LayerKeyframe(frameIndex: 0);
      expect(kf.easing, LayerKeyframeEasing.linear);
    });
  });

  group('LayerKeyframe.toJson/fromJson（Task#137：easingの永続化）', () {
    test('easingがJSONへ保存され、復元される', () {
      const kf = LayerKeyframe(frameIndex: 3, x: 1, easing: LayerKeyframeEasing.bounceOut);
      final json = kf.toJson();
      expect(json['easing'], 'bounceOut');
      final restored = LayerKeyframe.fromJson(json);
      expect(restored.easing, LayerKeyframeEasing.bounceOut);
    });

    test('easingキーが無い古い保存データはlinearとして復元される（後方互換）', () {
      final json = {'frameIndex': 0, 'x': 10.0, 'y': 0.0, 'scale': 1.0, 'rotation': 0.0};
      final restored = LayerKeyframe.fromJson(json);
      expect(restored.easing, LayerKeyframeEasing.linear);
    });
  });
}
