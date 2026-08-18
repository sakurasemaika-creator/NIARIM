import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/bucket_fill_engine.dart';

/// バケツ塗り詳細設定（拡張px・線の下まで潜る）のテスト。
/// 仕様：ユーザー要望「何px侵食するか」「線の下まで潜るようにするか」。
void main() {
  group('BucketFillEngine', () {
    // 横1列(width x 1)の単純なキャンバスを組み立てるヘルパー。
    // pixels: 各要素が[r,g,b,a]の4要素リスト。
    Uint8List buildRow(List<List<int>> pixels) {
      final data = Uint8List(pixels.length * 4);
      for (int i = 0; i < pixels.length; i++) {
        data[i * 4] = pixels[i][0];
        data[i * 4 + 1] = pixels[i][1];
        data[i * 4 + 2] = pixels[i][2];
        data[i * 4 + 3] = pixels[i][3];
      }
      return data;
    }

    const fillColor = ui.Color.fromARGB(255, 0, 255, 0); // 緑

    test('拡張px=0（従来通り）：許容誤差外の境界は塗られない', () {
      // white, white, black(opaque) の3px。境界の黒は塗られないはず。
      final data = buildRow([
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 255],
      ]);
      final result = BucketFillEngine().fill(
        canvasData: data,
        width: 3,
        height: 1,
        startX: 0,
        startY: 0,
        fillColor: fillColor,
      );
      expect(result.sublist(0, 4), [0, 255, 0, 255]);
      expect(result.sublist(4, 8), [0, 255, 0, 255]);
      // 境界の黒(不透明)は拡張なしなら変化しない
      expect(result.sublist(8, 12), [0, 0, 0, 255]);
    });

    test('拡張px>0・線の下まで潜らない：境界の外側をベタで上書きする', () {
      final data = buildRow([
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 255], // 不透明な線
        [0, 0, 0, 128], // 半透明の線
        [255, 255, 255, 255], // 線の外側（拡張2pxなら届く）
      ]);
      final result = BucketFillEngine().fill(
        canvasData: data,
        width: 5,
        height: 1,
        startX: 0,
        startY: 0,
        fillColor: fillColor,
        expandPx: 2,
        fillUnderLine: false,
      );
      // 拡張分（不透明の線・半透明の線ともに）はベタで塗り色に上書きされる
      expect(result.sublist(8, 12), [0, 255, 0, 255]);
      expect(result.sublist(12, 16), [0, 255, 0, 255]);
      // 拡張2pxを超えた先の白ピクセルは変化しない
      expect(result.sublist(16, 20), [255, 255, 255, 255]);
    });

    test('線の下まで潜る：不透明な線は見た目を保ったまま変化しない', () {
      final data = buildRow([
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 255], // 完全不透明の線
      ]);
      final result = BucketFillEngine().fill(
        canvasData: data,
        width: 3,
        height: 1,
        startX: 0,
        startY: 0,
        fillColor: fillColor,
        expandPx: 1,
        fillUnderLine: true,
      );
      // 不透明ピクセルの下に塗り色を回り込ませても、上に乗っている
      // 不透明な線の見た目は変わらない（src-over: 既存 over 塗り色）。
      expect(result.sublist(8, 12), [0, 0, 0, 255]);
    });

    test('線の下まで潜る：半透明の線は塗り色が透けて隙間が埋まる', () {
      final data = buildRow([
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 128], // 半透明の線（アンチエイリアス境界を想定）
      ]);
      final result = BucketFillEngine().fill(
        canvasData: data,
        width: 3,
        height: 1,
        startX: 0,
        startY: 0,
        fillColor: fillColor,
        expandPx: 1,
        fillUnderLine: true,
      );
      final r = result[8], g = result[9], b = result[10], a = result[11];
      // ベタ上書き（緑そのもの）でも、元の半透明黒のままでもない＝
      // 背後に塗り色が回り込んで合成された状態になっている。
      expect(g, greaterThan(0));
      expect(g, lessThan(255));
      expect(b, 0);
      expect(r, 0);
      // 透明度（隙間）は塗り色の分だけ埋まり、元より不透明になる
      expect(a, greaterThan(128));
    });

    test('selectionMaskがある場合、拡張分もマスク外へは広がらない', () {
      final data = buildRow([
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 255],
      ]);
      final mask = Uint8List.fromList([1, 1, 0]); // 3px目は選択範囲外
      final result = BucketFillEngine().fill(
        canvasData: data,
        width: 3,
        height: 1,
        startX: 0,
        startY: 0,
        fillColor: fillColor,
        selectionMask: mask,
        expandPx: 3,
        fillUnderLine: false,
      );
      // 選択範囲外の3px目は拡張があっても変化しない
      expect(result.sublist(8, 12), [0, 0, 0, 255]);
    });
  });
}
