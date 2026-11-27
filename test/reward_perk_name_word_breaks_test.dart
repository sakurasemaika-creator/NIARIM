// オパール・特典の交換の一覧で、特典の名前が語の途中で行を変えないことを、
// 本物のフォント・テーマ・320/360/390pxの幅・文字の大きさ1倍/1.3倍/2倍で
// 確かめる（日本語・韓国語・フランス語）。
//
// 日本語は字と字の間のどこでも行を変えるので、360pxで特典の名前が
// 「エンドマーク編集・削除（メイキング動 / 画を含む）」と語の途中で折れた
// （所有者の指摘、2026-11-27）。日本語の語（漢字・カタカナ・英数字の続きと、
// すぐ後のひらがな）は途中で折らず、語と語の間で行を変える。欄の1行に
// 入らない語だけは字の間で折ってよい。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/line_break.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'reward-perk-name-word-breaks';
  @override
  String get email => 'example.invalid';
  @override
  String get displayName => 'Example';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends GoogleAuthService {
  final _user = _Account();
  @override
  GoogleSignInAccount? get account => _user;
  @override
  bool get isConfigured => true;
}

CommunityService _server() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path == '/me/rewards'
                ? {
                    'balanceCoins': 60000,
                    'redemptionEnabled': true,
                    'entitlements': <Object>[],
                  }
                : <String, Object>{},
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    ),
  ),
);

/// The perk names of the exchange list.
List<String> _perkNames(AppLocalizations l10n) => [
  l10n.rewardUnlockEndCardEdit,
  l10n.rewardUnlockWatermark,
  l10n.rewardUnlockToneCurve,
  l10n.rewardUnlockLevelAdjustment,
  l10n.rewardUnlockUnlimitedDuration,
  l10n.rewardUnlockCustomAutomation,
  l10n.rewardUnlockProjectListAds,
  l10n.rewardUnlockCanvasAds,
  l10n.rewardUnlockTimelineAds,
  l10n.rewardUnlockProcessingAds,
  l10n.rewardUnlockAllAds,
  l10n.rewardUnlockFullPremium,
];

/// [word] in [text], allowing the zero-width spaces the paragraph may put
/// before a closing bracket.
Iterable<Match> _occurrences(String text, String word) => RegExp(
  word.runes.map((r) => RegExp.escape(String.fromCharCode(r))).join('\u200B?'),
).allMatches(text);

/// The words of [name] that must not be split, by language.
List<String> _words(String language, String name) => switch (language) {
  'ja' => japaneseWordParts(name),
  _ => [
    for (final m in RegExp(r'[^\s\u200B]+').allMatches(name))
      if (m[0]!.runes.length > 1) m[0]!,
  ],
};

void main() {
  var fontsLoaded = false;
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  test('the Japanese words of the perk names', () {
    expect(japaneseWordParts('エンドマークとGIFロゴの編集・削除（メイキング動画を含む）'), [
      'エンドマークと',
      'GIF',
      'ロゴの',
      '編集',
      '削除',
      'メイキング',
      '動画を',
      '含む',
    ]);
    expect(japaneseWordParts('作品広場の投稿枠（1日1作品→3作品）'), [
      '作品広場の',
      '投稿枠',
      '作品',
      '作品',
    ]);
    expect(japaneseWordParts('すべての広告なし'), ['すべての', '広告なし']);
  });

  for (final language in const ['ja', 'ko', 'fr']) {
    for (final width in const [320.0, 360.0, 390.0]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets('perk names keep their words whole '
            '($language, ${width.toInt()}px, ×$scale)', (tester) async {
          if (!fontsLoaded) {
            await loadAppFonts(tester);
            fontsLoaded = true;
          }
          final themes = ThemeService();
          await themes.init();
          addTearDown(themes.dispose);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 30000);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final premium = PremiumService();
          final locale = Locale(language);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PremiumService>.value(value: premium),
                ChangeNotifierProvider<SettingsService>.value(
                  value: SettingsService(),
                ),
                ChangeNotifierProvider<GoogleAuthService>.value(
                  value: _SignedIn(),
                ),
                ChangeNotifierProvider<CommunityService>.value(
                  value: _server(),
                ),
              ],
              child: MaterialApp(
                locale: locale,
                theme: themes.themeDataFor(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const RewardUnlockScreen(),
              ),
            ),
          );
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
          final l10n = lookupAppLocalizations(locale);
          final names = _perkNames(l10n);
          final seen = <String>{};
          final problems = <String>[];
          for (final element
              in find
                  .descendant(
                    of: find.byWidgetPredicate(
                      (w) =>
                          w.key is ValueKey<String> &&
                          (w.key! as ValueKey<String>).value.startsWith(
                            'rewardFeature_',
                          ),
                    ),
                    matching: find.byType(RichText),
                  )
                  .evaluate()) {
            final paragraph = element.renderObject;
            if (paragraph is! RenderParagraph || !paragraph.attached) continue;
            final lines = ParagraphLines(paragraph);
            final text = lines.visible;
            final plain = text
                .replaceAll('\u200B', '')
                .replaceAll('\u00A0', ' ');
            final name = names.where((n) => n == plain).firstOrNull;
            if (name == null) continue;
            seen.add(name);
            for (final word in _words(language, name)) {
              for (final match in _occurrences(text, word)) {
                final breaks = lines.breaksWithin(match.start, match.end);
                if (breaks.isEmpty) continue;
                final wordWidth = paragraph
                    .getBoxesForSelection(
                      lines.sourceSelection(match.start, match.end),
                    )
                    .fold<double>(0, (sum, box) => sum + box.right - box.left);
                // A word wider than the line has to break somewhere.
                if (wordWidth > paragraph.size.width) continue;
                problems.add(
                  '「$word」: ${lines.lines.join(' / ')} '
                  '(${wordWidth.toStringAsFixed(0)}px, '
                  'line ${paragraph.size.width.toStringAsFixed(0)}px)',
                );
              }
            }
          }
          expect(
            seen,
            contains(l10n.rewardUnlockEndCardEdit),
            reason: 'the end mark perk was not checked',
          );
          expect(seen.length, greaterThan(8));
          expect(problems, isEmpty, reason: problems.join('\n'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          premium.dispose();
        });
      }
    }
  }
}
