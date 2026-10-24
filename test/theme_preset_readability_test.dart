import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 組み込みテーマの配色が、どれも読みやすい組み合わせになっていること。
///
/// 救済ボタンの判定（|Lc| 10未満）よりずっと厳しい、配色を決めたときの基準。
/// 色覚の模擬（1・2・3型）でも大きく下がらないことも見る。利用者が選んだ色は
/// この基準で拒否も差し替えもしない（組み込みテーマだけの決まり）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const visionTypes = [
    ColorVisionType.protanopia,
    ColorVisionType.deuteranopia,
    ColorVisionType.tritanopia,
  ];

  double lc(Color foreground, Color background) =>
      apcaContrast(foreground, background).abs();

  double worstSimulatedLc(Color foreground, Color background) => [
    for (final type in visionTypes)
      lc(
        simulateColorVision(foreground, type),
        simulateColorVision(background, type),
      ),
  ].reduce(math.min);

  test('built-in themes pair every colour readably', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.presets, hasLength(28));

    for (final preset in service.presets) {
      final dark = preset.panelBgColor.computeLuminance() <= 0.5;
      String why(String what) => '${preset.id}: $what';

      for (final background in [preset.panelBgColor, preset.menuBgColor]) {
        expect(
          lc(preset.textColor, background),
          greaterThanOrEqualTo(90),
          reason: why('本文の文字'),
        );
        // 選択中のタブ名・文字や枠のボタン・一覧のアイコン。
        final accentText = preset.effectiveAccentTextColor;
        expect(
          lc(accentText, background),
          greaterThanOrEqualTo(dark ? 70 : 75),
          reason: why('アクセントの文字・アイコン色'),
        );
        expect(
          worstSimulatedLc(accentText, background),
          greaterThanOrEqualTo(dark ? 60 : 65),
          reason: why('アクセントの文字・アイコン色（色覚の模擬）'),
        );
        // コマ一覧の中央の枠・止めの数字・書き出し範囲の枠。
        expect(
          lc(preset.updateMarkColor, background),
          greaterThanOrEqualTo(dark ? 60 : 50),
          reason: why('更新マーク色'),
        );
        expect(
          worstSimulatedLc(preset.updateMarkColor, background),
          greaterThanOrEqualTo(40),
          reason: why('更新マーク色（色覚の模擬）'),
        );
      }
      expect(
        lc(preset.menuTextColor, preset.menuBgColor),
        greaterThanOrEqualTo(90),
        reason: why('メニューの文字'),
      );

      // 塗りのボタン・選択中の文字は、ライトは白抜き、ダークはパネル背景色
      // （ユーザー指定）。
      final ink = dark ? preset.panelBgColor : Colors.white;
      expect(preset.buttonTextColor, ink, reason: why('ボタンの文字'));
      expect(preset.selectionTextColor, ink, reason: why('選択中の文字'));
      // 塗りのボタン・起動画面の導線・選択中の行の文字。
      for (final (foreground, background, what) in [
        (preset.buttonTextColor, preset.accentColor, 'ボタンの文字'),
        (preset.buttonTextColor, preset.selectionColor, '起動画面の「作品広場」'),
        (preset.selectionTextColor, preset.selectionColor, '選択中の文字'),
      ]) {
        expect(
          lc(foreground, background),
          greaterThanOrEqualTo(60),
          reason: why(what),
        );
        expect(
          worstSimulatedLc(foreground, background),
          greaterThanOrEqualTo(50),
          reason: why('$what（色覚の模擬）'),
        );
      }

      // 更新マークは差し色（選択中のコマのチェック等）と見分けがつくこと。
      expect(
        okLabDistance(preset.updateMarkColor, preset.accentColor),
        greaterThanOrEqualTo(0.12),
        reason: why('更新マーク色と差し色'),
      );
      for (final type in visionTypes) {
        expect(
          perceivedColorDistance(
            preset.updateMarkColor,
            preset.accentColor,
            visionType: type,
          ),
          greaterThanOrEqualTo(0.04),
          reason: why('更新マーク色と差し色（$type）'),
        );
      }
    }
  });

  test('the default theme keeps the brand accent', () {
    // 書き出しのエンドカード・アプリアイコンの背景と同じ色。
    expect(AppThemePreset.defaultLight.accentColor, const Color(0xFFFF5C7A));
  });
}
