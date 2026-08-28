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
      data, width, height,
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
      data, width, height,
      strength: 100,
      brightness: 0,
      saturation: 0,
      preset: AuroraHologramPreset.cyberNeon,
    );
    // strength=100（完全ブレンド）の場合、結果は元のグレーとは異なる
    // （cyberNeonプリセットはグレーを含まない配色のため）はず。
    var changed = false;
    for (int i = 0; i < data.length; i += 4) {
      if (result[i] != data[i] || result[i + 1] != data[i + 1] || result[i + 2] != data[i + 2]) {
        changed = true;
        break;
      }
    }
    expect(changed, isTrue);
  });

  test('アルファ0（透明）の画素は変化しない', () {
    final data = Uint8List(width * height * 4); // 全画素アルファ0
    final result = engine.applyAuroraHologram(
      data, width, height,
      strength: 100,
      brightness: 50,
      saturation: 50,
      preset: AuroraHologramPreset.soapBubble,
    );
    expect(result, equals(data));
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
      data, width, height,
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

  test('プリセットごとに結果が異なる（配色パターンとして機能している）', () {
    final data = buildPattern();
    final aurora = engine.applyAuroraHologram(
      data, width, height,
      strength: 100, brightness: 0, saturation: 0,
      preset: AuroraHologramPreset.aurora,
    );
    final silverFoil = engine.applyAuroraHologram(
      data, width, height,
      strength: 100, brightness: 0, saturation: 0,
      preset: AuroraHologramPreset.silverFoil,
    );
    expect(aurora, isNot(equals(silverFoil)));
  });

  test('brightnessを上げると結果が明るくなる', () {
    final data = buildPattern();
    final base = engine.applyAuroraHologram(
      data, width, height,
      strength: 100, brightness: 0, saturation: 0,
      preset: AuroraHologramPreset.silverFoil,
    );
    final brighter = engine.applyAuroraHologram(
      data, width, height,
      strength: 100, brightness: 80, saturation: 0,
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
