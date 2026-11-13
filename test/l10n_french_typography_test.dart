// フランス語（とスペイン語）の言葉づかい・記号のそろいを見張る（DISC110 の
// （1）（2）（3）（6））。
//
// （1）クリップボードを空にするボタンと、切り取りを取り消す「元に戻す」が、
//     同じ画面に同時に並ぶのに同じ「Annuler」だった。
// （2）ゴミ箱へ移す動詞が「Mettre à la corbeille」と「Déplacer vers la
//     corbeille」で混ざっていた（スペイン語は「Mover a la papelera」で
//     そろっている）。
// （3）アポストロフィが ' と ’ で混ざっていた（’ にそろえる）。
// （6）「:」「;」「?」「!」の前・« » の内側が普通の空白で、行の折り返しで
//     記号だけが次の行へ落ちた（「…avant de revenir ?」が360pxで「?」だけ
//     2行目）。フランス語の決まり：「:」の前と « » の内側は改行しない空白
//     （U+00A0）、「;」「?」「!」の前は細い改行しない空白（U+202F）。
//     U+202F は本文・見出しの代替フォント（DelaGothicOne）にあり、同梱の
//     フォントだけで描ける（font_coverage_test）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';

import 'helpers/load_app_fonts.dart';

Map<String, String> _values(String locale) {
  final data =
      json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

const _nbsp = ' ';
const _narrowNbsp = ' ';

void main() {
  final fr = _values('fr');

  test('（1）仏語：クリップボードを空にするボタンと「元に戻す」は別の言葉', () {
    expect(fr['homeClipboardClear'], isNot(fr['homeUndoAction']));
  });

  test('（2）ゴミ箱へ移す動詞をそろえる（仏語は Mettre à la corbeille、'
      'スペイン語は Mover a la papelera）', () {
    final offenders = [
      for (final MapEntry(:key, :value) in fr.entries)
        if (RegExp(
          r'(déplac|plac|envoy)\w*\s+(vers|dans)\s+la\s+corbeille',
          caseSensitive: false,
        ).hasMatch(value))
          'fr $key: $value',
      for (final MapEntry(:key, :value) in _values('es').entries)
        if (RegExp(
          r'(envi|llev|tir)\w*\s+(a|en)\s+la\s+papelera',
          caseSensitive: false,
        ).hasMatch(value))
          'es $key: $value',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('（3）仏語のアポストロフィは ’ にそろえる（\' を使わない）', () {
    final offenders = [
      for (final MapEntry(:key, :value) in fr.entries)
        if (value.contains("'")) '$key: $value',
    ];
    expect(
      offenders,
      isEmpty,
      reason: '${offenders.length}件:\n${offenders.take(30).join('\n')}',
    );
  });

  test('仏語の文に、アクセントの抜けた語（meme・video・ecran・reglages 等）が無い', () {
    // アクセントを付けずには書かない語だけを並べる（「a」と「à」、
    // 「recherche」と「recherché」のように、どちらも正しい語は入れない）。
    final unaccented = RegExp(
      // 前後が文字（アクセント付きを含む）でない所だけ（「Paramètres」の
      // 「tres」は数えない）。
      r'(?<![\p{L}\w])(memes?|etre|deja|videos?|ecrans?|reglages?|durees?|publicites?|'
      r'egalement|reseaux?|selecteurs?|differente?s?|considerablement|'
      r'completement|precisement|hesitez|lumieres?|arrieres?|economiser|'
      r'reduire|reduisent|deplac\w*|cles|personnalisees?|personnalises|'
      r'separees?|separes?|evitez|accedez|ajoutees?|masquees?|plutot|themes?|'
      r'zero|oeuvres?|degradee?s?|selectionn\w*|redimensionnee?s?|'
      r'decontractee?|entrees|parametres?|systemes?|problemes?|derniere|'
      r'premiere|tres|apres|grace|interieur|exterieur|controle\w*|fenetres?|'
      r'telecharg\w*|reinitialis\w*|precedente?s?|categories?|methodes?|'
      r'qualite|frequence|etapes?|elements?|epaisseur|integree?s?)'
      r'(?![\p{L}\w])',
      unicode: true,
    );
    final offenders = [
      for (final MapEntry(:key, :value) in fr.entries)
        for (final match in unaccented.allMatches(value))
          '$key «${match.group(0)}»',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Tipsの合成モードの使い分けは、画面と同じ合成モードの名前で書く（7言語）', () {
    for (final locale in const [
      'ja',
      'en',
      'es',
      'fr',
      'ko',
      'zh',
      'zh_Hant',
    ]) {
      final values = _values(locale);
      final tip = values['tipsBlendModeUsageDesc']!;
      for (final mode in const [
        'blendModeMultiply',
        'blendModeScreen',
        'blendModeAddition',
        'blendModeOverlay',
        'blendModeSoftLight',
      ]) {
        expect(
          tip,
          contains(values[mode]!),
          reason: '$locale tipsBlendModeUsageDesc に $mode「${values[mode]}」が無い',
        );
      }
    }
  });

  test('画面に出す「名前: 値」はコードでつながず、ARBの文（commonLabelWithValue 等）'
      'で作る（仏語の「:」の前の改行しない空白・中国語の「：」が付く）', () {
    // 以前は YouTube のコメントの返信の数（「Réponses: 3」）、自分の作品の
    // 更新の失敗（「…YouTube: <error>」）、フィルターの数値の名前
    // （「Rayon: 12」）をコードで '$名前: $値' とつないでいた。
    // 読み上げだけの名前（Semantics の label）と、例外・記録の文は数えない。
    // ホーム（lib/screens/home）は別の作業で作り直し中なので、見つけたものは
    // 報告に回す（読み上げだけの2か所）。
    final concatenation = RegExp(r"""['"](\$\{[^}]*\}|\$[A-Za-z_]\w*)\s?: """);
    final exempt = RegExp(
      r'debugPrint|throw |Exception\(|Error\(|toString\(\)|assert\(|'
      r'(?<![\$\w])(label|semanticsLabel):|Semantics\(',
    );
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('app_localizations')) continue;
      if (file.path.replaceAll(r'\', '/').contains('lib/screens/home/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!concatenation.hasMatch(lines[i])) continue;
        final context = lines.sublist(i < 3 ? 0 : i - 3, i + 1).join('\n');
        if (exempt.hasMatch(context)) continue;
        offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));

    final frL10n = lookupAppLocalizations(const Locale('fr'));
    expect(frL10n.commonLabelWithValue('Rayon', '12'), 'Rayon$_nbsp: 12');
    expect(frL10n.communityYoutubeCommentReplies(3), '3 réponses');
    expect(
      frL10n.communityChannelRefreshFailed('x'),
      endsWith('YouTube$_nbsp: x'),
    );
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(zh.commonLabelWithValue('半径', '12'), '半径：12');
  });

  test('（6）仏語の「:」の前と « » の内側は U+00A0、「;」「?」「!」の前は U+202F', () {
    final offenders = <String>[];
    for (final MapEntry(:key, :value) in fr.entries) {
      for (final match in RegExp(r'(.)([:;?!»])').allMatches(value)) {
        final before = match.group(1)!;
        final mark = match.group(2)!;
        final after = match.end < value.length ? value[match.end] : '';
        if (mark == ':') {
          // 16:9 のような比・時刻、https:// は記号ではない。
          if (RegExp(r'\d').hasMatch(before) || after == '/') continue;
          if (before != _nbsp) offenders.add('$key «$before$mark»: $value');
        } else if (mark == '»') {
          if (before != _nbsp) offenders.add('$key «$before$mark»: $value');
        } else if (match.start > 0 &&
            value.substring(match.start - 1).startsWith('«$_nbsp')) {
          // « ? » のように記号そのものを括弧で示すときは記号ではない。
          continue;
        } else if (before != _narrowNbsp) {
          offenders.add('$key «$before$mark»: $value');
        }
      }
      for (final match in RegExp('«(.)').allMatches(value)) {
        if (match.group(1) != _nbsp) {
          offenders.add('$key «${match.group(0)}»: $value');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '${offenders.length}件:\n${offenders.take(40).join('\n')}',
    );
  });

  testWidgets('（6）仏語の文をどの幅で折り返しても、行が「:」「;」「?」「!」「»」で'
      '始まらず「«」で終わらない', (tester) async {
    await loadAppFonts(tester);
    // 書式の決まった文（{…}の置き換え）は見本の語で埋める。複数形・選択の
    // 文はそのまま測れないので外す。
    final samples = <String, String>{
      for (final MapEntry(:key, :value) in fr.entries)
        if (!value.contains(', plural,') &&
            !value.contains(', select,') &&
            RegExp(r'[   ][:;?!»]|«').hasMatch(value))
          key: value.replaceAll(RegExp(r'\{[^{}]*\}'), 'Exemple'),
    };
    expect(samples, isNotEmpty);
    final offenders = <String>{};
    for (final family in ['HakkouMincho', 'Kuramubon']) {
      for (final MapEntry(:key, :value) in samples.entries) {
        // 見出しの書体（太い）は150px未満では測らない：そこに入るのは短い
        // 見出し・ボタンだけで、長い文をそこまで狭めると、描画の仕組みが
        // 改行しない空白の後でも折り返すことがある（文のデータの問題ではない）。
        final narrowest = family == 'Kuramubon' ? 150.0 : 90.0;
        for (var width = narrowest; width <= 420; width += 6) {
          final painter = TextPainter(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: family,
                fontFamilyFallback: family == 'Kuramubon'
                    ? kHeadingFontFallback
                    : kBodyFontFallback,
                fontSize: 14,
              ),
            ),
            textDirection: TextDirection.ltr,
            locale: const Locale('fr'),
          )..layout(maxWidth: width);
          for (final line in painter.computeLineMetrics()) {
            final start = painter
                .getPositionForOffset(
                  Offset(0, line.baseline - line.ascent + 1),
                )
                .offset;
            final end = painter
                .getLineBoundary(TextPosition(offset: start))
                .end;
            final text = value.substring(start, end).trim();
            if (text.isEmpty) continue;
            final lead = RegExp(r'^[:;?!»]+').firstMatch(text);
            if (lead == null && !text.endsWith('«')) continue;
            if (lead != null && start > 0) {
              // 記号を含む、折り返せないひとかたまり（前後の普通の空白まで）が
              // 1行に入らないときは、どこででも折り返すしかない。入るのに
              // 記号だけが落ちたときだけを数える。
              final chunkStart =
                  value.substring(0, start).lastIndexOf(RegExp(r'[ \n]')) + 1;
              final after = value.indexOf(RegExp(r'[ \n]'), start + lead.end);
              final chunk = value.substring(
                chunkStart,
                after < 0 ? value.length : after,
              );
              final unit = TextPainter(
                text: TextSpan(text: chunk, style: painter.text!.style),
                textDirection: TextDirection.ltr,
              )..layout();
              final fits = unit.width <= width;
              unit.dispose();
              if (!fits) continue;
            }
            offenders.add('$key（$family、${width.round()}px）: 「$text」');
            break;
          }
          painter.dispose();
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '${offenders.length}件:\n${offenders.take(30).join('\n')}',
    );
  });
}
