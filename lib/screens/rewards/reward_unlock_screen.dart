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
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/coin_duration_label.dart';
import '../../widgets/coin_history_sheet.dart';
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
    setState(() {
      _rewardState = null;
      _officialPremiumQuote = null;
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
      if (state['redemptionEnabled'] == true) {
        try {
          final quote = await api.fullPremiumCoinQuote();
          if (!mounted || _authService?.account?.id != accountId) return;
          setState(() => _officialPremiumQuote = quote);
        } catch (_) {
          if (mounted && _authService?.account?.id == accountId) {
            setState(() => _officialPremiumQuote = null);
          }
        }
      } else {
        setState(() => _officialPremiumQuote = null);
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
    final priceVersion = _officialPremiumQuote?['priceVersion'];
    final price = _officialPremiumQuote?['priceCoins'];
    if (accountId == null ||
        api == null ||
        priceVersion is! String ||
        price is! int ||
        price != CoinBenefitPriceCatalog.unitCoins(
          CoinUnlockTarget.fullPremium, CoinDurationUnit.month,
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
    final projectedEnd = _redeemablePeriod.previewExpiry(from);
    final overlapMessage = activeCoin != null && activeCoin.isAfter(now)
        ? '現在プレミアム特典を利用中です。交換すると有効期限が'
          '${_formatBenefitExpiry(projectedEnd)}まで延長される見込みです。'
          'よろしいですか？'
        : '交換後の有効期限（参考）：${_formatBenefitExpiry(projectedEnd)}';
    final period = coinUnlockDurationLabel(
      AppLocalizations.of(context)!,
      _redeemablePeriod,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // 低い画面でも、何を・どの期間・何コインで交換するかの文が読める
        // （既定だと本文が先に潰れ、題とボタンだけになった）。
        scrollable: true,
        title: Text(t['redeem']),
        content: Text('${t['fullPremium']} · $period · $price ${t['coins']}\n\n$overlapMessage'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t['redeem']),
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
  static const _bundles = <CoinUnlockTarget>[
    CoinUnlockTarget.allAds,
  ];

  /// The only period the server sells for coins (the redeem request is
  /// always one month of the full bundle).
  static const _redeemablePeriod = CoinUnlockDuration(
    1,
    CoinDurationUnit.month,
  );

  CoinUnlockQuote? _quote() {
    if (_selected.isEmpty) return null;
    try {
      return const CoinUnlockQuoteCalculator().calculate(
        selections: [
          for (final target in _selected) CoinUnlockSelection(target: target),
        ],
        duration: _duration,
        prices: widget.priceCatalog,
        priceVersion: 'server-pending',
        fullPremiumMinimumCoins: widget.fullPremiumMinimumCoins,
      );
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

  String _formatBenefitExpiry(DateTime date) {
    final local = date.toLocal();
    return '${local.year}年${local.month}月${local.day}日'
        '${local.hour.toString().padLeft(2, '0')}時'
        '${local.minute.toString().padLeft(2, '0')}分';
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
      final candidate = CoinUnlockTarget.values.where(
        (target) => target.name == raw['feature'],
      ).firstOrNull;
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
    final premium = context.read<PremiumService>();
    final now = DateTime.now();
    final active = _activeBenefitExpiries(now);
    final paidUntil = premium.hasVerifiedPlayPremium
        ? premium.verifiedExpiryDate : null;
    final coinUntil = premium.activeCoinPremiumExpiry;
    final hasPlay = premium.hasVerifiedPlayPremium;
    final hasFull = _selected.contains(CoinUnlockTarget.fullPremium);
    final hasAllAds = _selected.contains(CoinUnlockTarget.allAds);
    final fullStarts = _later(_later(now, paidUntil), coinUntil);
    final fullEnds = hasFull ? _duration.previewExpiry(fullStarts) : null;
    final lines = <String>[];

    if (hasPlay) {
      lines.add(paidUntil != null
          ? '現在プレミアム会員を利用中です（${_formatBenefitExpiry(paidUntil)}まで）。'
          : '現在プレミアム会員を利用中です。契約終了日時は確認できていません。');
    } else if (coinUntil != null && coinUntil.isAfter(now)) {
      lines.add(
        '現在プレミアム特典を利用中です'
        '（${_formatBenefitExpiry(coinUntil)}まで）。',
      );
    }
    if (hasFull) {
      lines.add(
        '選択中の「${t['fullPremium']}」はほかの単品特典を含みます。'
        '重複分は二重に有効にせず、延長される想定です。',
      );
    }
    if (hasAllAds &&
        _placementTargets.any((target) => _selected.contains(target))) {
      lines.add('選択中の広告非表示特典は「${t['allAds']}」と重複します。');
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
      final coversNow = existing?.isAfter(now) == true ||
          (hasPlay && paidUntil?.isAfter(now) == true) ||
          (coinUntil?.isAfter(now) == true) ||
          (hasFull && target != CoinUnlockTarget.fullPremium) ||
          (hasAllAds && _placementTargets.contains(target));
      lines.add(
        '${t[target.name]}：${coversNow ? '既存・セット特典と重複。' : ''}'
        '参考の延長後期限 ${_formatBenefitExpiry(calculatedExpiry)}',
      );
    }
    final referenceTotal = _selected.fold<int>(0, (sum, target) =>
      sum + CoinBenefitPriceCatalog.cost(target, _duration));
    lines.add(
      '確定単価による合計：$referenceTotal コイン。'
      '単品特典・重複交換のコイン消費はまだサーバー未対応です。'
      '金額は確定済みですが、交換はサーバーが正式な見積もりを返す場合のみ可能です。'
      '正式な有効期限は交換直前のサーバー確認で決まります。',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('特典の重複・有効期限の確認'),
        content: Text(lines.join('\n\n')),
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
    if (target == CoinUnlockTarget.fullPremium &&
        _duration.unit == CoinDurationUnit.month &&
        _duration.amount == 1 &&
        _officialPremiumQuote?['enabled'] == true &&
        _officialPremiumQuote?['priceCoins'] ==
            CoinBenefitPriceCatalog.unitCoins(
              CoinUnlockTarget.fullPremium, CoinDurationUnit.month,
            ) &&
        _officialPremiumQuote?['priceVersion'] ==
            CoinBenefitPriceCatalog.version) {
      officialPrice = _officialPremiumQuote!['priceCoins'] as int;
    }
    final referencePrice = enabled
        ? CoinBenefitPriceCatalog.cost(target, _duration) : null;
    final hasSubscription = context.read<PremiumService>().hasPurchasedPremium;
    final japanese = Localizations.localeOf(context).languageCode == 'ja';
    return CheckboxListTile(
      key: ValueKey('rewardFeature_${target.name}'),
      value: selected,
      onChanged: enabled ? (_) => _toggle(target) : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(t[target.name]),
      subtitle: Text(
        !enabled
            ? t['notReady']
            : officialPrice != null
            ? '$officialPrice ${t['coins']}'
            : '${japanese ? '確定価格（交換準備中）' : 'Fixed price (redemption not yet available)'}'
              ' · $referencePrice ${t['coins']}'
              '${hasSubscription ? ' · ${t['activePremium']}' : ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      secondary: !enabled
          ? Tooltip(
              message: t['notReady'],
              child: Icon(
                Icons.lock_clock_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : target == CoinUnlockTarget.fullPremium && _fullBundleBadge()
          ? Chip(label: Text(t['bestValue']))
          : null,
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
    final referenceTotal = _selected.fold<int>(0, (sum, target) =>
        sum + CoinBenefitPriceCatalog.cost(target, _duration));
    final premiumActiveFromPlay =
        context.watch<PremiumService>().hasVerifiedPlayPremium;
    final serverPrice =
        _selected.length == 1 &&
            _selected.contains(CoinUnlockTarget.fullPremium) &&
            _duration.unit == CoinDurationUnit.month &&
            _duration.amount == 1 &&
            _officialPremiumQuote?['enabled'] == true &&
            _officialPremiumQuote?['priceCoins'] ==
                CoinBenefitPriceCatalog.unitCoins(
                  CoinUnlockTarget.fullPremium, CoinDurationUnit.month,
                ) &&
            _officialPremiumQuote?['priceVersion'] ==
                CoinBenefitPriceCatalog.version
        ? _officialPremiumQuote!['priceCoins'] as int
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
        ? t['rewardQuotaRemaining'].replaceAll(
            '{count}',
            '$rewardDailyRemaining',
          )
        : t['rewardQuotaUncapped'];
    final nav = RewardNavigationLabels.of(context);
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
                  ? '${_rewardState!['balanceCoins']} ${t['coins']}'
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
                label: Text(t['coinHistory']),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: !_walletLoading && _lastAccountId != null
                    ? () => _loadWallet(_lastAccountId!)
                    : null,
                label: Text(t['rewardRefresh']),
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
                      Text(
                        serverPrice != null
                            ? '$serverPrice ${t['coins']}'
                            : quote != null
                            ? '${quote.requiredCoins} ${t['coins']}'
                            : _selected.isEmpty
                            ? t['unavailable']
                            : '$referenceTotal ${t['coins']}'
                              '（参考価格・交換準備中）',
                        key: const Key('rewardTotalCoins'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('rewardOverlapPreviewButton'),
                        icon: const Icon(Icons.fact_check_outlined),
                        onPressed: _selected.isNotEmpty
                            ? _reviewSelections : null,
                        label: const Text('重複・有効期限を確認'),
                      ),
                      const SizedBox(height: 8),
                      // Once the authenticated quote/goal API is connected,
                      // these buttons become available. Never claim a saved
                      // goal or a completed redemption without a server ack.
                      FilledButton(
                        key: const Key('rewardSetGoalButton'),
                        onPressed: null,
                        child: Text(t['goal']),
                      ),
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
                            : null,
                        child: Text(t['redeem']),
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
