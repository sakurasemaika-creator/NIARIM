import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// Locale-aware UI labels for newly introduced plaza controls.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
class CommunityPlazaLabels {
  const CommunityPlazaLabels._(this._l10n);
  final AppLocalizations _l10n;

  static CommunityPlazaLabels of(BuildContext context) =>
      CommunityPlazaLabels._(appLocalizationsOf(context));

  String get muteWork => _l10n.communityPlazaMuteWork;
  String get unmuteWork => _l10n.communityPlazaUnmuteWork;
  String get mutedPlaceholder => _l10n.communityPlazaMutedPlaceholder;
  String get unmuteQuestion => _l10n.communityPlazaUnmuteQuestion;
  String get unmuteAlways => _l10n.communityPlazaUnmuteAlways;
  String get unmuteTemporary => _l10n.communityPlazaUnmuteTemporary;
  String get muteSettings => _l10n.communityPlazaMuteSettings;
  String get partialHint => _l10n.communityPlazaPartialHint;
  String get deleteHistory => _l10n.communityPlazaDeleteHistory;
  String get localData => _l10n.communityPlazaLocalData;
  String get exactTitle => _l10n.communityPlazaExactTitle;
  String get unavailablePlaceholder =>
      _l10n.communityPlazaUnavailablePlaceholder;
  String get searchTab => _l10n.communityPlazaSearchTab;
  String get mutePrivacyNotice => _l10n.communityPlazaMutePrivacyNotice;
}
