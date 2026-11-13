// ヘルプ・活用Tips・設定の検索が、キーボードで打った ' や普通の空白でも、
// 文の ’ や改行しない空白（U+00A0・U+202F）に当たることを見張る（DISC110 の
// レビュー指摘）。
//
// DISC110 で仏語のアポストロフィを ’ に、「:」「?」等の前を改行しない空白に
// そろえた。検索は文字をそのまま比べていたので、Androidのキーボードが打つ '
// （U+0027）で「Filtre d'effet」「l'espace de travail」を探すと何も出なく
// なった（以前は当たった）。比べる前に両方を同じ形にそろえる。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/help/help_screen.dart';
import 'package:niarim/screens/settings/settings_screen.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

Map<String, String> _fr() {
  final data =
      json.decode(File('lib/l10n/app_fr.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

/// キーボードで打つ形：’ ‘ を '、改行しない空白を普通の空白に。
String _typed(String text) =>
    text.replaceAll(RegExp('[’‘]'), "'").replaceAll(RegExp('[  ]'), ' ');

bool _needsFolding(String text) => text != _typed(text);

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

/// 見出しの文（[titles]）を、文のままと、キーボードで打つ形とで探し、当たる
/// 数が同じこと。文のままで1件も当たらないもの（その画面の項目でない）は
/// 数えない。
Future<List<String>> _compare(
  WidgetTester tester,
  Map<String, String> titles,
  int Function() hits,
) async {
  final offenders = <String>[];
  var checked = 0;
  for (final MapEntry(:key, :value) in titles.entries) {
    await tester.enterText(find.byType(TextField), value);
    await tester.pumpAndSettle();
    final exact = hits();
    if (exact == 0) continue;
    checked++;
    await tester.enterText(find.byType(TextField), _typed(value));
    await tester.pumpAndSettle();
    final typed = hits();
    if (typed != exact) {
      offenders.add('$key «${_typed(value)}»: $typed件（文のままでは$exact件）');
    }
  }
  expect(checked, greaterThan(5), reason: '確かめた見出しが少なすぎる');
  return offenders;
}

void main() {
  final fr = _fr();

  testWidgets('ヘルプ：仏語の見出しを \' と普通の空白で打っても同じ項目が出る', (tester) async {
    await _pumpScreen(tester, const HelpScreen());
    final titles = {
      for (final MapEntry(:key, :value) in fr.entries)
        if (key.startsWith('help') &&
            key.endsWith('Title') &&
            _needsFolding(value))
          key: value,
    };
    final offenders = await _compare(
      tester,
      titles,
      () => find.byType(ExpansionTile).evaluate().length,
    );
    expect(offenders, isEmpty, reason: offenders.join('\n'));

    // レビューで打った語（説明の中の語も）。
    for (final query in const [
      "Filtre d'effet",
      "Écran d'accueil",
      "Détection d'inclinaison",
      "l'espace de travail",
      "d'annulation",
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(
        find.byType(ExpansionTile).evaluate().length,
        greaterThan(0),
        reason: query,
      );
    }
    // 大文字・小文字も区別しない。
    await tester.enterText(find.byType(TextField), "FILTRE D'EFFET");
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile).evaluate().length, greaterThan(0));
  });

  testWidgets('活用Tips：仏語の見出しを \' と普通の空白で打っても同じTipsが出る', (tester) async {
    await _pumpScreen(tester, const TipsScreen());
    int tiles() => find
        .byWidgetPredicate((w) => w.runtimeType.toString() == '_TipListTile')
        .evaluate()
        .length;
    final titles = {
      for (final MapEntry(:key, :value) in fr.entries)
        if (key.startsWith('tips') &&
            key.endsWith('Title') &&
            _needsFolding(value))
          key: value,
    };
    final offenders = await _compare(tester, titles, tiles);
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    for (final query in const [
      "l'arbre de sauvegarde",
      "d'objectif",
      "l'ombrage",
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(tiles(), greaterThan(0), reason: query);
    }
  });

  testWidgets('設定：仏語の項目を \' で打っても出る', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final l10n = lookupAppLocalizations(const Locale('fr'));
    await tester.tap(find.byTooltip(l10n.commonSearch));
    await tester.pump(const Duration(milliseconds: 400));
    for (final (query, shown) in [
      ("historique d'annulation", l10n.settingsPerformanceSubtitle),
      ("barre d'outils", l10n.settingsWorkspaceSubtitle),
      ("ERREURS DE L'APPLICATION", l10n.settingsErrorLogSubtitle),
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(shown), findsOneWidget, reason: query);
    }
  });
}
