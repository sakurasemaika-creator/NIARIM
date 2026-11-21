import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// Labels for the creator mission screens; UI colors come from Theme.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
/// 数を含む文言は、単数・複数をARBで決めるAppLocalizationsのメソッドを
/// 直接使う（数と単位の語をコードでつなげない）。
class CreatorMissionLabels {
  const CreatorMissionLabels._(this._l10n);
  final AppLocalizations _l10n;

  factory CreatorMissionLabels.of(BuildContext context) =>
      CreatorMissionLabels._(appLocalizationsOf(context));

  String get(String key) => switch (key) {
    'title' => _l10n.creatorMissionTitle,
    'genericPublished' => _l10n.creatorMissionGenericPublished,
    'detailsTitle' => _l10n.creatorMissionDetailsTitle,
    'detailsHint' => _l10n.creatorMissionDetailsHint,
    'notAchieved' => _l10n.creatorMissionNotAchieved,
    'detailsTooltip' => _l10n.creatorMissionDetailsTooltip,
    'reviewing' => _l10n.creatorMissionReviewing,
    'coinReward' => _l10n.creatorMissionCoinReward,
    'claim' => _l10n.creatorMissionClaim,
    'activityTitle' => _l10n.creatorMissionActivityTitle,
    'activityObserved' => _l10n.creatorMissionActivityObserved,
    'activityEmpty' => _l10n.creatorMissionActivityEmpty,
    'activitySyncMore' => _l10n.creatorMissionActivitySyncMore,
    'activityHistoryMore' => _l10n.creatorMissionActivityHistoryMore,
    'activityError' => _l10n.creatorMissionActivityError,
    'activitySignIn' => _l10n.creatorMissionActivitySignIn,
    'detailsDraftCount' => _l10n.creatorMissionDetailsDraftCount,
    'detailsPerWorkRule' => _l10n.creatorMissionDetailsPerWorkRule,
    'detailsAccountRule' => _l10n.creatorMissionDetailsAccountRule,
    'detailsTemplateRule' => _l10n.creatorMissionDetailsTemplateRule,
    'detailsPending' => _l10n.creatorMissionDetailsPending,
    'detailsOffline' => _l10n.creatorMissionDetailsOffline,
    'drawerAttention' => _l10n.creatorMissionDrawerAttention,
    'achieved' => _l10n.creatorMissionAchieved,
    'claimReceived' => _l10n.creatorMissionClaimReceived,
    'holdStarted' => _l10n.creatorMissionHoldStarted,
    'claimFailed' => _l10n.creatorMissionClaimFailed,
    'workSection' => _l10n.creatorMissionWorkSection,
    'workWarning' => _l10n.creatorMissionWorkWarning,
    'noAchievements' => _l10n.creatorMissionNoAchievements,
    'loadMore' => _l10n.creatorMissionLoadMore,
    'workListError' => _l10n.creatorMissionWorkListError,
    'subtitle' => _l10n.creatorMissionSubtitle,
    'perWork' => _l10n.creatorMissionPerWork,
    'claimed' => _l10n.creatorMissionClaimed,
    'pending' => _l10n.creatorMissionPending,
    'notClaimed' => _l10n.creatorMissionNotClaimed,
    'upcoming' => _l10n.creatorMissionUpcoming,
    'login' => _l10n.creatorMissionLogin,
    'offline' => _l10n.creatorMissionOffline,
    'retry' => _l10n.creatorMissionRetry,
    'loading' => _l10n.creatorMissionLoading,
    'loadError' => _l10n.creatorMissionLoadError,
    'timeWarning' => _l10n.creatorMissionTimeWarning,
    'rankingWarning' => _l10n.creatorMissionRankingWarning,
    'budget' => _l10n.creatorMissionBudget,
    'rankOne' => _l10n.creatorMissionRankOne,
    'detailsCreatorBookmarkRule' => _l10n.creatorMissionDetailsBookmarkRule,
    'detailsCreatorWorksRule' => _l10n.creatorMissionDetailsWorksRule,
    'detailsCreatorFollowerRule' => _l10n.creatorMissionDetailsFollowerRule,
    'detailsCreatorTimeRule' => _l10n.creatorMissionDetailsTimeRule,
    'detailsCreatorClaimRule' => _l10n.creatorMissionDetailsClaimRule,
    'rankDetailsHold' => _l10n.creatorMissionRankDetailsHold,
    'rankSelectWork' => _l10n.creatorMissionRankSelectWork,
    'rankWorkNotPublic' => _l10n.creatorMissionRankWorkNotPublic,
    'rankCommunityNotMeasured' => _l10n.creatorMissionRankCommunityNotMeasured,
    'rankNotRanked' => _l10n.creatorMissionRankNotRanked,
    'rankQualified' => _l10n.creatorMissionRankQualified,
    'rankPoolUnknown' => _l10n.creatorMissionRankPoolUnknown,
    'rankCurrentUnknown' => _l10n.creatorMissionRankCurrentUnknown,
    'editTimeUnverified' => _l10n.creatorMissionEditTimeUnverified,
    'rankNotLive' => _l10n.creatorMissionRankNotLive,
    _ => key,
  };

  /// 数を1つ（[n]）か2つ（[n]と[each]）含む文言。単数・複数はARBが決める。
  /// 画面はAppLocalizationsのメソッドを直接使ってよい（こちらはキーの名前で
  /// 引く呼び出し元のための入口）。
  String format(String key, int n, {int? each}) {
    final other = each ?? 0;
    return switch (key) {
      'genericBookmark' => _l10n.creatorMissionGenericBookmark(n),
      'worksGoal' => _l10n.creatorMissionWorksGoal(n, other),
      'worksPublished' => _l10n.creatorMissionWorksPublished(n),
      'detailsWorkProgress' => _l10n.creatorMissionDetailsWorkProgress(
        n,
        other,
      ),
      'detailsWorksProgress' => _l10n.creatorMissionDetailsWorksProgress(
        n,
        other,
      ),
      'detailsFollowersProgress' =>
        _l10n.creatorMissionDetailsFollowersProgress(n, other),
      'time' => _l10n.creatorMissionTime(n),
      'followers' => _l10n.creatorMissionFollowers(n),
      'rank' => _l10n.creatorMissionRank(n),
      'localTime' => _l10n.creatorMissionLocalTime(n),
      'candidateMinutes' => _l10n.creatorMissionCandidateMinutes(n),
      'verifiedMinutes' => _l10n.creatorMissionVerifiedMinutes(n),
      // nは全体の上位の割合（％）、eachはミッションの順位。
      'rankDetailsRules' => _l10n.creatorMissionRankDetailsRules(n, other),
      'rankCommunityWait' => _l10n.creatorMissionRankCommunityWait(n, other),
      'rankBookmarkWait' => _l10n.creatorMissionRankBookmarkWait(n, other),
      'rankRankWait' => _l10n.creatorMissionRankRankWait(n, other),
      'rankPoolCurrent' => _l10n.creatorMissionRankPoolCurrent(n),
      'rankBookmarkCurrent' => _l10n.creatorMissionRankBookmarkCurrent(n),
      'rankCurrentPlace' => _l10n.creatorMissionRankCurrentPlace(n),
      'rankingRequirements' => _l10n.creatorMissionRankingRequirements(
        n,
        other,
      ),
      'rankingEffective' => _l10n.creatorMissionRankingEffective(n),
      _ => get(key),
    };
  }
}
