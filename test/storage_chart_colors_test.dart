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
