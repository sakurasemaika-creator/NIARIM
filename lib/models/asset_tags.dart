/// ブラシ・トーン・スタンプへ付ける分類用タグの共通ヘルパー。
///
/// お気に入り（1ビット）・フォルダ（1つだけ所属）とは別の軸として、
/// 1つの素材へ複数の観点（用途・雰囲気・案件名など）を付けられるようにする。
library;

/// 組み込みプリセットへ最初から付いている既定タグの識別子。
///
/// タグは保存データへそのまま書き込まれるため、**表示用の日本語文字列を
/// そのまま入れてしまうと、英語・韓国語などの利用者にも日本語のタグが
/// 表示される**（実際に一度そう実装してしまった）。そこで既定タグは
/// 言語に依存しないこのキーで保存し、画面へ出すときに
/// `localizeAssetTag()`でその言語の文言へ解決する。
///
/// 利用者が自由入力したタグと区別するため先頭に`@`を付ける。
/// [splitTagInput]が利用者入力から先頭の`@`を取り除くので、
/// 利用者がキーと衝突するタグを作ることはできない。
class AssetTagKeys {
  const AssetTagKeys._();

  static const lineArt = '@lineart';
  static const basic = '@basic';
  static const mainLine = '@mainline';
  static const paint = '@paint';
  static const blur = '@blur';
  static const mixing = '@mixing';
  static const analog = '@analog';
  static const decoration = '@decoration';
  static const rough = '@rough';
  static const effect = '@effect';
  static const taper = '@taper';
  static const pixelArt = '@pixelart';
  static const halftone = '@halftone';
  static const shadow = '@shadow';
  static const line = '@line';
  static const gradient = '@gradient';
  static const texture = '@texture';
  static const clothing = '@clothing';
  static const mesh = '@mesh';
  static const background = '@background';
  static const pattern = '@pattern';
  static const shape = '@shape';
  static const symbol = '@symbol';
  static const manga = '@manga';

  /// 既定タグのキー一覧（テストの網羅性検証に使う）。
  static const all = <String>[
    lineArt,
    basic,
    mainLine,
    paint,
    blur,
    mixing,
    analog,
    decoration,
    rough,
    effect,
    taper,
    pixelArt,
    halftone,
    shadow,
    line,
    gradient,
    texture,
    clothing,
    mesh,
    background,
    pattern,
    shape,
    symbol,
    manga,
  ];

  /// そのタグが既定タグのキーか（＝l10nで解決すべきものか）。
  static bool isKey(String tag) => tag.startsWith('@');
}

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
///
/// 先頭の`@`は取り除く。`@`始まりは[AssetTagKeys]（既定タグのキー）専用の
/// 名前空間で、利用者がそこへ入り込めるとl10nの解決結果と食い違うため。
List<String> splitTagInput(String text) => normalizeTags(
  text.split(RegExp(r'[,、\s]+')).map((t) => t.replaceFirst(RegExp(r'^@+'), '')),
);

/// [tags]が[query]に一致するか（大文字小文字を無視した部分一致）。
bool tagsMatch(List<String> tags, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return tags.any((t) => t.toLowerCase().contains(q));
}

/// 既定タグを日本語リテラルで保存していた版からの移行表。
///
/// タグ機能を入れた直後の版は、既定タグを表示用の日本語文字列のまま
/// 保存していた（そのため英語UIでも日本語のタグが出ていた）。その版で
/// 保存されたデータを、言語非依存のキーへ読み替える。
///
/// 対象は**組み込みプリセットの既定タグと完全一致するものだけ**。
/// 利用者が偶然同じ語を自分で入力していた場合も既定タグ扱いになるが、
/// 表示は同じ語のままで、言語を切り替えたときに訳が出るようになるだけ
/// なので実害が無い。
const Map<String, String> kLegacyJapaneseTagMigration = {
  '線画': AssetTagKeys.lineArt,
  '基本': AssetTagKeys.basic,
  '主線': AssetTagKeys.mainLine,
  '塗り': AssetTagKeys.paint,
  'ぼかし': AssetTagKeys.blur,
  '混色': AssetTagKeys.mixing,
  'アナログ風': AssetTagKeys.analog,
  '装飾': AssetTagKeys.decoration,
  'ラフ': AssetTagKeys.rough,
  '効果': AssetTagKeys.effect,
  '入り抜き': AssetTagKeys.taper,
  'ドット絵': AssetTagKeys.pixelArt,
  '網点': AssetTagKeys.halftone,
  '影': AssetTagKeys.shadow,
  '線': AssetTagKeys.line,
  'グラデ': AssetTagKeys.gradient,
  '質感': AssetTagKeys.texture,
  '服': AssetTagKeys.clothing,
  '網目': AssetTagKeys.mesh,
  '背景': AssetTagKeys.background,
  '模様': AssetTagKeys.pattern,
  '図形': AssetTagKeys.shape,
  '記号': AssetTagKeys.symbol,
  'マンガ': AssetTagKeys.manga,
};

/// 保存済みタグ列を、必要なら新しいキー形式へ読み替える。
/// 変換が起きなければ元のリストをそのまま返す（無駄な再保存を避けるため、
/// 呼び出し側は同一性で「変わったかどうか」を判定できる）。
List<String> migrateLegacyTags(List<String> tags) {
  if (!tags.any(kLegacyJapaneseTagMigration.containsKey)) return tags;
  return normalizeTags([
    for (final t in tags) kLegacyJapaneseTagMigration[t] ?? t,
  ]);
}
