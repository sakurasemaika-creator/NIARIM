import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// Posting visibility must be explicit: unlisted does not mean private.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
class CommunityPostVisibilityLabels {
  const CommunityPostVisibilityLabels._(this._l10n);
  final AppLocalizations _l10n;

  static CommunityPostVisibilityLabels of(BuildContext context) =>
      CommunityPostVisibilityLabels._(appLocalizationsOf(context));

  String get heading => _l10n.communityPostVisibilityHeading;
  String get unlistedTitle => _l10n.communityPostVisibilityUnlistedTitle;
  String get unlistedHelp => _l10n.communityPostVisibilityUnlistedHelp;
  String get publicTitle => _l10n.communityPostVisibilityPublicTitle;
  String get publicHelp => _l10n.communityPostVisibilityPublicHelp;
  String get unlistedDisclosure =>
      _l10n.communityPostVisibilityUnlistedDisclosure;
}
