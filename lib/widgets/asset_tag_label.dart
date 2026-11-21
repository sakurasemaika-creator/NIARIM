import '../l10n/app_localizations.dart';
import '../models/asset_tags.dart';

/// 素材タグを、その言語での表示文言へ解決する。
///
/// 組み込みプリセットの既定タグは言語非依存のキー（[AssetTagKeys]）で
/// 保存されているので、ここでl10nの文言へ置き換える。利用者が自分で
/// 入力したタグはそのまま返す（利用者自身の言語で書かれているため、
/// 翻訳する対象ではない）。
///
/// 未知のキー（将来のバージョンで追加されたタグが付いたデータを、古い
/// アプリで開いた場合など）は`@`を落とした素の文字列を返す。消してしまう
/// より、読める形で見えているほうが害が少ない。
String localizeAssetTag(AppLocalizations l10n, String tag) {
  if (!AssetTagKeys.isKey(tag)) return tag;
  return switch (tag) {
    AssetTagKeys.lineArt => l10n.assetTagLineArt,
    AssetTagKeys.basic => l10n.assetTagBasic,
    AssetTagKeys.mainLine => l10n.assetTagMainLine,
    AssetTagKeys.paint => l10n.assetTagPaint,
    AssetTagKeys.blur => l10n.assetTagBlur,
    AssetTagKeys.mixing => l10n.assetTagMixing,
    AssetTagKeys.analog => l10n.assetTagAnalog,
    AssetTagKeys.decoration => l10n.assetTagDecoration,
    AssetTagKeys.rough => l10n.assetTagRough,
    AssetTagKeys.effect => l10n.assetTagEffect,
    AssetTagKeys.taper => l10n.assetTagTaper,
    AssetTagKeys.pixelArt => l10n.assetTagPixelArt,
    AssetTagKeys.halftone => l10n.assetTagHalftone,
    AssetTagKeys.shadow => l10n.assetTagShadow,
    AssetTagKeys.line => l10n.assetTagLine,
    AssetTagKeys.gradient => l10n.assetTagGradient,
    AssetTagKeys.texture => l10n.assetTagTexture,
    AssetTagKeys.clothing => l10n.assetTagClothing,
    AssetTagKeys.mesh => l10n.assetTagMesh,
    AssetTagKeys.background => l10n.assetTagBackground,
    AssetTagKeys.pattern => l10n.assetTagPattern,
    AssetTagKeys.shape => l10n.assetTagShape,
    AssetTagKeys.symbol => l10n.assetTagSymbol,
    AssetTagKeys.manga => l10n.assetTagManga,
    _ => tag.replaceFirst('@', ''),
  };
}

/// タグ一覧をまとめて表示文言へ解決する。
List<String> localizeAssetTags(AppLocalizations l10n, List<String> tags) => [
  for (final tag in tags) localizeAssetTag(l10n, tag),
];

/// [localizeAssetTag]の逆変換。表示文言を、保存用のキーへ戻す。
///
/// タグ編集ダイアログは利用者に**表示文言**を見せて編集させるため、保存時
/// にこれを通さないと、既定タグがその言語の文字列として焼き付いてしまい
/// （日本語UIで開いて保存しただけで「線画」という日本語リテラルになる）、
/// 言語を切り替えたときに元へ戻らなくなる。
///
/// 一致判定は大文字小文字を無視する。利用者が候補チップではなく手入力で
/// 「pixel art」と打った場合も既定タグとして扱いたいため。どのキーにも
/// 当たらないものは利用者独自のタグなのでそのまま返す。
String delocalizeAssetTag(AppLocalizations l10n, String text) {
  final t = text.trim().toLowerCase();
  for (final key in AssetTagKeys.all) {
    if (localizeAssetTag(l10n, key).toLowerCase() == t) return key;
  }
  return text;
}

/// タグ一覧をまとめて保存用のキーへ戻す。
List<String> delocalizeAssetTags(AppLocalizations l10n, List<String> tags) => [
  for (final tag in tags) delocalizeAssetTag(l10n, tag),
];
