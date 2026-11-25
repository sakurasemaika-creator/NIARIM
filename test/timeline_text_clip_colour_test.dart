import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// タイムラインの文字のクリップの色は、テーマの差し色から作る。
///
/// 以前はどのテーマでも固定の橙色（0xFFE09A2C）で、動画・画像・音声の
/// クリップ（差し色・選択色から作る）と違い、テーマの色に従わなかった。
/// 差し色の色相を少し回した色にし、どの組み込みテーマでも、ほかの3種の
/// クリップの色と見分けられることを確かめる。
void main() {
  double distance(Color a, Color b) {
    final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255;
    final db = (a.b - b.b) * 255;
    return dr * dr + dg * dg + db * db;
  }

  test('既定のピンクでは、今までの橙色に近い色になる', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF5C7A),
    ).copyWith(primary: const Color(0xFFFF5C7A));
    final colour = textClipColorFor(scheme);
    final hue = HSLColor.fromColor(colour).hue;
    expect(hue, inInclusiveRange(15, 40), reason: '$colour');
  });

  test('灰色の差し色では、文字色の方へ寄せた色になる', () {
    const grey = Color(0xFF808080);
    final scheme = ColorScheme.fromSeed(
      seedColor: grey,
    ).copyWith(primary: grey, onSurface: const Color(0xFF101010));
    final colour = textClipColorFor(scheme);
    expect(colour, isNot(grey));
    expect(distance(colour, grey), greaterThan(400));
  });

  test('どの組み込みテーマでも、テーマの差し色から作られ、ほかのクリップと見分けられる', () async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    final seen = <int>{};
    for (final preset in theme.presets) {
      theme.applyPreset(preset.id);
      final scheme = theme.themeData.colorScheme;
      final text = textClipColorFor(scheme);
      seen.add(text.toARGB32());
      for (final (name, other) in [
        ('video', scheme.primary),
        ('image', scheme.secondary),
        ('audio', scheme.tertiary),
      ]) {
        expect(
          distance(text, other),
          greaterThan(400),
          reason: '${preset.name}: text clip vs $name ($text vs $other)',
        );
      }
    }
    // A fixed colour would be the same for every theme.
    expect(seen.length, greaterThan(1));
  });
}
