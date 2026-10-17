/// 作品・フォルダの名前を、人が読む順に並べ・探すための比較。
///
/// 文字コードの順に並べると「作品10」が「作品2」より前、大文字の「Banana」が
/// 小文字の「apple」より前、全角の「ＡＢＣ」や半角の「ｶﾀｶﾅ」が一番後ろに
/// なる。ここでは比べる前に次をそろえる（表示する名前は変えない）。
/// - 全角の英数字・記号を半角に、全角の空白を半角に
/// - 半角カタカナを全角に（濁点・半濁点はまとめて1文字に）
/// - カタカナをひらがなに
/// - 英字の大文字を小文字に
/// 並べるときは、名前の中の数字の並びを数として比べる。
library;

/// [compareNames]・[nameMatches]で使う、比べるための形。
String foldName(String name) {
  final out = StringBuffer();
  final runes = name.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    var c = runes[i];
    if (c == 0x3000) {
      c = 0x20;
    } else if (c >= 0xFF01 && c <= 0xFF5E) {
      c -= 0xFEE0;
    } else if (c >= 0xFF61 && c <= 0xFF9F) {
      final mark = i + 1 < runes.length ? runes[i + 1] : 0;
      final full = _halfwidthKana[c - 0xFF61];
      final voiced = mark == 0xFF9E ? _voiced(full) : null;
      final semi = mark == 0xFF9F ? _semiVoiced(full) : null;
      c = voiced ?? semi ?? full;
      if (voiced != null || semi != null) i++;
    }
    if (c >= 0x30A1 && c <= 0x30F6) c -= 0x60;
    out.writeCharCode(c);
  }
  return out.toString().toLowerCase();
}

/// [name]に[query]が含まれるか（[foldName]でそろえて比べる）。
/// [query]はあらかじめ[foldName]を通したものを渡す。
bool nameMatches(String name, String foldedQuery) =>
    foldName(name).contains(foldedQuery);

/// 名前の比較（昇順）。数字の並びは数として比べ（「作品2」＜「作品10」）、
/// それ以外は[foldName]でそろえた文字で比べる。そろえると同じになる名前
/// どうしは、元の文字の順で決める（並び順が毎回変わらないように）。
/// 一覧を並べるときは[NameSortKey]で名前ごとに1回だけそろえること
/// （比べるたびにそろえると、数百件で1回の並べ替えに数十ミリ秒かかる）。
int compareNames(String a, String b) =>
    compareNameKeys(NameSortKey(a), NameSortKey(b));

/// [foldName]した結果を持たせた、並べ替え用の名前。
class NameSortKey {
  NameSortKey(this.raw) : folded = foldName(raw);

  final String raw;
  final String folded;
}

/// [compareNames]と同じ順で、そろえ済みの名前を比べる。
int compareNameKeys(NameSortKey a, NameSortKey b) {
  final byFolded = _compareNatural(a.folded, b.folded);
  return byFolded != 0 ? byFolded : a.raw.compareTo(b.raw);
}

int _compareNatural(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final ca = a.codeUnitAt(i);
    final cb = b.codeUnitAt(j);
    if (_isDigit(ca) && _isDigit(cb)) {
      final startA = i;
      final startB = j;
      while (i < a.length && _isDigit(a.codeUnitAt(i))) {
        i++;
      }
      while (j < b.length && _isDigit(b.codeUnitAt(j))) {
        j++;
      }
      final numA = _stripZeros(a.substring(startA, i));
      final numB = _stripZeros(b.substring(startB, j));
      if (numA.length != numB.length) return numA.length - numB.length;
      final byValue = numA.compareTo(numB);
      if (byValue != 0) return byValue;
      // 同じ数なら、前に0の少ない方（「1」＜「01」）。
      final byZeros = (i - startA) - (j - startB);
      if (byZeros != 0) return byZeros;
      continue;
    }
    if (ca != cb) return ca - cb;
    i++;
    j++;
  }
  return (a.length - i) - (b.length - j);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

String _stripZeros(String digits) {
  var k = 0;
  while (k < digits.length - 1 && digits.codeUnitAt(k) == 0x30) {
    k++;
  }
  return digits.substring(k);
}

// 半角カタカナ（U+FF61〜U+FF9F）に対応する全角の文字。
const List<int> _halfwidthKana = [
  0x3002, 0x300C, 0x300D, 0x3001, 0x30FB, 0x30F2, 0x30A1, 0x30A3, //
  0x30A5, 0x30A7, 0x30A9, 0x30E3, 0x30E5, 0x30E7, 0x30C3, 0x30FC, //
  0x30A2, 0x30A4, 0x30A6, 0x30A8, 0x30AA, 0x30AB, 0x30AD, 0x30AF, //
  0x30B1, 0x30B3, 0x30B5, 0x30B7, 0x30B9, 0x30BB, 0x30BD, 0x30BF, //
  0x30C1, 0x30C4, 0x30C6, 0x30C8, 0x30CA, 0x30CB, 0x30CC, 0x30CD, //
  0x30CE, 0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB, 0x30DE, 0x30DF, //
  0x30E0, 0x30E1, 0x30E2, 0x30E4, 0x30E6, 0x30E8, 0x30E9, 0x30EA, //
  0x30EB, 0x30EC, 0x30ED, 0x30EF, 0x30F3, 0x309B, 0x309C, //
];

// 濁点が付く文字（カ〜ト・ハ〜ホは次の文字、ウはヴ）。
int? _voiced(int kana) {
  if (kana == 0x30A6) return 0x30F4;
  if ((kana >= 0x30AB && kana <= 0x30C8 && kana != 0x30C3) ||
      (kana >= 0x30CF && kana <= 0x30DB && (kana - 0x30CF) % 3 == 0)) {
    return kana + 1;
  }
  return null;
}

// 半濁点が付く文字（ハ〜ホ）。
int? _semiVoiced(int kana) =>
    kana >= 0x30CF && kana <= 0x30DB && (kana - 0x30CF) % 3 == 0
    ? kana + 2
    : null;
