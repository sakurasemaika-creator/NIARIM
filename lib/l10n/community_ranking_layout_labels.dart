import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// Ranking-only display modes. All labels are localized; no global grid sizes
/// or other community tabs are changed by the ranking layout selector.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
class CommunityRankingLayoutLabels {
  const CommunityRankingLayoutLabels._(this._l10n);
  final AppLocalizations _l10n;

  static CommunityRankingLayoutLabels of(BuildContext context) =>
      CommunityRankingLayoutLabels._(appLocalizationsOf(context));

  String get title => _l10n.communityRankingLayoutTitle;
  String get horizontal => _l10n.communityRankingLayoutHorizontal;
  String get largeThumbnail => _l10n.communityRankingLayoutLargeThumbnail;

  /// 順位の読み上げ（「3位」「Rank 3」）。数と単位の順は言語で違うので、
  /// 単位の語だけを返してコードで数とつながない。
  String rankedPlace(int rank) => _l10n.communityRankingLayoutRankedPlace(rank);
  String get periodBookmarks => _l10n.communityRankingLayoutPeriodBookmarks;
}
