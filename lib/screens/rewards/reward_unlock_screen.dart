import 'package:flutter/material.dart';
import '../../config/accent_text_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/reward_unlock_labels.dart';
import '../../l10n/reward_navigation_labels.dart';
import '../../models/coin_unlock_quote.dart';
import '../../models/coin_benefit_price_proposal.dart';
import '../../services/premium_service.dart';
import '../../services/advertising_service.dart';
import '../../services/coin_redemption_attempt_store.dart';
import '../../services/individual_coin_redemption_attempt_store.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/coin_duration_label.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/button_label_room.dart';
import '../../widgets/coin_history_sheet.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/responsive.dart';

enum RewardPageMode { exchange, earnCoins }

/// Reward UI shell; the server wallet/pricing/ad issuance are not yet live.
/// Never invent coin balances, price quotes or exchange success on the client.
class RewardUnlockScreen extends StatefulWidget {
  const RewardUnlockScreen({
    super.key,
    this.priceCatalog = const {},
    this.fullPremiumMinimumCoins,
    this.mode = RewardPageMode.exchange,
    this.embedded = false,
  });

  /// Server-verified price catalog. Missing entries are NOT free.
  final Map<CoinUnlockTarget, CoinUnlockUnitPrices> priceCatalog;
  final int? fullPremiumMinimumCoins;
  final RewardPageMode mode;
  final bool embedded;

  @override
  State<RewardUnlockScreen> createState() => _RewardUnlockScreenState();
}

class _RewardUnlockScreenState extends State<RewardUnlockScreen> {
  CoinUnlockDuration _duration = const CoinUnlockDuration(
    1,
    CoinDurationUnit.hour,
  );
  final Set<CoinUnlockTarget> _selected = {};
  GoogleAuthService? _authService;
  String? _lastAccountId;
  Map<String, dynamic>? _rewardState;
  bool _walletLoading = false;
  bool _rewardBusy = false;
  bool _redeemBusy = false;
  Map<String, dynamic>? _officialPremiumQuote;
  Map<String, dynamic>? _officialAnnualPremiumQuote;

  /// Only a matching, enabled server quote can authorize spending coins.
  Map<String, dynamic>? get _selectedFullPremiumQuote {
    if (_duration.unit != CoinDurationUnit.month) return null;
    if (_duration.amount == 1) return _officialPremiumQuote;
    if (_duration.amount == 12) return _officialAnnualPremiumQuote;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authService = context.read<GoogleAuthService>();
      _authService!.addListener(_onAccountChanged);
      _onAccountChanged();
    });
  }

  void _onAccountChanged() {
    final id = _authService?.account?.id;
    if (_lastAccountId == id) return;
    _lastAccountId = id;
    context.read<PremiumService>().applyServerCoinPremiumExpiry(null);
    if (id != null) {
      context.read<PremiumService>().applyServerCoinBenefitEntitlements(null,accountId:id);
    }
    setState(() {
      _rewardState = null;
      _officialPremiumQuote = null;
      _officialAnnualPremiumQuote = null;
    });
    if (id != null) _loadWallet(id);
  }

  Future<void> _loadWallet(String accountId) async {
    final api = context.read<CommunityService>().api;
    if (api == null) return;
    setState(() => _walletLoading = true);
    try {
      final state = await api.myRewardState();
      if (!mounted || _authService?.account?.id != accountId) return;
      setState(() => _rewardState = state);
      DateTime? activeCoinPremium;
      for (final row in (state['entitlements'] as List? ?? const [])) {
        if (row is Map &&
            row['feature'] == 'fullPremium' &&
            row['status'] == 'active' &&
            row['expiresAtEpochMs'] is num) {
          final ms = (row['expiresAtEpochMs'] as num).toInt();
          if (ms > DateTime.now().millisecondsSinceEpoch) {
            activeCoinPremium = DateTime.fromMillisecondsSinceEpoch(ms);
          }
        }
      }
      context.read<PremiumService>().applyServerCoinPremiumExpiry(
        activeCoinPremium,
        accountId: accountId,
      );
      context.read<PremiumService>().applyServerCoinBenefitEntitlements(
        state['entitlements'] as List<dynamic>?,accountId:accountId,
      );
      if (state['redemptionEnabled'] == true) {
        try {
          final quote = await api.fullPremiumCoinQuote(months: 1);
          // Annual availability is independently approved on the server.
          // A failed annual request must not hide the verified monthly quote.
          Map<String, dynamic>? annual;
          try {
            annual = await api.fullPremiumCoinQuote(months: 12);
          } catch (_) {
            annual = null;
          }
          if (!mounted || _authService?.account?.id != accountId) return;
          setState(() {
            _officialPremiumQuote = quote;
            _officialAnnualPremiumQuote = annual;
          });
        } catch (_) {
          if (mounted && _authService?.account?.id == accountId) {
            setState(() {
              _officialPremiumQuote = null;
              _officialAnnualPremiumQuote = null;
            });
          }
        }
      } else {
        setState(() {
          _officialPremiumQuote = null;
          _officialAnnualPremiumQuote = null;
        });
      }
    } catch (_) {
      // Never show a stale wallet or an invented zero while offline.
      if (!mounted || _authService?.account?.id != accountId) return;
      setState(() => _rewardState = null);
    } finally {
      if (mounted && _authService?.account?.id == accountId) {
        setState(() => _walletLoading = false);
      }
    }
  }

  void _showCoinHistory() {
    final auth = context.read<GoogleAuthService>();
    final owner = auth.account?.id;
    final api = context.read<CommunityService>().api;
    if (owner == null || api == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CoinHistorySheet(
        ownerId: owner,
        accountChanges: auth,
        currentAccountId: () => auth.account?.id,
        fetchPage: ({String? cursor, int limit = 20}) =>
            api.myCoinHistory(cursor: cursor, limit: limit),
      ),
    );
  }

  Future<void> _watchRewardedAd() async {
    if (_rewardBusy) return;
    final accountId = context.read<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    final ads = context.read<AdvertisingService>();
    if (accountId == null || api == null || !ads.canOfferRewardedAds) return;
    setState(() => _rewardBusy = true);
    try {
      final invitation = await api.beginRewardedAdSession();
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != accountId) {
        return;
      }
      final adUnit = invitation['adUnitId'];
      final customData = invitation['customData'];
      if (adUnit is! String || customData is! String) {
        throw StateError('Missing server-issued rewarded ad session');
      }
      final completed = await ads.showRewardedCoinAd(
        adUnitId: adUnit,
        customData: customData,
      );
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != accountId) {
        return;
      }
      final t = RewardUnlockLabels.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completed ? t['rewardPending'] : t['rewardUnavailable'],
          ),
        ),
      );
      // The SDK callback is NOT an award. Only a signed SSV transaction may
      // consume the session and credit the wallet. Query a bounded number of
      // times so the user needn't manually refresh after a normal callback.
      // This intentionally never increments balanceCoins on the device.
      if (completed) {
        final nonce = customData.split('.').last;
        for (final delay in [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
          const Duration(seconds: 6),
        ]) {
          await Future<void>.delayed(delay);
          if (!mounted ||
              context.read<GoogleAuthService>().account?.id != accountId) {
            break;
          }
          try {
            final status = await api.rewardedAdStatus(nonce);
            if (!mounted ||
                context.read<GoogleAuthService>().account?.id != accountId) {
              break;
            }
            if (status['credited'] == true) {
              await _loadWallet(accountId);
              break;
            }
            if (status['status'] == 'expired' ||
                status['status'] == 'not_found') {
              break;
            }
          } catch (_) {
            // Temporary network errors never create local coin grants.
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RewardUnlockLabels.of(context)['rewardUnavailable']),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _rewardBusy = false);
    }
  }

  Future<void> _redeemFullPremium() async {
    if (_redeemBusy) return;
    final accountId = context.read<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    final months = _duration.unit == CoinDurationUnit.month
        ? _duration.amount : 0;
    final serverQuote = _selectedFullPremiumQuote;
    final priceVersion = serverQuote?['priceVersion'];
    final price = serverQuote?['priceCoins'];
    if (accountId == null ||
        api == null ||
        (months != 1 && months != 12) ||
        serverQuote?['enabled'] != true ||
        priceVersion is! String ||
        price is! int ||
        price != CoinBenefitPriceCatalog.cost(
          CoinUnlockTarget.fullPremium, _duration,
        ) ||
        priceVersion != CoinBenefitPriceCatalog.version) {
      return;
    }
    final t = RewardUnlockLabels.of(context);
    final premium = context.read<PremiumService>();
    // The backend has not implemented pausing/extending during an active
    // Google Play subscription. Refuse spending in that overlapping case.
    if (premium.hasVerifiedPlayPremium) {
      await _reviewSelections();
      return;
    }
    final activeCoin = premium.activeCoinPremiumExpiry;
    final now = DateTime.now();
    final from = _later(now, activeCoin);
    final projectedEnd = _duration.previewExpiry(from);
    final l10n = AppLocalizations.of(context)!;
    final overlapMessage = activeCoin != null && activeCoin.isAfter(now)
        ? l10n.rewardUnlockRedeemExtendNotice(projectedEnd.toLocal())
        : l10n.rewardUnlockRedeemExpiryNotice(projectedEnd.toLocal());
    final period = coinUnlockDurationLabel(l10n, _duration);
    final amount = l10n.coinAmount(price);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // 低い画面でも、何を・どの期間・何コインで交換するかの文が読める
        // （既定だと本文が先に潰れ、題とボタンだけになった）。
        scrollable: true,
        title: Text(t['redeem']),
        // 期間と数＋単位は途中で行を変えない（「55000코」「인」と切れた）。
        content: KeepTogetherText(
          '${t['fullPremium']} · $period · $amount\n\n$overlapMessage',
          keep: [period, amount],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Padding(
              padding: buttonLabelRoom(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Padding(
              padding: buttonLabelRoom(ctx),
              child: Text(t['redeem']),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        context.read<GoogleAuthService>().account?.id != accountId) {
      return;
    }
    setState(() => _redeemBusy = true);
    try {
      final result = await const CoinRedemptionAttemptStore().redeem(
        api: api,
        accountId: accountId,
        serverPriceVersion: priceVersion,
        months: months,
      );
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != accountId) {
        return;
      }
      if (result['redeemed'] == true) {
        await _loadWallet(accountId);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t['redemptionSuccess'])));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t['redemptionUncertain'])));
      }
    } finally {
      if (mounted) setState(() => _redeemBusy = false);
    }
  }

  /// Flexible Full Premium period: always fetch a fresh server quote at tap.
  /// This shares the legacy idempotency store and server entitlement model.
  Future<void> _redeemFlexibleFullPremium() async {
    if(_redeemBusy || _selected.length!=1 ||
       !_selected.contains(CoinUnlockTarget.fullPremium) ||
       _rewardState?['redemptionEnabled']!=true)return;
    final accountId=context.read<GoogleAuthService>().account?.id;
    final api=context.read<CommunityService>().api;
    if(accountId==null||api==null||
       context.read<PremiumService>().hasVerifiedPlayPremium)return;
    final currentDuration=_duration;
    final unit=currentDuration.unit.name;
    final quantity=currentDuration.amount;
    final reference=CoinBenefitPriceCatalog.cost(
      CoinUnlockTarget.fullPremium,currentDuration,
    );
    setState(()=>_redeemBusy=true);
    final t=RewardUnlockLabels.of(context);
    final l10n=AppLocalizations.of(context)!;
    try{
      final quote=await api.flexiblePremiumCoinQuote(
        duration:unit,quantity:quantity,
      );
      if(!mounted||
         context.read<GoogleAuthService>().account?.id!=accountId)return;
      final amount=quote['priceCoins'];
      final version=quote['priceVersion'];
      final balance=_rewardState?['balanceCoins'];
      if(quote['enabled']!=true||amount is! int||amount!=reference||
         quote['catalogPriceCoins']!=amount||
         version!=CoinBenefitPriceCatalog.version||
         balance is! int||balance<amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(t['redemptionUncertain'])),
        );
        return;
      }
      final period=coinUnlockDurationLabel(l10n,currentDuration);
      final cost=l10n.coinAmount(amount);
      final now=DateTime.now();
      final last=context.read<PremiumService>().activeCoinPremiumExpiry;
      final projected=currentDuration.previewExpiry(
        last!=null&&last.isAfter(now)?last:now,
      );
      final overlapMessage=last!=null&&last.isAfter(now)
        ? l10n.rewardUnlockRedeemExtendNotice(projected.toLocal())
        : l10n.rewardUnlockRedeemExpiryNotice(projected.toLocal());
      final confirmed=await showDialog<bool>(
        context:context,
        builder:(dialog)=>AlertDialog(
          scrollable:true,
          title:Text(t['redeem']),
          content:KeepTogetherText(
            '${t['fullPremium']} · $period · $cost\\n\\n$overlapMessage',
            keep:[period,cost],
          ),
          actions:[
            TextButton(
              onPressed:()=>Navigator.pop(dialog,false),
              child:Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            FilledButton(onPressed:()=>Navigator.pop(dialog,true),
              child:Text(t['redeem'])),
          ],
        ),
      );
      if(confirmed!=true||!mounted||
         context.read<GoogleAuthService>().account?.id!=accountId)return;
      final response=await const CoinRedemptionAttemptStore().redeem(
        api:api,accountId:accountId,serverPriceVersion:version,
        duration:unit,quantity:quantity,
      );
      if(!mounted||
         context.read<GoogleAuthService>().account?.id!=accountId)return;
      if(response['redeemed']==true){
        await _loadWallet(accountId);
        if(!mounted)return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(t['redemptionSuccess'])),
        );
      }
    }catch(_){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(t['redemptionUncertain'])),
        );
      }
    }finally{
      if(mounted)setState(()=>_redeemBusy=false);
    }
  }

  Future<void> _redeemSelectedBenefits() async {
    if (_redeemBusy || _selected.isEmpty ||
        _selected.contains(CoinUnlockTarget.fullPremium) ||
        _selected.contains(CoinUnlockTarget.communityPostQuota) ||
        _rewardState?['individualRedemptionEnabled'] != true) {
      return;
    }
    final accountId=context.read<GoogleAuthService>().account?.id;
    final api=context.read<CommunityService>().api;
    final premium=context.read<PremiumService>();
    if(accountId==null||api==null||premium.isPremium)return;
    final targets=CoinUnlockTarget.values
        .where((target)=>_selected.contains(target))
        .map((target)=>target.name).toList(growable:false);
    final duration=_duration.unit.name;
    final count=_duration.amount;
    final expected=_selected.fold<int>(0,(sum,target)=>
        sum+CoinBenefitPriceCatalog.cost(target,_duration));
    if(expected<=0)return;
    final labels=RewardUnlockLabels.of(context);
    final l10n=AppLocalizations.of(context)!;
    setState(()=>_redeemBusy=true);
    try {
      // Server quote is the only authority for price and activation.
      final quote=await api.selectedBenefitCoinQuote(
        targets:targets,duration:duration,quantity:count,
      );
      if(!mounted ||
          context.read<GoogleAuthService>().account?.id!=accountId)return;
      final price=quote['priceCoins'];
      final version=quote['priceVersion'];
      final wallet=_rewardState?['balanceCoins'];
      if(quote['enabled']!=true||price is! int||price!=expected||
          quote['catalogPriceCoins']!=price||
          version!=CoinBenefitPriceCatalog.version||
          wallet is! int||wallet<price) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(labels['redemptionUncertain'])),
        );
        return;
      }
      final period=coinUnlockDurationLabel(l10n,_duration);
      final amount=l10n.coinAmount(price);
      final confirm=await showDialog<bool>(
        context:context,
        builder:(dialog)=>AlertDialog(
          scrollable:true,
          title:Text(labels['redeem']),
          content:KeepTogetherText(
            '${targets.length} · $period · $amount',
            keep:[period,amount],
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog,false),
              child:Text(MaterialLocalizations.of(dialog).cancelButtonLabel)),
            FilledButton(onPressed:()=>Navigator.pop(dialog,true),
              child:Text(labels['redeem'])),
          ],
        ),
      );
      if(confirm!=true||!mounted||
          context.read<GoogleAuthService>().account?.id!=accountId)return;
      final result=await const IndividualCoinRedemptionAttemptStore().redeem(
        api:api,accountId:accountId,targets:targets,
        duration:duration,quantity:count,serverPriceVersion:version,
      );
      if(!mounted||
          context.read<GoogleAuthService>().account?.id!=accountId)return;
      if(result['redeemed']==true) {
        await _loadWallet(accountId);
        if(!mounted)return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(labels['redemptionSuccess'])),
        );
      }
    }catch(_) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(labels['redemptionUncertain'])),
        );
      }
    }finally{
      if(mounted)setState(()=>_redeemBusy=false);
    }
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAccountChanged);
    super.dispose();
  }

  static const _standardTargets = <CoinUnlockTarget>[
    CoinUnlockTarget.endCardEdit,
    CoinUnlockTarget.watermark,
    CoinUnlockTarget.toneCurve,
    CoinUnlockTarget.levelAdjustment,
    CoinUnlockTarget.unlimitedDuration,
    CoinUnlockTarget.customAutomation,
    CoinUnlockTarget.communityPostQuota,
  ];
  static const _placementTargets = <CoinUnlockTarget>[
    CoinUnlockTarget.projectListAds,
    CoinUnlockTarget.canvasAds,
    CoinUnlockTarget.timelineAds,
    CoinUnlockTarget.processingAds,
  ];
  static const _bundles = <CoinUnlockTarget>[CoinUnlockTarget.allAds];

  CoinUnlockQuote? _quote() {
    if (_selected.isEmpty) return null;
    try {
      final quote = const CoinUnlockQuoteCalculator().calculate(
        selections: [
          for (final target in _selected) CoinUnlockSelection(target: target),
        ],
        duration: _duration,
        prices: widget.priceCatalog,
        priceVersion: 'server-pending',
        fullPremiumMinimumCoins: widget.fullPremiumMinimumCoins,
      );
      // The existing per-month quote model cannot express the annual
      // Premium discount. Never show its 12×month cost as a finalized total.
      final finalTotal = _selected.fold<int>(
        0,
        (sum, target) => sum + CoinBenefitPriceCatalog.cost(target, _duration),
      );
      if (quote.requiredCoins != finalTotal) return null;
      return quote;
    } on StateError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  void _toggle(CoinUnlockTarget target) {
    setState(() {
      if (!_selected.add(target)) {
        _selected.remove(target);
        return;
      }
      // Preserve multi-selection even when rights overlap. The review dialog
      // explains overlap/queueing; unsupported combinations cannot debit coins.
      // The server, not this widget, remains the sole owner of entitlements.
    });
  }

  DateTime _later(DateTime left, DateTime? right) =>
      right != null && right.isAfter(left) ? right : left;

  Map<CoinUnlockTarget, DateTime> _activeBenefitExpiries(DateTime now) {
    final active = <CoinUnlockTarget, DateTime>{};
    for (final raw in (_rewardState?['entitlements'] as List? ?? const [])) {
      if (raw is! Map ||
          raw['status'] != 'active' ||
          raw['feature'] is! String ||
          raw['expiresAtEpochMs'] is! num) {
        continue;
      }
      final candidate = CoinUnlockTarget.values
          .where((target) => target.name == raw['feature'])
          .firstOrNull;
      if (candidate == null) continue;
      final until = DateTime.fromMillisecondsSinceEpoch(
        (raw['expiresAtEpochMs'] as num).toInt(),
      );
      if (until.isAfter(now)) active[candidate] = until;
    }
    return active;
  }

  /// Review *all* chosen items, including overlapping bundles and an active
  /// paid Premium term, before any possible purchase. For choices the server
  /// cannot redeem, this is an explicitly non-binding price/expiry preview.
  Future<void> _reviewSelections() async {
    if (_selected.isEmpty) return;
    final t = RewardUnlockLabels.of(context);
    final l10n = AppLocalizations.of(context)!;
    final premium = context.read<PremiumService>();
    final now = DateTime.now();
    final active = _activeBenefitExpiries(now);
    final paidUntil = premium.hasVerifiedPlayPremium
        ? premium.verifiedExpiryDate
        : null;
    final coinUntil = premium.activeCoinPremiumExpiry;
    final hasPlay = premium.hasVerifiedPlayPremium;
    final hasFull = _selected.contains(CoinUnlockTarget.fullPremium);
    final hasAllAds = _selected.contains(CoinUnlockTarget.allAds);
    final fullStarts = _later(_later(now, paidUntil), coinUntil);
    final fullEnds = hasFull ? _duration.previewExpiry(fullStarts) : null;
    final lines = <String>[];

    if (hasPlay) {
      lines.add(
        paidUntil != null
            ? l10n.rewardUnlockReviewPlayPremiumUntil(paidUntil.toLocal())
            : l10n.rewardUnlockReviewPlayPremiumUnknown,
      );
    } else if (coinUntil != null && coinUntil.isAfter(now)) {
      lines.add(l10n.rewardUnlockReviewCoinPremiumUntil(coinUntil.toLocal()));
    }
    if (hasFull) {
      lines.add(l10n.rewardUnlockReviewFullIncludes(t['fullPremium']));
    }
    if (hasAllAds &&
        _placementTargets.any((target) => _selected.contains(target))) {
      lines.add(l10n.rewardUnlockReviewAdsOverlap(t['allAds']));
    }

    for (final target in CoinUnlockTarget.values) {
      if (!_selected.contains(target)) continue;
      final existing = active[target];
      var starts = _later(now, existing);
      if (target == CoinUnlockTarget.fullPremium) {
        starts = fullStarts;
      } else {
        if (hasFull) starts = _later(starts, fullEnds);
        if (hasAllAds && _placementTargets.contains(target)) {
          final adsStarts = _later(
            _later(now, active[CoinUnlockTarget.allAds]),
            _later(now, paidUntil),
          );
          starts = _later(starts, _duration.previewExpiry(adsStarts));
        }
        starts = _later(starts, paidUntil);
        starts = _later(starts, coinUntil);
      }
      final calculatedExpiry = _duration.previewExpiry(starts);
      final coversNow =
          existing?.isAfter(now) == true ||
          (hasPlay && paidUntil?.isAfter(now) == true) ||
          (coinUntil?.isAfter(now) == true) ||
          (hasFull && target != CoinUnlockTarget.fullPremium) ||
          (hasAllAds && _placementTargets.contains(target));
      lines.add(
        coversNow
            ? l10n.rewardUnlockReviewItemOverlap(
                t[target.name],
                calculatedExpiry.toLocal(),
              )
            : l10n.rewardUnlockReviewItem(
                t[target.name],
                calculatedExpiry.toLocal(),
              ),
      );
    }
    final referenceTotal = _selected.fold<int>(
      0,
      (sum, target) => sum + CoinBenefitPriceCatalog.cost(target, _duration),
    );
    final total = l10n.coinAmount(referenceTotal);
    lines.add(l10n.rewardUnlockReviewFixedTotal(total));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l10n.rewardUnlockReviewTitle),
        content: KeepTogetherText(lines.join('\n\n'), keep: [total]),
        actions: [
          FilledButton(
            key: const Key('rewardOverlapReviewClose'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDuration(RewardUnlockLabels t) async {
    final l10n = AppLocalizations.of(context)!;
    final groups = <(String, List<CoinUnlockDuration>)>[
      (
        t['hour'],
        [
          for (var i = 1; i <= 24; i++)
            CoinUnlockDuration(i, CoinDurationUnit.hour),
        ],
      ),
      (
        t['day'],
        [
          for (var i = 2; i <= 6; i++)
            CoinUnlockDuration(i, CoinDurationUnit.day),
        ],
      ),
      (
        t['week'],
        [
          for (var i = 1; i <= 3; i++)
            CoinUnlockDuration(i, CoinDurationUnit.week),
        ],
      ),
      (
        t['month'],
        [
          for (var i = 1; i <= 120; i++)
            CoinUnlockDuration(i, CoinDurationUnit.month),
        ],
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.75,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    t['chooseDuration'],
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                for (final (label, options) in groups)
                  ExpansionTile(
                    title: Text(label),
                    // Keep all duration categories accessible without scrolling past
                    // 24 hourly choices on small phones.
                    initiallyExpanded: false,
                    children: [
                      for (final option in options)
                        // 選んでいる期間は、印だけでなく読み上げにも伝える。
                        Semantics(
                          selected:
                              _duration.unit == option.unit &&
                              _duration.amount == option.amount,
                          child: ListTile(
                            key: ValueKey(
                              'rewardDuration_${option.unit.name}_${option.amount}',
                            ),
                            title: Text(coinUnlockDurationLabel(l10n, option)),
                            trailing:
                                _duration.unit == option.unit &&
                                    _duration.amount == option.amount
                                ? Icon(
                                    Icons.check,
                                    color: AccentTextTheme.of(sheetContext),
                                  )
                                : null,
                            onTap: () {
                              setState(() => _duration = option);
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _targetTile(
    BuildContext context,
    RewardUnlockLabels t,
    CoinUnlockTarget target,
  ) {
    final enabled = target.isRedeemableNow;
    final selected = _selected.contains(target);
    final rate = widget.priceCatalog[target];
    int? officialPrice;
    try {
      if (enabled && rate != null) {
        final quoted = rate.cost(_duration);
        // A stale server price must not silently replace the owner-final
        // tariff. A mismatch is presented as "redemption not yet available".
        if (quoted == CoinBenefitPriceCatalog.cost(target, _duration)) {
          officialPrice = quoted;
        }
      }
    } on StateError {
      officialPrice = null;
    }
    final verifiedPremiumQuote = _selectedFullPremiumQuote;
    if (target == CoinUnlockTarget.fullPremium &&
        verifiedPremiumQuote?['enabled'] == true &&
        verifiedPremiumQuote?['priceCoins'] ==
            CoinBenefitPriceCatalog.cost(target, _duration) &&
        verifiedPremiumQuote?['priceVersion'] ==
            CoinBenefitPriceCatalog.version) {
      officialPrice = verifiedPremiumQuote!['priceCoins'] as int;
    }
    final referencePrice = enabled
        ? CoinBenefitPriceCatalog.cost(target, _duration)
        : null;
    final hasSubscription = context.read<PremiumService>().hasPurchasedPremium;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bodySmall = theme.textTheme.bodySmall;
    final Widget price;
    if (!enabled) {
      price = Text(t['notReady'], style: bodySmall);
    } else if (officialPrice != null) {
      price = Text(l10n.coinAmount(officialPrice), style: bodySmall);
    } else {
      // 数＋単位は途中で行を変えない（「…・70コ」「イン」と切れた）。
      final amount = l10n.coinAmount(referencePrice!);
      price = KeepTogetherText(
        '${l10n.rewardUnlockFixedPrice} · $amount'
        '${hasSubscription ? ' · ${t['activePremium']}' : ''}',
        keep: [amount],
        style: bodySmall,
      );
    }
    // CheckboxListTileと同じ並び（先頭のチェックボックス・題・価格・右端の
    // 印）。ただし、題か価格の語がチェックボックスの右に収まらない大きな
    // 文字では、チェックボックスを上の行へ回して題と価格に行の幅いっぱいを
    // 使わせる（CheckboxListTileは題の列をチェックボックスの右に固定する
    // ので、文字2倍のフランス語・スペイン語で「personnalisée|s」
    // 「Publication|s」と単語の途中で切れた）。
    final tileTheme = ListTileTheme.of(context);
    var priceStyle =
        tileTheme.subtitleTextStyle ??
        theme.textTheme.bodyMedium!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    if (!enabled) priceStyle = priceStyle.copyWith(color: theme.disabledColor);
    return MergeSemantics(
      child: ListTile(
        key: ValueKey('rewardFeature_${target.name}'),
        enabled: enabled,
        onTap: enabled ? () => _toggle(target) : null,
        // 題と価格の2行の行（CheckboxListTileの2行の行と同じ高さ）。
        minTileHeight: 72,
        title: ActionBesideOrBelow(
          actionFirst: true,
          gap: 16,
          spacing: 4,
          action: ExcludeFocus(
            child: Checkbox(
              value: selected,
              onChanged: enabled ? (_) => _toggle(target) : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          text: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            // ListTileの題と2行目の間と同じくらい空ける。
            spacing: 4,
            children: [
              // 名前の中の数と単位（「1作品」「1개」「1篇」「2時間」）は
              // 途中で行を変えない。
              KeepTogetherText(t[target.name], keep: const []),
              DefaultTextStyle(style: priceStyle, child: price),
            ],
          ),
        ),
        trailing: !enabled
            ? Tooltip(
                message: t['notReady'],
                child: Icon(
                  Icons.lock_clock_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : target == CoinUnlockTarget.fullPremium && _fullBundleBadge()
            ? Chip(label: Text(t['bestValue']))
            : null,
      ),
    );
  }

  bool _fullBundleBadge() {
    final targets = [..._standardTargets, ..._placementTargets]
      ..remove(CoinUnlockTarget.communityPostQuota);
    try {
      return const CoinUnlockQuoteCalculator().isFullPremiumBestValue(
        duration: _duration,
        prices: widget.priceCatalog,
        comparisonTargets: targets,
        fullPremiumMinimumCoins: widget.fullPremiumMinimumCoins ?? 0,
      );
    } on StateError {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RewardUnlockLabels.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final quote = _quote();
    final referenceTotal = _selected.fold<int>(
      0,
      (sum, target) => sum + CoinBenefitPriceCatalog.cost(target, _duration),
    );
    final premiumActiveFromPlay = context
        .watch<PremiumService>()
        .hasVerifiedPlayPremium;
    final fullPremiumQuote = _selectedFullPremiumQuote;
    final serverPrice =
        _selected.length == 1 &&
            _selected.contains(CoinUnlockTarget.fullPremium) &&
            fullPremiumQuote?['enabled'] == true &&
            fullPremiumQuote?['priceCoins'] ==
                CoinBenefitPriceCatalog.cost(
                  CoinUnlockTarget.fullPremium, _duration,
                ) &&
            fullPremiumQuote?['priceVersion'] ==
                CoinBenefitPriceCatalog.version
        ? fullPremiumQuote!['priceCoins'] as int
        : null;
    final balance = _rewardState?['balanceCoins'];
    final rewardDailyLimit = _rewardState?['rewardedDailyLimit'];
    final rewardDailyRemaining = _rewardState?['rewardedDailyRemaining'];
    final rewardCapReached =
        rewardDailyLimit is int &&
        rewardDailyRemaining is int &&
        rewardDailyRemaining <= 0;
    final rewardQuotaLabel = rewardCapReached
        ? t['rewardQuotaReached']
        : rewardDailyLimit is int && rewardDailyRemaining is int
        ? l10n.rewardUnlockRewardQuotaRemaining(rewardDailyRemaining)
        : t['rewardQuotaUncapped'];
    final nav = RewardNavigationLabels.of(context);
    final labelRoom = buttonLabelRoom(context);
    final earn = widget.mode == RewardPageMode.earnCoins;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(earn ? nav['earn'] : nav['exchange'])),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              earn ? nav['earnDescription'] : nav['exchange'],
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              _rewardState != null && _rewardState!['balanceCoins'] is int
                  ? l10n.coinAmount(_rewardState!['balanceCoins'] as int)
                  : _walletLoading
                  ? t['loading']
                  : t['balancePending'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (earn && _rewardState?['rewardEarningEnabled'] == true) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                icon: _rewardBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.smart_display_outlined),
                onPressed:
                    !_rewardBusy &&
                        !rewardCapReached &&
                        context.watch<AdvertisingService>().canOfferRewardedAds
                    ? _watchRewardedAd
                    : null,
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t['watchRewardedAd']),
                    Text(
                      rewardQuotaLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t['rewardQuotaCaution'],
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (earn && _rewardState?['rewardEarningEnabled'] != true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(nav['earnUnavailable']),
              ),
            if (!earn && _rewardState != null) ...[
              TextButton.icon(
                key: const Key('coinHistoryButton'),
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: _lastAccountId != null ? _showCoinHistory : null,
                label: Padding(
                  padding: labelRoom,
                  child: Text(t['coinHistory']),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: !_walletLoading && _lastAccountId != null
                    ? () => _loadWallet(_lastAccountId!)
                    : null,
                label: Padding(
                  padding: labelRoom,
                  child: Text(t['rewardRefresh']),
                ),
              ),
            ],
            if (!earn) ...[
              const SizedBox(height: 16),
              // Shared duration goes BEFORE the list of checkboxes.
              Text(
                t['duration'],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('rewardDurationButton'),
                icon: const Icon(Icons.schedule),
                label: Text(coinUnlockDurationLabel(l10n, _duration)),
                onPressed: () => _chooseDuration(t),
              ),
              const SizedBox(height: 18),
              Text(
                t['chooseBenefits'],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _targetTile(context, t, CoinUnlockTarget.fullPremium),
              Divider(color: scheme.outlineVariant),
              for (final target in _standardTargets)
                _targetTile(context, t, target),
              Divider(color: scheme.outlineVariant),
              for (final target in _placementTargets)
                _targetTile(context, t, target),
              Divider(color: scheme.outlineVariant),
              for (final target in _bundles) _targetTile(context, t, target),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t['total'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_selected.isEmpty)
                        Text(
                          t['unavailable'],
                          key: const Key('rewardTotalCoins'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        )
                      else
                        // 合計の数＋単位は1行に収め、入りきらなければ字を
                        // 縮める（大きな文字で「55000コイ」「ン」と単位の
                        // 途中で切れた）。
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              serverPrice != null
                                  ? l10n.coinAmount(serverPrice)
                                  : quote != null
                                  ? l10n.coinAmount(quote.requiredCoins)
                                  : l10n.coinAmount(referenceTotal),
                              key: const Key('rewardTotalCoins'),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      // 確定価格（交換準備中）の注記は注釈なので、見出しの
                      // 大きな字に混ぜず本文の書体の別の行に出す（見出しに
                      // つなぐと、長い言語・大きな文字で単語の途中で切れた）。
                      if (serverPrice == null &&
                          quote == null &&
                          _selected.isNotEmpty)
                        Text(
                          l10n.rewardUnlockFixedPrice,
                          key: const Key('rewardTotalReferenceNote'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('rewardOverlapPreviewButton'),
                        icon: const Icon(Icons.fact_check_outlined),
                        onPressed: _selected.isNotEmpty
                            ? _reviewSelections
                            : null,
                        label: Padding(
                          padding: labelRoom,
                          child: Text(l10n.rewardUnlockReviewButton),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Once the authenticated quote/goal API is connected,
                      // these buttons become available. Never claim a saved
                      // goal or a completed redemption without a server ack.
                      FilledButton(
                        key: const Key('rewardSetGoalButton'),
                        onPressed: null,
                        child: Padding(
                          padding: labelRoom,
                          child: Text(t['goal']),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const Key('rewardRedeemButton'),
                        onPressed:
                            serverPrice != null &&
                                _rewardState?['redemptionEnabled'] == true &&
                                balance is int &&
                                balance >= serverPrice &&
                                !premiumActiveFromPlay &&
                                !_redeemBusy
                            ? _redeemFullPremium
                            : _selected.length == 1 &&
                                  _selected.contains(CoinUnlockTarget.fullPremium) &&
                                  _rewardState?['redemptionEnabled'] == true &&
                                  balance is int &&
                                  balance >= referenceTotal &&
                                  !premiumActiveFromPlay &&
                                  !_redeemBusy
                            ? _redeemFlexibleFullPremium
                            : _selected.isNotEmpty &&
                                  !_selected.contains(CoinUnlockTarget.fullPremium) &&
                                  !_selected.contains(CoinUnlockTarget.communityPostQuota) &&
                                  _rewardState?['individualRedemptionEnabled'] == true &&
                                  balance is int &&
                                  balance >= referenceTotal &&
                                  !context.watch<PremiumService>().isPremium &&
                                  !_redeemBusy
                            ? _redeemSelectedBenefits
                            : null,
                        child: Padding(
                          padding: labelRoom,
                          child: Text(t['redeem']),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t['freeOnly'],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                t['earning'],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => context.push('/membership'),
                child: Text(nav['membership']),
              ),
            ],
            if (earn && !widget.embedded)
              OutlinedButton.icon(
                onPressed: () => context.push('/rewards'),
                icon: const Icon(Icons.redeem_outlined),
                label: Text(nav['exchange']),
              ),
          ],
        ),
      ),
    );
  }
}
