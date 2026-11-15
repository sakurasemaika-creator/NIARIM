import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';

import 'helpers/home_matrix_harness.dart';

/// 作品一覧のカードで、絵を出さない作品の表紙（exportedWorkThumbnailArea）の
/// 種類の印は、その表紙の面（用紙側の色 surfaceContainerHighest：パネルの
/// 背景色を本文の文字色へ寄せた色）の文字色の役目（本文の文字色、
/// onSurface。作品一覧の共有ファイルの表紙の印と同じ）で描く。どの組み込みテーマ（28種）でも、メニューと本文の
/// 色が違う自作テーマでも、印は面の上で見える（アプリの読める色の判定
/// isEssentialTextNearlyInvisible）。カードの名前・日付はカードの面
/// （メニューの背景色）の上なので、メニューの文字色のまま。
///
/// 以前は印をメニューの文字色で描き、メニューを暗く・メニューの文字を明るく
/// した自作テーマ（#EDEFF2 on #E2E0D9、Lc −7.5）で見えなかった（DISC219）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/home-works-cover-icon'));
  setUpAll(run.prepare);

  for (final grid in const [true, false]) {
    testWidgets('a Works card without a picture draws its kind mark in the '
        'cover surface\'s ink (${grid ? 'grid' : 'detail'})', (tester) async {
      final m = HomeMatrix(tester, 'ja', run);
      await m.begin();
      final problems = <String>{};
      var checked = 0;
      try {
        await m.start();
        await tester.runAsync(() async {
          final exports = await ExportStorage.createManagedDirectory();
          for (final name in const [
            'walk_cycle.mp4',
            'teaser.webm',
            'loop_take_02.mp4',
          ]) {
            File(
              '${exports.path}/$name',
            ).writeAsBytesSync(List<int>.filled(512, 1));
          }
          ExportStorage.invalidate();
          await ExportEngine.listExportedFiles(forceRefresh: true);
        });
        await m.frames(4);
        await m.settleIo();
        await m.resize(const Size(1280, 1200));
        if (!grid) {
          // 作品一覧のタブで、表示サイズを「詳細」にする。
          await m.show(HomeView.works);
          await tester.tap(find.byType(ProjectViewModeMenu));
          await m.frames(6);
          await tester.tap(
            find
                .byType(PopupMenuItem<ProjectViewMode>)
                .at(ProjectViewMode.detail.index),
          );
          await m.frames(6);
        }
        final themes = <AppThemePreset>[
          ...m.themes.presets,
          const AppThemePreset(
            id: ThemeService.customCurrentId,
            name: 'dark menu',
            accentColor: Color(0xFF2E7D6B),
            textColor: Color(0xFF1F2328),
            buttonTextColor: Color(0xFFFFFFFF),
            menuTextColor: Color(0xFFEDEFF2),
            selectionTextColor: Color(0xFFFFFFFF),
            panelBgColor: Color(0xFFF7F4EC),
            menuBgColor: Color(0xFF1E2430),
            selectionColor: Color(0xFF2E7D6B),
            updateMarkColor: Color(0xFFE0A100),
          ),
          const AppThemePreset(
            id: ThemeService.customCurrentId,
            name: 'light menu',
            accentColor: Color(0xFFFFB74D),
            textColor: Color(0xFFF2F2F2),
            buttonTextColor: Color(0xFF000000),
            menuTextColor: Color(0xFF15171A),
            selectionTextColor: Color(0xFF000000),
            panelBgColor: Color(0xFF1B1D21),
            menuBgColor: Color(0xFFF7F7F2),
            selectionColor: Color(0xFFFFB74D),
            updateMarkColor: Color(0xFFE0A100),
          ),
        ];
        for (final theme in themes) {
          m.themes.previewCurrent(theme);
          await m.frames(4);
          await m.show(HomeView.works);
          final scheme = Theme.of(
            tester.element(find.byType(ExportedWorkCard).first),
          ).colorScheme;
          for (final area
              in find
                  .byKey(const Key('exportedWorkThumbnailArea'))
                  .evaluate()) {
            final box = area.widget as ColoredBox;
            final icons = find.descendant(
              of: find.byWidget(area.widget),
              matching: find.byType(Icon),
            );
            for (final e in icons.evaluate()) {
              final icon = e.widget as Icon;
              final ink = icon.color ?? IconTheme.of(e).color!;
              final drawn = Color.alphaBlend(ink, box.color);
              checked++;
              if (box.color != scheme.surfaceContainerHighest) {
                problems.add('${theme.name}: the cover is not the cover role');
              }
              if (ink != scheme.onSurface) {
                problems.add(
                  '${theme.name}: mark #${ink.toARGB32().toRadixString(16)} '
                  'is not the cover surface\'s ink '
                  '#${scheme.onSurface.toARGB32().toRadixString(16)}',
                );
              }
              if (isEssentialTextNearlyInvisible(drawn, box.color)) {
                problems.add(
                  '${theme.name}: #${drawn.toARGB32().toRadixString(16)} on '
                  '#${box.color.toARGB32().toRadixString(16)} '
                  '(Lc ${apcaContrast(drawn, box.color).toStringAsFixed(1)})',
                );
              }
            }
          }
          if (theme.id == ThemeService.customCurrentId) {
            await m.capture(
              'works_${grid ? 'grid' : 'detail'}_'
              '${theme.name.replaceAll(' ', '_')}',
            );
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      debugPrint('marks checked: $checked');
      expect(problems, isEmpty, reason: problems.join('\n'));
      // 30のテーマで、3つの作品の表紙の印。
      expect(checked, 30 * 3);
      expect(tester.takeException(), isNull);
    });
  }
}
