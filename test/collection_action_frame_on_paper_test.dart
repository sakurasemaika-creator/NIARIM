// ホームのカードの丸い操作（星・︙）の丸は、表紙（作品の用紙。作品ごとに選ぶ
// 背景色、透明なら市松模様）の上で、その形が見分けられる（DISC241）。
//
// 丸は塗りがカードの色、縁がテーマから選ぶ縁取りの色（明るいテーマでは
// 白）で、どちらも用紙の色を見ない。組み込みの明るいテーマ（と、メニューの
// 背景が白いダークテーマ）では、白い用紙・透明な用紙の上で丸の塗りも縁も
// 用紙とAPCAの差が0になり、丸が消えて記号だけが浮いていた。
//
// 組み込みの28テーマ（と、暗いメニュー・明るい文字の自作の2テーマ）×白・黒・
// ベージュ・灰・赤・紺・黄・青・透明・半透明の用紙で、本物の丸
// （`CollectionFavoriteButton`・︙の`CollectionActionFrame`）を表紙の上に置き、
// 丸の縁で用紙と接する色（塗り・縁・外側の輪）のどれかが、用紙とAPCAで
// |Lc| 45以上（正常と1・2・3型色覚の模擬の小さい方。表紙の印と同じ、細かい
// 形のある記号の目安）離れていることを見る。丸は下の用紙を知らないので、
// 色を用紙ごとに選ぶのではなく、明るい輪と暗い輪の両方を持つ。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:niarim/widgets/frame_preview_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _papers = <String, int>{
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

const _sims = [
  ColorVisionType.protanopia,
  ColorVisionType.deuteranopia,
  ColorVisionType.tritanopia,
];

const double _needed = 45;

double _weakest(Color drawn, Color under) {
  var lc = apcaContrast(drawn, under).abs();
  for (final type in _sims) {
    final v = apcaContrast(
      simulateColorVision(drawn, type),
      simulateColorVision(under, type),
    ).abs();
    if (v < lc) lc = v;
  }
  return lc;
}

List<Color> _surfaces(int paper) {
  final color = Color(paper);
  if (color.a == 0) {
    return const [kTransparencyCheckerLight, kTransparencyCheckerDark];
  }
  if (color.a < 1) {
    return [
      Color.alphaBlend(color, kTransparencyCheckerLight),
      Color.alphaBlend(color, kTransparencyCheckerDark),
    ];
  }
  return [color];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the action circles stand out from any paper in every '
      'built-in theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await tester.runAsync(themes.init);
    final presets = <AppThemePreset>[
      ...themes.presets,
      // メニューを暗く・本文の文字を暗くした自作の色と、本文の文字を明るく・
      // メニューを白くした自作の色（ホームの表紙の印のテストと同じ）。
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
    expect(presets.length, greaterThanOrEqualTo(30));
    final problems = <String>[];
    var weakestSeen = double.infinity;
    var weakestAt = '';
    var checked = 0;
    for (final preset in presets) {
      themes.previewCurrent(preset);
      for (final MapEntry(key: name, value: paper) in _papers.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: themes.themeData,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FramePreviewBackground(backgroundColor: paper),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CollectionActionFrame(
                          key: const Key('menu'),
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.more_vert),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: CollectionFavoriteButton(
                          key: const Key('star'),
                          favorite: false,
                          tooltip: 'star',
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        for (final key in const ['menu', 'star']) {
          // 丸の形の飾り（塗り・縁・外側の輪）。
          var fill = const Color(0x00000000);
          Color? ring;
          final halos = <Color>[];
          for (final e
              in find
                  .descendant(
                    of: find.byKey(Key(key)),
                    matching: find.byType(DecoratedBox),
                  )
                  .evaluate()) {
            final decoration =
                (e.renderObject! as RenderDecoratedBox).decoration;
            if (decoration is! BoxDecoration ||
                decoration.shape != BoxShape.circle) {
              continue;
            }
            if (decoration.color case final color?) fill = color;
            final side = (decoration.border as Border?)?.top;
            if (side == null) continue;
            if (side.strokeAlign > BorderSide.strokeAlignInside) {
              halos.add(side.color);
            } else {
              ring = side.color;
            }
            for (final shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
              halos.add(shadow.color);
            }
          }
          expect(ring, isNotNull, reason: '${preset.name} $key');
          for (final under in _surfaces(paper)) {
            checked++;
            final filled = Color.alphaBlend(fill, under);
            final parts = <String, double>{
              'fill': _weakest(filled, under),
              'ring': _weakest(Color.alphaBlend(ring!, filled), under),
              for (var i = 0; i < halos.length; i++)
                'halo$i': _weakest(Color.alphaBlend(halos[i], under), under),
            };
            final best = parts.values.reduce((a, b) => a > b ? a : b);
            if (best < weakestSeen) {
              weakestSeen = best;
              weakestAt =
                  '${preset.name} $name paper $key: '
                  '${parts.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(1)}').join(', ')}';
            }
            if (best < _needed) {
              problems.add(
                '${preset.name} $name paper '
                '#${under.toARGB32().toRadixString(16)} $key: '
                '${parts.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(1)}').join(', ')}',
              );
            }
          }
        }
      }
    }
    debugPrint(
      'circle edges checked: $checked, weakest strongest-part |Lc| '
      '${weakestSeen.toStringAsFixed(1)} ($weakestAt)',
    );
    for (final p in problems) {
      debugPrint(p);
    }
    expect(problems, isEmpty, reason: '${problems.length} problems');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async => themes.dispose());
  });
}
