import 'package:intl/intl.dart';

/// 単語結合子（U+2060）。幅も字形も持たず、両側での折り返しを禁じる。
const String _wordJoiner = '\u2060';

final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]');

/// 韓国語の文を、語（空白で区切られた単位）の途中で折り返さないようにする。
///
/// 韓国語は語を空白で区切って書き、折り返しも空白の所で行うのが普通
/// （CSSの`word-break: keep-all`）。Flutterの折り返しはハングルを漢字と
/// 同じく「どの字の間でも折り返せる」扱いにするため、「애니메이션 만들기」が
/// 「애니메이션 만들／기」のように語の途中で切れる。語の中の字の間に
/// 単語結合子を挟み、空白の所でだけ折り返すようにする。
///
/// ハングルを含まない文はそのまま返す（日本語・中国語は字の間で折り返すのが
/// 正しく、ここで結合すると長い語が折り返せなくなる）。語そのものが
/// 表示幅より長い場合は折り返せなくなるので、短い見出し・ボタンの文言に
/// 使うこと。
String keepKoreanWordsTogether(String text) {
  if (!_hangul.hasMatch(text)) return text;
  final out = StringBuffer();
  String? previous;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (previous != null &&
        !_isBreakable(previous) &&
        !_isBreakable(char) &&
        previous != _wordJoiner &&
        char != _wordJoiner) {
      out.write(_wordJoiner);
    }
    out.write(char);
    previous = char;
  }
  return out.toString();
}

bool _isBreakable(String char) => char.trim().isEmpty;

/// 文[text]の中の[parts]（日付・時刻など）を、それぞれ行の途中で折り返さない
/// ひとかたまりにする。かたまりの中の空白は改行しない空白（U+00A0）にし、
/// ほかの字の間には語結合子を挟む（数字・記号・ハングル・漢字のどの間でも
/// 折り返さない）。かたまりの外の空白では今までどおり折り返せる。
///
/// [fits]を渡すと、それが偽を返すかたまり（1行に入らないもの）はそのままに
/// する（かたまりにすると、行に入らないとき字の途中で切れる）。[fits]には
/// かたまりにした後の文を渡す。表示する`Text`には[plainSemanticsLabel]か
/// 元の文を読み上げに添えること。
String keepPartsTogether(
  String text,
  Iterable<String> parts, {
  bool Function(String part)? fits,
}) {
  var result = text;
  for (final part in parts) {
    if (part.isEmpty) continue;
    final at = result.indexOf(part);
    if (at < 0) continue;
    final joined = StringBuffer();
    String? previous;
    for (final rune in part.runes) {
      var char = String.fromCharCode(rune);
      if (char == ' ') char = '\u00A0';
      if (previous != null && !_isBreakable(previous) && !_isBreakable(char)) {
        joined.write(_wordJoiner);
      }
      joined.write(char);
      previous = char;
    }
    final kept = joined.toString();
    if (fits != null && !fits(kept)) continue;
    result = result.replaceRange(at, at + part.length, kept);
  }
  return result;
}

/// [when]を日付（`yMd`）と時刻（`jm`）の書き方で含む文[line]を、日付・時刻の
/// 途中と韓国語の語の途中では折り返さないようにする（狭い行・大きな文字で、
/// 「2026. 11. 13. 오 / 후 6:19」のように午後の途中で切れた）。日付と時刻の
/// 間・ほかの語との間の空白では折り返せる。[fits]は[keepPartsTogether]と同じ
/// （1行に入らない日付・時刻・語はそのまま）。
String keepDateTimeTogether(
  String line,
  DateTime when,
  String localeName, {
  bool Function(String part)? fits,
}) => keepKoreanWordsTogetherWhere(
  keepPartsTogether(line, [
    DateFormat.yMd(localeName).format(when),
    DateFormat.jm(localeName).format(when),
  ], fits: fits),
  fits ?? (_) => true,
);

/// 行の頭に置かない字（長音・小書きの仮名）。前の字と同じ行に残す
/// （日本語の行頭禁則）。
const String _noLineStart = 'ーぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ';

/// [char]が、行の頭に置かない字（長音・小書きの仮名）か。
bool isNoLineStartCharacter(String char) =>
    char.isNotEmpty && _noLineStart.contains(char);

/// 文[text]の長音（ー）・小書きの仮名（ッ・ョ等）を、前の字と同じ行に残す
/// （前に単語結合子を挟む）。Flutterの行分けはこれらの前でも行を変える
/// ので、名前が「(コピ / ー 2)」「ファーストショ / ット」のように長音・
/// 小書きの仮名から始まる行に折れた。表示する文にだけ入れ、読み上げ・
/// 文での検索には元の文を渡す（[plainSemanticsLabel]）。
String keepJapaneseLineStartsAttached(String text) {
  if (!text.runes.any((rune) => _noLineStart.runes.contains(rune))) {
    return text;
  }
  final out = StringBuffer();
  String? previous;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (previous != null &&
        _noLineStart.contains(char) &&
        previous.trim().isNotEmpty &&
        previous != _wordJoiner) {
      out.write(_wordJoiner);
    }
    out.write(char);
    previous = char;
  }
  return out.toString();
}

/// [text]にハングルが入っているか。
bool containsHangul(String text) => _hangul.hasMatch(text);

/// ファイル名の区切りの記号（「_」「.」「-」）。
final RegExp _fileNameSeparators = RegExp(r'[_.-]');

/// 空白の無いファイル名（「walk_cycle_loop.gif」等）に、区切りの記号
/// （「_」「.」「-」）の前で行を変えてよい印（幅の無い空白 U+200B）を入れる。
///
/// 印が無いと、行に入らない名前は入る所までの字で切れ、
/// 「walk_cycle_loop.gi / f」「discarded_take_03.m / p4」のように最後の字だけ
/// 次の行へ送られた。書き出した作品の詳細の行（ExportedWorkCard）と同じ
/// 決まり。表示する文にだけ入れ、読み上げ・文での検索には元の名前を渡す。
/// ハングルを含む名前はそのまま返す（語の途中で折り返さない処理
/// 〔[keepKoreanWordsTogetherWhere]〕に任せる）。
String breakableAtFileSeparators(String name) {
  if (containsHangul(name)) return name;
  return name.replaceAllMapped(_fileNameSeparators, (m) => '\u200B${m[0]}');
}

/// [keepKoreanWordsTogether]と同じく韓国語の語の途中で折り返さないように
/// するが、[fits]が偽を返す語（1行に入らない長い語）はそのままにする（語の
/// 途中で折り返せないと、行からはみ出す）。作品名のように長さの決まって
/// いない文に使う。[fits]には語結合子を挟んだ後の語を渡す（語結合子にも
/// 字の間隔〔letterSpacing〕が付くので、挟んだ後の幅で測る）。
String keepKoreanWordsTogetherWhere(
  String text,
  bool Function(String word) fits,
) {
  if (!_hangul.hasMatch(text)) return text;
  return text.splitMapJoin(
    RegExp(r'\S+'),
    onMatch: (match) {
      final word = match[0]!;
      if (!_hangul.hasMatch(word)) return word;
      final joined = keepKoreanWordsTogether(word);
      return fits(joined) ? joined : word;
    },
  );
}

/// 字の間のどこでも折り返せる字（漢字・ひらがな・カタカナ）。
final RegExp _cjkLetter = RegExp(r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF]');

/// 名前を囲む引用符。
const String _quotationMarks = '「」『』“”‘’«»"\'';

/// 文[text]の中の名前[phrase]（押すボタンの名前など）を、すぐ外の引用符ごと
/// 行の途中で折り返さないようにする。
///
/// 日本語・中国語は字の間のどこでも折り返せるので、「もう一度「はじめる」を
/// 押してください」が「「はじ／める」」のように、押すボタンの名前の途中で
/// 切れる。名前とそのすぐ外の引用符の字の間に単語結合子を挟む。
///
/// 名前に漢字・かなが無いとき（英語・フランス語など、語を空白で区切る言語）は
/// そのまま返す。語の途中では折り返されず、空白の所の折り返しは単語結合子
/// では止められない。韓国語は文全体を[keepKoreanWordsTogether]に通すこと。
/// 表示する`Text`には[plainSemanticsLabel]を添える。
String keepPhraseTogether(String text, String phrase) {
  if (phrase.isEmpty || !_cjkLetter.hasMatch(phrase)) return text;
  final out = StringBuffer();
  var from = 0;
  while (true) {
    final at = text.indexOf(phrase, from);
    if (at < 0) break;
    var start = at;
    var end = at + phrase.length;
    if (start > from && _quotationMarks.contains(text[start - 1])) start--;
    if (end < text.length && _quotationMarks.contains(text[end])) end++;
    out
      ..write(text.substring(from, start))
      ..write(
        text
            .substring(start, end)
            .runes
            .map(String.fromCharCode)
            .join(_wordJoiner),
      );
    from = end;
  }
  out.write(text.substring(from));
  return out.toString();
}

/// 語結合子を入れた表示の文[shown]を出す`Text`の`semanticsLabel`。
///
/// 語結合子は字形を持たないが、読み上げ（TalkBack）・点字には字として渡り、
/// 音節ごとに区切りが入る。語結合子を除いた元の文を返し、語結合子が無ければ
/// null（`Text`の既定どおり表示の文を読む）を返す。
/// [keepKoreanWordsTogether]を通した文を出すときは必ず添えること。
String? plainSemanticsLabel(String shown) =>
    shown.contains(_wordJoiner) ? shown.replaceAll(_wordJoiner, '') : null;

/// 行の始めに来てはいけない字（日本語の行頭禁則）：長音符「ー」、小さいかな、
/// 閉じ括弧・句読点。
///
/// ーぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ
/// ㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ
/// 、。，．・：；？！）」』】〕〉》〙〗］｝’”)]},.:;?!
///
/// 字を照らし合わせるためのもので画面には出さないので、同梱の書体に無い字
/// （小さいかなの一部・アイヌ語の小書きのカタカナ等）も入れられるよう、
/// 逃がし文字で書く。[_noLineStart]（長音・小書きの仮名だけ）より広い。
const String _noLineStartOrClosing =
    '\u30FC\u3041\u3043\u3045\u3047\u3049\u3063\u3083\u3085\u3087'
    '\u308E\u3095\u3096\u30A1\u30A3\u30A5\u30A7\u30A9\u30C3\u30E3'
    '\u30E5\u30E7\u30EE\u30F5\u30F6\u31F0\u31F1\u31F2\u31F3\u31F4'
    '\u31F5\u31F6\u31F7\u31F8\u31F9\u31FA\u31FB\u31FC\u31FD\u31FE'
    '\u31FF\u3001\u3002\uFF0C\uFF0E\u30FB\uFF1A\uFF1B\uFF1F\uFF01'
    '\uFF09\u300D\u300F\u3011\u3015\u3009\u300B\u3019\u3017\uFF3D'
    '\uFF5D\u2019\u201D)]},.:;?!';

/// 文[text]の中の、行の始めに来てはいけない字（長音符・小さいかな・閉じ
/// 括弧・句読点）の続きと、そのすぐ前の字を合わせた部分（「カリグラフィー」の
/// 「フィー」）。`KeepTogetherText`の`keep`に渡すと、その字の前で行を変え
/// ない（Flutterは長音符・小さいかなの前でも行を変え、「カリグラフィ / ー」
/// と長音符で始まる行ができた）。文の始め・空白の後の字は数えない。
List<String> lineStartKeepParts(String text) {
  final parts = <String>[];
  var i = 1;
  while (i < text.length) {
    if (!_noLineStartOrClosing.contains(text[i]) || _isBreakable(text[i - 1])) {
      i++;
      continue;
    }
    // すぐ前の字（サロゲートペアなら2単位）から、禁則の字の続きの終わりまで。
    var start = i - 1;
    if (start > 0 &&
        text.codeUnitAt(start) >= 0xDC00 &&
        text.codeUnitAt(start) <= 0xDFFF) {
      start--;
    }
    var end = i + 1;
    while (end < text.length && _noLineStartOrClosing.contains(text[end])) {
      end++;
    }
    parts.add(text.substring(start, end));
    i = end;
  }
  return parts;
}

/// ひらがな。
final RegExp _hiragana = RegExp(r'[\u3041-\u309F]');

/// 日本語の語（文節）の始まりになる字：漢字・カタカナ・英数字・開き括弧。
final RegExp _phraseHead = RegExp(
  r'[\u30A0-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF'
  r'A-Za-z0-9\uFF10-\uFF19\uFF21-\uFF3A\uFF41-\uFF5A（「『【]',
);

/// 字（文字・数字）。句読点・括弧・空白は数えない。
final RegExp _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// 日本語の文[text]の最後の語（ひらがなの後で漢字・カタカナ・英数字が
/// 始まる所から文の終わりまで）。最後の語が[minLetters]字より短いときは、
/// その前の語の始まりまで広げる（「見る」→「詳しく見る」）。
/// `KeepTogetherText`の`keep`に渡すと、最後の行へ送る字を語の途中から
/// 取らない（欄の1行に入らなければ普通に折る）。
///
/// 日本語は字と字の間のどこでも行を変えるので、ボタンの名前が1字分だけ
/// 欄に入らないと「プレミアム会員について詳しく見 / る」と最後の1字だけが
/// 次の行に出た。最後の語をつなぐと、「プレミアム会員について / 詳しく
/// 見る」と語の境目で折る。ひらがなの無い文（中国語など）・語の境目の無い
/// 文・最後の語が文の中にほかにもある文は何もしない（空のリスト）。
List<String> japaneseLastPhraseParts(String text, {int minLetters = 3}) {
  if (!_hiragana.hasMatch(text)) return const [];
  for (var i = text.length - 1; i > 0; i--) {
    if (!_hiragana.hasMatch(text[i - 1]) || !_phraseHead.hasMatch(text[i])) {
      continue;
    }
    final tail = text.substring(i);
    if (_letter.allMatches(tail).length < minLetters) continue;
    return text.indexOf(tail) == i ? [tail] : const [];
  }
  return const [];
}

/// 漢字（々〆ヶを含む）。
final RegExp _kanji = RegExp(
  r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\u3005\u3006\u30F6]',
);

/// カタカナ（長音符を含み、中黒「・」は含まない）。
final RegExp _katakanaLetter = RegExp(
  r'[\u30A1-\u30FA\u30FC-\u30FF\u31F0-\u31FF]',
);

/// 英字・数字（全角を含む）。
final RegExp _latinOrDigit = RegExp(
  r'[A-Za-z0-9\uFF10-\uFF19\uFF21-\uFF3A\uFF41-\uFF5A]',
);

/// 日本語の文[text]の語（漢字の続き・カタカナの続き・英数字の続きに、すぐ
/// 後のひらがな〔送り仮名・助詞〕を足したもの。ひらがなで始まる語はひらがなの
/// 続き）。2字以上の語だけを返す。`KeepTogetherText`の`keep`に渡すと、語の
/// 途中では行を変えず、語と語の間（ひらがなの後・漢字とカタカナの境目・
/// 記号や括弧の所）で行を変える（欄の1行に入らない語だけは字の間で折る）。
///
/// 日本語は字と字の間のどこでも行を変えるので、特典の名前が360pxの幅で
/// 「…（メイキング動 / 画を含む）」と語の途中で折れた。ひらがなの無い漢字
/// だけの文（中国語）では漢字の続きが文全体になるので、日本語の表示のときだけ
/// 使うこと。
List<String> japaneseWordParts(String text) {
  int kind(String char) {
    if (_kanji.hasMatch(char)) return 1;
    if (_katakanaLetter.hasMatch(char)) return 2;
    if (_latinOrDigit.hasMatch(char)) return 3;
    if (_hiragana.hasMatch(char)) return 4;
    return 0;
  }

  final parts = <String>[];
  final chars = [for (final rune in text.runes) String.fromCharCode(rune)];
  var i = 0;
  while (i < chars.length) {
    final head = kind(chars[i]);
    if (head == 0) {
      i++;
      continue;
    }
    var end = i + 1;
    while (end < chars.length && kind(chars[end]) == head) {
      end++;
    }
    if (head != 4) {
      while (end < chars.length && kind(chars[end]) == 4) {
        end++;
      }
    }
    if (end - i > 1) parts.add(chars.sublist(i, end).join());
    i = end;
  }
  return parts;
}
