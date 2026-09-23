import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// FilterEngine.applyAuroraHologram（オーロラホログラムフィルター）の
/// 単体テスト。
void main() {
  const width = 4;
  const height = 4;
  final engine = FilterEngine();

  /// 明度の異なる3色（暗い・中間・明るい）が並ぶテストパターン（RGBA）。
  Uint8List buildPattern() {
    final data = Uint8List(width * height * 4);
    for (int i = 0; i < width * height; i++) {
      final idx = i * 4;
      final shade = (i % 3) * 100; // 0, 100, 200
      data[idx] = shade;
      data[idx + 1] = shade;
      data[idx + 2] = shade;
      data[idx + 3] = 255;
    }
    return data;
  }

  test('strength=0のときは元の画素と完全に一致する', () {
    final data = buildPattern();
    final result = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 0,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.aurora,
    );
    expect(result, equals(data));
  });

  test('strength>0のとき、不透明画素の色はグラデーションマップ側へ寄る', () {
    final data = buildPattern();
    final result = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.cyberNeon,
    );
    // strength=100（完全ブレンド）の場合、結果は元のグレーとは異なる
    // （cyberNeonプリセットはグレーを含まない配色のため）はず。
    var changed = false;
    for (int i = 0; i < data.length; i += 4) {
      if (result[i] != data[i] ||
          result[i + 1] != data[i + 1] ||
          result[i + 2] != data[i + 2]) {
        changed = true;
        break;
      }
    }
    expect(changed, isTrue);
  });

  test('アルファ0（透明）の画素は変化しない', () {
    final data = Uint8List(width * height * 4); // 全画素アルファ0
    final result = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 50,
      saturation: 50,
      preset: AuroraHologramPreset.soapBubble,
    );
    expect(result, equals(data));
  });

  test('半透明画素はRGBだけ変化しアルファ値を保持する', () {
    final data = Uint8List.fromList([
      70,
      90,
      120,
      32,
      100,
      120,
      140,
      96,
      130,
      150,
      170,
      160,
      160,
      180,
      200,
      224,
    ]);
    final originalAlpha = [32, 96, 160, 224];
    final result = engine.applyAuroraHologram(
      data,
      4,
      1,
      strength: 100,
      brightness: 10,
      saturation: 25,
      preset: AuroraHologramPreset.soapBubble,
    );

    var rgbChanged = false;
    for (var i = 0; i < 4; i++) {
      final offset = i * 4;
      expect(result[offset + 3], originalAlpha[i]);
      if (result[offset] != data[offset] ||
          result[offset + 1] != data[offset + 1] ||
          result[offset + 2] != data[offset + 2]) {
        rgbChanged = true;
      }
    }
    expect(rgbChanged, isTrue);
  });

  test('入力バッファを破壊せず新しい結果を返す', () {
    final data = buildPattern();
    final before = Uint8List.fromList(data);
    final result = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 75,
      brightness: -20,
      saturation: 30,
      preset: AuroraHologramPreset.sunsetGold,
    );

    expect(data, equals(before));
    expect(result, isNot(same(data)));
  });

  test('同じ明度の画素は同じ結果色になる（グラデーションマップの一貫性）', () {
    // 全画素を同じ明度（128,128,128）にする。
    final data = Uint8List(width * height * 4);
    for (int i = 0; i < data.length; i += 4) {
      data[i] = 128;
      data[i + 1] = 128;
      data[i + 2] = 128;
      data[i + 3] = 255;
    }
    final result = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.pastelDream,
    );
    final first = (result[0], result[1], result[2]);
    for (int i = 4; i < result.length; i += 4) {
      expect((result[i], result[i + 1], result[i + 2]), equals(first));
    }
  });


  test('100%では同じ明度なら元RGBが違っても同じグラデーション色へ置換される', () {
    // (255,0,0) and (0,130,0) both round to luminance 76 with the
    // production 0.299/0.587/0.114 luminance calculation.
    final data = Uint8List.fromList([
      255, 0, 0, 255,
      0, 130, 0, 255,
    ]);
    final result = engine.applyAuroraHologram(
      data,
      2,
      1,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.blueHologram,
    );
    expect(
      (result[0], result[1], result[2]),
      equals((result[4], result[5], result[6])),
    );
  });

  test('プリセットごとに結果が異なる（配色パターンとして機能している）', () {
    final data = buildPattern();
    final aurora = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.aurora,
    );
    final silverFoil = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.silverFoil,
    );
    expect(aurora, isNot(equals(silverFoil)));
  });

  test('全プリセットが不透明入力を処理でき、アルファを保持する', () {
    final data = buildPattern();
    for (final preset in AuroraHologramPreset.values) {
      final result = engine.applyAuroraHologram(
        data,
        width,
        height,
        strength: 100,
        brightness: 0,
        saturation: 0,
        preset: preset,
      );
      expect(result.length, data.length, reason: preset.name);
      var changed = false;
      for (var i = 0; i < result.length; i += 4) {
        expect(result[i + 3], data[i + 3], reason: preset.name);
        if (result[i] != data[i] ||
            result[i + 1] != data[i + 1] ||
            result[i + 2] != data[i + 2]) {
          changed = true;
        }
      }
      expect(changed, isTrue, reason: preset.name);
    }
  });

  test('brightnessを上げると結果が明るくなる', () {
    final data = buildPattern();
    final base = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.silverFoil,
    );
    final brighter = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 80,
      saturation: 0,
      preset: AuroraHologramPreset.silverFoil,
    );
    // 明度80だけ底上げした結果は、平均してbaseより明るいはず。
    int sumBase = 0, sumBrighter = 0;
    for (int i = 0; i < data.length; i += 4) {
      sumBase += base[i] + base[i + 1] + base[i + 2];
      sumBrighter += brighter[i] + brighter[i + 1] + brighter[i + 2];
    }
    expect(sumBrighter, greaterThan(sumBase));
  });

  test('strengthは0〜100へクランプされる', () {
    final data = buildPattern();
    final belowZero = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: -50,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.aurora,
    );
    final atHundred = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.aurora,
    );
    final aboveHundred = engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 250,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.aurora,
    );

    expect(belowZero, equals(data));
    expect(aboveHundred, equals(atHundred));
  });

  test('brightness/saturationの極端値でもチャンネル範囲とアルファを維持する', () {
    final data = buildPattern();
    for (final values in [(-500.0, -500.0), (500.0, 500.0)]) {
      final result = engine.applyAuroraHologram(
        data,
        width,
        height,
        strength: 100,
        brightness: values.$1,
        saturation: values.$2,
        preset: AuroraHologramPreset.cyberNeon,
      );
      expect(result.length, data.length);
      for (var i = 0; i < result.length; i += 4) {
        expect(result[i], inInclusiveRange(0, 255));
        expect(result[i + 1], inInclusiveRange(0, 255));
        expect(result[i + 2], inInclusiveRange(0, 255));
        expect(result[i + 3], data[i + 3]);
      }
    }
  });

  test('同一入力・同一パラメータなら常に同じ結果になる', () {
    final data = buildPattern();
    Uint8List apply() => engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: 83,
      brightness: 17,
      saturation: -12,
      preset: AuroraHologramPreset.pastelDream,
    );

    expect(apply(), equals(apply()));
  });

  test('ホログラム色プリセットは白ハイライトと主色を両方持つ', () {
    const expectedDominant = {
      AuroraHologramPreset.blueHologram: 'blue',
      AuroraHologramPreset.lightBlueHologram: 'blue',
      AuroraHologramPreset.purpleHologram: 'purple',
      AuroraHologramPreset.blueGreenHologram: 'blueGreen',
    };
    for (final entry in expectedDominant.entries) {
      final stops = auroraHologramStops(entry.key);
      expect(
        stops.any((s) => s.$2 >= 238 && s.$3 >= 238 && s.$4 >= 238),
        isTrue,
        reason: '${entry.key.name} should retain pearly white highlights',
      );
      switch (entry.value) {
        case 'blue':
          expect(stops.any((s) => s.$4 > s.$2 && s.$4 >= 230), isTrue);
        case 'purple':
          expect(stops.any((s) => s.$2 >= 140 && s.$4 >= 230), isTrue);
        case 'blueGreen':
          expect(
            stops.any((s) => s.$3 >= 210 && s.$4 >= 210),
            isTrue,
          );
      }
    }
  });


  test('全プリセットで黒と白が帯の両端へ100%マッピングされる', () {
    for (final preset in AuroraHologramPreset.values) {
      final stops = auroraHologramStops(preset);
      final data = Uint8List.fromList([
        0, 0, 0, 255,
        255, 255, 255, 255,
      ]);
      final result = engine.applyAuroraHologram(
        data,
        2,
        1,
        strength: 100,
        brightness: 0,
        saturation: 0,
        preset: preset,
      );
      expect(
        (result[0], result[1], result[2]),
        equals((stops.first.$2, stops.first.$3, stops.first.$4)),
        reason: '${preset.name}: black should map to the left endpoint',
      );
      expect(
        (result[4], result[5], result[6]),
        equals((stops.last.$2, stops.last.$3, stops.last.$4)),
        reason: '${preset.name}: white should map to the right endpoint',
      );
    }
  });

  test('全プリセットの右端はその配色の最明色である', () {
    int luminance((double, int, int, int) stop) =>
        299 * stop.$2 + 587 * stop.$3 + 114 * stop.$4;

    for (final preset in AuroraHologramPreset.values) {
      final stops = auroraHologramStops(preset);
      final maxLuminance = stops
          .map(luminance)
          .reduce((a, b) => a >= b ? a : b);
      expect(
        luminance(stops.last),
        maxLuminance,
        reason: '${preset.name}: right endpoint must be a brightest stop',
      );
    }
  });

  test('100% Gradient Mapは元RGBではなく入力輝度だけで決まる', () {
    final data = Uint8List.fromList([
      255, 0, 0, 255,
      0, 130, 0, 255,
    ]);
    for (final preset in AuroraHologramPreset.values) {
      final result = engine.applyAuroraHologram(
        data,
        2,
        1,
        strength: 100,
        brightness: 0,
        saturation: 0,
        preset: preset,
      );
      expect(
        (result[0], result[1], result[2]),
        equals((result[4], result[5], result[6])),
        reason: preset.name,
      );
    }
  });



  test('全15配色presetは名前で保存・復元できる', () {
    expect(AuroraHologramPreset.values.length, 15);
    for (final preset in AuroraHologramPreset.values) {
      final original = FilterDef(
        id: 'texture-${preset.name}',
        name: 'texture',
        kind: FilterKind.auroraHologram,
        strength: 100,
        hologramBrightness: 17,
        hologramSaturation: -9,
        hologramPreset: preset,
      );
      final json = original.toJson();
      expect(json['hologramPreset'], preset.name, reason: preset.name);

      final restored = FilterDef.fromJson(json);
      expect(restored.kind, FilterKind.auroraHologram, reason: preset.name);
      expect(restored.strength, 100, reason: preset.name);
      expect(restored.hologramBrightness, 17, reason: preset.name);
      expect(restored.hologramSaturation, -9, reason: preset.name);
      expect(restored.hologramPreset, preset, reason: preset.name);
    }
  });


  test('auroraHologramStopsは各プリセットで昇順の位置を持つ', () {
    for (final preset in AuroraHologramPreset.values) {
      final stops = auroraHologramStops(preset);
      expect(stops.length, greaterThanOrEqualTo(2));
      for (int i = 1; i < stops.length; i++) {
        expect(stops[i].$1, greaterThanOrEqualTo(stops[i - 1].$1));
      }
      expect(stops.first.$1, 0.0);
      expect(stops.last.$1, 1.0);
    }
  });
}
