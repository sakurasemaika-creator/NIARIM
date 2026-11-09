import 'package:flutter/widgets.dart';

/// Ranking-only display modes. All labels are localized; no global grid sizes
/// or other community tabs are changed by the ranking layout selector.
class CommunityRankingLayoutLabels {
  const CommunityRankingLayoutLabels._(this._values);
  final List<String> _values;

  static CommunityRankingLayoutLabels of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final code = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant'
        : locale.languageCode;
    return CommunityRankingLayoutLabels._(_all[code] ?? _all['en']!);
  }

  String get title => _values[0];
  String get horizontal => _values[1];
  String get largeThumbnail => _values[2];
  String get rankedPlace => _values[3];
  String get periodBookmarks => _values[4];
}

const _all = <String, List<String>>{
  'ja': ['ランキングの表示形式', '横長リスト', '大きいサムネイル', '位', '期間内ブックマーク'],
  'en': ['Ranking layout', 'Compact rows', 'Large thumbnails', 'Rank', 'Bookmarks this period'],
  'es': [
    'Vista de clasificación',
    'Filas compactas',
    'Miniaturas grandes',
    'Puesto',
    'Marcadores del período',
  ],
  'fr': [
    'Affichage du classement',
    'Lignes compactes',
    'Grandes miniatures',
    'Rang',
    'Favoris de la période',
  ],
  'ko': ['랭킹 표시 방식', '가로 목록', '큰 썸네일', '순위', '기간 내 북마크'],
  'zh': ['排行榜布局', '横向列表', '大缩略图', '排名', '本期收藏'],
  'zh_Hant': ['排行榜版面', '橫向清單', '大縮圖', '排名', '本期書籤'],
};
