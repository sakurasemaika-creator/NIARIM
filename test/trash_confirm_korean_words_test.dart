// ゴミ箱へ移す・完全に削除する・削除する・ゴミ箱から戻す確認の文は、韓国語の
// 語（空白で区切った単位）の途中で行を変えない（DISC171）。
//
// 確認のボタンの文字（trashConfirmLabelText）は語の途中で折らないが、本文は
// 普通の文で、韓国語・320px・文字2倍で「1개 항목을 휴지통 / 으로 이동하시겠 /
// 습니까? / 폴더 안의 프로젝 / 트 2개도 …」と語の途中で切れていた。削除の確認
// （confirmDelete）も「「애니메이션 연 / 습」을(를) 삭제하 / 시겠습니까?」と
// 切れていた。1行に入る語は途中で折らず（入らない長い語だけは字の間で折る）、
// 読み上げは元の文のまま。7言語×320/360/412px×文字1.0/1.3/2.0で、語の途中の
// 折り返し・はみ出しが無いことを見張る。
//
// 削除の確認の本文を普通のTextで書いた所が残っていないことも、ソースで見張る
// （どの画面の削除の確認も同じ決まり）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/confirm_delete.dart';
import 'package:niarim/widgets/copy_name_text.dart';
import 'package:niarim/widgets/keep_together_text.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

const _widths = [320.0, 360.0, 412.0];
const _scales = [1.0, 1.3, 2.0];

/// 確認を開く画面（[open]は開いた画面のcontextでダイアログを開く）。
Future<BuildContext> _pumpHost(WidgetTester tester, Locale locale) async {
  final host = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: ThemeService().themeDataFor(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(key: host, body: const SizedBox.expand()),
    ),
  );
  return host.currentContext!;
}

/// 開いている確認を、幅と文字の大きさを変えながら調べる。
Future<void> _sweep(
  WidgetTester tester,
  String where,
  List<String> problems,
) async {
  for (final width in _widths) {
    for (final scale in _scales) {
      tester.view.physicalSize = Size(width, 740);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget, reason: where);
      final at = '$where ${width.toInt()}px x$scale';
      for (final paragraph in textParagraphsIn(dialog)) {
        for (final broken in wordsBrokenThatFit(paragraph)) {
          problems.add('$at: $broken');
        }
        // 1つの語が行より広い所は、短い訳に替える（所有者の判断、
        // 2026-11-22、DISC155）。
        for (final wide in wordsWiderThanLine(paragraph)) {
          problems.add('$at: wider than the line (DISC155): $wide');
        }
      }
      final error = tester.takeException();
      if (error != null) problems.add('$at: $error');
    }
  }
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  tester.view.physicalSize = const Size(360, 740);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(AlertDialog))).pop();
  await tester.pumpAndSettle();
}

void main() {
  var fontsLoaded = false;
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(360, 740);
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<void> fonts(WidgetTester tester) async {
    if (fontsLoaded) return;
    await loadAppFonts(tester);
    fontsLoaded = true;
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('trash and delete questions break only between words ($tag)', (
      tester,
    ) async {
      await fonts(tester);
      final l10n = lookupAppLocalizations(locale);
      final context = await _pumpHost(tester, locale);
      final problems = <String>[];
      final korean = locale.languageCode == 'ko';
      final name = korean ? '애니메이션 연습' : 'Storyboard practice';

      // フォルダを中身ごとゴミ箱へ移す（ホームのフォルダのメニュー）。
      final trashMessage =
          '${l10n.homeMoveToTrashConfirm(1)}\n'
          '${l10n.homeMoveToTrashFolderContents(l10n.homeFolderContents(2, 1))}';
      showDialog<void>(
        context: context,
        builder: (_) => ProjectTrashDialog(
          title: l10n.homeMoveToTrash,
          message: trashMessage,
          confirmLabel: l10n.homeMoveToTrash,
          itemNames: [name],
          onApply: () async {},
        ),
      );
      await tester.pumpAndSettle();
      await _sweep(tester, 'move to trash', problems);
      await _close(tester);

      // ゴミ箱を空にする・完全に削除する（容量削減・ゴミ箱）。
      showDialog<void>(
        context: context,
        builder: (_) => ProjectTrashDialog(
          title: l10n.homePermanentDeleteConfirmTitle,
          message:
              '${l10n.homePermanentDeleteConfirmBody}\n'
              '${l10n.homeProjectsLoadFailed}',
          confirmLabel: l10n.homePermanentDelete,
          itemNames: [name, '$name 2'],
          onApply: () async {},
        ),
      );
      await tester.pumpAndSettle();
      await _sweep(tester, 'delete for good', problems);
      await _close(tester);

      // 削除の確認（ブラシ・フォント・保存など、名前つき）。
      confirmDelete(context, itemName: name);
      await tester.pumpAndSettle();
      await _sweep(tester, 'delete', problems);
      await _close(tester);
      confirmDelete(context);
      await tester.pumpAndSettle();
      await _sweep(tester, 'delete (no name)', problems);
      await _close(tester);

      // ゴミ箱から選んで戻す確認（件数の文）と、作品・フォルダの名前を並べた
      // 戻す確認（ホーム）。
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.commonRestore),
          content: countText(l10n.homeTrashRestoreSelectedConfirm(3)),
          actions: [
            TextButton(onPressed: () {}, child: Text(l10n.commonCancel)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _sweep(tester, 'restore selected', problems);
      await _close(tester);
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.commonRestore),
          content: copyNameText(
            '${l10n.homeRestoreFromTrashQuestion}\n'
            '${l10n.commonBulletItem(name)}',
            name: name,
          ),
          actions: [
            TextButton(onPressed: () {}, child: Text(l10n.commonCancel)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _sweep(tester, 'restore named', problems);
      await _close(tester);

      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }

  // 仏語・西語の完全削除の確認は、1語が行より広い「définitivement」
  // 「definitivamente」を使わない短い訳にした（所有者の判断、2026-11-22、
  // DISC155）。320px・文字2倍で、題とボタンの語が途中で折れないこと。
  for (final locale in const [Locale('fr'), Locale('es')]) {
    testWidgets(
      'the ${locale.languageCode} permanent-delete question keeps every word whole',
      (tester) async {
        await fonts(tester);
        final l10n = lookupAppLocalizations(locale);
        final context = await _pumpHost(tester, locale);
        tester.view.physicalSize = const Size(320, 740);
        tester.platformDispatcher.textScaleFactorTestValue = 2;

        showDialog<void>(
          context: context,
          builder: (_) => ProjectTrashDialog(
            title: l10n.homePermanentDeleteConfirmTitle,
            message: l10n.homePermanentDeleteConfirmBody,
            confirmLabel: l10n.homePermanentDelete,
            itemNames: const ['Storyboard practice'],
            onApply: () async {},
          ),
        );
        await tester.pumpAndSettle();

        final confirm = find.byKey(const Key('trash-dialog-confirm'));
        final label = find.descendant(
          of: confirm,
          matching: find.byType(RichText),
        );
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final span = paragraph.text as TextSpan;
        final displayed = span.toPlainText(includeSemanticsLabels: false);
        expect(displayed.replaceAll('\u2060', ''), l10n.homePermanentDelete);
        expect(span.semanticsLabel ?? displayed, l10n.homePermanentDelete);
        final problems = <String>[];
        for (final p in textParagraphsIn(find.byType(AlertDialog))) {
          problems
            ..addAll(wordsBrokenThatFit(p))
            ..addAll(wordsWiderThanLine(p));
        }
        expect(problems, isEmpty);
        expect(
          ParagraphLines(paragraph).charsOutsideWidth(),
          isEmpty,
          reason: 'The label must stay inside the confirm button.',
        );
        expect(tester.takeException(), isNull);
        await _close(tester);
      },
    );
  }

  testWidgets('a Korean body is read as the plain sentence', (tester) async {
    await fonts(tester);
    const locale = Locale('ko');
    final l10n = lookupAppLocalizations(locale);
    final handle = tester.ensureSemantics();
    final context = await _pumpHost(tester, locale);
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final message = l10n.homeMoveToTrashConfirm(1);
    showDialog<void>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: message,
        confirmLabel: l10n.homeMoveToTrash,
        itemNames: const ['Storyboards'],
        onApply: () async {},
      ),
    );
    await tester.pumpAndSettle();
    // 描く文では語がつながっている（行は語の間でだけ変わる）。
    final body = textParagraphsIn(
      find.byType(AlertDialog),
    ).firstWhere((p) => ParagraphLines(p).visible == message);
    expect(ParagraphLines(body).lines.length, greaterThan(1));
    expect(wordsBrokenThatFit(body), isEmpty);
    // 読み上げは、語をつなぐ字の無い元の文。
    expect(find.bySemanticsLabel(message), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(wordJoiner)),
      findsNothing,
      reason: 'a screen reader would read the word joiners',
    );
    await _close(tester);
    confirmDelete(context, itemName: '애니메이션 연습');
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n.confirmDeleteNamedBody('애니메이션 연습')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(wordJoiner)), findsNothing);
    await _close(tester);
    handle.dispose();
  });

  // ほかの画面の削除の確認も、本文を普通のTextにしない（韓国語の語の途中で
  // 折れる）。確認の文のキー（削除・ゴミ箱の確認の本文）を、普通のTextに
  // 渡している所を探す（ホームのゴミ箱へ貼り付ける・ゴミ箱から戻す確認の
  // 問いも。DISC188）。
  test('no delete or trash question body is a plain Text', () {
    final keys = RegExp(
      r'\bText\(\s*l10n\.(\w*(?:Delete|Trash|Remove|Erase)\w*'
      r'(?:Confirm|Question|DialogBody)\w*'
      r'|\w*Confirm\w*(?:Delete|Trash|Remove|Erase)\w*)\b',
    );
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('/l10n/')) continue;
      final source = file.readAsStringSync();
      for (final match in keys.allMatches(source)) {
        final key = match[1]!;
        // 題（title:）は見出しなので数えない（本文だけ）。
        final before = source.substring(
          source.lastIndexOf('\n', match.start) + 1,
          match.start,
        );
        if (before.contains('title:')) continue;
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        found.add('${file.path}:${line + 1} $key');
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
