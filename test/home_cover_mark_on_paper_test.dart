import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:niarim/widgets/frame_preview_background.dart';

import 'helpers/home_matrix_harness.dart';

/// 絵の無い作品の表紙（プロジェクトのタブと、共有の「受け取ったもの」）の
/// 印は、作品の用紙（作品ごとに選ぶ背景色。透明なら市松模様）の上で読める。
/// 用紙はテーマの色ではないので、どのテーマ（組み込みの28種・自作）でも、
/// 白・黒・ベージュ・灰・赤・紺・黄・青・透明・半透明の用紙の上で、印と
/// 用紙のAPCAの差（正常と1・2・3型色覚の模擬の小さい方）が45以上ある
/// （APCAの、細かい形のある絵文字・アイコンの目安）。
///
/// 以前は「受け取ったもの」の表紙が用紙の色の上にテーマのアイコンの色で
/// 印を置き、組み込みのダークテーマでは白い用紙の上の#F5F1F0が見えなかった
/// （DISC218）。プロジェクトのタブの表紙も、テーマの本文の文字色の38%で
/// 描いていて、暗いテーマの白い用紙・明るいテーマの黒い用紙で薄かった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/home-cover-mark-on-paper'));
  setUpAll(run.prepare);

  const papers = <String, int>{
    'white': 0xFFFFFFFF,
    'black': 0xFF000000,
    'beige': 0xFFF3EAD6,
    'grey': 0xFF808080,
    'red': 0xFFFF0000,
    'navy': 0xFF1A237E,
    'yellow': 0xFFFFEB3B,
    'blue': 0xFF2196F3,
    'clear': 0x00000000,
    'half red': 0x80FF0000,
  };

  const sims = [
    ColorVisionType.protanopia,
    ColorVisionType.deuteranopia,
    ColorVisionType.tritanopia,
  ];

  double weakest(Color ink, Color under) {
    final drawn = Color.alphaBlend(ink, under);
    var lc = apcaContrast(drawn, under).abs();
    for (final type in sims) {
      final v = apcaContrast(
        simulateColorVision(drawn, type),
        simulateColorVision(under, type),
      ).abs();
      if (v < lc) lc = v;
    }
    return lc;
  }

  /// [icon]の下の色（用紙の見本なら、透明な所の市松模様の2色も）。
  List<Color> paperUnder(Element icon) {
    final fills = <Color>[];
    List<Color>? found;
    icon.visitAncestorElements((a) {
      final w = a.widget;
      if (w is FramePreviewBackground) {
        final paper = Color(w.backgroundColor);
        if (w.showTransparency || paper.a == 0) {
          found = const [kTransparencyCheckerLight, kTransparencyCheckerDark];
        } else if (paper.a < 1) {
          found = [
            Color.alphaBlend(paper, kTransparencyCheckerLight),
            Color.alphaBlend(paper, kTransparencyCheckerDark),
          ];
        } else {
          found = [paper];
        }
        return false;
      }
      final fill = switch (w) {
        ColoredBox(:final color) => color,
        Card(:final color?) => color,
        Material(:final color?) => color,
        _ => null,
      };
      if (fill != null && fill.a > 0) {
        fills.add(fill);
        if (fill.a >= 1) return false;
      }
      return true;
    });
    if (found != null) return found!;
    var under = fills.last;
    for (final f in fills.reversed.skip(1)) {
      under = Color.alphaBlend(f, under);
    }
    return [under];
  }

  testWidgets('a cover without a picture shows its mark on any paper in any '
      'theme (Projects and received shares)', (tester) async {
    final m = HomeMatrix(tester, 'ja', run);
    await m.begin();
    final problems = <String>{};
    final seen = <String, int>{};
    try {
      await m.start();
      await tester.runAsync(() async {
        for (final entry in papers.entries) {
          final project = await m.projects.createProject(
            name: entry.key,
            fps: 12,
            durationSeconds: 1,
            backgroundColor: entry.value,
            exportWidth: 640,
            exportHeight: 360,
          );
          final saved = await m.projects.createOutgoingShare(project: project);
          final data = await NiaproSerializer.loadShare(saved.path);
          await m.projects.importSharedProject(data);
        }
      });
      await m.frames(4);
      await m.settleIo();
      // どの表紙も一度に画面に入る高さ。
      await m.resize(const Size(1280, 2400));

      final themes = <AppThemePreset>[
        ...m.themes.presets,
        // メニューを暗く・本文の文字を暗くした自作の色（マトリクスの
        // customdark）と、本文の文字を明るく・用紙を暗くした自作の色。
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
          name: 'light text',
          accentColor: Color(0xFFFFB74D),
          textColor: Color(0xFFFFFFFF),
          buttonTextColor: Color(0xFF000000),
          menuTextColor: Color(0xFF000000),
          selectionTextColor: Color(0xFF000000),
          panelBgColor: Color(0xFF202020),
          menuBgColor: Color(0xFFFFFFFF),
          selectionColor: Color(0xFFFFB74D),
          updateMarkColor: Color(0xFFE0A100),
        ),
      ];
      expect(themes.length, greaterThanOrEqualTo(30));
      for (final theme in themes) {
        m.themes.previewCurrent(theme);
        await m.frames(4);
        for (final (view, glyph) in const [
          (HomeView.projects, Icons.image),
          (HomeView.sharedReceived, Icons.movie_creation_outlined),
        ]) {
          await m.show(view);
          final icons = find.descendant(
            of: find.byType(TabBarView),
            matching: find.byWidgetPredicate(
              (w) => w is Icon && w.icon == glyph,
            ),
          );
          var count = 0;
          for (final e in icons.evaluate()) {
            final icon = e.widget as Icon;
            final ink =
                icon.color ??
                IconTheme.of(e).color!.withValues(
                  alpha:
                      IconTheme.of(e).color!.a * (IconTheme.of(e).opacity ?? 1),
                );
            final unders = paperUnder(e);
            count++;
            for (final under in unders) {
              final lc = weakest(ink, under);
              if (lc < 45) {
                problems.add(
                  '${theme.name} ${view.name}: '
                  '#${ink.toARGB32().toRadixString(16)} on '
                  '#${under.toARGB32().toRadixString(16)} '
                  '(weakest |Lc| ${lc.toStringAsFixed(1)})',
                );
              }
            }
          }
          seen[view.name] = count;
          if (theme.id == 'default_light' ||
              theme.id == AppThemePreset.defaultDark.id ||
              theme.name == 'dark menu') {
            await m.capture(
              'covers_${theme.id == ThemeService.customCurrentId ? theme.name : theme.id}_${view.name}'
                  .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_'),
            );
          }
        }
      }
    } finally {
      debugDisableShadows = true;
    }
    debugPrint('covers checked per theme: $seen');
    expect(problems, isEmpty, reason: problems.join('\n'));
    // 10枚の用紙のどれも表紙として出た。
    expect(seen['projects'], papers.length);
    expect(seen['sharedReceived'], papers.length);
    expect(tester.takeException(), isNull);
  });

  test('the mark keeps APCA |Lc| 45 on every opaque paper colour', () {
    var worst = 1000.0;
    String? where;
    for (var r = 0; r <= 255; r += 17) {
      for (var g = 0; g <= 255; g += 17) {
        for (var b = 0; b <= 255; b += 17) {
          final paper = 0xFF000000 | (r << 16) | (g << 8) | b;
          final lc = weakest(paperMarkColor(paper), Color(paper));
          if (lc < worst) {
            worst = lc;
            where = paper.toRadixString(16);
          }
        }
      }
    }
    expect(worst, greaterThanOrEqualTo(45), reason: 'on #$where');
    // 透明な用紙は、市松模様のどちらの色の上でも。半透明の用紙は、市松模様の
    // 2色が中ほどの明るさに分かれ、1つの印の色で両方に45を取れないことが
    // ある（25%の黒で44.4）ので、その中でいちばん読める色（40以上）。
    for (final (paper, least) in const [
      (0x00000000, 45.0),
      (0x80FF0000, 40.0),
      (0x40000000, 40.0),
      (0x80000000, 40.0),
      (0x80FFFFFF, 40.0),
    ]) {
      for (final square in const [
        kTransparencyCheckerLight,
        kTransparencyCheckerDark,
      ]) {
        final under = Color.alphaBlend(Color(paper), square);
        expect(
          weakest(paperMarkColor(paper), under),
          greaterThanOrEqualTo(least),
          reason: '#${paper.toRadixString(16)} over $square',
        );
      }
    }
    // ふつうの用紙では、目立ちすぎない控えめな濃さのまま。
    expect(paperMarkColor(0xFFFFFFFF), Colors.black.withValues(alpha: 0.6));
    expect(paperMarkColor(0xFF000000), Colors.white.withValues(alpha: 0.7));
  });
}
