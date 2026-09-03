import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/monetization_gate.dart';
import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';

/// プレミアム画面。ユーザー作品そのものを除くUI色はColorSchemeへ集約する。
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = context.watch<PremiumService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premiumScreenTitle),
        actions: const [HelpButton(topic: 'プレミアム')],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (premium.isLaunchCampaignActive) ...[
                _campaignBanner(context, l10n),
                const SizedBox(height: 24),
              ] else if (premium.hasPurchasedPremium) ...[
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
                            Text(
                              l10n.premiumActiveLabel,
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 16,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                                fontWeight: FontWeight.w700,
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
              if (!premium.hasPurchasedPremium &&
                  !premium.isLaunchCampaignActive) ...[
                _heroSection(context, l10n),
                const SizedBox(height: 24),
              ],
              Text(
                l10n.premiumVsTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _comparisonTable(context, l10n),
              if (premium.isLaunchCampaignActive) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.premiumCampaignFreeNote,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!premium.isLaunchCampaignActive &&
                  !premium.hasPurchasedPremium) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.premiumPlanSectionTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (!premium.storeAvailable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.premiumStoreUnavailable,
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                  ),
                if (premium.purchaseError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      premium.purchaseError!,
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                  ),
                _planCard(
                  context,
                  l10n,
                  l10n.premiumYearlyTitle,
                  l10n.premiumYearlyPrice,
                  l10n.premiumYearlyDescription,
                  true,
                  premium,
                  PremiumService.yearlyProductId,
                  originalPrice: l10n.premiumYearlyOriginalPrice,
                ),
                const SizedBox(height: 12),
                _planCard(
                  context,
                  l10n,
                  l10n.premiumMonthlyTitle,
                  l10n.premiumMonthlyPrice,
                  '',
                  false,
                  premium,
                  PremiumService.monthlyProductId,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: premium.storeAvailable
                        ? () async {
                            await premium.restorePurchases();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.premiumRestoredSnackbar),
                                ),
                              );
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

  String _campaignEndLabel(AppLocalizations l10n) {
    final end = kMonetizationEnabledFrom.subtract(const Duration(minutes: 1));
    final mo = end.month.toString().padLeft(2, '0');
    final dd = end.day.toString().padLeft(2, '0');
    final hh = end.hour.toString().padLeft(2, '0');
    final mm = end.minute.toString().padLeft(2, '0');
    return l10n.premiumCampaignEndLabel('${end.year}/$mo/$dd $hh:$mm');
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Widget _campaignBanner(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.premiumCampaignBannerTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.premiumCampaignBannerBody,
              style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              _campaignEndLabel(l10n),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.premiumHeroTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.premiumHeroSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroHighlight(
                  context,
                  Icons.schedule,
                  l10n.premiumHeroHighlightDuration,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroHighlight(
                  context,
                  Icons.hide_image_outlined,
                  l10n.premiumHeroHighlightWatermark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroHighlight(
                  context,
                  Icons.tune,
                  l10n.premiumHeroHighlightGrading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroHighlight(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
              color: scheme.onSurfaceVariant,
              height: 1.3,
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
        ? scheme.onPrimary
        : scheme.onSurface;
    if (value == '○') {
      return Icon(
        Icons.check_circle_rounded,
        color: premiumColumn ? scheme.onPrimary : scheme.onSurfaceVariant,
        size: 20,
      );
    }
    if (value == '×') {
      return Icon(
        Icons.remove_circle_outline_rounded,
        color: premiumColumn
            ? scheme.onPrimary.withValues(alpha: 0.72)
            : scheme.outline,
        size: 20,
      );
    }
    return Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: foreground),
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
      (l10n.premiumFeatureAds, l10n.premiumValueYes, l10n.premiumValueNo),
      (
        l10n.premiumFeatureCommunityUpload,
        l10n.premiumValueUploadFree,
        l10n.premiumValueUploadPremium,
      ),
    ];
    final premiumBg = scheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: scheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Table(
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
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
                child: Text(
                  l10n.premiumComparisonFeature,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Container(
                color: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
                child: Text(
                  l10n.premiumComparisonFree,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                    color: scheme.onSurfaceVariant,
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
                      color: scheme.onPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.premiumComparisonPremium,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                        color: scheme.onPrimary,
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
                  child: Text(
                    item.$1,
                    style: TextStyle(fontSize: 12, color: scheme.onSurface),
                  ),
                ),
                Container(
                  color: zebra,
                  padding: const EdgeInsets.all(12),
                  child: Center(child: _comparisonCell(context, item.$2)),
                ),
                Container(
                  color: premiumBg,
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: _comparisonCell(
                      context,
                      item.$3,
                      premiumColumn: true,
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
    String price,
    String description,
    bool isRecommended,
    PremiumService premium,
    String productId, {
    String? originalPrice,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final busy = premium.purchasePending;
    return Card(
      elevation: isRecommended ? 6 : 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRecommended
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: (!premium.storeAvailable || busy)
            ? null
            : () async {
                final ok = await premium.buy(productId);
                if (!ok && context.mounted && premium.purchaseError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(premium.purchaseError!)),
                  );
                }
              },
        child: Container(
          decoration: isRecommended
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
                    if (isRecommended)
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
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                l10n.premiumPlanRecommendedBadge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Kuramubon',
                                  fontFamilyFallback: kHeadingFontFallback,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              else
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (originalPrice != null)
                        Text(
                          originalPrice,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: scheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        price,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
