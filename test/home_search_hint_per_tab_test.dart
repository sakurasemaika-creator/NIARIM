import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers/home_keyboard_harness.dart';

/// ホームの検索欄のヒントは、開いているタブで何を探すかを言う（プロジェクト・
/// 書き出した作品・共有ファイル・ゴミ箱の中）。どの言語・幅・文字の大きさでも、
/// いつもの大きさのまま1行に入るときだけ字を出し、入らないときは字を縮めず
/// 「…」で切らず、探す物の印（読み上げはヒントの文）だけにする（所有者の判断、
/// 2026-11-16）。字も印も上部バーの中に収まる（タブの列に重ならない）。PCの
/// 幅ではどの言語も字が出る。
///
/// 以前は作品一覧・共有・ゴミ箱のタブでも「プロジェクト名で検索」と出た
/// （DISC201）。仏語の360ではゴミ箱のタブでも「Rechercher par nom …」と切れた。
void main() {
  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  // タブごとのヒントのARBのキー（プロジェクトは今までの「プロジェクト名で検索」）。
  const keys = [
    'homeSearchHint',
    'homeSearchHintWorks',
    'homeSearchHintShared',
    'homeSearchHintTrash',
  ];

  String? arb(String language, String key) =>
      (jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
              as Map<String, dynamic>)[key]
          as String?;

  for (final language in languages) {
    for (final (width, scale) in const [
      (320, 1.0),
      (360, 1.0),
      (360, 2.0),
      (1280, 1.0),
    ]) {
      testWidgets('$language $width x$scale: the search hint names what each '
          'tab searches, at full size or as an icon, never cut', (
        tester,
      ) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: Size(width.toDouble(), 740),
          textScale: scale,
          works: 1,
        );
        final semantics = tester.ensureSemantics();
        final problems = <String>[];
        final hints = <String>[];
        for (var tab = 0; tab < 4; tab++) {
          await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
          await home.settle();
          await tester.tap(find.byKey(const Key('homeSearchButton')));
          await home.settle();
          final field = tester.widget<TextField>(
            find.byKey(const Key('homeSearchInput')),
          );
          final decoration = field.decoration!;
          final hintText = decoration.hintText;
          final hintIcon = decoration.hint;
          // 字のときはその字、印のときは読み上げの文がヒント。
          final hint =
              hintText ?? (hintIcon is Icon ? hintIcon.semanticLabel : null);
          hints.add(hint ?? '');
          final expected = arb(language, keys[tab]);
          if (expected == null) {
            problems.add('tab $tab: no ARB text ${keys[tab]}');
          } else if (hint != expected) {
            problems.add('tab $tab: hint "$hint", expected "$expected"');
          }
          // 字を縮めない（大きさは渡さない）。
          final hintSize = decoration.hintStyle?.fontSize;
          if (hintSize != null) {
            problems.add('tab $tab: hint font size changed to $hintSize');
          }
          // PCの幅では字が出る（印だけになるのは入らない幅だけ）。
          if (width >= 1280 && hintText == null) {
            problems.add('tab $tab: only an icon at $width');
          }
          final tabs = tester.getRect(find.byType(TabBar));
          if (hintText != null) {
            final shown = find.descendant(
              of: find.byType(AppBar),
              matching: find.text(hintText),
            );
            if (shown.evaluate().isEmpty) {
              problems.add('tab $tab: hint "$hint" not drawn');
            } else {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: shown, matching: find.byType(RichText)),
              );
              final rect = tester.getRect(shown);
              // 字を出すときは1行に全部入る（「…」で切らない）。
              if (paragraph.didExceedMaxLines) {
                problems.add('tab $tab: hint "$hint" cut at $rect');
              }
              if (rect.bottom > tabs.top + 2 || rect.top < 0) {
                problems.add(
                  'tab $tab: hint $rect leaves the bar (tabs $tabs)',
                );
              }
            }
          } else if (hintIcon is! Icon) {
            problems.add('tab $tab: neither hint text nor an icon');
          } else {
            final shown = find.descendant(
              of: find.byKey(const Key('homeSearchInput')),
              matching: find.byIcon(hintIcon.icon!),
            );
            if (shown.evaluate().isEmpty) {
              problems.add('tab $tab: hint icon not drawn');
            } else {
              final rect = tester.getRect(shown.first);
              if (rect.bottom > tabs.top + 2 || rect.top < 0) {
                problems.add(
                  'tab $tab: hint icon $rect leaves the bar (tabs $tabs)',
                );
              }
            }
            if (find.bySemanticsLabel(expected ?? '').evaluate().isEmpty) {
              problems.add('tab $tab: the icon does not read "$expected"');
            }
          }
          // 打ち始めたら、打った字の行は隣のボタン（検索を閉じる）と縦の
          // 真ん中がそろう（折り返したヒントの1行目の高さに残らない）。
          await tester.enterText(
            find.byKey(const Key('homeSearchInput')),
            'zzqx',
          );
          await home.settle();
          final typed = tester.getRect(
            find.descendant(
              of: find.byKey(const Key('homeSearchInput')),
              matching: find.byType(EditableText),
            ),
          );
          final closeButton = tester.getRect(
            find.byKey(const Key('homeSearchCloseButton')),
          );
          if ((typed.center.dy - closeButton.center.dy).abs() > 2) {
            problems.add(
              'tab $tab: typed line $typed is not level with the close '
              'button $closeButton',
            );
          }
          await tester.enterText(find.byKey(const Key('homeSearchInput')), '');
          await home.settle();
          // 確かめに見る画面（build/home-search-hints/、上部バーとタブ）。
          final shot = await home.shot();
          final image = img.copyCrop(
            img.Image.fromBytes(
              width: shot.width,
              height: shot.height,
              bytes: shot.rgba.buffer,
              numChannels: 4,
            ),
            x: 0,
            y: 0,
            width: shot.width,
            height: 112,
          );
          Directory('build/home-search-hints').createSync(recursive: true);
          File(
            'build/home-search-hints/${language}_${width}_x${scale}_tab$tab.png',
          ).writeAsBytesSync(img.encodePng(image));
          await tester.tap(find.byKey(const Key('homeSearchCloseButton')));
          await home.settle();
        }
        if (hints.toSet().length != 4) {
          problems.add('the four tabs do not have four hints: $hints');
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await home.close();
      });
    }
  }
}
