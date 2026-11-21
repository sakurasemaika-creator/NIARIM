import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';

import 'home_matrix_harness.dart';

/// テーマのマトリクスで、プロジェクト以外のタブと引き出しも撮る言語
/// （プロジェクトのタブは7言語すべて）。
const kHomeMatrix2ThemeTabLanguages = ['ja', 'en', 'fr', 'ko', 'zh'];

/// 読める自作テーマ：本文・メニューの文字・メニューの地・パネル・差し色・
/// 差し色の文字がどれも違う色で、アプリ自身の判定（救済ボタンを出さない）
/// でも読める。
const kHomeMatrix2ReadableTheme = AppThemePreset(
  id: 'theme_custom_current',
  name: 'Matrix readable',
  accentColor: Color(0xFF7A3EB1),
  accentTextColor: Color(0xFF5B2A86),
  textColor: Color(0xFF3B2F1E),
  buttonTextColor: Color(0xFFFFFFFF),
  menuTextColor: Color(0xFF0D3B66),
  selectionTextColor: Color(0xFFFFFFFF),
  panelBgColor: Color(0xFFFFF8E7),
  menuBgColor: Color(0xFFDCEBFA),
  selectionColor: Color(0xFF1B7F5B),
  updateMarkColor: Color(0xFFD7263D),
);

/// テーマ[theme]（`dark`＝組み込みのダーク、`custom`＝メニューが暗い
/// 自作テーマ、`readable`＝[kHomeMatrix2ReadableTheme]）で、24幅×スマホ/PCの
/// 全セルを撮るテストを言語ごとに作る。プロジェクトのタブは7言語、ほかの
/// タブ（作品一覧・共有の2つの一覧・ゴミ箱）と引き出しは
/// [kHomeMatrix2ThemeTabLanguages]の5言語。
void defineThemeMatrix(HomeMatrixRun run, String theme) {
  for (final language in kHomeMatrixLanguages) {
    final tabs = kHomeMatrix2ThemeTabLanguages.contains(language);
    testWidgets('seeded Home ($language, $theme theme): '
        '${tabs ? 'every tab and the drawer' : 'Projects'} '
        'at 24 widths x phone/PC', (tester) async {
      // フォーカスの順は色で変わらない（同じ配置の既定のテーマのセルが
      // home_matrix2_tabs・text_scaleで確かめる）。
      final m = HomeMatrix(tester, language, run)
        ..extended = true
        ..walkFocus = false;
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        if (theme == 'readable') {
          await m.applyCustomTheme(theme, kHomeMatrix2ReadableTheme);
        } else {
          await m.applyTheme(theme);
        }
        for (final pc in const [false, true]) {
          await m.setPc(pc);
          for (final w in kHomeMatrixWidths) {
            await m.resize(
              Size(
                w.toDouble(),
                pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
              ),
            );
            final boundary = kHomeMatrixBoundaryWidths.contains(w);
            await m.cell('theme', HomeView.projects, captureEnd: boundary);
            if (!tabs) continue;
            for (final view in HomeView.values.skip(1)) {
              await m.cell('theme', view, captureEnd: boundary);
            }
            await m.show(HomeView.projects);
            await m.drawerCell('theme');
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}

/// 文字の大きさ[scale]で、24幅×スマホ/PC×7言語の全タブと引き出しを撮る
/// テストを言語ごとに作る。
void defineTextScaleMatrix(HomeMatrixRun run, double scale) {
  for (final language in kHomeMatrixLanguages) {
    testWidgets('seeded Home ($language, text x$scale): every tab and the '
        'drawer at 24 widths x phone/PC', (tester) async {
      final m = HomeMatrix(tester, language, run)..extended = true;
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        await m.setTextScale(scale);
        for (final pc in const [false, true]) {
          await m.setPc(pc);
          for (final w in kHomeMatrixWidths) {
            await m.resize(
              Size(
                w.toDouble(),
                pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
              ),
            );
            // 配置が変わる境目の幅では、フォーカスの順も回して確かめる。
            final boundary = kHomeMatrixBoundaryWidths.contains(w);
            m.walkFocus = boundary;
            for (final view in HomeView.values) {
              await m.cell('scale', view, captureEnd: boundary);
            }
            await m.show(HomeView.projects);
            await m.drawerCell('scale');
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}
