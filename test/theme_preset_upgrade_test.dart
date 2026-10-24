import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/previous_theme_presets.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 組み込みテーマの配色を見直したとき、端末に保存された一覧・現在の色のうち
/// 以前の配色のまま（利用者が手を加えていない）ものだけを新しい配色にする。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 組み込みテーマ[id]の以前の[version]番目（0が最も古い）の配色。
  AppThemePreset previous(
    String id, {
    String? as,
    String? name,
    int version = 0,
  }) {
    final c = kPreviousBuiltInThemeColors[id]![version];
    return AppThemePreset(
      id: as ?? id,
      name: name ?? id,
      accentColor: Color(c[0]!),
      textColor: Color(c[1]!),
      buttonTextColor: Color(c[2]!),
      menuTextColor: Color(c[3]!),
      selectionTextColor: Color(c[4]!),
      panelBgColor: Color(c[5]!),
      menuBgColor: Color(c[6]!),
      selectionColor: Color(c[7]!),
      updateMarkColor: Color(c[8]!),
      accentTextColor: c[9] == null ? null : Color(c[9]!),
    );
  }

  Map<String, dynamic> colours(AppThemePreset preset) => preset.toJson()
    ..remove('id')
    ..remove('name')
    ..remove('isFavorite');

  late Map<String, AppThemePreset> latest;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fresh = ThemeService();
    await fresh.init();
    latest = {for (final p in fresh.presets) p.id: p};
    fresh.dispose();
  });

  test('the table covers every built-in theme and they all changed', () {
    expect(kPreviousBuiltInThemeColors.keys.toSet(), latest.keys.toSet());
    expect(
      kPreviousBuiltInThemeColors['orange_light']!.first.first,
      0xFFFF8A3D,
    );
    for (final id in latest.keys) {
      for (var v = 0; v < kPreviousBuiltInThemeColors[id]!.length; v++) {
        expect(
          colours(previous(id, version: v)),
          isNot(colours(latest[id]!)),
          reason: '$id v$v',
        );
      }
    }
  });

  test(
    'dark themes saved with the background-coloured button text move on',
    () async {
      // ダークの塗りのボタンの文字がパネル背景色だった版（e41ebee）。
      final saved = previous('purple_dark', version: 1);
      expect(saved.buttonTextColor, saved.panelBgColor);
      expect(saved.accentTextColor, isNotNull);
      SharedPreferences.setMockInitialValues({
        'theme_presets': [jsonEncode(saved.toJson())],
        'theme_current_json': jsonEncode(
          previous(
            'default_dark',
            version: 1,
            as: ThemeService.customCurrentId,
            name: '取り込み',
          ).toJson(),
        ),
      });
      final service = ThemeService();
      addTearDown(service.dispose);
      await service.init();
      final purple = service.presets.firstWhere((p) => p.id == 'purple_dark');
      expect(colours(purple), colours(latest['purple_dark']!));
      expect(purple.buttonTextColor, Colors.white);
      expect(colours(service.current), colours(latest['default_dark']!));
      expect(service.current.accentColor, const Color(0xFFFF5C7A));
    },
  );

  test('untouched built-in themes get the new colours', () async {
    final editedBlue = previous(
      'blue_light',
    ).copyWith(accentColor: const Color(0xFF123456));
    final mine = previous('pink_dark', as: 'my_theme', name: '自分の');
    SharedPreferences.setMockInitialValues({
      'theme_presets': [
        for (final preset in [
          previous('orange_light', name: 'オレンジ改名').copyWith(isFavorite: true),
          editedBlue,
          mine,
          previous('default_dark'),
        ])
          jsonEncode(preset.toJson()),
      ],
      // テーマ一覧から配色だけ取り込んだ現在の色。
      'theme_current_json': jsonEncode(
        previous(
          'yellow_dark',
          as: ThemeService.customCurrentId,
          name: '取り込み',
        ).toJson(),
      ),
    });
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.init();

    AppThemePreset byId(String id) =>
        service.presets.firstWhere((p) => p.id == id);
    final orange = byId('orange_light');
    expect(colours(orange), colours(latest['orange_light']!));
    // 名前・お気に入りはそのまま。
    expect(orange.name, 'オレンジ改名');
    expect(orange.isFavorite, isTrue);
    expect(colours(byId('default_dark')), colours(latest['default_dark']!));
    // 手を加えたテーマ・自分で作ったテーマはそのまま。
    expect(byId('blue_light').toJson(), editedBlue.toJson());
    expect(byId('my_theme').toJson(), mine.toJson());

    expect(service.current.id, ThemeService.customCurrentId);
    expect(service.current.name, '取り込み');
    expect(colours(service.current), colours(latest['yellow_dark']!));

    // 保存し直してあるので、次の起動でも同じ。
    final prefs = await SharedPreferences.getInstance();
    final saved = AppThemePreset.fromJson(
      jsonDecode(prefs.getString('theme_current_json')!)
          as Map<String, dynamic>,
    );
    expect(colours(saved), colours(latest['yellow_dark']!));
    final savedList = prefs
        .getStringList('theme_presets')!
        .map((e) => AppThemePreset.fromJson(jsonDecode(e)))
        .toList();
    expect(
      colours(savedList.firstWhere((p) => p.id == 'orange_light')),
      colours(latest['orange_light']!),
    );
  });

  test('a current colour set with any change is kept', () async {
    final tweaked = previous(
      'default_light',
    ).copyWith(accentTextColor: const Color(0xFF8A1538));
    SharedPreferences.setMockInitialValues({
      'theme_current_json': jsonEncode(tweaked.toJson()),
    });
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.current.toJson(), tweaked.toJson());
  });

  test('an untouched built-in theme being edited is upgraded', () async {
    SharedPreferences.setMockInitialValues({
      'theme_current_json': jsonEncode(previous('green_dark').toJson()),
    });
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.current.id, 'green_dark');
    expect(colours(service.current), colours(latest['green_dark']!));
  });
}
