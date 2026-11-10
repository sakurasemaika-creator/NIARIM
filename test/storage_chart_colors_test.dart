import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/color_channels.dart';

/// 容量削減画面の内訳グラフの色が、**どのテーマでも互いに区別できる**
/// ことを検証する。
///
/// 以前は6色のうち2組が`Theme.of(context).colorScheme`と
/// `ThemeService.activeColorScheme`（同じインスタンス）から取られていて
/// **完全に同じ色**になっており、「プロジェクトデータ」と「キャッシュ」が
/// 見分けられなかった（build/all-route-screenshots/32_storage.png で発覚）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 2色の距離。8bitのRGBの差の二乗和で、十分離れているかだけを見る。
  int distance(Color a, Color b) {
    final dr = a.red8 - b.red8;
    final dg = a.green8 - b.green8;
    final db = a.blue8 - b.blue8;
    return dr * dr + dg * dg + db * db;
  }

  test('組み込みテーマ全てで内訳グラフの6色が互いに区別できる', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    var checked = 0;
    for (final preset in service.presets) {
      service.applyPreset(preset.id);
      final scheme = service.themeData.colorScheme;
      final colors = sliceColorsOf(scheme);
      expect(colors.length, 6);
      final deviceColors = storageDeviceSliceColorsOf(scheme);
      expect(deviceColors.length, 3);
      final primaryHsl = HSLColor.fromColor(scheme.primary);
      final shifted = primaryHsl.withHue(
        (primaryHsl.hue + storageDeviceHueShiftDegrees) % 360,
      );
      for (var i = 0; i < 3; i++) {
        expect(
          deviceColors[i],
          shifted.withLightness(storageChartLightnessLevels[i]).toColor(),
          reason: '${preset.id}: device chart must shift hue only',
        );
        expect(
          deviceColors[i],
          isNot(colors[i]),
          reason: '${preset.id}: device chart should be a distinct hue',
        );
      }

      // 6色の色相と彩度はアクセントと完全に同じ。
      // 明度以外の成分が変更されると、色の統一感が失われる。
      final accent = HSLColor.fromColor(scheme.primary);
      expect(storageChartLightnessLevels.length, 6);
      for (var i = 0; i < colors.length; i++) {
        expect(
          colors[i],
          accent.withLightness(storageChartLightnessLevels[i]).toColor(),
          reason: '${preset.id}: $i番目が明度以外も変更している',
        );
        // Same H/S, but a deliberately different accent lightness, must
        // produce exactly the same six colors: only H/S are imported.
        final alternateScheme = scheme.copyWith(
          primary: accent.withLightness(0.93).toColor(),
        );
        // Color -> HSL -> Color is 8-bit quantized; a small RGB rounding
        // difference is expected when re-encoding a different source L.
        expect(
          distance(sliceColorsOf(alternateScheme)[i], colors[i]),
          lessThan(150),
          reason: '${preset.id}: 色の明るさが元アクセントの明度に依存',
        );
        if (i > 0) {
          expect(
            HSLColor.fromColor(colors[i]).lightness,
            greaterThan(HSLColor.fromColor(colors[i - 1]).lightness),
            reason: '${preset.id}: 明度が順に明るくなっていない',
          );
        }
      }
      for (var i = 0; i < colors.length; i++) {
        for (var j = i + 1; j < colors.length; j++) {
          expect(
            distance(colors[i], colors[j]),
            greaterThan(900),
            reason:
                '${preset.id}: $i番目と$j番目の色が近すぎる '
                '(${colors[i]} / ${colors[j]})',
          );
        }
      }
      checked++;
    }
    expect(checked, greaterThan(5), reason: '組み込みテーマが読めていない');
  });
}
