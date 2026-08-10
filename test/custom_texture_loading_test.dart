import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';

/// [size]×[size]の単色PNGバイト列を生成する（テスト用の自作ブラシ/トーン/
/// スタンプ画像の代替）。
Future<Uint8List> _solidColorPng(int size, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Task#85：自作ブラシ・自作トーン・自作スタンプの画像が、キャンバスの
  // 実描画（DrawingEngine／トーン・スタンプ描画）で読み込まれず、常に
  // 名前ベースのフォールバックパターンが使われてしまっていたバグの回帰
  // テスト。

  group('brush_texture_cache（自作ブラシ画像）', () {
    test('黒画像は全ピクセルがalpha高値（インクあり）のマスクへ変換される', () async {
      final dir = await Directory.systemTemp.createTemp('niabrush_test');
      final file = File('${dir.path}/black.png');
      await file.writeAsBytes(await _solidColorPng(8, const ui.Color(0xFF000000)));

      expect(getCachedBrushTexture(file.path), isNull);
      await preloadBrushTexture(file.path);
      final texture = getCachedBrushTexture(file.path);
      expect(texture, isNotNull);
      expect(texture!.length, brushTextureSize * brushTextureSize * 4);
      for (int i = 3; i < texture.length; i += 4) {
        expect(texture[i], greaterThan(200));
      }
    });

    test('白画像は全ピクセルがalpha低値（インクなし）のマスクへ変換される', () async {
      final dir = await Directory.systemTemp.createTemp('niabrush_test');
      final file = File('${dir.path}/white.png');
      await file.writeAsBytes(await _solidColorPng(8, const ui.Color(0xFFFFFFFF)));

      await preloadBrushTexture(file.path);
      final texture = getCachedBrushTexture(file.path);
      expect(texture, isNotNull);
      for (int i = 3; i < texture!.length; i += 4) {
        expect(texture[i], lessThan(20));
      }
    });

    test('存在しないパスはキャッシュされず、getCachedBrushTextureはnullのまま', () async {
      await preloadBrushTexture('/no/such/path.png');
      expect(getCachedBrushTexture('/no/such/path.png'), isNull);
    });
  });

  group('generateBuiltInToneTexture（自作トーン画像）', () {
    test('texturePath読み込み前は組み込みパターン（黒白混在）が返る', () {
      const tone = Tone(id: 't1', name: 'カスタム');
      final texture = generateBuiltInToneTexture(tone, size: 32);
      final alphas = [for (int i = 3; i < texture.length; i += 4) texture[i]];
      expect(alphas.contains(0), isTrue);
      expect(alphas.contains(255), isTrue);
    });

    test('ensureToneTextureLoaded後は画像由来のパターンが同期関数からも返る', () async {
      final dir = await Directory.systemTemp.createTemp('niatone_test');
      final file = File('${dir.path}/white.png');
      await file.writeAsBytes(await _solidColorPng(8, const ui.Color(0xFFFFFFFF)));
      final tone = Tone(id: 't2', name: 'カスタム2', texturePath: file.path);

      await ensureToneTextureLoaded(tone, size: 32);
      final texture = generateBuiltInToneTexture(tone, size: 32);
      // 白画像 → インクなし → 全ピクセルalpha=0（組み込みパターンなら
      // 一部255が混ざるため、これで画像由来と判別できる）。
      for (int i = 3; i < texture.length; i += 4) {
        expect(texture[i], 0);
      }
    });
  });

  group('generateBuiltInStampTexture（自作スタンプ画像）', () {
    test('imagePath未設定時は組み込み図形（角は透明）が返る', () async {
      const stamp = Stamp(id: 's1', name: '丸');
      final texture = await generateBuiltInStampTexture(stamp, size: 16);
      // 組み込み図形は中央付近の半径のみ塗るため、四隅は透明のはず。
      expect(texture[3], 0); // 左上角のalpha
    });

    test('imagePath設定時は画像のRGBAがそのまま返る（四隅も不透明）', () async {
      final dir = await Directory.systemTemp.createTemp('niastamp_test');
      final file = File('${dir.path}/red.png');
      await file.writeAsBytes(await _solidColorPng(8, const ui.Color(0xFFFF0000)));
      final stamp = Stamp(id: 's2', name: '自作', imagePath: file.path);

      final texture = await generateBuiltInStampTexture(stamp, size: 16);
      expect(texture[3], 255); // 左上角も不透明
      expect(texture[0], 255); // R
      expect(texture[1], 0); // G
      expect(texture[2], 0); // B
    });
  });
}
