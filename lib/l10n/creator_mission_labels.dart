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
    _ => _pendingText(key),
  };

  String format(String key, int n, {int? each}) => switch (key) {
    'rank' => _l10n.creatorMissionRank(n),
    _ => _pendingText(
      key,
    ).replaceAll('{n}', '$n').replaceAll('{each}', '${each ?? 0}'),
  };

  String _pendingText(String key) =>
      _pendingTranslations[_l10n.localeName]?[key] ??
      _pendingTranslations['en']![key] ??
      key;
}

// dev_branchが後から足したランキングの条件などの文言（ARBへ移す前の一時の表）。
const Map<String, Map<String, String>> _pendingTranslations = {
  'ja': {
    'rankOne': 'ブックマークランキング1位',
    'detailsCreatorBookmarkRule':
        '【作品のブックマーク数】自分がNIARIMで公開中の作品について、NIARIM内で付けられたブックマーク数が目標以上であることが条件です。作品ごとに判定します。公開を取り消した作品や削除された作品は対象外です。',
    'detailsCreatorWorksRule':
        '【複数作品の条件】NIARIMで公開中の自分の作品のうち、それぞれが指定のブックマーク数以上を獲得している作品が、指定作品数以上必要です。ブックマーク0件の条件は公開作品数のみで判定します。サーバーで対象作品を再確認します。',
    'detailsCreatorFollowerRule':
        '【フォロワーの条件】NIARIMアカウントの現在のフォロワー数が目標以上必要です。端末から申告した人数ではなく、サーバーの記録を使用します。',
    'detailsCreatorTimeRule':
        '【制作時間の条件】端末の自己申告や端末に保存した制作時間は報酬対象ではありません。実際の制作を証明する仕組みが未完成のため、制作時間ミッションのコイン受取は現在できません。画面に表示される制作時間は参考値です。',
    'detailsCreatorClaimRule':
        '【受取方法】対象の達成状況をサーバーで確認し、初回申請から48時間保留します。48時間後にもう一度「受け取る」を押すと、その時点の達成条件を再検証し、満たしていれば支給します。条件を失った場合は保留をやり直します。報酬は同一ミッションにつきアカウントまたは作品ごとに1回限りです。',
    'rankDetailsRules':
        '【順位の計算方法】NIARIMで公開中の自分の作品が対象です。全体の公開作品が100件以上で、作品のブックマーク数が指定件数以上、かつランキング{each}位以内・全体の上位{n}％以内を同時に満たす必要があります。上位割合による順位上限は「全体の公開作品数 × {n}％」を小数点以下切り捨て（最低1位）で計算し、{each}位と比較して厳しい方を適用します。公開作品数はサーバーの集計値を使用します。',
    'rankSelectWork': '作品を選択すると現在の達成状況を確認できます',
    'rankWorkNotPublic': 'この作品は現在公開されていません',
    'rankCommunityNotMeasured': '全体の公開作品数を集計中です。集計が終わるまで受取できません',
    'rankCommunityWait': '公開作品数が不足：現在{n}件／必要{each}件',
    'rankBookmarkWait': 'ブックマーク不足：現在{n}件／必要{each}件',
    'rankNotRanked': '対象作品が現在のランキング50位以内に入っていません',
    'rankRankWait': '現在{n}位／条件は{each}位以内（上位割合も適用）',
    'rankQualified': 'すべての条件を達成。申請時と48時間後に再確認します',
    'rankPoolCurrent': 'NIARIM公開作品：現在{n}件',
    'rankPoolUnknown': '公開作品数のサーバー集計がまだ完了していません',
    'rankCurrentUnknown': 'この作品は現在の上位50位に入っていません',
    'editTimeUnverified': '制作時間は端末側で偽装可能なため、現在コイン報酬の対象外です。計測した時間は参考値です。',
    'rankBookmarkCurrent': '対象作品のブックマーク：現在{n}件',
    'rankCurrentPlace': '対象作品の現在順位：{n}位',
    'rankDetailsHold':
        '【受取のタイミング】ランキングは随時更新されます。申請時に条件をサーバーが確認し、48時間の確認期間が始まります。48時間経過後、もう一度「受け取る」を押した時点で再確認し、条件を満たしていれば報酬を付与します。再確認時に順位などの条件を失っていれば確認期間はリセットされます。過去の一瞬のランクインは自動認定されません。同じ作品の同じ順位報酬は1回限りです。異なる作品では別々に達成できます。',
    'rankNotLive': 'コイン支給は現在準備中です。条件を満たしても今は受け取れません。',
    'verifiedMinutes': 'サーバー時刻で検証した制作時間: {n}分',
    'rankingRequirements': '受取条件: NIARIMの公開作品が{n}件以上、この作品のブックマークが{each}件以上',
    'rankingEffective': '現在の公開作品数で必要な順位: {n}位以内',
  },
  'en': {
    'rankOne': 'NIARIM bookmark ranking #1',
    'detailsCreatorBookmarkRule':
        'WORK BOOKMARKS: Your own work must still be published on NIARIM and have at least the required number of NIARIM bookmarks. Each work is assessed separately. Unpublished or deleted works do not qualify.',
    'detailsCreatorWorksRule':
        'MULTIPLE WORKS: You need at least the required number of your currently published NIARIM works, each meeting the specified bookmark minimum. A zero-bookmark target only requires publication. The server verifies qualifying works again.',
    'detailsCreatorFollowerRule':
        'FOLLOWERS: Your NIARIM account must currently have at least the specified number of followers. The server record, not a client-supplied count, determines progress.',
    'detailsCreatorTimeRule':
        'EDITING TIME: Client-reported time and device-stored project duration cannot earn coins. A trustworthy proof of real editing activity is not yet available, so editing-time rewards cannot currently be claimed. Displayed time is informational.',
    'detailsCreatorClaimRule':
        'CLAIMING: The server verifies your milestone at the first request and starts a 48-hour hold. Press Claim again after 48 hours: the server rechecks the live conditions before paying. If conditions are lost, the hold restarts. Each mission pays once per account or once per work, depending on the mission.',
    'rankDetailsRules':
        'RANK CALCULATION: The work must be your own and currently published on NIARIM. At least 100 NIARIM works must be published; your work needs the specified bookmarks; and it must rank both within top {each} and the top {n}% of all published works. The percentile rank limit is floor(published work count × {n}%), at least 1, capped at top {each}. The server-maintained published-work count is used.',
    'rankSelectWork': 'Select a work to check its ranking reward eligibility',
    'rankWorkNotPublic': 'This work is not currently published',
    'rankCommunityNotMeasured':
        'Published works are still being counted; claims are unavailable until complete',
    'rankCommunityWait':
        'Community too small: {n} published works / {each} required',
    'rankBookmarkWait': 'Not enough bookmarks: {n} / {each} required',
    'rankNotRanked': 'This work is not currently in the top 50',
    'rankRankWait': 'Current rank: {n}; required: top {each} by percentile',
    'rankQualified':
        'All conditions met. Rechecked at request and after 48 hours',
    'rankPoolCurrent': 'Published NIARIM works: {n}',
    'rankPoolUnknown': 'The server has not finished counting published works',
    'rankCurrentUnknown': 'This work is not currently in the top 50',
    'editTimeUnverified':
        'Local editing activity can be spoofed, so editing-time coin rewards are unavailable. Time shown is informational.',
    'rankBookmarkCurrent': 'Bookmarks on this work: {n}',
    'rankCurrentPlace': 'Current rank for this work: {n}',
    'rankDetailsHold':
        'CLAIM TIMING: Rankings update continuously. The server checks all conditions when you apply and starts a 48-hour hold. After 48 hours, press Claim again; the server rechecks current conditions before paying. If they are no longer met, the hold resets. A brief past appearance in the ranking is not automatically credited. Each work can receive each rank reward once; different works qualify separately.',
    'rankNotLive':
        'Coin payouts are being prepared; ranking rewards cannot be claimed yet.',
    'verifiedMinutes': 'Server-clock-validated editing time: {n} min',
    'rankingRequirements':
        'Eligibility: at least {n} published works and {each} bookmarks on this work',
    'rankingEffective':
        'Required live rank with the current community size: top {n}',
  },
  'es': {
    'rankOne': 'Primer puesto del ranking de marcadores',
    'detailsCreatorBookmarkRule':
        'MARCADORES: Debe ser una obra tuya publicada actualmente en NIARIM y contar con los marcadores de NIARIM requeridos. Cada obra se evalúa por separado; las obras ocultas o eliminadas no cuentan.',
    'detailsCreatorWorksRule':
        'VARIAS OBRAS: Debes tener el número requerido de obras propias publicadas en NIARIM y cada una debe reunir el mínimo indicado de marcadores. Con objetivo cero solo cuenta la publicación. El servidor vuelve a verificar las obras.',
    'detailsCreatorFollowerRule':
        'SEGUIDORES: Tu cuenta de NIARIM debe tener ahora el número requerido de seguidores según el servidor, no según datos enviados por el dispositivo.',
    'detailsCreatorTimeRule':
        'TIEMPO: El tiempo declarado por el dispositivo no genera monedas. Aún no hay una prueba fiable de la edición real y estas recompensas no se pueden reclamar.',
    'detailsCreatorClaimRule':
        'COBRO: El servidor comprueba las condiciones al solicitar y espera 48 horas. Vuelve a pulsar Reclamar después; se comprobarán las condiciones otra vez. Si dejan de cumplirse, se reinicia la espera. Cada recompensa se concede una vez por cuenta u obra.',
    'rankDetailsRules':
        'CÁLCULO: La obra debe ser tuya y estar publicada en NIARIM. Debe haber al menos 100 obras públicas; tu obra debe tener los marcadores requeridos y estar tanto en los primeros {each} puestos como en el {n} % superior. El límite se calcula redondeando hacia abajo el número de obras públicas × {n} %, con mínimo de 1, y aplicando el límite más estricto. Se usa el recuento del servidor.',
    'rankDetailsHold':
        'COBRO: El ranking se actualiza continuamente. El servidor comprueba los requisitos al solicitar y vuelve a comprobarlos cuando pulsas Cobrar tras 48 horas. Si dejan de cumplirse, se reinicia la espera. No se acredita una aparición pasada breve. Cada obra puede cobrar una vez por puesto; las obras distintas se evalúan por separado.',
  },
  'fr': {
    'rankOne': '1re place du classement des favoris',
    'detailsCreatorBookmarkRule':
        'FAVORIS : Votre œuvre doit être la vôtre, encore publique sur NIARIM, et avoir suffisamment de favoris NIARIM. Chaque œuvre est évaluée séparément. Les œuvres privées ou supprimées ne comptent pas.',
    'detailsCreatorWorksRule':
        'PLUSIEURS ŒUVRES : Vous devez publier sur NIARIM le nombre demandé d’œuvres, chacune ayant atteint le minimum de favoris. Un objectif de zéro favori concerne seulement la publication. Le serveur vérifie ces œuvres.',
    'detailsCreatorFollowerRule':
        'ABONNÉS : Votre compte NIARIM doit actuellement atteindre le nombre indiqué selon les données du serveur, non les données envoyées par le téléphone.',
    'detailsCreatorTimeRule':
        'TEMPS DE CRÉATION : Une durée déclarée localement ne peut pas créditer de pièces. Une preuve fiable de la création réelle n’est pas encore disponible. Cette récompense est donc inaccessible.',
    'detailsCreatorClaimRule':
        'RÉCLAMATION : Le serveur vérifie les conditions lors de la demande, puis attend 48 heures. Appuyez de nouveau sur Réclamer ; la condition est revérifiée. Si elle ne tient plus, le délai recommence. Une récompense par compte ou par œuvre.',
    'rankDetailsRules':
        'CALCUL : Votre œuvre doit être publiée sur NIARIM. Il faut au moins 100 œuvres publiques, assez de favoris sur votre œuvre, une place dans le top {each} et dans le top {n} %. Le seuil de rang est la partie entière de (nombre d’œuvres publiques × {n} %), au minimum 1, puis le rang le plus strict est retenu. Le comptage provient du serveur.',
    'rankDetailsHold':
        'VALIDATION : Le classement change continuellement. Le serveur vérifie les conditions lors de la demande et de nouveau après 48 heures, lorsque vous appuyez encore sur Réclamer. Si une condition manque alors, le délai recommence. Une présence momentanée passée ne suffit pas. Chaque œuvre peut recevoir une fois chaque récompense de rang.',
  },
  'ko': {
    'rankOne': '북마크 랭킹 1위',
    'detailsCreatorBookmarkRule':
        '【북마크 조건】본인이 NIARIM에 현재 공개 중인 작품이 NIARIM 북마크 목표 수 이상이어야 합니다. 작품마다 별도로 확인하며 비공개 또는 삭제 작품은 제외됩니다.',
    'detailsCreatorWorksRule':
        '【여러 작품 조건】본인이 NIARIM에 공개 중인 작품 중 각 작품이 지정된 북마크 수를 충족하는 작품이 목표 개수 이상이어야 합니다. 북마크 0개 조건은 공개 작품 수만 확인합니다. 서버에서 다시 확인합니다.',
    'detailsCreatorFollowerRule':
        '【팔로워 조건】NIARIM 계정의 현재 팔로워가 목표 이상이어야 합니다. 기기에서 신고한 수치가 아닌 서버 기록을 사용합니다.',
    'detailsCreatorTimeRule':
        '【제작 시간 조건】기기에서 신고한 제작 시간은 코인으로 인정되지 않습니다. 실제 제작을 신뢰할 수 있게 검증하는 시스템이 아직 없어 코인 수령은 불가합니다.',
    'detailsCreatorClaimRule':
        '【수령 조건】최초 신청 시 서버가 달성을 확인하고 48시간 보류합니다. 48시간 후 다시 수령을 누르면 조건을 재확인합니다. 미달성 시 다시 대기합니다. 계정 또는 작품별 동일 미션은 1회만 수령할 수 있습니다.',
    'rankDetailsRules':
        '【순위 산정】NIARIM에 공개 중인 본인의 작품만 해당합니다. 전체 공개 작품이 100개 이상이며, 작품의 북마크가 기준 이상이고, 랭킹 {each}위 이내이면서 전체 상위 {n}% 이내여야 합니다. 상위 비율 순위는 전체 공개 작품 수 × {n}%를 내림 처리하고 최소 1위로 계산한 뒤, {each}위와 비교해 더 엄격한 조건을 적용합니다. 서버 집계 수치를 사용합니다.',
    'rankDetailsHold':
        '【보상 수령】순위는 수시로 변경됩니다. 신청 시 서버가 확인하고 48시간 대기가 시작됩니다. 48시간 후 다시 수령 버튼을 누르면 조건을 재확인합니다. 미달이면 대기 기간이 초기화됩니다. 과거 잠깐 진입한 순위는 자동 인정하지 않습니다. 동일 작품의 동일 순위 보상은 1회만 지급되며, 다른 작품은 별도입니다.',
  },
  'zh': {
    'rankOne': 'NIARIM 收藏榜第1名',
    'detailsCreatorBookmarkRule':
        '【作品收藏数】仅限本人目前在 NIARIM 公开的作品，收藏数必须达到目标。每件作品独立计算，隐藏或删除的作品不计入。',
    'detailsCreatorWorksRule':
        '【多件作品】本人当前公开的 NIARIM 作品中，至少指定数量的作品须各自达到收藏数要求。收藏目标为0时仅要求公开作品数。服务器会再次检查。',
    'detailsCreatorFollowerRule':
        '【关注者】NIARIM 账号当前关注者数须达到目标，以服务器数据为准，不采信设备上报人数。',
    'detailsCreatorTimeRule':
        '【创作时间】设备自行上报的时间不能兑换金币。目前尚无法可靠证明真实创作行为，创作时间奖励暂不可领取。',
    'detailsCreatorClaimRule':
        '【领取方式】首次申请时服务器验证条件并开始48小时等待。48小时后需再次点击领取并重新验证；条件未满足时重新等待。同一任务每个账号或每件作品只能领取一次。',
    'rankDetailsRules':
        '【排名规则】仅限本人在 NIARIM 上公开的作品。全站公开作品至少100件，作品收藏数达到要求，同时排名进入前 {each} 名及全站前 {n}%。百分比排名上限按公开作品总数×{n}%向下取整（最低为第1名），再与前 {each} 名比较，采用更严格的上限。作品总数以服务器统计为准。',
    'rankDetailsHold':
        '【领取时间】排名随时变化。申请时服务器检查条件并开始48小时等待；48小时后需再次点击领取，服务器重新检查当前条件。若条件不再满足，等待期重新开始。过去短暂上榜不自动算作达成。同一作品同一名次奖励只能领取一次，不同作品分别计算。',
  },
  'zh_Hant': {
    'rankOne': 'NIARIM 收藏榜第1名',
    'detailsCreatorBookmarkRule':
        '【作品收藏數】僅限本人目前在 NIARIM 公開的作品，收藏數必須達到目標。每件作品獨立計算，隱藏或刪除的作品不計入。',
    'detailsCreatorWorksRule':
        '【多件作品】本人目前公開的 NIARIM 作品中，至少指定數量的作品須各自達到收藏數要求。收藏目標為0時僅要求公開作品數。伺服器會再次確認。',
    'detailsCreatorFollowerRule':
        '【追蹤者】NIARIM 帳號目前追蹤者數須達到目標，以伺服器資料為準，不採信裝置上報人數。',
    'detailsCreatorTimeRule':
        '【創作時間】裝置自行回報的時間無法兌換金幣。目前尚無法可靠證明真實創作行為，因此創作時間獎勵暫不可領取。',
    'detailsCreatorClaimRule':
        '【領取方式】首次申請時伺服器驗證條件並開始48小時等待。48小時後須再次點擊領取並重新驗證；條件未滿足時重新等待。同一任務每個帳號或每件作品只能領取一次。',
    'rankDetailsRules':
        '【排名規則】僅限本人在 NIARIM 上公開的作品。全站公開作品至少100件，作品收藏數達到要求，同時排名進入前 {each} 名及全站前 {n}%。百分比排名上限按公開作品總數×{n}%向下取整（最低為第1名），再與前 {each} 名比較，採用更嚴格的上限。作品總數以伺服器統計為準。',
    'rankDetailsHold':
        '【領取時間】排名隨時變化。申請時伺服器檢查條件並開始48小時等待；48小時後需再次點擊領取，伺服器重新檢查當前條件。若條件不再滿足，等待期重新開始。過去短暫上榜不自動算作達成。同一作品同一名次獎勵只能領取一次，不同作品分別計算。',
  },
};
