import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

void main() {
  const locales = {
    'ja': Locale('ja'),
    'en': Locale('en'),
    'es': Locale('es'),
    'fr': Locale('fr'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };

  test('manual part-coloring autofill tip exists in every supported language', () async {
    for (final locale in locales.values) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.tipsAutofillManualPartColorTitle.trim(), isNotEmpty);
      final autofillTip = l10n.tipsAutofillManualPartColorDesc;
      expect(autofillTip.trim(), isNotEmpty);
      expect(autofillTip, contains(l10n.layerPanelMenuLineartLayer));
      expect(autofillTip, contains(l10n.layerPanelMenuPartAssign));
      expect(autofillTip, contains(l10n.layerPanelMenuAutofillLayer));
      expect(autofillTip, contains(l10n.layerPanelMenuRunAutofill));
      expect(autofillTip, contains(l10n.layerPanelAutofillColorUpdateTitle));
      expect(l10n.tipsLineColorUsageDesc.trim(), isNotEmpty);
      expect(
        l10n.tipsLineColorUsageDesc,
        contains(l10n.autofillPartLineColorLabel),
      );
      expect(
        l10n.tipsLineColorUsageDesc,
        contains(l10n.autofillLineColorModeSameAsFill),
      );
    }
  });

  test('Tips page registers the manual part-coloring autofill tip', () {
    final source = File('lib/screens/tips/tips_screen.dart').readAsStringSync();
    expect(source, contains('l10n.tipsAutofillManualPartColorTitle'));
    expect(source, contains('l10n.tipsAutofillManualPartColorDesc'));
  });

  test('Japanese tip distinguishes manual fill shapes from lineart-driven autofill', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    final tip = l10n.tipsAutofillManualPartColorDesc;
    expect(tip, contains('通常レイヤー1枚'));
    expect(tip, contains('自動塗り用線画レイヤー'));
    expect(tip, contains('パーツ設定'));
    expect(tip, contains('自動塗りレイヤー'));
    expect(tip, contains('線ではなく面'));
    expect(tip, contains('自動塗り実行'));
    expect(tip, contains('形状を保ったまま色だけ更新'));
    expect(tip, contains('線画からパーツを自動判定'));
  });

  test('Tips page registers the separate line-color usage tip', () {
    final source = File('lib/screens/tips/tips_screen.dart').readAsStringSync();
    expect(source, contains('l10n.tipsLineColorUsageTitle'));
    expect(source, contains('l10n.tipsLineColorUsageDesc'));
  });

  test('line-color tip recommends Same as fill for shadows and highlights', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(l10n.tipsLineColorUsageDesc, contains('影やハイライト'));
    expect(l10n.tipsLineColorUsageDesc, contains('塗り色と同じ'));
  });
}
