import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/accent_text_theme.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';

/// テーマ・外観で1つの色を変えたら、その色の役目のところだけが変わること
/// （ユーザー指定「差し色だけ設定変えたら差し色だけ変わるように」）。
/// 以前はColorScheme.fromSeedが差し色から面・線・3つ目の色まで作っていたため、
/// 差し色を変えるとカード・入力欄・区切り線の色や選択色の淡い色まで変わった。
void main() {
  Map<String, Color> rolesOf(ThemeData theme) {
    final s = theme.colorScheme;
    return {
      'primary': s.primary,
      'onPrimary': s.onPrimary,
      'primaryContainer': s.primaryContainer,
      'onPrimaryContainer': s.onPrimaryContainer,
      'primaryFixed': s.primaryFixed,
      'primaryFixedDim': s.primaryFixedDim,
      'onPrimaryFixed': s.onPrimaryFixed,
      'onPrimaryFixedVariant': s.onPrimaryFixedVariant,
      'secondary': s.secondary,
      'onSecondary': s.onSecondary,
      'secondaryContainer': s.secondaryContainer,
      'onSecondaryContainer': s.onSecondaryContainer,
      'secondaryFixed': s.secondaryFixed,
      'secondaryFixedDim': s.secondaryFixedDim,
      'onSecondaryFixed': s.onSecondaryFixed,
      'onSecondaryFixedVariant': s.onSecondaryFixedVariant,
      'tertiary': s.tertiary,
      'onTertiary': s.onTertiary,
      'tertiaryContainer': s.tertiaryContainer,
      'onTertiaryContainer': s.onTertiaryContainer,
      'tertiaryFixed': s.tertiaryFixed,
      'tertiaryFixedDim': s.tertiaryFixedDim,
      'onTertiaryFixed': s.onTertiaryFixed,
      'onTertiaryFixedVariant': s.onTertiaryFixedVariant,
      'error': s.error,
      'onError': s.onError,
      'errorContainer': s.errorContainer,
      'onErrorContainer': s.onErrorContainer,
      'surface': s.surface,
      'onSurface': s.onSurface,
      'surfaceDim': s.surfaceDim,
      'surfaceBright': s.surfaceBright,
      'surfaceContainerLowest': s.surfaceContainerLowest,
      'surfaceContainerLow': s.surfaceContainerLow,
      'surfaceContainer': s.surfaceContainer,
      'surfaceContainerHigh': s.surfaceContainerHigh,
      'surfaceContainerHighest': s.surfaceContainerHighest,
      'onSurfaceVariant': s.onSurfaceVariant,
      'outline': s.outline,
      'outlineVariant': s.outlineVariant,
      'shadow': s.shadow,
      'scrim': s.scrim,
      'inverseSurface': s.inverseSurface,
      'onInverseSurface': s.onInverseSurface,
      'inversePrimary': s.inversePrimary,
      'surfaceTint': s.surfaceTint,
      'accentText': theme.extension<AccentTextTheme>()!.color,
      'scaffold': theme.scaffoldBackgroundColor,
      'canvas': theme.canvasColor,
      'card': theme.cardTheme.color!,
      'dialog': theme.dialogTheme.backgroundColor!,
      'snackBar': theme.snackBarTheme.backgroundColor!,
      'chip': theme.chipTheme.backgroundColor!,
      'chipSelected': theme.chipTheme.selectedColor!,
      'divider': theme.dividerTheme.color!,
      'appBar': theme.appBarTheme.backgroundColor!,
      'listTileIcon': theme.listTileTheme.iconColor!,
      'listTileSelected': theme.listTileTheme.selectedTileColor!,
    };
  }

  Set<String> changed(AppThemePreset before, AppThemePreset after) {
    final service = ThemeService();
    addTearDown(service.dispose);
    service.previewCurrent(before);
    final a = rolesOf(service.themeData);
    service.previewCurrent(after);
    final b = rolesOf(service.themeData);
    return {
      for (final key in a.keys)
        if (a[key] != b[key]) key,
    };
  }

  // 差し色の役目：塗り（primary）と、差し色から作る淡い色。
  const accentRoles = {
    'primary',
    'primaryContainer',
    'primaryFixed',
    'primaryFixedDim',
    'onPrimaryFixed',
    'onPrimaryFixedVariant',
    'inversePrimary',
  };
  // 選択色の役目：選択中の下地と、選択色から作る淡い色・3つ目の色。
  const selectionRoles = {
    'secondary',
    'secondaryContainer',
    'secondaryFixed',
    'secondaryFixedDim',
    'onSecondaryFixed',
    'onSecondaryFixedVariant',
    'tertiary',
    'onTertiary',
    'tertiaryContainer',
    'onTertiaryContainer',
    'tertiaryFixed',
    'tertiaryFixedDim',
    'onTertiaryFixed',
    'onTertiaryFixedVariant',
    'chipSelected',
    'listTileSelected',
  };
  const blue = Color(0xFF2E9CF5);

  for (final base in [
    AppThemePreset.defaultLight,
    AppThemePreset.defaultDark,
    AppThemePreset.defaultLight.copyWith(
      panelBgColor: const Color(0xFFEAF4EC),
      selectionColor: const Color(0xFF7A5CC9),
    ),
    // アクセントの文字・アイコン色を自分で選んだテーマ。
    AppThemePreset.defaultLight.copyWith(
      id: 'own_accent_text',
      accentTextColor: const Color(0xFF8A1538),
    ),
  ]) {
    test('${base.id}: the accent changes only the accent', () {
      final roles = changed(base, base.copyWith(accentColor: blue));
      // アクセントの文字・アイコン色を選んでいなければ、それも差し色と同じ
      // 色なので一緒に変わる（選んでいれば変わらない）。
      final expected = {
        ...accentRoles,
        if (base.accentTextColor == null) ...{'accentText', 'listTileIcon'},
      };
      expect(roles.difference(expected), isEmpty);
      expect(roles, contains('primary'));
      if (base.accentTextColor != null) {
        expect(roles, isNot(contains('accentText')));
      }
    });

    test('${base.id}: the selection colour changes only the selection', () {
      final roles = changed(base, base.copyWith(selectionColor: blue));
      expect(roles.difference(selectionRoles), isEmpty);
      expect(roles, contains('secondary'));
    });
  }

  test('an accent text colour left unset still follows the accent', () {
    final base = AppThemePreset.defaultLight.copyWith(accentTextColor: null);
    final roles = changed(base, base.copyWith(accentColor: blue));
    expect(
      roles.difference({...accentRoles, 'accentText', 'listTileIcon'}),
      isEmpty,
    );
    expect(roles, containsAll(['accentText', 'listTileIcon']));
  });

  test('the background colour moves the surfaces and lines with it', () {
    final base = AppThemePreset.defaultLight;
    final roles = changed(
      base,
      base.copyWith(panelBgColor: const Color(0xFFEAF4EC)),
    );
    expect(
      roles,
      containsAll([
        'surface',
        'surfaceContainerLow',
        'surfaceContainerHigh',
        'outline',
        'outlineVariant',
        'scaffold',
        'canvas',
      ]),
    );
    expect(roles.intersection(accentRoles), isEmpty);
  });
}
