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

/// [text]にハングルが入っているか。
bool containsHangul(String text) => _hangul.hasMatch(text);

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
