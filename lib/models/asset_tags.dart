/// ブラシ・トーン・スタンプへ付ける分類用タグの共通ヘルパー。
///
/// お気に入り（1ビット）・フォルダ（1つだけ所属）とは別の軸として、
/// 1つの素材へ複数の観点（用途・雰囲気・案件名など）を付けられるようにする。
library;

/// タグ1件の最大文字数。長すぎるとチップの表示が破綻するため制限する。
const int kAssetTagMaxLength = 24;

/// 1つの素材へ付けられるタグの最大数。
const int kAssetTagMaxCount = 12;

/// 保存済みJSONからタグ一覧を復元する。
///
/// タグは後から追加したフィールドなので、旧データにはキー自体が存在しない
/// （その場合は空リストになる）。型が壊れているデータでも落ちないよう、
/// 文字列以外の要素は捨てる。
List<String> parseTags(Object? raw) {
  if (raw is! List) return const [];
  return normalizeTags(raw.whereType<String>());
}

/// 入力されたタグ列を正規化する。
///
/// 前後の空白を落とし、空文字を除き、大文字小文字を無視した重複を1つに
/// まとめ、長すぎるものを切り詰めたうえで、件数の上限を適用する。
/// 表示順は入力順のままにする（利用者が付けた順に並ぶほうが探しやすい）。
List<String> normalizeTags(Iterable<String> input) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in input) {
    var tag = raw.trim();
    if (tag.isEmpty) continue;
    if (tag.length > kAssetTagMaxLength) {
      tag = tag.substring(0, kAssetTagMaxLength);
    }
    if (!seen.add(tag.toLowerCase())) continue;
    out.add(tag);
    if (out.length >= kAssetTagMaxCount) break;
  }
  return List.unmodifiable(out);
}

/// カンマ・読点・空白区切りの入力文字列をタグ一覧へ分解する。
List<String> splitTagInput(String text) =>
    normalizeTags(text.split(RegExp(r'[,、\s]+')));

/// [tags]が[query]に一致するか（大文字小文字を無視した部分一致）。
bool tagsMatch(List<String> tags, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return tags.any((t) => t.toLowerCase().contains(q));
}
