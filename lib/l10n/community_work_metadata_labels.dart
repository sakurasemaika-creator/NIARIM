import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
class CommunityWorkMetadataLabels {
  const CommunityWorkMetadataLabels._(this._l10n);
  final AppLocalizations _l10n;

  static CommunityWorkMetadataLabels of(BuildContext context) =>
      CommunityWorkMetadataLabels._(appLocalizationsOf(context));

  String get title => _l10n.communityWorkMetadataTitle;
  String get description => _l10n.communityWorkMetadataDescription;
  String get descriptionHint => _l10n.communityWorkMetadataDescriptionHint;
  String get edit => _l10n.communityWorkMetadataEdit;
  String get saved => _l10n.communityWorkMetadataSaved;
  String get info => _l10n.communityWorkMetadataInfo;
  String get loadFailed => _l10n.communityWorkMetadataLoadFailed;
  String get youtubeDescription =>
      _l10n.communityWorkMetadataYoutubeDescription;
  String get youtubeDescriptionHint =>
      _l10n.communityWorkMetadataYoutubeDescriptionHint;
  String get youtubeDescriptionInvalid =>
      _l10n.communityWorkMetadataYoutubeDescriptionInvalid;
  String get youtubeTitle => _l10n.communityWorkMetadataYoutubeTitle;
  String get copyTitleToYoutube =>
      _l10n.communityWorkMetadataCopyTitleToYoutube;
  String get copyTitleToNiarim => _l10n.communityWorkMetadataCopyTitleToNiarim;
  String get copyDescriptionToYoutube =>
      _l10n.communityWorkMetadataCopyDescriptionToYoutube;
  String get copyDescriptionToNiarim =>
      _l10n.communityWorkMetadataCopyDescriptionToNiarim;
  String get youtubeTitleRequired =>
      _l10n.communityWorkMetadataYoutubeTitleRequired;
  String get copyConfirmTitle => _l10n.communityWorkMetadataCopyConfirmTitle;
  String get copyConfirmMessage =>
      _l10n.communityWorkMetadataCopyConfirmMessage;
  String get copyCancel => _l10n.communityWorkMetadataCopyCancel;
  String get copyConfirmAction => _l10n.communityWorkMetadataCopyConfirmAction;
  String copyTooLong(int maximum) =>
      _l10n.communityWorkMetadataCopyTooLong(maximum);
}
