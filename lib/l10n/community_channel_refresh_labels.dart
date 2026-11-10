import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// Manual YouTube channel profile refresh: one successful request per JST day.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
class CommunityChannelRefreshLabels {
  const CommunityChannelRefreshLabels._(this._l10n);
  final AppLocalizations _l10n;

  static CommunityChannelRefreshLabels of(BuildContext context) =>
      CommunityChannelRefreshLabels._(appLocalizationsOf(context));

  String get button => _l10n.communityChannelRefreshButton;
  String get success => _l10n.communityChannelRefreshSuccess;
  String get noToken => _l10n.communityChannelRefreshNoToken;
  String get unavailable => _l10n.communityChannelRefreshUnavailable;
  String get failed => _l10n.communityChannelRefreshFailed;
}
