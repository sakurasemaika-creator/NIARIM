// テーマ（ThemeData）は色・言語が同じなら同じ物を使い回し、関係の無い設定の
// 変更でアプリ全体の切り替えの動きを始めないことを確かめる
// （ThemeService.themeDataFor・NiarimApp）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_app_harness.dart';

void main() {
  test('同じ色・同じ言語には同じテーマ、色か言語が変われば作り直す', () {
    final themes = ThemeService();
    const ja = Locale('ja');
    const zh = Locale('zh');
    final first = themes.themeDataFor(ja);
    expect(themes.themeDataFor(ja), same(first));
    expect(themes.themeDataFor(zh), isNot(same(first)));
    expect(themes.themeDataFor(ja), same(first));

    themes.previewCurrent(
      themes.current.copyWith(accentColor: const Color(0xFF123456)),
    );
    final recoloured = themes.themeDataFor(ja);
    expect(recoloured, isNot(same(first)));
    expect(recoloured.colorScheme.primary, const Color(0xFF123456));
    expect(ThemeService.activeColorScheme, same(recoloured.colorScheme));

    themes.previewCurrent(AppThemePreset.defaultLight);
    final back = themes.themeDataFor(ja);
    expect(back.colorScheme.primary, first.colorScheme.primary);
    expect(ThemeService.activeColorScheme, same(back.colorScheme));
  });

  testWidgets('設定を変えてもテーマの切り替えの動きは始まらない', (tester) async {
    final h = HomeAppHarness.prepare(tester);
    await h.open(
      seed: (s) async {
        for (var i = 0; i < 6; i++) {
          await HomeAppHarness.work(s, '作品$i');
        }
      },
    );
    final home = tester.element(find.byType(HomeScreen));
    final themeBefore = Theme.of(home);
    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    final settings = home.read<SettingsService>();
    await tester.runAsync(
      () => settings.setBucketTolerance(settings.bucketTolerance + 1),
    );
    await tester.pump();
    rebuilds = 0;
    // 以前は新しいテーマへ約200msかけて移り、その間は毎フレーム画面全体
    // （数千の部品）を組み立て直していた。
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = null;
    expect(rebuilds, 0);
    expect(Theme.of(home), same(themeBefore));
    await h.close();
  });
}
