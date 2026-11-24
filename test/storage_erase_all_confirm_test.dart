// 「全データを削除」の確かめ：言語ごとの言葉を打つまで押せない（前後の空白・
// 大文字と小文字・全角と半角は問わない）。言葉が合えばEnterでも削除でき、
// 削除は起動し直す処理（AppRunner）へ渡る。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_runner.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/widgets/erase_all_dialog.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_locale.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/storage_screen_harness.dart';

const _languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

/// [word]の英字を全角にした形（日本語の入力のまま打った字）。
String _fullWidth(String word) => String.fromCharCodes([
  for (final c in word.runes)
    if (c >= 0x21 && c <= 0x7E) c + 0xFEE0 else c,
]);

class _RecordingRunner extends AppRunner {
  _RecordingRunner() : super(show: (_) {});

  final resets = <String?>[];
  Future<void> Function()? erase;
  Future<void> Function()? prepare;

  @override
  Future<void> resetToFactory({
    required Future<void> Function() erase,
    Future<void> Function()? prepare,
    String? languageCode,
  }) async {
    resets.add(languageCode);
    this.erase = erase;
    this.prepare = prepare;
  }
}

void main() {
  group('the confirmation word', () {
    for (final language in _languages) {
      final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
      final word = l10n.storageEraseAllConfirmWord;
      test('$language: «$word» in any case, width or padding', () {
        expect(word.trim(), isNotEmpty);
        for (final typed in [
          word,
          ' $word ',
          '　$word　',
          word.toLowerCase(),
          word.toUpperCase(),
          _fullWidth(word),
          _fullWidth(word.toLowerCase()),
        ]) {
          expect(eraseConfirmWordMatches(typed, word), isTrue, reason: typed);
        }
        for (final typed in [
          '',
          ' ',
          word.substring(0, word.length - 1),
          '$word$word',
          '${word}x',
          l10n.commonCancel,
        ]) {
          expect(eraseConfirmWordMatches(typed, word), isFalse, reason: typed);
        }
      });
    }

    test('each language asks for its own word, shown in the prompt', () {
      for (final language in _languages) {
        final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
        final word = l10n.storageEraseAllConfirmWord;
        expect(l10n.storageEraseAllConfirmPrompt(word), contains(word));
        expect(l10n.storageEraseAllErasedItems.split('\n'), hasLength(4));
        expect(l10n.storageEraseAllKeptItems.split('\n'), hasLength(3));
      }
    });
  });

  group('the dialog', () {
    Future<Future<bool?>> open(WidgetTester tester, String language) async {
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locale = localeFromLanguageCode(language);
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeService().themeDataFor(locale),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold();
            },
          ),
        ),
      );
      final result = showDialog<bool>(
        context: host,
        builder: (_) => const EraseAllDataDialog(),
      );
      await tester.pumpAndSettle();
      return result;
    }

    FilledButton confirmButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(EraseAllDataDialog.confirmKey));

    for (final language in _languages) {
      testWidgets('$language: lists what goes and what stays, and the button '
          'waits for the word', (tester) async {
        final result = await open(tester, language);
        final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
        for (final text in [
          l10n.storageEraseAllConfirmTitle,
          l10n.storageEraseAllConfirmBody,
          l10n.storageEraseAllErasedTitle,
          ...l10n.storageEraseAllErasedItems.split('\n'),
          l10n.storageEraseAllKeptTitle,
          ...l10n.storageEraseAllKeptItems.split('\n'),
          l10n.storageEraseAllConfirmPrompt(l10n.storageEraseAllConfirmWord),
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        final field = find.byKey(EraseAllDataDialog.wordFieldKey);
        // 何も打っていない・違う言葉では押せない。Enterでも閉じない。
        expect(confirmButton(tester).onPressed, isNull);
        await tester.enterText(field, l10n.commonCancel);
        await tester.pump();
        expect(confirmButton(tester).onPressed, isNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.byType(EraseAllDataDialog), findsOneWidget);
        // 合わない字を打ち足しても押せないまま（途中まで合っていても）。
        final word = l10n.storageEraseAllConfirmWord;
        await tester.enterText(field, word.substring(0, word.length - 1));
        await tester.pump();
        expect(confirmButton(tester).onPressed, isNull);
        // 全角・前後の空白つきでも、言葉が合えば押せる。Enterで削除する。
        await tester.enterText(field, ' ${_fullWidth(word.toLowerCase())} ');
        await tester.pump();
        expect(confirmButton(tester).onPressed, isNotNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.byType(EraseAllDataDialog), findsNothing);
        expect(await result, isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cancel closes without erasing; the button erases once', (
      tester,
    ) async {
      var result = await open(tester, 'ja');
      final l10n = lookupAppLocalizations(const Locale('ja'));
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(await result, isFalse);

      result = await open(tester, 'ja');
      // 文字を変えている途中（変換中の印のある字）でも、言葉が合えば押せる。
      final field = find.byKey(EraseAllDataDialog.wordFieldKey);
      await tester.showKeyboard(field);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '削除',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(EraseAllDataDialog.confirmKey));
      await tester.tap(
        find.byKey(EraseAllDataDialog.confirmKey),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('confirming on the storage screen starts the reset with the '
      'screen\'s eraser; nothing happens before the word is typed', (
    tester,
  ) async {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(
      tester,
      providers,
      service,
      size: const Size(390, 1200),
    );
    service.deviceQueries.single.complete(storageTestDevice);
    service.scans.single.complete(storageBreakdownOf());
    await settle(tester);
    final runner = _RecordingRunner();
    AppRunner.current = runner;
    addTearDown(() => AppRunner.current = null);

    final erase = storageTile(l10n.storageEraseAllButton);
    await tester.ensureVisible(erase);
    await tester.tap(erase);
    await settle(tester);
    await tester.tap(
      find.byKey(EraseAllDataDialog.confirmKey),
      warnIfMissed: false,
    );
    await settle(tester);
    expect(find.byType(EraseAllDataDialog), findsOneWidget);
    expect(runner.resets, isEmpty);

    await tester.enterText(
      find.byKey(EraseAllDataDialog.wordFieldKey),
      l10n.storageEraseAllConfirmWord,
    );
    await tester.pump();
    await tester.tap(find.byKey(EraseAllDataDialog.confirmKey));
    await settle(tester);
    expect(find.byType(EraseAllDataDialog), findsNothing);
    expect(runner.resets, ['ja']);
    // 消すのは画面のサービス。起動し直す処理が呼ぶまでは何も消さない。
    expect(service.erasures, 0);
    await tester.runAsync(() async {
      // ログインしていなければログアウトは何もしない（失敗しない）。
      await runner.prepare!();
      await runner.erase!();
    });
    expect(service.erasures, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
