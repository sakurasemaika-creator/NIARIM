import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_clipboard_harness.dart';

/// 作品一覧・共有・ゴミ箱のタブの「当たるものが無い」表示が、7言語・
/// 320/360/1280px・文字1倍/2倍で、はみ出さず、外すボタンの名前が切れず、
/// 送り出せば浮かぶボタンに重ならない（プロジェクトのタブの
/// home_filtered_empty_states_testと同じ確かめ方）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('filtered empty states of the other tabs fit in $language', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        exports: ['clip_apple.gif'],
      );
      final l10n = home.l10n;
      await home.addReceived('apple');
      final trashed = await home.addWork('pear');
      await tester.runAsync(() => home.projects.deleteProject(trashed.id));
      await home.settleIo(2);
      for (final tab in [1, 2, 3]) {
        await home.showTab(tab);
        await tester.tap(find.byKey(const Key('homeSearchButton')));
        await home.settle();
        await tester.enterText(find.byKey(const Key('homeSearchInput')), 'zzz');
        await home.settleIo(2);
        for (final width in [320.0, 360.0, 1280.0]) {
          for (final scale in [1.0, 2.0]) {
            tester.view.physicalSize = Size(width, 800);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await home.settle();
            final why = '$language tab $tab $width x$scale';
            expect(tester.takeException(), isNull, reason: why);
            final button = find.text(l10n.projectListClearSearch);
            expect(button, findsOneWidget, reason: why);
            await tester.ensureVisible(button);
            await home.settle();
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: button, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: why);
            final outlined = tester.getRect(
              find.ancestor(of: button, matching: find.byType(OutlinedButton)),
            );
            expect(outlined.left, greaterThanOrEqualTo(0), reason: why);
            expect(outlined.right, lessThanOrEqualTo(width), reason: why);
            for (final fab in find.byType(FloatingActionButton).evaluate()) {
              final box = fab.renderObject! as RenderBox;
              final rect = box.localToGlobal(Offset.zero) & box.size;
              expect(outlined.overlaps(rect), isFalse, reason: '$why $rect');
            }
          }
        }
        tester.view.physicalSize = const Size(800, 900);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await home.settle();
        await tester.tap(find.text(l10n.projectListClearSearch));
        await home.settle();
      }
      await home.close();
    });
  }
}
