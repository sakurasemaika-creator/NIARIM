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
}

const _all = <String, List<String>>{
  'ja': ['ランキングの表示形式', '横長リスト', '大きいサムネイル', '位'],
  'en': ['Ranking layout', 'Compact rows', 'Large thumbnails', 'Rank'],
  'es': [
    'Vista de clasificación',
    'Filas compactas',
    'Miniaturas grandes',
    'Puesto',
  ],
  'fr': [
    'Affichage du classement',
    'Lignes compactes',
    'Grandes miniatures',
    'Rang',
  ],
  'ko': ['랭킹 표시 방식', '가로 목록', '큰 썸네일', '순위'],
  'zh': ['排行榜布局', '横向列表', '大缩略图', '排名'],
  'zh_Hant': ['排行榜版面', '橫向清單', '大縮圖', '排名'],
};
