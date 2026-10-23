import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SnackBarの操作ボタン（ゴミ箱の「元に戻す」等）が、どの組み込みテーマでも
/// SnackBarの下地の上で読める。Material3の既定（inversePrimary）は暗い
/// 下地向けの色で、明るい下地のこのアプリでは白に近い薄桃色になり、
/// ほとんど見えなかった。
void main() {
  test('SnackBarの操作ボタンは下地の上で読める', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    var weakest = double.infinity;
    var weakestName = '';
    for (final preset in service.presets) {
      service.applyPreset(preset.id);
      final snackBar = service.themeData.snackBarTheme;
      final action = snackBar.actionTextColor;
      final background = snackBar.backgroundColor;
      expect(action, isNotNull, reason: preset.name);
      expect(background, isNotNull, reason: preset.name);
      final ratio = contrastRatio(action!, background!);
      if (ratio < weakest) {
        weakest = ratio;
        weakestName = preset.name;
      }
    }
    debugPrint('最も低いコントラスト：$weakestName ${weakest.toStringAsFixed(2)}');
    // ダイアログの文字ボタンと同じ色・同じ下地なので、テーマが「読める」と
    // 判定されるしきい値を満たす（最も低いのは水色のテーマの約1.75で、
    // そのテーマのダイアログの文字ボタンと同じ）。
    expect(
      weakest,
      greaterThanOrEqualTo(kMinReadableContrast),
      reason: weakestName,
    );
  });
}
