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

/// 語結合子を入れた表示の文[shown]を出す`Text`の`semanticsLabel`。
///
/// 語結合子は字形を持たないが、読み上げ（TalkBack）・点字には字として渡り、
/// 音節ごとに区切りが入る。語結合子を除いた元の文を返し、語結合子が無ければ
/// null（`Text`の既定どおり表示の文を読む）を返す。
/// [keepKoreanWordsTogether]を通した文を出すときは必ず添えること。
String? plainSemanticsLabel(String shown) =>
    shown.contains(_wordJoiner) ? shown.replaceAll(_wordJoiner, '') : null;
