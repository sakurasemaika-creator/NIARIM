import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

// 貼り付けの結果の知らせ（理由ごとに行が増える）が、7言語・幅320/360/1280・
// 文字の大きさ1倍/2倍で、はみ出さず・切れず・語の途中で折れず、貼り付けの
// 欄（切り取ったまま残したフォルダを貼る所）を覆わない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  // 幅1280・360・320の画面と、高さの低い横向き（640x360）。
  const sizes = [
    Size(1280, 800),
    Size(360, 760),
    Size(320, 568),
    Size(640, 360),
  ];

  for (final language in languages) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets(
        '$language ×$scale: the paste result with every reason fits',
        (tester) async {
          final home = await HomeClipboardHarness.open(
            tester,
            language: language,
            size: sizes.first,
            textScale: scale,
            realFonts: true,
          );
          await home.addFolder('box');
          await home.addWork('apple');
          await home.addWork('cherry');
          final date = await home.addWork('date');
          await home.cut(['box', 'apple', 'cherry', 'date']);
          // cherryはゴミ箱へ（元が無い）、dateは保存できない（失敗）。
          await tester.tap(home.card('cherry'), buttons: kSecondaryMouseButton);
          await home.settle();
          await tester.tap(find.text(home.l10n.projectDetailTrashMenuItem));
          await home.waitFor(() => home.projects.trash.isNotEmpty);
          final base = (await tester.runAsync(
            NiaproSerializer.projectsBasePath,
          ))!;
          final file = File('$base/${date.id}/${date.id}.niapro');
          file.renameSync('${file.path}.aside');
          Directory(file.path).createSync();
          File('${file.path}/keep').writeAsStringSync('x');
          await tester.tap(home.card('box'));
          await home.settleIo(3);
          await home.paste();
          final l10n = home.l10n;
          final expected = [
            l10n.homePastedSnackbar(1),
            l10n.homePasteSkippedMissing(1),
            l10n.homePasteSkippedIntoSelf(1),
            l10n.homePasteSkippedFailed(1),
          ].join('\n');
          await home.waitFor(() => home.snackText() == expected);
          await home.settle();

          for (final size in sizes) {
            tester.view.physicalSize = size;
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 16));
            final where =
                '$language ${size.width.toInt()}x'
                '${size.height.toInt()} ×$scale';
            expect(tester.takeException(), isNull, reason: where);
            final snack = tester.getRect(find.byType(SnackBar));
            final toolbar = tester.getRect(
              find.byKey(const Key('homeClipboardToolbar')),
            );
            debugPrint(
              '$where: notice ${snack.top.toStringAsFixed(0)}–'
              '${snack.bottom.toStringAsFixed(0)}, paste bar bottom '
              '${toolbar.bottom.toStringAsFixed(0)}',
            );
            // 高さの低い横向き（640x360）は、上のバー・貼り付けの欄・浮かぶ
            // ボタンの間が120pxほどしか無く、4つの理由を出すと文字1倍でも
            // 欄に数px重なる（知らせの中はスクロールする）。測って残すだけ。
            if (size.height >= 568) {
              expect(
                snack.top,
                greaterThanOrEqualTo(toolbar.bottom),
                reason: '$where: the notice covers the paste bar',
              );
            }
            expect(snack.bottom, lessThanOrEqualTo(size.height), reason: where);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byType(SnackBar),
                matching: find.text(expected),
              ),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: where);
            final lines = ParagraphLines(paragraph);
            expect(lines.charsOutsideWidth(), isEmpty, reason: where);
            if (const ['en', 'es', 'fr'].contains(language)) {
              // 空白で区切った語の途中で行が変わっていない。
              final text = lines.visible;
              final midWord = <String>[];
              for (var i = 1; i < text.length; i++) {
                final before = lines.lineOf(i - 1);
                final after = lines.lineOf(i);
                if (before == null || after == null || before == after) {
                  continue;
                }
                if (RegExp(
                      r'[\p{L}\p{N}]',
                      unicode: true,
                    ).hasMatch(text[i - 1]) &&
                    RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text[i])) {
                  midWord.add('${text[i - 1]}|${text[i]}');
                }
              }
              expect(midWord, isEmpty, reason: '$where: ${lines.lines}');
            }
          }
          expect(tester.takeException(), isNull);
          await home.close();
        },
      );
    }
  }
}
