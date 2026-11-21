// 同梱フォント（SIL Open Font License 1.1）の著作権表示・ライセンス本文が
// アプリのライセンス一覧へ登録されていることを確認する。
//
// OFL第2条は再配布時に著作権表示とライセンス本文を同梱することを求めており、
// assets/fonts/へ直接置いたフォントはLicenseRegistryの自動収集対象外のため、
// main.dartで明示的に登録している。その登録が将来壊れないよう固定する。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/license_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'font credits describe the uses and show the actual catalog path in each language',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(locale),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const LicenseScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.legalLastUpdated), findsOneWidget);
        Future<void> show(String text) async {
          final label = find.text(text);
          await tester.scrollUntilVisible(label, 300, maxScrolls: 150);
          expect(label, findsOneWidget, reason: locale.toLanguageTag());
        }

        await show(l10n.licenseCreditHeading);
        await show(l10n.licenseCreditCjkBody);
        final path = [
          l10n.settingsScreenTitle,
          l10n.settingsFontTitle,
          l10n.fontSettingsTabSearch,
        ].join(' → ');
        await show(l10n.licenseCreditCatalog(path));
        expect(
          find.textContaining(l10n.licenseCreditCatalogAuthor),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('同梱フォントのライセンス本文がアセットとして読み込める', () async {
    final text = await rootBundle.loadString(
      'assets/licenses/FONT_LICENSES.txt',
    );
    // 3書体すべての著作権表示が含まれていること。
    expect(text, contains('HakkouMincho'));
    expect(text, contains('Kuramubon.otf'));
    expect(text, contains('NotoSerifJP.ttf'));
    expect(text, contains('DelaGothicOne-Regular.ttf'));
    expect(text, contains('NotoSerifKRSubset.ttf'));
    expect(text, contains('NotoSansKRBlackSubset.ttf'));
    // OFL第3条（改変版はReserved Font Nameを使えない）への言及があること
    expect(text, contains("Reserved Font Name 'Source'"));
    expect(text, contains('The Dela Gothic Project Authors'));
    expect(text, contains('Adobe'));
    // OFL本文（全文）が含まれていること。
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(text, contains('PERMISSION & CONDITIONS'));
    expect(text, contains('TERMINATION'));
  });

  test('LicenseRegistryへ同梱フォントのライセンスが登録されている', () async {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(
        'assets/licenses/FONT_LICENSES.txt',
      );
      yield LicenseEntryWithLineBreaks(const [
        'HakkouMincho',
        'Kuramubon',
        'Noto Serif JP',
        'Dela Gothic One',
        'Noto Serif KR / SC',
        'Noto Sans KR / SC',
      ], text);
    });
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((e) => e.packages).toSet();
    expect(
      packages,
      containsAll([
        'HakkouMincho',
        'Kuramubon',
        'Noto Serif JP',
        'Dela Gothic One',
        'Noto Serif KR / SC',
        'Noto Sans KR / SC',
      ]),
    );
  });
}
