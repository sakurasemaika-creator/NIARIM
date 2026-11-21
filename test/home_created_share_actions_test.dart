import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/utils/duplicate_name.dart' show copyNameIn;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/home_clipboard_harness.dart';

/// 共有の「自分が作成したもの」（.niashare）の名前の変更と複製を、作品・
/// フォルダと同じ決まりにする。
/// - 名前の変更：空白だけの名前は確定させない（以前は黙って何もせず閉じた）。
///   同じ名前のファイルがあるときは、ダイアログの中に理由を出して開いたまま
///   （以前は閉じて、ゴミ箱の失敗の文を後ろに出した）。入力欄は閉じる動きの
///   途中に破棄しない（NameEntryDialogが持つ）。
/// - 複製：画面の言語の「(コピー)」と番号（「mine (copy).niashare」
///   「mine (copy 2).niashare」）。以前はどの言語でも「mine (1).niashare」。
/// - 名前を変えても、お気に入りとコピーしたもの（クリップボード）は新しい
///   名前のファイルについていく（お気に入りはファイルの場所で覚えるので、
///   以前は外れ、保存した設定に古い場所が残った）。
/// - 同じタブの「受け取ったもの」の名前の変更も同じダイアログ（以前は
///   空白だけの名前で黙って閉じ、確定のボタンは「保存」だった）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(HomeClipboardHarness, File)> openWithShare(
    WidgetTester tester, {
    String language = 'ja',
    List<String> others = const [],
  }) async {
    final home = await HomeClipboardHarness.open(tester, language: language);
    final dir = Directory('${home.dir.path}/niarim/shared/outgoing')
      ..createSync(recursive: true);
    final file = File('${dir.path}/mine.niashare')
      ..writeAsBytesSync(List.filled(64, 1));
    for (final name in others) {
      File('${dir.path}/$name.niashare').writeAsBytesSync(List.filled(64, 2));
    }
    await tester.runAsync(() => home.projects.refreshOutgoingShares());
    await home.settleIo(2);
    await home.showTab(2);
    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await home.settleIo(2);
    return (home, file);
  }

  Future<void> choose(
    HomeClipboardHarness home,
    File file,
    String label,
  ) async {
    await home.tester.tap(
      find.byKey(ValueKey('outgoingShareMenu_${file.path}')),
    );
    await home.settle();
    await home.tester.tap(find.text(label).last);
    await home.settle();
  }

  Set<String> sharesIn(HomeClipboardHarness home) => {
    for (final entity in Directory(
      '${home.dir.path}/niarim/shared/outgoing',
    ).listSync())
      entity.uri.pathSegments.last,
  };

  testWidgets('rename: a blank name is not accepted and the dialog stays', (
    tester,
  ) async {
    final (home, file) = await openWithShare(tester);
    final l10n = home.l10n;
    await choose(home, file, l10n.commonRename);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await home.settle();
    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'a blank name closed the dialog without a word',
    );
    expect(sharesIn(home), {'mine.niashare'});
    await tester.tap(find.text(l10n.commonCancel).last);
    await home.settle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('rename: a name that is taken is explained inside the dialog', (
    tester,
  ) async {
    final (home, file) = await openWithShare(tester, others: ['other']);
    final l10n = home.l10n;
    await choose(home, file, l10n.commonRename);
    await tester.enterText(find.byType(TextField), 'other');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await home.settleIo(2);
    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'the dialog closed on a taken name',
    );
    final taken = (l10n as dynamic).homeShareFileNameTaken as String;
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(taken)),
      findsOneWidget,
    );
    expect(sharesIn(home), {'mine.niashare', 'other.niashare'});
    // 別の名前にすると変わって閉じる。
    await tester.enterText(find.byType(TextField), 'renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await home.waitFor(() => find.byType(AlertDialog).evaluate().isEmpty);
    await home.settleIo(2);
    expect(sharesIn(home), {'renamed.niashare', 'other.niashare'});
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('rename: a favourite stays a favourite under its new name', (
    tester,
  ) async {
    final (home, file) = await openWithShare(tester);
    await tester.runAsync(
      () => home.projects.toggleOutgoingShareFavorite(file.path),
    );
    await home.settleIo(2);
    final l10n = home.l10n;
    await choose(home, file, l10n.commonRename);
    await tester.enterText(find.byType(TextField), 'renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await home.waitFor(() => find.byType(AlertDialog).evaluate().isEmpty);
    await home.settleIo(2);
    final renamed = '${file.parent.path}/renamed.niashare';
    expect(sharesIn(home), {'renamed.niashare'});
    expect(home.projects.isOutgoingShareFavorite(renamed), isTrue);
    expect(home.projects.isOutgoingShareFavorite(file.path), isFalse);
    final saved = await tester.runAsync(
      () async => (await SharedPreferences.getInstance()).getStringList(
        'niarim_outgoing_share_favorites',
      ),
    );
    expect(saved, [renamed], reason: 'the saved settings keep the old path');
    // お気に入りだけの絞り込みにも新しい名前で出る。
    expect(find.byKey(ValueKey('outgoingShareMenu_$renamed')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('rename: a copy on the clipboard follows the new name', (
    tester,
  ) async {
    final (home, file) = await openWithShare(tester);
    final l10n = home.l10n;
    // 選んでコピーする（選ぶとメニューは隠れ、コピーすると選ぶのを終える）。
    await tester.longPress(find.text('mine').first);
    await home.settle();
    await home.copySelection();
    await choose(home, file, l10n.commonRename);
    await tester.enterText(find.byType(TextField), 'renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await home.waitFor(() => find.byType(AlertDialog).evaluate().isEmpty);
    await home.settleIo(2);
    expect(sharesIn(home), {'renamed.niashare'});
    await home.paste();
    await home.waitFor(() => sharesIn(home).length == 2);
    expect(sharesIn(home), {
      'renamed.niashare',
      '${copyNameIn(l10n, 'renamed', 1)}.niashare',
    });
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('received work rename: same dialog as a work (blank name '
      'stays, the button says change)', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final gift = await home.addReceived('gift');
    await home.showTab(2);
    final l10n = home.l10n;
    await tester.tap(find.byKey(ValueKey('receivedShareMenu_${gift.id}')));
    await home.settle();
    await tester.tap(find.text(l10n.commonRename).last);
    await home.settle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final labels = [
      for (final button in tester.widgetList<ButtonStyleButton>(
        find.descendant(
          of: dialog,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      ))
        if (button.child case final Text text) text.data,
    ];
    expect(labels, [l10n.commonCancel, l10n.commonChange]);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await home.settleIo(2);
    expect(
      dialog,
      findsOneWidget,
      reason: 'a blank name closed the dialog without a word',
    );
    expect(home.projects.shared.single.name, 'gift');
    await tester.enterText(find.byType(TextField), '  present ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await home.waitFor(() => find.byType(AlertDialog).evaluate().isEmpty);
    await home.settleIo(2);
    expect(home.projects.shared.single.name, 'present');
    expect(tester.takeException(), isNull);
    await home.close();
  });

  for (final language in ['ja', 'en', 'zh']) {
    testWidgets('duplicate names the copy in the screen language '
        '($language)', (tester) async {
      final (home, file) = await openWithShare(tester, language: language);
      final l10n = home.l10n;
      await choose(home, file, l10n.themeDuplicateAction);
      await home.waitFor(() => sharesIn(home).length == 2);
      await tester.runAsync(() => home.projects.refreshOutgoingShares());
      await home.settleIo(2);
      await choose(home, file, l10n.themeDuplicateAction);
      await home.waitFor(() => sharesIn(home).length == 3);
      expect(sharesIn(home), {
        'mine.niashare',
        '${copyNameIn(l10n, 'mine', 1)}.niashare',
        '${copyNameIn(l10n, 'mine', 2)}.niashare',
      });
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
