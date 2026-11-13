// 訳の読みやすさのレビューで見つかった、言語ごとの言い回しの見張り。
//
// - 同じ画面に並ぶ別の操作が同じ文になっていた（フランス語のサムネイルの
//   ダイアログで「フレームを指定する」と「画像を選択」がどちらも
//   « Choisir une image »、中国語のホームで「コピー」と「複製」がどちらも
//   「复制」「複製」）。
// - 同じものを同じ言語の中で別の言葉で呼んでいた（簡体字の「非公開」が
//   「私享」「私密」「视频不公开」の3通り、繁体字の共有ファイルが
//   「分享檔案」と「共享檔案」）。
// - 数と単位の間に普通の空白があり、行の途中で「秒」だけが次の行へ落ちうる。
// - 読み違えやすい・文法の崩れた言い回し（下の表、理由つき）。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_thumbnail_dialog.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _locales = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

Map<String, String> _values(String locale) {
  final data =
      json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

/// 同じ画面に同時に出て、別々の操作・意味を持つ文（どの言語でも違う文にする）。
const _shownTogether = <String, List<String>>{
  'サムネイルのダイアログの選択肢とボタン': [
    'thumbnailLastSavedFrame',
    'thumbnailSelectFrame',
    'thumbnailChooseDeviceImage',
    'thumbnailHide',
    'thumbnailPickImage',
  ],
  // ホームのゴミ箱の「コピー」と共有のメニューの「複製」、タイムラインの
  // シーンのメニューの「複製」と「コピー」。素材の「複製」のボタン
  // （commonDuplicate）も同じ操作の名前。
  '「コピー」と「複製」': ['commonCopy', 'themeDuplicateAction'],
  '「コピー」と素材の「複製」': ['commonCopy', 'commonDuplicate'],
};

/// 言語 → キー → 出てはいけない言い回しと理由。
const _forbidden = <String, Map<String, Map<String, String>>>{
  'fr': {
    'thumbnailStillImageOneFrame': {
      'ne compte qu’une seule image': '« image » が静止画とフレームの2つの意味で並ぶ',
    },
    'communityRecentlyUnfollowedHeader': {
      'Plus suivis': '冠詞が無く「最もフォローされた」とも読める',
    },
    'pcLayoutAutoFoldHelp': {
      'Seulement si': '文頭の条件が主語とつながらない',
      'Désactivé, la colonne': '「Désactivé」が「la colonne」にかかって読める',
    },
    'communityPostScheduleTooSoon': {'plus tard': '何から後かが無い（現在時刻から）'},
  },
  'es': {
    'communityUnfollowedLabel': {' lo ': '相手を男性と決めつける代名詞'},
    'communityRecentlyUnfollowedHeader': {
      'Dejaste de seguir recientemente': '見出しなのに主語の無い節の途中',
    },
    'communityPostScheduleTooSoon': {'después de ahora': '直訳の言い回し'},
  },
  'en': {
    'pcLayoutAutoFoldHelp': {
      'Only when windows still don’t fit after being shortened, the':
          '文頭の「Only when」の後に倒置が無い',
    },
    'communityPostScheduleAt': {'Publishes:': 'ラベルとして不自然'},
  },
  'zh_Hant': {
    'homePasteRestrictionTitle': {'貼上到': '簡体字の「粘贴到」の直訳（このARBは「貼到」）'},
    'homePasteCrossFormatBody': {'貼上到': '簡体字の「粘贴到」の直訳（このARBは「貼到」）'},
    'rewardUnlockRedeem': {'兌換歐泊': '「兌換＋目的語」は手に入れる物。歐泊を使う操作が歐泊をもらうように読める'},
    'rewardNavigationExchange': {'特權': 'このタブの中の「特典」は「權益」（選擇權益・目前使用中的權益）'},
    'rewardNavigationMembershipNoBenefit': {'特權': '見出し「目前權益」の下の空の表示が別の語になる'},
  },
  'zh': {
    'rewardUnlockRedeem': {'兑换欧泊': '「兑换＋目的語」は手に入れる物。欧泊を使う操作が欧泊をもらうように読める'},
    'rewardNavigationExchange': {'特权': 'このタブの中の「特典」は「权益」（选择权益・当前使用中的权益）'},
    'rewardNavigationMembershipNoBenefit': {'特权': '見出し「当前权益」の下の空の表示が別の語になる'},
  },
};

/// 報酬の通貨の名前（コイン→オパール）を語だけ置き換えた所の文法の崩れ。
///
/// フランス語の「opale」は母音で始まる女性名詞（「de opales」→「d’opales」、
/// 冠詞を落とさない）、スペイン語の「ópalo」は男性名詞（「monedas recibidas」→
/// 「ópalos recibidas」「Las ópalos」になっていた）、韓国語の「오팔」は終声ㄹで
/// 終わる（「오팔으로」→「오팔로」）。
final _frOpalElision = RegExp(
  r'(?<![\p{L}’])(?:de|du|au|le|la|que|ne|se|ce|je|me|te|jusque|lorsque|'
  r'puisque) opales?(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// 冠詞の抜け（avec des opales・pour des opales・contre des opales）。
/// 「payer en opales」「sans opales」は冠詞を付けないので見ない。
final _frOpalBareArticle = RegExp(
  r'(?<![\p{L}])(?:avec|pour|contre) opales?(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// 女性名詞の opale に付いた男性形（「un opale」「tous les opales」、
/// 「Opales reçus」「Les opales seront ajoutés」）。過去分詞・形容詞は、
/// 間に語が2つまで入っても同じ文の中なら見る。ただし間に et・ou・ni・
/// de・d’ 等が入ると、後の語は別の名詞に付く（「Opales et bonus gratuits」
/// 「opales d’avantages offerts」）ので見ない。
final _frOpalMasculine = RegExp(
  r'(?<![\p{L}])(?:un|cet|aucun|nouvel|nouveaux|premiers?|derniers?|certains|'
  r'tous (?:les|des|ces|vos|nos|mes|tes|leurs)) opales?(?![\p{L}])|'
  r'(?<![\p{L}])opales?'
  r'(?: (?!(?:et|ou|ni|de|des|du|aux?|avec|pour|sans|par|sur|dans|contre)'
  r'(?![\p{L}’]))(?![dl]’)[\p{L}’]+){0,2} (?:reçus?|obtenus?|ajoutés?|'
  r'gagnés?|crédités?|débités?|dépensés?|échangés?|cumulés?|accumulés?|'
  r'offerts?|versés?|utilisés?|attribués?|distribués?|gratuits?|acquis|'
  r'requis|restants)(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// 男性名詞の ópalo に付いた女性形の限定詞・形容詞・過去分詞。「cada」
/// 「nada」は性で形を変えない語（「5 ópalos cada día」「ópalos nada más」）。
final _esOpalFeminine = RegExp(
  r'(?<![\p{L}])(?:la|las|una|unas|esta|estas|esa|esas|aquella|aquellas|'
  r'nuestra|nuestras|vuestra|vuestras|toda|todas|mucha|muchas|poca|pocas|'
  r'alguna|algunas|ninguna|otra|otras|varias|tantas|cuántas|cuantas|'
  r'demasiadas|ciertas|mismas|primeras?|últimas?|nuevas?) ópalos?(?![\p{L}])|'
  r'(?<![\p{L}])ópalos? (?!(?:cada|nada)(?![\p{L}]))'
  r'(?:\p{L}+(?:ada|ida|uita|osa|iva|aria)s?|nuevas?|propias?|máximas?|'
  r'mínimas?)(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// 終声ㄹで終わる「오팔」の後の、母音で終わる語に付く形の助詞・語尾
/// （로・을・은・과・이・이랑・이나・이에요・이야・이라고・이라서・이라면・
/// 이면・이며・이다）。後ろにハングルが続くときは複合語（「오팔가루」）の
/// ことがあるので、「가」「나」「면」「며」「다」はそこで語が終わるときだけ。
final _koOpalParticle = RegExp(
  '오팔(?:으로|를|는|와|랑|예요|야|라고|라서|라면|'
  '(?:가|나|면|며|다)(?![가-힣]))',
);

/// 文の終わり（. ! ?）の後で、次の文が小文字で始まっている所。
///
/// 前が字・数字・閉じ括弧・閉じ引用符でない「?」（「Tap ? at the top」の
/// ボタンの記号）と、略語の点（[_abbreviations]）は文の終わりではない。
final _lowercaseAfterSentence = RegExp(
  r'(?<=[\p{L}\p{N}”»"’)])[.!?][\s\u00a0]+[«“"(¿¡]?[\s\u00a0]*\p{Ll}',
  unicode: true,
);

/// 点で終わる略語（この前で文は終わらない）。
const _abbreviations = [
  'etc',
  'vs',
  'e.g',
  'i.e',
  'p',
  'p. ej',
  'ex',
  'Transf',
  'Min',
  'Max',
  'Mín',
  'Máx',
];

/// [text]の中の、文の終わりの後が小文字で始まっている所。
List<String> _lowercaseSentenceStarts(String text) => [
  for (final match in _lowercaseAfterSentence.allMatches(text))
    if (!_abbreviations.any((abbreviation) {
      final before = text.substring(0, match.start);
      if (!before.endsWith(abbreviation)) return false;
      final at = before.length - abbreviation.length;
      return at == 0 ||
          !RegExp(r'\p{L}', unicode: true).hasMatch(before[at - 1]);
    }))
      text.substring((match.start - 20).clamp(0, text.length), match.end),
];

/// 見張りの式が、崩れた文を拾い、正しい文を拾わないことを確かめる見本。
/// 式を書き換えるときは、ここに見本を足してから書き換える。
const _grammarSamples = <String, ({List<String> bad, List<String> good})>{
  'fr': (
    bad: [
      'Échange de opales',
      'Gagner du opale',
      'Voir des pubs pour opales',
      'Débloqué avec opales',
      'Échanger contre opales',
      'Opales reçus',
      'Les opales seront ajoutés après confirmation.',
      'Il reste un opale',
      'Utiliser tous les opales',
      '5 opales gratuits',
    ],
    good: [
      "Historique d'opales",
      'Total de l’opale',
      'Échange d’opales',
      'Opales reçues',
      'Les opales seront ajoutées après confirmation.',
      'Débloqué avec des opales',
      'Prix en opales',
      'Un compte sans opales',
      'Les abonnés Premium pourront aussi cumuler des opales',
      'Il reste une opale',
      'Utiliser toutes les opales',
      '5 opales gratuites',
      'Opales nécessaires : à définir',
      'Opales et bonus gratuits',
      'Opales ou avantages offerts',
      'Opales d’avantages offerts',
    ],
  ),
  'es': (
    bad: [
      'Las ópalos se añadirán',
      'Ópalos recibidas',
      'Total de ópalos acumuladas',
      'Consigue ópalos gratuitas',
      'Historial de otras ópalos',
      'Una ópalo más',
      'Varias ópalos nuevas',
    ],
    good: [
      'Gana 5 ópalos cada día',
      'Canjear ópalos nada más',
      'Usa ópalos para nada',
      'Los ópalos se añadirán',
      'Ópalos recibidos',
      'Canje de ópalos obtenidos',
      'Consigue ópalos gratuitos',
      'Historial de otros ópalos',
      'Ópalos necesarios: por definir',
      'Ópalos y premios',
    ],
  ),
  'ko': (
    bad: [
      '오팔으로 해제',
      '무료 오팔를 모으기',
      '오팔는 사라지지 않습니다',
      '오팔와 특전',
      '오팔가 쌓입니다',
      '이 오팔랑 목표',
      '오팔나 교환',
      '오팔예요',
      '오팔야',
      '오팔라고 합니다',
      '오팔면 됩니다',
    ],
    good: [
      '오팔로 잠금 해제됨',
      '오팔을 모으기',
      '오팔은 사라지지 않습니다',
      '오팔과 특전',
      '오팔이 쌓입니다',
      '이 오팔이랑 목표',
      '오팔이나 교환',
      '오팔이에요',
      '오팔로써 교환',
      '광고 보고 오팔가루 받기',
      '오팔다운 색',
      '무료 오팔 적립',
    ],
  ),
};

/// 言語ごとの、オパールの文法の見張りの式。
final _opalGrammar = <String, List<(RegExp, String)>>{
  'fr': [
    (_frOpalElision, '母音の前は d’・l’・qu’ と省略する'),
    (_frOpalBareArticle, '冠詞が無い（avec des opales）'),
    (_frOpalMasculine, 'opale は女性名詞'),
  ],
  'es': [(_esOpalFeminine, 'ópalo は男性名詞')],
  'ko': [(_koOpalParticle, '終声ㄹの後は 로・을・은・과・이')],
};

/// 頭文字が小文字で始まってよい語（固有の綴り）。
const _lowercaseNames = ['iOS', 'iPad', 'iPhone', 'macOS'];

String _firstLetterOf(String text) {
  final trimmed = text.replaceFirst(RegExp('^[¿¡«“"\'(   ]+'), '');
  return trimmed.isEmpty ? '' : trimmed[0];
}

/// コピー・切り取りをやめて帯を閉じるボタン（homeClipboardClear）に使わない語
/// （切り取った項目を消すように読める）。
const _clipboardClearErase = <String, List<String>>{
  'es': ['Borrar', 'Eliminar'],
  'fr': ['Effacer', 'Supprimer'],
  'ko': ['지우기', '삭제'],
};

void main() {
  final values = {for (final locale in _locales) locale: _values(locale)};

  test('同じ画面に並ぶ別の操作は、どの言語でも違う文で出す', () {
    final offenders = <String>[];
    for (final MapEntry(key: where, value: keys) in _shownTogether.entries) {
      for (final locale in _locales) {
        final seen = <String, String>{};
        for (final key in keys) {
          final text = values[locale]![key]!;
          final previous = seen[text];
          if (previous != null) {
            offenders.add('$locale $where: $previous と $key が「$text」');
          }
          seen[text] = key;
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('読み違えやすい・崩れた言い回しが残っていない', () {
    final offenders = [
      for (final MapEntry(key: locale, value: byKey) in _forbidden.entries)
        for (final MapEntry(key: key, value: phrases) in byKey.entries)
          for (final MapEntry(key: phrase, value: why) in phrases.entries)
            if (values[locale]![key]!.contains(phrase))
              '$locale $key:「$phrase」($why)',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('コピー・切り取りの帯の「クリア」を、消す意味の語にしない', () {
    final offenders = [
      for (final MapEntry(key: locale, value: words)
          in _clipboardClearErase.entries)
        if (words.contains(values[locale]!['homeClipboardClear']))
          '$locale: ${values[locale]!['homeClipboardClear']}',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('簡体字の作品広場は、YouTubeの「非公開」をいつも同じ語（私享）で呼ぶ', () {
    final zh = values['zh']!;
    final private = zh['communityPostVisibilityPrivateTitle']!;
    final offenders = [
      for (final MapEntry(:key, :value) in zh.entries)
        if (key.startsWith('community') &&
            (value.contains('私密') || value.contains('视频不公开')))
          '$key: $value',
    ];
    expect(
      offenders,
      isEmpty,
      reason: '「$private」へそろえる:\n${offenders.join('\n')}',
    );
    expect(zh['communityPlaybackPrivateTitle'], contains(private));
    expect(zh['communityPlaybackUnavailableBody'], contains(private));
  });

  test('繁体字は共有ファイル（.niashare）をいつも「共享檔案」と呼ぶ', () {
    final offenders = [
      for (final MapEntry(:key, :value) in values['zh_Hant']!.entries)
        if (value.contains('分享檔案')) '$key: $value',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('中国語は数と「秒」の間に空白を入れない（行の途中で単位だけ次の行へ落ちる）', () {
    final spaced = RegExp(r'\} 秒');
    final offenders = [
      for (final locale in const ['zh', 'zh_Hant'])
        for (final MapEntry(:key, :value) in values[locale]!.entries)
          if (spaced.hasMatch(value)) '$locale $key: $value',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('オパール（報酬の通貨）の文は、各言語の文法（省略形・冠詞・性・助詞）に合わせる', () {
    final offenders = <String>[];
    for (final MapEntry(key: locale, value: patterns) in _opalGrammar.entries) {
      for (final (pattern, why) in patterns) {
        for (final MapEntry(:key, :value) in values[locale]!.entries) {
          for (final match in pattern.allMatches(value)) {
            offenders.add('$locale $key:「${match[0]}」($why)');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('オパールの文法の見張りは、崩れた見本を拾い、正しい見本を拾わない', () {
    // スペイン語の「cada」「nada」（性で形を変えない語）を女性形と数えて
    // 正しい文を拾い、フランス語の性の一致（「Opales reçus」）・「du opale」・
    // 「pour opales」、スペイン語の「otras ópalos」「ópalos gratuitas」、
    // 韓国語の「오팔랑」「오팔나」「오팔예요」を拾っていなかった。
    final problems = <String>[];
    for (final MapEntry(key: locale, value: samples)
        in _grammarSamples.entries) {
      bool caught(String text) =>
          _opalGrammar[locale]!.any((rule) => rule.$1.hasMatch(text));
      for (final text in samples.bad) {
        if (!caught(text)) problems.add('$locale 見逃し: $text');
      }
      for (final text in samples.good) {
        if (caught(text)) problems.add('$locale 誤検出: $text');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('英語・スペイン語・フランス語で、文の終わりの後の文が小文字で始まらない', () {
    // 書き出しの大文字・小文字は下のテストで見るが、2つ目の文は見ていなかった
    // （「Opales reçues. vérifiez…」が通った）。
    final offenders = [
      for (final locale in const ['en', 'es', 'fr'])
        for (final MapEntry(:key, :value) in values[locale]!.entries)
          for (final at in _lowercaseSentenceStarts(value))
            '$locale $key:「$at」',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    // 見張りの式そのもの。
    expect(_lowercaseSentenceStarts('Opales reçues. vérifiez le solde'), [
      'Opales reçues. v',
    ]);
    for (final good in const [
      'Mín. minutos',
      'Toca ? arriba a la derecha',
      'Nombre (p. ej., Animación)',
      'Ctrl/Shift/Alt, etc. a la vez',
      'For bulk operations (e.g. applying a filter)',
      'Commentaire (ex. bouche « a » ici)',
      'Utilisez Transf. libre',
    ]) {
      expect(_lowercaseSentenceStarts(good), isEmpty, reason: good);
    }
  });

  test('英語・スペイン語・フランス語で、同じ文の書き出しの大文字・小文字がそろっている', () {
    // 「Monedas recibidas」の語だけを置き換えて「ópalos recibidas」と小文字で
    // 始まっていた（英語は「Opals received」）。画面の見出し・知らせは文頭を
    // 大文字にする。
    final offenders = <String>[];
    for (final key in values['en']!.keys) {
      final starts = <String, String>{
        for (final locale in const ['en', 'es', 'fr'])
          if (values[locale]![key] case final text?)
            if (!_lowercaseNames.any(text.startsWith))
              locale: _firstLetterOf(text),
      };
      bool isLetter(String c) => c.toUpperCase() != c.toLowerCase();
      final upper = [
        for (final MapEntry(key: locale, value: c) in starts.entries)
          if (isLetter(c) && c == c.toUpperCase()) locale,
      ];
      final lower = [
        for (final MapEntry(key: locale, value: c) in starts.entries)
          if (isLetter(c) && c == c.toLowerCase()) locale,
      ];
      if (upper.isNotEmpty && lower.isNotEmpty) {
        offenders.add(
          '$key: ${[for (final l in lower) '$l「${values[l]![key]}」'].join(' ')}'
          '（${upper.join('・')}は大文字）',
        );
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('ホームのコピー・切り取り・ゴミ箱の件数は単数・複数で書き分ける（item(s)にしない）', () {
    // 新しいコピー・切り取りの帯は「1 item copied」と書き分けているのに、
    // すぐ下の知らせは「Copied 1 item(s)」だった。
    final offenders = <String>[];
    for (final language in const ['en', 'es', 'fr']) {
      final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
      for (final count in const [1, 2]) {
        for (final text in [
          l10n.homeCopiedSnackbar(count),
          l10n.homeCutSnackbar(count),
          l10n.homeMoveToTrashConfirm(count),
          l10n.homeMovedToTrashSnackbar(count),
        ]) {
          if (text.contains('(s)')) offenders.add('$language $count: $text');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.homeCopiedSnackbar(1), startsWith('Copied 1 item. '));
    expect(en.homeCopiedSnackbar(3), startsWith('Copied 3 items. '));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.homeMovedToTrashSnackbar(1), '1 élément mis à la corbeille');
    expect(fr.homeMovedToTrashSnackbar(2), '2 éléments mis à la corbeille');
  });

  group('書き出した作品のサムネイルのダイアログ', () {
    late Directory dir;
    late File work;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('thumb-wording-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
      work = File('${dir.path}/still.png');
    });

    tearDown(() {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    for (final language in _locales) {
      testWidgets('$language: 同時に出る文がすべて違う', (tester) async {
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(
            const Rect.fromLTWH(0, 0, 8, 8),
            Paint()..color = const Color(0xFF3366CC),
          );
          final image = await recorder.endRecording().toImage(8, 8);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await work.writeAsBytes(png!.buffer.asUint8List(), flush: true);
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 1400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: localeFromLanguageCode(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showExportedWorkThumbnailDialog(context, file: work),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }

        List<String> shown() => [
          for (final widget in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          ))
            if ((widget.data ?? '').isNotEmpty) widget.data!,
        ];

        for (final mode in const ['exportCoverCustom', 'exportCoverFrame']) {
          await tester.tap(find.byKey(Key(mode)));
          await tester.pump(const Duration(milliseconds: 300));
          final texts = shown();
          final duplicated = [
            for (final text in texts.toSet())
              if (texts.where((t) => t == text).length > 1) text,
          ];
          expect(duplicated, isEmpty, reason: '$language $mode: $texts');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
