import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:niarim/utils/splash_gradient.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 起動画面の導線ボタンのグラデーションは、ボタンの文字が読めなくなる手前で
/// 止める（白抜きの文字が淡い終点の上で溶けていた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every built-in theme keeps the button text on the whole gradient',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      addTearDown(service.dispose);
      await service.init();
      for (final preset in service.presets) {
        service.applyPreset(preset.id);
        final scheme = service.themeData.colorScheme;
        for (final (fill, container) in [
          (scheme.primary, scheme.primaryContainer),
          (scheme.secondary, scheme.secondaryContainer),
        ]) {
          final colors = splashGradientColors(
            fill,
            container,
            preset.buttonTextColor,
          );
          expect(colors.first, fill, reason: preset.id);
          for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
            expect(
              apcaContrast(
                preset.buttonTextColor,
                Color.lerp(colors.first, colors.last, t)!,
              ).abs(),
              greaterThanOrEqualTo(kSplashGradientMinLc - 0.5),
              reason: '${preset.id} at $t',
            );
          }
          // 塗りと同じ色の平らなボタンにはしない。
          expect(colors.last, isNot(fill), reason: preset.id);
        }
      }
    },
  );

  test('a readable end colour is kept as it is', () {
    const fill = Color(0xFFF2B90F);
    const container = Color(0xFFFFF1C9);
    expect(splashGradientColors(fill, container, const Color(0xFF17161C)), [
      fill,
      container,
    ]);
  });

  test('a fill the text cannot be read on is left alone', () {
    const fill = Color(0xFFF2B90F);
    const container = Color(0xFFFFF1C9);
    expect(splashGradientColors(fill, container, Colors.white), [
      fill,
      container,
    ]);
  });

  test('white text stops the gradient before the pale end', () {
    final preset = AppThemePreset.defaultLight;
    const container = Color(0xFFFFD9DE);
    final colors = splashGradientColors(
      preset.accentColor,
      container,
      preset.buttonTextColor,
    );
    expect(colors.last, isNot(container));
    expect(
      apcaContrast(preset.buttonTextColor, container).abs(),
      lessThan(kSplashGradientMinLc),
    );
  });
}
