import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/app_locale.dart';

import 'helpers/home_clipboard_harness.dart';

// 所有者の判断6「件数内訳を出して正常に貼り付けられているかわかるように
// しましょう。」：貼り付けた件数と、貼り付けられなかった理由ごとの件数を
// 出す。貼り付けられない物があっても止めずに残りを貼り付け、元が無くなった
// 物はクリップボードから外す（同じ失敗を繰り返さない）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  // 貼り付けられなかった理由の文（件数つき）。
  String reason(AppLocalizations l10n, String key, int count) =>
      switch (key) {
            'favorite' => (l10n as dynamic).homePasteSkippedFavorite(count),
            'failed' => (l10n as dynamic).homePasteSkippedFailed(count),
            'partial' => (l10n as dynamic).homePasteSkippedPartial(count),
            _ => throw ArgumentError(key),
          }
          as String;

  Future<void> trashFromMenu(HomeClipboardHarness home, String name) async {
    await home.tester.tap(home.card(name), buttons: kSecondaryMouseButton);
    await home.settle();
    await home.tester.tap(find.text(home.l10n.projectDetailTrashMenuItem));
    await home.waitFor(
      () => home.projects.trash.any((p) => p.name == name),
      reason: '$name was not moved to the Trash',
    );
    await home.settle();
  }

  /// 貼り付けた結果の知らせの文（出るまで待つ）。
  Future<String> pasteResult(HomeClipboardHarness home) async {
    final l10n = home.l10n;
    // 件数の後ろの文（日本語の画面で調べる）。
    String tail(String withNine) => withNine.split('9').last;
    final notResults = [
      tail(l10n.homeCopiedSnackbar(9)),
      tail(l10n.homeCutSnackbar(9)),
      tail(l10n.homeMovedToTrashSnackbar(9)),
    ];
    bool isResult(String? text) =>
        text != null && !notResults.any(text.endsWith);
    await home.waitFor(() => isResult(home.snackText()));
    return home.snackText()!;
  }

  /// [id]の作品の保存を失敗させる（.niaproの所をフォルダにする）。戻す関数を
  /// 返す。
  Future<void Function()> breakSave(WidgetTester tester, String id) async {
    final base = (await tester.runAsync(NiaproSerializer.projectsBasePath))!;
    final file = File('$base/$id/$id.niapro');
    final aside = File('${file.path}.aside');
    file.renameSync(aside.path);
    Directory(file.path).createSync();
    File('${file.path}/keep').writeAsStringSync('x');
    return () {
      Directory(file.path).deleteSync(recursive: true);
      aside.renameSync(file.path);
    };
  }

  testWidgets('a copy whose middle work went to the Trash pastes the rest, '
      'says how many, and drops the missing work', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    for (final name in ['apple', 'banana', 'cherry']) {
      await home.addWork(name);
    }
    await home.copy(['apple', 'banana', 'cherry']);
    await trashFromMenu(home, 'banana');
    await home.paste();
    final l10n = home.l10n;
    final text = await pasteResult(home);
    debugPrint('paste result: $text');
    expect(home.projects.projects.map((p) => p.name).toSet(), {
      'apple',
      'cherry',
      l10n.projectDuplicateName('apple'),
      l10n.projectDuplicateName('cherry'),
    }, reason: 'the paste stopped at the missing work');
    expect(text.split('\n'), [
      l10n.homePastedSnackbar(2),
      l10n.homePasteSkippedMissing(1),
    ]);
    // 無くなった作品はクリップボードから外れる（もう一度貼っても同じ失敗を
    // 繰り返さない）。
    expect(
      find.text(l10n.homeClipboardCopiedStatus(2)),
      findsOneWidget,
      reason: 'the missing work stayed on the clipboard',
    );
    await home.settleIo(2);
    await home.paste();
    await home.waitFor(
      () => home.snackText() == l10n.homePastedSnackbar(2),
      reason: 'the second paste did not say "${l10n.homePastedSnackbar(2)}"',
    );
    expect(home.projects.projects, hasLength(6));
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a cut pasted into one of its folders moves the rest and says '
      'why each other item stayed', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final box = await home.addFolder('box');
    for (final name in ['apple', 'cherry']) {
      await home.addWork(name);
    }
    await home.cut(['box', 'apple', 'cherry']);
    await trashFromMenu(home, 'cherry');
    await tester.tap(home.card('box'));
    await home.settleIo(3);
    await home.paste();
    final l10n = home.l10n;
    final text = await pasteResult(home);
    debugPrint('paste result: $text');
    final apple = home.projects.projects.singleWhere((p) => p.name == 'apple');
    expect(apple.folderId, box.id, reason: 'apple was not moved');
    expect(home.projects.folders.single.parentFolderId, isNull);
    expect(text.split('\n'), [
      l10n.homePastedSnackbar(1),
      l10n.homePasteSkippedMissing(1),
      l10n.homePasteSkippedIntoSelf(1),
    ]);
    // 自分の中へ移せなかったフォルダは切り取ったまま残る。
    expect(find.text(l10n.homeClipboardCutStatus(1)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a cut work that cannot be saved is counted, stays cut, and '
      'pastes once it can be saved', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final box = await home.addFolder('box');
    await home.addWork('apple');
    final banana = await home.addWork('banana');
    await home.cut(['apple', 'banana']);
    final restore = await breakSave(tester, banana.id);
    await tester.tap(home.card('box'));
    await home.settleIo(3);
    await home.paste();
    final l10n = home.l10n;
    final text = await pasteResult(home);
    debugPrint('paste result: $text');
    expect(
      home.projects.projects.singleWhere((p) => p.name == 'apple').folderId,
      box.id,
    );
    expect(
      home.projects.projects.singleWhere((p) => p.name == 'banana').folderId,
      isNull,
    );
    expect(text.split('\n'), [
      l10n.homePastedSnackbar(1),
      reason(l10n, 'failed', 1),
    ]);
    expect(find.text(l10n.homeClipboardCutStatus(1)), findsOneWidget);
    restore();
    await home.settleIo(2);
    await home.paste();
    await home.waitFor(
      () => home.snackText() == l10n.homePastedSnackbar(1),
      reason: 'the second paste did not say "${l10n.homePastedSnackbar(1)}"',
    );
    expect(
      home.projects.projects.singleWhere((p) => p.name == 'banana').folderId,
      box.id,
    );
    expect(home.pasteButton, findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('pasting into the Trash moves the rest and counts the '
      'favorite that stays', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    final banana = await home.addWork('banana');
    await home.addWork('cherry');
    await tester.runAsync(() => home.projects.setFavorite(banana.id, true));
    await home.settleIo(2);
    await home.copy(['banana', 'apple', 'cherry']);
    await home.showTab(3);
    await tester.tap(home.pasteButton);
    await home.settle();
    await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
    final l10n = home.l10n;
    final text = await pasteResult(home);
    debugPrint('paste result: $text');
    expect(home.projects.trash.map((p) => p.name).toSet(), {'apple', 'cherry'});
    expect(text.split('\n'), [
      l10n.homePastedSnackbar(2),
      reason(l10n, 'favorite', 1),
    ]);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a paste that succeeds says how many were pasted', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await home.addFolder('box');
    await home.copy(['apple', 'box']);
    await home.paste();
    expect(await pasteResult(home), home.l10n.homePastedSnackbar(2));
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a copied received work that is gone is dropped from the '
      'clipboard and counted', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final walk = await home.addReceived('Walk');
    await home.showTab(2);
    await tester.longPress(find.text('Walk').first);
    await home.settle();
    await home.copySelection();
    await tester.runAsync(() => home.projects.deleteProject(walk.id));
    await home.settleIo(2);
    await home.paste();
    final l10n = home.l10n;
    expect(await pasteResult(home), l10n.homePasteSkippedMissing(1));
    expect(home.pasteButton, findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // ICUの複数形で、どの言語でも「item(s)」のような書き方をしない。
  test('the paste result sentences use plural forms in every language', () {
    for (final language in languages) {
      final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
      final sentences = [
        for (final count in [1, 2, 5])
          for (final sentence in [
            l10n.homePastedSnackbar(count),
            l10n.homePasteSkippedMissing(count),
            l10n.homePasteSkippedIntoSelf(count),
            reason(l10n, 'favorite', count),
            reason(l10n, 'failed', count),
            reason(l10n, 'partial', count),
          ])
            (count, sentence),
      ];
      for (final (count, sentence) in sentences) {
        expect(sentence, contains('$count'), reason: '$language: $sentence');
        expect(
          sentence,
          isNot(matches(RegExp(r'\((s|es|e|x)\)'))),
          reason: '$language uses a (s) form: $sentence',
        );
      }
      if (language == 'en') {
        expect(l10n.homePastedSnackbar(1), 'Pasted 1 item.');
        expect(l10n.homePastedSnackbar(2), 'Pasted 2 items.');
      }
    }
  });
}
