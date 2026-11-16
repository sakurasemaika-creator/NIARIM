import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers/home_keyboard_harness.dart';

/// 狭い画面（320px）でホームの引き出しを開いても、外側に押して閉じられる幕が
/// 少なくとも56px残る（引き出しの幅を画面の幅から決める）。普通のスマホ
/// （360px以上）とPCは今までどおり304px。引き出しの中の項目・見出しは切れず、
/// はみ出さない。7言語×320（文字1倍・2倍）・360・1280。
///
/// 以前はMaterialの既定の304pxのままで、320pxの画面では外側が約16pxしか残らず、
/// 外を押して閉じにくかった（DISC142）。
void main() {
  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  for (final (width, scale) in const [
    (320, 1.0),
    (320, 2.0),
    (360, 1.0),
    (1280, 1.0),
  ]) {
    for (final language in languages) {
      testWidgets('$language $width x$scale: the drawer leaves room outside '
          'and its items fit', (tester) async {
        final size = Size(width.toDouble(), width > 600 ? 800 : 740);
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: size,
          textScale: scale,
          prefs: {'force_pc_mode': width > 600 ? 1 : 0},
        );
        final problems = <String>[];
        await tester.tap(find.byKey(const Key('homeMenuButton')));
        await home.settle();
        final drawer = find.byType(Drawer);
        expect(drawer, findsOneWidget);
        final rect = tester.getRect(drawer);
        final outside = size.width - rect.width;
        if (width < 360) {
          if (outside < 56) {
            problems.add(
              'only ${outside}px outside the ${rect.width}px drawer',
            );
          }
        } else if (rect.width != 304) {
          problems.add('drawer ${rect.width}px wide on a ${width}px screen');
        }
        // 引き出しの中の文字は切れず、引き出しからはみ出さない。
        for (final e
            in find
                .descendant(of: drawer, matching: find.byType(RichText))
                .evaluate()) {
          final paragraph = e.renderObject;
          if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
          // 描いた文（語結合子を含む。読み上げの文ではない）。
          final text = paragraph.text.toPlainText(
            includeSemanticsLabels: false,
          );
          if (text.trim().isEmpty) continue;
          final box = tester.getRect(find.byWidget(e.widget));
          if (paragraph.didExceedMaxLines) {
            problems.add('"${text.replaceAll('\u2060', '')}" is cut');
          }
          // 韓国語は語（空白で区切った所）の途中で行を変えない。
          if (language == 'ko') {
            int? previous;
            double? previousTop;
            for (var i = 0; i < text.length; i++) {
              if (text[i] == ' ' || text[i] == '\u2060') continue;
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1),
              );
              if (boxes.isEmpty) continue;
              final top = boxes.first.top;
              // 次の行（同じ行の中の字の高さの違いは数px）。
              if (previous != null &&
                  top > previousTop! + 8 &&
                  !text.substring(previous, i).contains(' ')) {
                problems.add('"$text" breaks a word at $i');
              }
              previous = i;
              previousTop = top;
            }
          }
          if (box.left < rect.left - 0.5 || box.right > rect.right + 0.5) {
            problems.add('"$text" $box leaves the drawer $rect');
          }
        }
        final shot = await home.shot();
        Directory('build/home-drawer-width').createSync(recursive: true);
        File(
          'build/home-drawer-width/${language}_${width}_x$scale.png',
        ).writeAsBytesSync(
          img.encodePng(
            img.Image.fromBytes(
              width: shot.width,
              height: shot.height,
              bytes: shot.rgba.buffer,
              numChannels: 4,
            ),
          ),
        );
        // 外側（幕）を押すと閉じる。
        await tester.tapAt(Offset(outside / 2, size.height / 2));
        await home.settle();
        await tester.pump(const Duration(milliseconds: 400));
        if (find.byType(Drawer).hitTestable().evaluate().isNotEmpty) {
          problems.add('tapping outside did not close the drawer');
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
