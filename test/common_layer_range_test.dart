import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/layer.dart';

void main() {
  group('trimCommonLayerRange（タスク#148：共通レイヤーのフレーム内削除）', () {
    test('範囲が1フレームのみの場合はnull（＝レイヤー自体を削除すべき）', () {
      expect(
        trimCommonLayerRange(start: 3, end: 3, frameIndex: 3),
        isNull,
      );
    });

    test('先頭フレームで削除すると開始位置が1つ後ろへ縮む', () {
      final r = trimCommonLayerRange(start: 2, end: 8, frameIndex: 2);
      expect(r, (start: 3, end: 8));
    });

    test('末尾フレームで削除すると終了位置が1つ手前へ縮む', () {
      final r = trimCommonLayerRange(start: 2, end: 8, frameIndex: 8);
      expect(r, (start: 2, end: 7));
    });

    test('範囲の途中のフレームでkeepBefore未指定ならnull（ユーザーに選ばせる必要がある）', () {
      expect(
        trimCommonLayerRange(start: 2, end: 8, frameIndex: 5),
        isNull,
      );
    });

    test('範囲の途中でkeepBefore:trueなら、そのフレームより前だけが残る', () {
      final r = trimCommonLayerRange(
        start: 2, end: 8, frameIndex: 5, keepBefore: true,
      );
      expect(r, (start: 2, end: 4));
    });

    test('範囲の途中でkeepBefore:falseなら、そのフレームより後だけが残る', () {
      final r = trimCommonLayerRange(
        start: 2, end: 8, frameIndex: 5, keepBefore: false,
      );
      expect(r, (start: 6, end: 8));
    });

    test('2フレームの範囲で先頭を削除すると1フレームだけの範囲になる', () {
      final r = trimCommonLayerRange(start: 4, end: 5, frameIndex: 4);
      expect(r, (start: 5, end: 5));
    });
  });
}
