import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
/// 数を含む文言は、単数・複数をARBで決めるAppLocalizationsのメソッドを
/// 直接使う（数と単位の語をコードでつなげない）。
class LoginBonusLabels {
  const LoginBonusLabels._(this._l10n);
  final AppLocalizations _l10n;

  factory LoginBonusLabels.of(BuildContext context) =>
      LoginBonusLabels._(appLocalizationsOf(context));

  String operator [](String key) => switch (key) {
    'title' => _l10n.loginBonusTitle,
    'daily' => _l10n.loginBonusDaily,
    'claim' => _l10n.loginBonusClaim,
    'claimed' => _l10n.loginBonusClaimed,
    'notYet' => _l10n.loginBonusNotYet,
    'milestones' => _l10n.loginBonusMilestones,
    'unknown' => _l10n.loginBonusUnknown,
    'unavailable' => _l10n.loginBonusUnavailable,
    'utc' => _l10n.loginBonusUtc,
    'retry' => _l10n.loginBonusRetry,
    'failed' => _l10n.loginBonusFailed,
    'success' => _l10n.loginBonusSuccess,
    'visitMissing' => _l10n.loginBonusVisitMissing,
    _ => key,
  };
}
