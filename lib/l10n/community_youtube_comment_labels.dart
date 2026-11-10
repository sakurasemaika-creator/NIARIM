import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
class CommunityYoutubeCommentLabels {
  const CommunityYoutubeCommentLabels._(this._l10n);
  final AppLocalizations _l10n;

  static CommunityYoutubeCommentLabels of(BuildContext context) =>
      CommunityYoutubeCommentLabels._(appLocalizationsOf(context));

  String get heading => _l10n.communityYoutubeCommentHeading;
  String get loadMore => _l10n.communityYoutubeCommentLoadMore;
  String get noComments => _l10n.communityYoutubeCommentNoComments;
  String get unavailable => _l10n.communityYoutubeCommentUnavailable;
  String get retry => _l10n.communityYoutubeCommentRetry;
  String get replies => _l10n.communityYoutubeCommentReplies;
  String get attribution => _l10n.communityYoutubeCommentAttribution;
}
