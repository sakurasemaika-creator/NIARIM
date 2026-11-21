import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/custom_automation_labels.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 公式の自動操作（保存する名前は日本語のまま、画面の言語で出す）の複製は、
/// どの言語の画面でも、訳した名前に画面の言語の「(コピー)」と番号を付けて
/// 出す。引き継ぎで足したときの知らせも同じ名前で書く（日本語の名前の
/// まま英語・仏語の一覧に並ばない）。

const _shipped = '線画作成（デジタル）';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_automation_names_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  for (final code in ['en', 'fr']) {
    test('$code: an official preset both devices edited arrives as a copy '
        'shown under the translated name with the copy suffix, and the '
        'import message names it the same way', () async {
      final l10n = lookupAppLocalizations(Locale(code));
      Future<TransferDevice> edited(int removedStep) async {
        SharedPreferences.setMockInitialValues({'language': code});
        final d = await TransferDevice.start();
        d.automation.editExisting('builtin_draft_to_lineart');
        d.automation.removeDraftStep(removedStep);
        await d.automation.saveDraft();
        await settleTransfer();
        return d;
      }

      final bytes = await (await edited(0)).export();
      final b = await edited(1);
      final report = TransferImportReport();
      await b.import(bytes, nextDir(), l10n: l10n, report: report);

      final translated = l10n.customAutomationBuiltinDraftToLineart;
      final copy = l10n.projectDuplicateName(translated);
      expect(
        [
          for (final item in b.automation.items)
            if (TransferCopyNames.related(item.name, _shipped))
              customAutomationDisplayName(l10n, item.name),
        ],
        [translated, copy],
        reason: '複製も画面の言語の名前で出る',
      );
      expect(report.addedCopies, [copy], reason: '知らせも一覧と同じ名前');
    });
  }

  test('copy names of the official presets are shown translated in every '
      'language with their number, also when the copy was named in another '
      'language; other names are the user\'s own', () {
    final ja = lookupAppLocalizations(const Locale('ja'));
    final en = lookupAppLocalizations(const Locale('en'));
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final digital = l10n.customAutomationBuiltinDraftToLineart;
      final analog = l10n.customAutomationBuiltinAnalogLineart;
      final trace = l10n.customAutomationBuiltinLineartColorTrace;
      for (final (stored, shown) in [
        (ja.projectDuplicateName(_shipped), l10n.projectDuplicateName(digital)),
        (
          en.projectDuplicateNameNumbered('線画抽出（アナログ）', 3),
          l10n.projectDuplicateNameNumbered(analog, 3),
        ),
        (
          ja.projectDuplicateNameNumbered('線画色トレス', 2),
          l10n.projectDuplicateNameNumbered(trace, 2),
        ),
        (_shipped, digital),
        ('My lineart (copy)', 'My lineart (copy)'),
      ]) {
        expect(
          customAutomationDisplayName(l10n, stored),
          shown,
          reason: '$locale: $stored',
        );
      }
    }
  });
}
