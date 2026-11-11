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
    expect(service.presets, isNotEmpty);
    for (final preset in service.presets) {
      service.applyPreset(preset.id);
      final theme = service.themeData;
      final snackBar = theme.snackBarTheme;
      // Regressions: Flutter's default elevated SnackBar becomes an opaque
      // thick black ring in screenshot tests; flat by default in every theme.
      expect(snackBar.elevation, 0, reason: preset.name);
      // Preserve intended non-notification shadows; only the SnackBar is flat.
      expect(theme.shadowColor, isNot(Colors.transparent),
          reason: preset.name);
      expect(theme.bottomSheetTheme.elevation, isNull, reason: preset.name);
      expect(theme.bottomSheetTheme.modalElevation, isNull, reason: preset.name);
      expect(theme.popupMenuTheme.elevation, 0, reason: preset.name);
      expect(theme.dialogTheme.elevation, 0, reason: preset.name);
      expect((snackBar.shape! as RoundedRectangleBorder).side,
          BorderSide.none, reason: preset.name);
      final action = snackBar.actionTextColor;
      final background = snackBar.backgroundColor;
      expect(action, isNotNull, reason: preset.name);
      expect(background, isNotNull, reason: preset.name);
      // ダイアログの文字ボタンと同じ色（テーマの差し色）を、同じ下地の上に
      // 出す。どのテーマでも「ほとんど見えない」にはならない。
      expect(
        isEssentialTextNearlyInvisible(action!, background!),
        isFalse,
        reason: preset.name,
      );
    }
  });
}
