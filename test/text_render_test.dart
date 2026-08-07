import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:miranima/engine/text_render.dart';
import 'package:miranima/models/text_object.dart';

/// テキストラスタライズ（Task#63・#72での縦書き・半角英数字回転・縦中横・
/// ルビ対応、Task#75でのルビの横書き対応）が実際にクラッシュせず、期待する
/// サイズのバッファを返すことを検証する。実機での目視確認ができない開発
/// 環境のため、少なくとも「例外を投げない」「出力サイズが正しい」ことを
/// 機械的に確認する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TextObject baseText(String text, {
    TextWritingDirection direction = TextWritingDirection.horizontal,
    bool outline = false,
  }) =>
      TextObject(
        id: 't1',
        text: text,
        fontFamily: 'Roboto',
        fontSize: 24,
        color: const ui.Color(0xFF000000),
        isBold: false,
        isItalic: false,
        lineHeight: 1.2,
        letterSpacing: 0,
        direction: direction,
        align: ui.TextAlign.left,
        position: const ui.Offset(10, 10),
        rotation: 0,
        scale: 1,
        opacity: 1,
        outline: outline
            ? const TextOutline(enabled: true, color: ui.Color(0xFFFFFFFF), width: 2)
            : null,
      );

  const canvasWidth = 200;
  const canvasHeight = 200;
  const expectedBytes = canvasWidth * canvasHeight * 4;

  test('横書き・通常テキスト（ルビなし）', () async {
    final result = await rasterizeTextObject(baseText('こんにちは'), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('横書き・複数行（手動改行）', () async {
    final result = await rasterizeTextObject(baseText('1行目\n2行目\n3行目'), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('横書き・アウトライン付き', () async {
    final result =
        await rasterizeTextObject(baseText('アウトライン', outline: true), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('横書き・ルビ付き（Task#75で対応）', () async {
    final result =
        await rasterizeTextObject(baseText('{明日|あした}は{晴|は}れ'), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('横書き・ルビ付き複数行＋アウトライン', () async {
    final result = await rasterizeTextObject(
        baseText('{漢字|かんじ}の{行|ぎょう}\n{二行目|にぎょうめ}', outline: true), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('縦書き・通常テキスト', () async {
    final result = await rasterizeTextObject(
        baseText('こんにちは', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('縦書き・半角英数字回転（アルファベット単独）', () async {
    final result = await rasterizeTextObject(
        baseText('ABCテスト', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('縦書き・縦中横（半角数字2桁）', () async {
    final result = await rasterizeTextObject(
        baseText('令和06年12月', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('縦書き・縦中横（3桁以上は個別回転扱いにフォールバック）', () async {
    final result = await rasterizeTextObject(
        baseText('123456', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('縦書き・ルビ付き', () async {
    final result = await rasterizeTextObject(
        baseText('{明日|あした}は{晴|は}れ', direction: TextWritingDirection.vertical),
        canvasWidth,
        canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('縦書き・半角英数字回転＋縦中横＋ルビ＋アウトラインの複合', () async {
    final result = await rasterizeTextObject(
        baseText('{令和|れいわ}06年ABC\n2行目テスト',
            direction: TextWritingDirection.vertical, outline: true),
        canvasWidth,
        canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });

  test('縦書き・整形不良のルビ記法（閉じ括弧なし）でも例外を投げない', () async {
    final result = await rasterizeTextObject(
        baseText('{閉じてない|かこ', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(result, isNotNull);
  });

  test('空文字列（縦書き）はクラッシュせずnullを返す', () async {
    final result = await rasterizeTextObject(
        baseText('', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(result, isNull);
  });

  int countOpaquePixels(List<int> bytes) {
    int count = 0;
    for (int i = 3; i < bytes.length; i += 4) {
      if (bytes[i] > 0) count++;
    }
    return count;
  }

  test('横書き・ルビは実際に描画される（ルビなしより不透明ピクセルが多い）', () async {
    final withoutRuby = await rasterizeTextObject(baseText('明日'), canvasWidth, canvasHeight);
    final withRuby = await rasterizeTextObject(baseText('{明日|あした}'), canvasWidth, canvasHeight);
    expect(withoutRuby, isNotNull);
    expect(withRuby, isNotNull);
    final countWithout = countOpaquePixels(withoutRuby!);
    final countWith = countOpaquePixels(withRuby!);
    expect(countWith, greaterThan(countWithout),
        reason: 'ルビ文字が実際にラスタライズされ、追加のピクセルが描画されているはず');
  });

  test('縦書き・ルビは実際に描画される（ルビなしより不透明ピクセルが多い）', () async {
    final withoutRuby = await rasterizeTextObject(
        baseText('明日', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    final withRuby = await rasterizeTextObject(
        baseText('{明日|あした}', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(withoutRuby, isNotNull);
    expect(withRuby, isNotNull);
    final countWithout = countOpaquePixels(withoutRuby!);
    final countWith = countOpaquePixels(withRuby!);
    expect(countWith, greaterThan(countWithout),
        reason: 'ルビ文字が実際にラスタライズされ、追加のピクセルが描画されているはず');
  });

  test('縦書き・縦中横は実際に描画される（数字が正しく塗られる）', () async {
    final result = await rasterizeTextObject(
        baseText('12', direction: TextWritingDirection.vertical), canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(countOpaquePixels(result!), greaterThan(0));
  });

  test('回転・拡大・不透明度を伴う横書きテキスト', () async {
    final text = baseText('回転テスト').copyWith(rotation: 45, scale: 1.5, opacity: 0.5);
    final result = await rasterizeTextObject(text, canvasWidth, canvasHeight);
    expect(result, isNotNull);
    expect(result!.length, expectedBytes);
  });
}
