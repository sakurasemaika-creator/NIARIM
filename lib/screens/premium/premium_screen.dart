import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/menu_card.dart';

/// プレミアム画面。ユーザー作品そのものを除くUI色はColorSchemeへ集約する。
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _planHeading = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _planHeading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = context.watch<PremiumService>();
    final scheme = Theme.of(context).colorScheme;

    final monthlyPrice = premium.storeAvailable
        ? premium.products
              .where((product) => product.id == PremiumService.monthlyProductId)
              .firstOrNull
              ?.price
        : null;
    final yearlyPrice = premium.storeAvailable
        ? premium.products
              .where((product) => product.id == PremiumService.yearlyProductId)
              .firstOrNull
              ?.price
        : null;

    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.premiumScreenTitle),
        actions: const [HelpButton(topic: 'プレミアム')],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (premium.hasPurchasedPremium) ...[
                Card(
                  color: scheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: scheme.onPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.premiumActiveLabel,
                                style: localizedHeadingStyle(
                                  context,
                                  TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (premium.purchaseDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.premiumRegisteredDateLabel(
                              _formatDate(premium.purchaseDate!),
                            ),
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (premium.nextRenewalDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.premiumNextRenewalDateLabel(
                              _formatDate(premium.nextRenewalDate!),
                            ),
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (!premium.hasPurchasedPremium) ...[
                _heroSection(context, l10n),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('premiumSeePlansButton'),
                  onPressed: () {
                    final target = _planHeading.context;
                    if (target != null) {
                      _planHeading.requestFocus();
                      Scrollable.ensureVisible(
                        target,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(l10n.rewardNavigationPremiumPlans),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                l10n.premiumVsTitle,
                style: localizedHeadingStyle(
                  context,
                  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _comparisonTable(context, l10n),
              const SizedBox(height: 8),
              Text(
                l10n.premiumDurationExportNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!premium.hasPurchasedPremium) ...[
                const SizedBox(height: 24),
                Focus(
                  focusNode: _planHeading,
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.premiumPlanSectionTitle,
                      style: localizedHeadingStyle(
                        context,
                        TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (yearlyPrice == null || monthlyPrice == null) ...[
                  Text(
                    l10n.premiumStoreUnavailable,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: premium.refreshStoreProducts,
                      child: Text(l10n.communityRetry),
                    ),
                  ),
                ],
                if (premium.purchasePending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.premiumCheckoutPending)),
                        ],
                      ),
                    ),
                  ),
                if (premium.purchaseError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _purchaseErrorText(l10n, premium.purchaseError!),
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                  ),
                _planCard(
                  context,
                  l10n,
                  l10n.premiumYearlyTitle,
                  yearlyPrice,
                  true,
                  premium,
                  PremiumService.yearlyProductId,
                ),
                const SizedBox(height: 12),
                _planCard(
                  context,
                  l10n,
                  l10n.premiumMonthlyTitle,
                  monthlyPrice,
                  false,
                  premium,
                  PremiumService.monthlyProductId,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed:
                        premium.storeAvailable && !premium.purchasePending
                        ? () async {
                            var message = l10n.premiumRestoredSnackbar;
                            try {
                              await premium.restorePurchases();
                            } catch (_) {
                              message = l10n.premiumRestoreFailed;
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          }
                        : null,
                    child: Text(l10n.premiumRestorePurchases),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _purchaseErrorText(AppLocalizations l10n, String error) =>
      error == PremiumService.checkoutStartFailed
      ? l10n.premiumCheckoutStartFailed
      : error;

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Widget _heroSection(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final badge = ExcludeSemantics(
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: const Icon(Icons.workspace_premium_rounded, size: 25),
                ),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.premiumHeroTitle,
                      style: localizedHeadingStyle(
                        context,
                        TextStyle(
                          fontSize: 20,
                          height: 1.24,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l10n.premiumHeroSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              final textScale = MediaQuery.textScalerOf(context).scale(20) / 20;
              if ((constraints.maxWidth - 58) / textScale < 190) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [badge, copy],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  badge,
                  Expanded(child: copy),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth /
                      MediaQuery.textScalerOf(context).scale(1) <
                  365;
              final highlights = [
                (Icons.schedule, l10n.premiumHeroHighlightDuration),
                (Icons.hide_image_outlined, l10n.premiumHeroHighlightWatermark),
                (Icons.tune, l10n.premiumHeroHighlightGrading),
              ];
              final tiles = [
                for (final (icon, label) in highlights)
                  _heroHighlight(context, icon, label, stacked: stacked),
              ];
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 6,
                      children: tiles,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        for (final tile in tiles) Expanded(child: tile),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _heroHighlight(
    BuildContext context,
    IconData icon,
    String label, {
    required bool stacked,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Flex(
        direction: stacked ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(icon, size: 20, color: AccentTextTheme.of(context)),
          Flexible(
            flex: stacked ? 1 : 0,
            child: Text(
              stacked ? label.replaceAll('\n', ' ') : label,
              textAlign: stacked ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCell(
    BuildContext context,
    String value, {
    bool premiumColumn = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = premiumColumn
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    if (value == '○') {
      return Icon(
        Icons.check_circle_rounded,
        color: premiumColumn
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        size: 20,
      );
    }
    if (value == '×') {
      return Icon(
        Icons.remove_circle_outline_rounded,
        color: premiumColumn ? scheme.onPrimaryContainer : scheme.outline,
        size: 20,
      );
    }
    return Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: foreground),
    );
  }

  Widget _comparisonTable(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (l10n.premiumFeatureDrawing, '○', '○'),
      (l10n.premiumFeatureTimeline, '○', '○'),
      (l10n.premiumFeatureExport, '○', '○'),
      (
        l10n.premiumFeatureMaxDuration,
        l10n.premiumValueDuration90Sec,
        l10n.premiumValueDuration2Hours,
      ),
      (
        l10n.premiumFeatureEndLogo,
        l10n.premiumValueYes,
        l10n.premiumValueRemovable,
      ),
      (l10n.premiumFeatureWatermark, '×', '○'),
      (l10n.premiumFeatureToneCurve, '×', '○'),
      (l10n.premiumFeatureLevelCorrection, '×', '○'),
      (l10n.helpCustomAutomationTitle, '×', '○'),
      (l10n.premiumFeatureAds, l10n.premiumValueYes, l10n.premiumValueNo),
      (
        l10n.premiumFeatureCommunityUpload,
        l10n.premiumValueUploadFree,
        l10n.premiumValueUploadPremium,
      ),
    ];
    String spoken(String value) => switch (value) {
      '○' => l10n.premiumValueYes,
      '×' => l10n.premiumValueNo,
      _ => value,
    };
    String rowLabel((String, String, String) item) =>
        '${item.$1}\n${l10n.premiumComparisonFree} ${spoken(item.$2)}\n${l10n.premiumComparisonPremium} ${spoken(item.$3)}';
    final premiumBg = scheme.primaryContainer;
    if (MediaQuery.textScalerOf(context).scale(14) >= 21) {
      return MenuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) ...[
              if (item != items.first)
                Divider(height: 1, color: scheme.outlineVariant),
              Semantics(
                container: true,
                label: rowLabel(item),
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${l10n.premiumComparisonFree}  ${spoken(item.$2)}'),
                      Text(
                        '${l10n.premiumComparisonPremium}  ${spoken(item.$3)}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return MenuCard(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: scheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Table(
        // セルの高さは既定（top）だと**各セルが自分の中身ぶんしか高さを
        // 持たない**ため、機能名が2行に折り返した行だけ、他の列の背景色が
        // 行の下端まで届かず白い帯が残る（実際に「アニメ制作・描画機能」の
        // 行で発生していた）。intrinsicHeightにすると全セルが行内で最も
        // 高いセルと同じ高さになり、背景が必ず行いっぱいに塗られる。
        // fillは「全セルがfillだと行の高さが0になる」ため使わないこと。
        defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
        border: TableBorder(
          horizontalInside: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(1.4),
        },
        children: [
          TableRow(
            children: [
              Container(
                color: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(12),
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.premiumComparisonFeature,
                  style: localizedHeadingStyle(
                    context,
                    TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              Container(
                color: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                child: Text(
                  l10n.premiumComparisonFree,
                  textAlign: TextAlign.center,
                  style: localizedHeadingStyle(
                    context,
                    TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Container(
                color: premiumBg,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 14,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.premiumComparisonPremium,
                      textAlign: TextAlign.center,
                      style: localizedHeadingStyle(
                        context,
                        TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ...items.asMap().entries.map((entry) {
            final zebra = entry.key.isOdd
                ? scheme.surfaceContainerLowest
                : scheme.surface;
            final item = entry.value;
            return TableRow(
              children: [
                Container(
                  color: zebra,
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.$1,
                    semanticsLabel: rowLabel(item),
                    style: TextStyle(fontSize: 14, color: scheme.onSurface),
                  ),
                ),
                Container(
                  color: zebra,
                  padding: const EdgeInsets.all(12),
                  child: ExcludeSemantics(
                    child: Center(child: _comparisonCell(context, item.$2)),
                  ),
                ),
                Container(
                  color: premiumBg,
                  padding: const EdgeInsets.all(12),
                  child: ExcludeSemantics(
                    child: Center(
                      child: _comparisonCell(
                        context,
                        item.$3,
                        premiumColumn: true,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _planCard(
    BuildContext context,
    AppLocalizations l10n,
    String title,
    String? price,
    bool isRecommended,
    PremiumService premium,
    String productId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final busy = premium.purchasePending;
    final available = price != null;
    final featured = isRecommended && available;
    return MenuCard(
      elevation: !available
          ? 0
          : featured
          ? 6
          : 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: featured
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Semantics(
        button: true,
        enabled: available && !busy,
        child: InkWell(
          onTap: (!available || busy)
              ? null
              : () async {
                  final ok = await premium.buy(productId);
                  if (!ok && context.mounted && premium.purchaseError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _purchaseErrorText(l10n, premium.purchaseError!),
                        ),
                      ),
                    );
                  }
                },
          child: Container(
            decoration: featured
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primaryContainer.withValues(alpha: 0.6),
                        scheme.surface,
                      ],
                    ),
                  )
                : null,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (featured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: AccentTextTheme.of(context),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  l10n.premiumPlanRecommendedBadge,
                                  style: localizedHeadingStyle(
                                    context,
                                    TextStyle(
                                      fontSize: 12,
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        title,
                        style: localizedHeadingStyle(
                          context,
                          TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Expanded(
                    child: Text(
                      price,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
