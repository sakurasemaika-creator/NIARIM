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
