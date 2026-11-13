import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

/// 使い方の最後のページの「この使い方をもう一度見る道順」が、実際の画面と
/// 合っていることを確かめる：ホームのメニューは右上（右から開く引き出し）、
/// 引き出しの「使い方」を開き、その中の「使い方を見る」を押す。
void main() {
  // 言語ごとの「左」を表す言い方（メニューは右上にある）。
  const leftWords = {
    'ja': ['左上', '左の'],
    'en': ['top left', 'upper left', 'left of'],
    'es': ['izquierda'],
    'fr': ['gauche'],
    'ko': ['왼쪽'],
    'zh': ['左上', '左侧'],
    'zh_Hant': ['左上', '左側'],
  };

  test('the home menu opens from the right (end drawer)', () {
    final source = File('lib/screens/home/home_screen.dart').readAsStringSync();
    expect(
      RegExp(r'\bendDrawer:\s*(const\s+)?HomeDrawer\(').hasMatch(source),
      isTrue,
      reason: 'the guide text below says the menu is at the top right',
    );
    expect(
      RegExp(r'[^d]drawer:\s*(const\s+)?HomeDrawer\(').hasMatch(source),
      isFalse,
    );
  });

  test('the figure shows the same icon as the drawer entry', () {
    String iconBefore(String path, String anchor) {
      final source = File(path).readAsStringSync();
      final at = source.indexOf(anchor);
      expect(at, greaterThan(0), reason: '$anchor in $path');
      return RegExp(r'Icons\.(\w+)')
          .allMatches(source.substring(0, at))
          .last
          .group(1)!;
    }

    expect(
      iconBefore('lib/widgets/app_tutorial.dart', 'l10n.homeDrawerTutorial'),
      iconBefore(
        'lib/screens/home/widgets/home_drawer.dart',
        'guideHubTitle(context)',
      ),
    );
  });

  test('the drawer entry and the guide text use one localized name', () {
    final source = File('lib/screens/help/guide_hub_screen.dart')
        .readAsStringSync();
    final title = source.substring(
      source.indexOf('String guideHubTitle('),
      source.indexOf('class GuideHubScreen'),
    );
    expect(title, contains('homeDrawerTutorial'));
    expect(
      title,
      isNot(contains('languageCode')),
      reason: 'a hand-written table per language drifts from the guide text',
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.scriptCode == null
        ? locale.languageCode
        : '${locale.languageCode}_${locale.scriptCode}';
    test('the last guide step names the real way back to the guide ($tag)', () {
      final l10n = lookupAppLocalizations(locale);
      final step = l10n.tutorialPage6Step3;
      for (final word in leftWords[tag]!) {
        expect(
          step.toLowerCase().contains(word.toLowerCase()),
          isFalse,
          reason: '"$word" in: $step',
        );
      }
      expect(step, contains(l10n.homeDrawerTutorial), reason: step);
      expect(step, contains(l10n.helpTutorialButton), reason: step);
    });
  }
}
