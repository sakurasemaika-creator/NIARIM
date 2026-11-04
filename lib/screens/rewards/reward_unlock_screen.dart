import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/reward_unlock_labels.dart';
import '../../models/coin_unlock_quote.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';

/// Reward UI shell; the server wallet/pricing/ad issuance are not yet live.
/// Never invent coin balances, price quotes or exchange success on the client.
class RewardUnlockScreen extends StatefulWidget {
  const RewardUnlockScreen({
    super.key,
    this.priceCatalog = const {},
    this.fullPremiumMinimumCoins,
  });

  /// Server-verified price catalog. Missing entries are NOT free.
  final Map<CoinUnlockTarget, CoinUnlockUnitPrices> priceCatalog;
  final int? fullPremiumMinimumCoins;

  @override
  State<RewardUnlockScreen> createState() => _RewardUnlockScreenState();
}

class _RewardUnlockScreenState extends State<RewardUnlockScreen> {
  CoinUnlockDuration _duration =
      const CoinUnlockDuration(1, CoinDurationUnit.hour);
  final Set<CoinUnlockTarget> _selected = {};

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
    CoinUnlockTarget.fullPremium,
  ];

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
      if (target == CoinUnlockTarget.fullPremium) {
        _selected.removeWhere((value) => value != target);
      } else {
        _selected.remove(CoinUnlockTarget.fullPremium);
      }
      if (target == CoinUnlockTarget.allAds) {
        _selected.removeAll(_placementTargets);
      } else if (_placementTargets.contains(target)) {
        _selected.remove(CoinUnlockTarget.allAds);
      }
    });
  }

  String _durationText(RewardUnlockLabels t, CoinUnlockDuration value) {
    final unit = switch (value.unit) {
      CoinDurationUnit.hour => t['hour'],
      CoinDurationUnit.day => t['day'],
      CoinDurationUnit.week => t['week'],
      CoinDurationUnit.month => t['month'],
    };
    return '${value.amount}$unit';
  }

  Future<void> _chooseDuration(RewardUnlockLabels t) async {
    final groups = <(String, List<CoinUnlockDuration>)>[
      (t['hour'], [for (var i = 1; i <= 24; i++)
        CoinUnlockDuration(i, CoinDurationUnit.hour)]),
      (t['day'], [for (var i = 2; i <= 6; i++)
        CoinUnlockDuration(i, CoinDurationUnit.day)]),
      (t['week'], [for (var i = 1; i <= 3; i++)
        CoinUnlockDuration(i, CoinDurationUnit.week)]),
      (t['month'], [for (var i = 1; i <= 120; i++)
        CoinUnlockDuration(i, CoinDurationUnit.month)]),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(t['chooseDuration'],
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                ),
                for (final (label, options) in groups)
                  ExpansionTile(
                    title: Text(label),
                    initiallyExpanded: label == t['hour'],
                    children: [
                      for (final option in options)
                        ListTile(
                          key: ValueKey('rewardDuration_${option.unit.name}_${option.amount}'),
                          title: Text(_durationText(t, option)),
                          trailing: _duration.unit == option.unit &&
                                  _duration.amount == option.amount
                              ? Icon(Icons.check,
                                  color: Theme.of(sheetContext).colorScheme.primary)
                              : null,
                          onTap: () {
                            setState(() => _duration = option);
                            Navigator.of(sheetContext).pop();
                          },
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
    final price = enabled && rate != null
        ? rate.cost(_duration)
        : null;
    return CheckboxListTile(
      key: ValueKey('rewardFeature_${target.name}'),
      value: selected,
      onChanged: enabled ? (_) => _toggle(target) : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(t[target.name]),
      subtitle: Text(
        price == null
            ? t['pricePending']
            : '$price ${t['coins']}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      secondary: !enabled
          ? Tooltip(
              message: t['notReady'],
              child: Icon(Icons.lock_clock_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            )
          : target == CoinUnlockTarget.fullPremium && _fullBundleBadge()
              ? Chip(label: Text(t['bestValue']))
              : null,
    );
  }

  bool _fullBundleBadge() {
    final targets = [..._standardTargets, ..._placementTargets]
      ..remove(CoinUnlockTarget.communityPostQuota);
    return const CoinUnlockQuoteCalculator().isFullPremiumBestValue(
      duration: _duration,
      prices: widget.priceCatalog,
      comparisonTargets: targets,
      fullPremiumMinimumCoins: widget.fullPremiumMinimumCoins ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RewardUnlockLabels.of(context);
    final premium = context.watch<PremiumService>();
    final scheme = Theme.of(context).colorScheme;
    final quote = _quote();
    return Scaffold(
      appBar: AppBar(title: Text(t['title'])),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t['active'],
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(premium.hasPurchasedPremium
                        ? t['activePremium']
                        : premium.isLaunchCampaignActive
                            ? t['activeCampaign']
                            : t['activeUnavailable']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(t['balancePending'],
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            // Shared duration goes BEFORE the list of checkboxes.
            Text(t['duration'],
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('rewardDurationButton'),
              icon: const Icon(Icons.schedule),
              label: Text(_durationText(t, _duration)),
              onPressed: () => _chooseDuration(t),
            ),
            const SizedBox(height: 18),
            Text(t['chooseBenefits'],
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final target in _standardTargets)
              _targetTile(context, t, target),
            Divider(color: scheme.outlineVariant),
            for (final target in _placementTargets)
              _targetTile(context, t, target),
            Divider(color: scheme.outlineVariant),
            for (final target in _bundles)
              _targetTile(context, t, target),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t['total'],
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      quote == null
                          ? t['unavailable']
                          : '${quote.requiredCoins} ${t['coins']}',
                      key: const Key('rewardTotalCoins'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    // Once the authenticated quote/goal API is connected,
                    // these buttons become available. Never claim a saved
                    // goal or a completed redemption without a server ack.
                    FilledButton(
                      onPressed: null,
                      child: Text(t['goal']),
                    ),
                    OutlinedButton(
                      onPressed: null,
                      child: Text(t['redeem']),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(t['freeOnly'],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            Text(t['earning'],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: () => context.push('/premium'),
              child: Text(t['subscribe']),
            ),
          ],
        ),
      ),
    );
  }
}
