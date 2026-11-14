// [KeepTogetherText]を実際の呼び出し元の文（ログインボーナス・ミッション・
// 特典交換・容量削減の行）で、7言語・見出しと本文の書体・文字1/1.3/2倍・
// 幅60〜420pxに並べ、欄の幅でつなぎ方を決めるようになって（DISC130）崩れた
// ものが無いことを確かめる。
//
// - 文の横か下に「受け取る」のボタンを置く並べ方（[ActionBesideOrBelow]）は、
//   DISC130 より前（どの幅でもかたまりをすべてつないだ文を描いた）と同じ
//   （内側の最小の幅をつながない文で答えた版では、ボタンを横に置いて
//   「55000 / 오팔」とかたまりを分けた）。
// - 前後の離せない字と合わせて1行に入るかたまりは、途中で行を変えない。
// - どのかたまりも語も1行に入る欄では、閉じ括弧・読点で始まる行、開き括弧で
//   終わる行を作らない（1行に入らない語は普通のTextと同じに字の途中で折れる。
//   その時の決まりは keep_together_text_wide_part_test が見る）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/coin_duration_label.dart';
import 'package:niarim/widgets/action_beside_or_below.dart';
import 'package:niarim/widgets/keep_together_text.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
const _noBreakSpace = '\u00a0';
const _zeroWidthSpace = '\u200b';

/// 数の前に付けて、後ろの数と離さない記号（部品と同じ）。
final _prefix = RegExp(
  '[\$+\\\\\u00a3\u00a4\u00a5\u00b1\u2116\u2212\u2213'
  '\u20a0-\u20cf\ufe69\uff04\uffe1\uffe5\uffe6]',
);

/// 数の前に空白なしで続くと、行分けの決まりで数と離せない字（英字・矢印等の
/// 記号〔UAX #14 の AL〕。漢字・仮名・ハングル・全角の字は数の前でも行を
/// 変えてよい）。部品はつながないが、かたまりが入るかを見るときは一緒に数える
/// （「→3作品）」はかたまり「3作品」が入っても、まとめて入らなければどこかで
/// 折れる。普通のTextでも同じ）。
final _gluedBeforeNumber = RegExp(r'[\p{L}\p{S}]', unicode: true);
final _breakableBeforeNumber = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}'
  r'\u3000-\u303f\uff00-\uffef]',
  unicode: true,
);

/// 実際の呼び出し元の文と、途中で切らない部分（呼び出し元が[keep]に渡す
/// もの）。
List<(String, String, List<String>)> _callerCases(AppLocalizations l) {
  String d(int seconds) => missionDurationLabel(l, seconds);
  final amount = l.coinAmount(55000);
  final period = l.rewardDurationDays(2);
  final progress = l.recurringMissionProgress(2, 3);
  final coins4 = l.coinAmount(4);
  List<String> bracketed(String t) => [
    for (final m in RegExp(r'[（(][^（）()\s]+[）)]').allMatches(t)) m.group(0)!,
  ];
  return [
    ('loginDays', l.loginBonusDays(31), const []),
    ('loginDaily', l.loginBonusDailyCoins(100), [l.coinAmount(100)]),
    ('milestone', l.loginBonusMilestone(30), const []),
    ('coin', amount, [amount]),
    ('plazaGoal', l.plazaMissionGoal(d(36000)), [d(36000)]),
    (
      'plazaProgress',
      '${d(1800)} / ${d(36000)} · ${l.coinAmount(40)}',
      [d(1800), d(36000), l.coinAmount(40)],
    ),
    ('recurringWeek', l.recurringMissionGoalWeek(3), const []),
    ('recurringMonth', l.recurringMissionGoalMonth(20), const []),
    ('recurringProgress', '$progress · $coins4', [progress, coins4]),
    (
      'creatorLocal',
      l.creatorMissionLocalTime(10),
      [l.missionDurationHours(10)],
    ),
    (
      'creatorCandidate',
      l.creatorMissionCandidateMinutes(20),
      [l.missionDurationMinutes(20)],
    ),
    ('creatorNamed', l.creatorMissionNamedBookmark('My work 2', 100), const []),
    ('creatorWorks', l.creatorMissionWorksGoal(3, 10), const []),
    ('creatorTime', l.creatorMissionTime(10), [l.missionDurationHours(10)]),
    (
      'redeem',
      '${l.rewardUnlockFullPremium} · $period · $amount\n\n'
          '${l.missionCompletedBody}',
      [period, amount],
    ),
    ('fixedPrice', '${l.rewardUnlockFixedPrice} · $amount', [amount]),
    ('quota', l.rewardUnlockCommunityPostQuota, const []),
    ('reviewTotal', l.rewardUnlockReviewFixedTotal(amount), [amount]),
    (
      'missionDone',
      '・${l.plazaMissionGoal(d(3600))}\n\n${l.missionCompletedBody}',
      const [],
    ),
    for (final t in [
      l.storageClearCacheButton,
      l.storageRemoveUnusedMaterialsButton,
      l.storageEmptyTrashButton,
      l.storageOrganizeProjectsButton,
      l.storageEraseAllButton,
    ])
      ('storage', t, bracketed(t)),
  ];
}

/// かたまりをすべてつないだ文の中の、つないだかたまり（[wordJoiner]で
/// つないだ字の並び）。かたまりの文（改行しない空白は普通の空白にする）と、
/// 前後の離せない字（前の開き括弧・数の前の記号・数の前の英字や記号、後ろの
/// 閉じ括弧・読点）と合わせて1行に並べた幅。
List<(String, double)> _groups(TextPainter joined) {
  final text = joined.text!.toPlainText(includeSemanticsLabels: false);
  final groups = <(String, double)>[];
  for (final m in RegExp(
    '(?:[^$wordJoiner]$wordJoiner)+[^$wordJoiner]',
  ).allMatches(text)) {
    var start = m.start;
    var end = m.end;
    final number = RegExp(r'\d').hasMatch(text[start]);
    while (start > 0) {
      final before = text[start - 1];
      if (!lineEndForbidden.contains(before) &&
          !_prefix.hasMatch(before) &&
          !(number &&
              _gluedBeforeNumber.hasMatch(before) &&
              !_breakableBeforeNumber.hasMatch(before))) {
        break;
      }
      start--;
    }
    while (end < text.length && lineStartForbidden.contains(text[end])) {
      end++;
    }
    final boxes = joined.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    groups.add((
      m.group(0)!.replaceAll(wordJoiner, '').replaceAll(_noBreakSpace, ' '),
      boxes.last.right - boxes.first.left,
    ));
  }
  return groups;
}

/// 描いた行で、[part]のどこかが途中で行を変えているか。
bool _splits(ParagraphLines lines, String part) {
  final index = <int>[];
  final flat = StringBuffer();
  for (var i = 0; i < lines.visible.length; i++) {
    final char = lines.visible[i];
    if (char == _zeroWidthSpace) continue;
    index.add(i);
    flat.write(char == _noBreakSpace ? ' ' : char);
  }
  final text = flat.toString();
  for (var at = text.indexOf(part); at >= 0; at = text.indexOf(part, at + 1)) {
    final end = index[at + part.length - 1] + 1;
    if (lines.breaksWithin(index[at], end).isNotEmpty) return true;
  }
  return false;
}

void main() {
  const fonts = {
    '見出し': ('Kuramubon', kHeadingFontFallback),
    '本文': ('HakkouMincho', kBodyFontFallback),
  };
  final widths = [for (var w = 60; w <= 420; w += 12) w.toDouble()];

  for (final locale in const [
    Locale('ja'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ko'),
    Locale('zh'),
    _zhHant,
  ]) {
    testWidgets('呼び出し元の文の並べ方（${locale.toLanguageTag()}, '
        '見出し・本文の書体, 文字1〜2倍, 幅60〜420px）', (tester) async {
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 30000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l = lookupAppLocalizations(locale);
      final problems = <String>[];
      var checkedPlacements = 0;
      var checkedGroups = 0;
      var checkedEdges = 0;
      for (final MapEntry(key: fontName, value: (family, fallback))
          in fonts.entries) {
        final style = TextStyle(
          fontFamily: family,
          fontFamilyFallback: fallback,
          fontSize: 14,
        );
        for (final scale in [1.0, 1.3, 2.0]) {
          final scaler = TextScaler.linear(scale);
          for (final (name, text, keep) in _callerCases(l)) {
            Widget app(Widget child) => MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(1400, 30000),
                  textScaler: scaler,
                ),
                child: Material(
                  child: DefaultTextStyle(
                    style: style,
                    child: Align(alignment: Alignment.topLeft, child: child),
                  ),
                ),
              ),
            );

            // かたまりをすべてつないだ文（幅の制限が無いときに描く文。
            // DISC130 より前の部品は、どの幅でもこの文を描いた）。
            await tester.pumpWidget(
              app(
                OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: double.infinity,
                  child: KeepTogetherText(text, keep: keep),
                ),
              ),
            );
            final joinedSpan = tester
                .widget<RichText>(
                  find.descendant(
                    of: find.byType(KeepTogetherText),
                    matching: find.byType(RichText),
                  ),
                )
                .text;
            final joined = TextPainter(
              text: joinedSpan,
              textDirection: TextDirection.ltr,
              textScaler: scaler,
            )..layout();
            final groups = _groups(joined);
            // 最も長い語（つないだかたまりを1語として）の幅。
            final widestWord = joined.minIntrinsicWidth;
            joined.dispose();

            final action = OutlinedButton(
              onPressed: () {},
              child: Text(l.missionClaim),
            );
            await tester.pumpWidget(
              app(
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final w in widths) ...[
                        SizedBox(
                          key: ValueKey('bare$w'),
                          width: w,
                          child: KeepTogetherText(text, keep: keep),
                        ),
                        SizedBox(
                          key: ValueKey('beside$w'),
                          width: w + 120,
                          child: ActionBesideOrBelow(
                            text: KeepTogetherText(text, keep: keep),
                            action: action,
                          ),
                        ),
                        SizedBox(
                          key: ValueKey('joined$w'),
                          width: w + 120,
                          child: ActionBesideOrBelow(
                            text: RichText(
                              text: joinedSpan,
                              textScaler: scaler,
                            ),
                            action: action,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);

            String placement(String key) {
              final box = find.byKey(ValueKey(key));
              final textBottom = tester
                  .getBottomLeft(
                    find
                        .descendant(of: box, matching: find.byType(RichText))
                        .first,
                  )
                  .dy;
              final buttonTop = tester
                  .getTopLeft(
                    find.descendant(
                      of: box,
                      matching: find.byType(OutlinedButton),
                    ),
                  )
                  .dy;
              return buttonTop >= textBottom - 0.5 ? 'below' : 'beside';
            }

            for (final w in widths) {
              final where =
                  '$fontName 文字$scale倍 $name 幅${w.toInt()}'
                  '「${text.replaceAll('\n', ' ')}」';
              checkedPlacements++;
              final kept = placement('beside$w');
              final before = placement('joined$w');
              if (kept != before) {
                problems.add('$where: ボタンが$kept（つないだ文では$before）');
              }
              for (final key in ['bare$w', 'beside$w']) {
                final paragraph = tester.renderObject<RenderParagraph>(
                  find
                      .descendant(
                        of: find.byKey(ValueKey(key)),
                        matching: find.byType(RichText),
                      )
                      .first,
                );
                final lines = ParagraphLines(paragraph);
                final available = paragraph.constraints.maxWidth;
                var allFit = widestWord <= available;
                for (final (group, width) in groups) {
                  if (width > available) {
                    allFit = false;
                    continue;
                  }
                  checkedGroups++;
                  if (_splits(lines, group)) {
                    problems.add(
                      '$where ($key): 入る「$group」を分けた: '
                      '${lines.lines.join(' / ')}',
                    );
                  }
                }
                if (allFit) {
                  checkedEdges++;
                  for (final problem in lines.lineEdgeViolations()) {
                    problems.add('$where ($key): $problem');
                  }
                }
              }
            }
          }
        }
      }
      debugPrint(
        '${locale.toLanguageTag()}: ボタンの置き場所 $checkedPlacements通り、'
        '入るかたまり $checkedGroups通り、行の頭・終わり $checkedEdges通り',
      );
      expect(problems, isEmpty, reason: problems.take(12).join('\n'));
    });
  }
}
