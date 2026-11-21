import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

// 所有者の判断6の続き：貼り付けの結果（理由ごとに行が増える）とコピー・
// 切り取りの知らせは、上の空いている所（タブの下の貼り付けの欄まで）を
// 使って全文を出す。入るのに決まった高さ（画面の4分の1）で切って中を
// スクロールさせない（文字2倍では件数の行が5秒で消える知らせの見えない
// 所に隠れていた）。入らないときだけ、空いている所いっぱいまで広げて中を
// スクロールする。貼り付けの欄は覆わない。韓国語は語の途中で折り返さない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  const sizes = [
    Size(1280, 800),
    Size(360, 760),
    Size(320, 568),
    Size(640, 360),
  ];

  /// 知らせの上端と貼り付けの欄の間に空ける幅（実装と同じ）。
  const gap = 8.0;

  /// 知らせの文の段落・スクロール・大きさを測り、決まりを確かめる。
  void checkNotice(WidgetTester tester, String where, String language) {
    final snack = tester.getRect(find.byType(SnackBar));
    final toolbar = tester.getRect(
      find.byKey(const Key('homeClipboardToolbar')),
    );
    final paragraphFinder = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      paragraphFinder.first,
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Scrollable),
      ),
    );
    final viewport = scrollable.position.viewportDimension;
    final hidden = scrollable.position.maxScrollExtent;
    // 知らせの縁（文の上下の余白・知らせの外側の余白）。
    final chrome = snack.height - viewport;
    // 知らせの下端から貼り付けの欄までに、知らせが使ってよい高さ。
    final room = snack.bottom - toolbar.bottom - gap;
    final needed = paragraph.size.height + chrome;
    debugPrint(
      '$where: notice ${snack.top.toStringAsFixed(0)}–'
      '${snack.bottom.toStringAsFixed(0)}, paste bar bottom '
      '${toolbar.bottom.toStringAsFixed(0)}, text '
      '${paragraph.size.height.toStringAsFixed(0)} in '
      '${viewport.toStringAsFixed(0)}, hidden ${hidden.toStringAsFixed(0)}, '
      'room ${room.toStringAsFixed(0)}',
    );
    expect(tester.takeException(), isNull, reason: where);
    final lineHeight = paragraph.getFullHeightForCaret(
      const TextPosition(offset: 0),
    );
    if (needed <= room) {
      expect(
        hidden,
        lessThan(0.5),
        reason:
            '$where: the notice fits above itself but hides '
            '${hidden.toStringAsFixed(0)}px of its text',
      );
    } else if (room - chrome >= lineHeight) {
      // 入らない：空いている所いっぱいまで広げる。
      expect(
        snack.top - toolbar.bottom,
        lessThanOrEqualTo(gap + 1),
        reason:
            '$where: the notice scrolls ${hidden.toStringAsFixed(0)}px '
            'although ${(snack.top - toolbar.bottom).toStringAsFixed(0)}px '
            'above it are free',
      );
    } else {
      // 1行も入らないほど低い画面：少なくとも1行は見せる。
      expect(viewport, greaterThanOrEqualTo(lineHeight - 0.5), reason: where);
    }
    if (room - chrome >= lineHeight) {
      expect(
        snack.top,
        greaterThanOrEqualTo(toolbar.bottom),
        reason: '$where: the notice covers the paste bar',
      );
    }
    final lines = ParagraphLines(paragraph);
    expect(lines.charsOutsideWidth(), isEmpty, reason: where);
    if (language == 'ko') {
      // ハングルの語の途中で行が変わっていない（語が行の頭から始まっても
      // 1行に入らないほど長いときは、途中で折るしかないので数えない）。
      final hangul = RegExp(r'[가-힣]');
      final text = lines.visible;
      final midWord = <String>[];
      for (var i = 1; i < text.length; i++) {
        final before = lines.lineOf(i - 1);
        final after = lines.lineOf(i);
        if (before == null || after == null || before == after) continue;
        if (!hangul.hasMatch(text[i - 1]) || !hangul.hasMatch(text[i])) {
          continue;
        }
        var start = i - 1;
        while (start > 0 && text[start - 1].trim().isNotEmpty) {
          start--;
        }
        final startsLine =
            start == 0 || lines.lineOf(start - 1) != lines.lineOf(start);
        if (!startsLine) midWord.add('${text[i - 1]}|${text[i]}');
      }
      expect(midWord, isEmpty, reason: '$where: ${lines.lines}');
    }
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    // 大きさが変わった次の描画で、知らせが空いている所を測り直す。
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (final language in languages) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('$language ×$scale: the paste result shows every reason '
          'when there is room', (tester) async {
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
        // cherryはゴミ箱へ（元が無い）、dateは保存できない（失敗）、boxは
        // 自分の中へ移せない。
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
          await resize(tester, size);
          checkNotice(
            tester,
            '$language ${size.width.toInt()}x${size.height.toInt()} ×$scale',
            language,
          );
        }
        await home.close();
      });
    }

    testWidgets('$language ×2.0: copy and cut notices show their whole text', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        size: sizes[2],
        textScale: 2,
        realFonts: true,
      );
      await home.addWork('apple');
      for (final cut in [false, true]) {
        if (cut) {
          await home.cut(['apple']);
        } else {
          await home.copy(['apple']);
        }
        await home.settle();
        for (final size in sizes.take(3)) {
          await resize(tester, size);
          checkNotice(
            tester,
            '$language ${cut ? 'cut' : 'copy'} '
            '${size.width.toInt()}x${size.height.toInt()} ×2.0',
            language,
          );
        }
        await resize(tester, sizes[2]);
        await tester.tap(home.clearButton);
        await home.settle();
        await home.settle();
      }
      await home.close();
    });
  }
}
