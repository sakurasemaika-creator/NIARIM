import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/monetization_gate.dart';
import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = context.watch<PremiumService>();

    return Scaffold(
      // topic: 'プレミアム' はhelp_screen.dart側の項目タイトル（日本語固定の
      // 内部検索キー）と一致させる必要があるため、翻訳対象から除外している。
      // 「NIARIM Premium」はアプリ名＋英語のPremiumで構成される固有表記のため翻訳しない。
      appBar: AppBar(title: const Text('NIARIM Premium'), actions: const [HelpButton(topic: 'プレミアム')]),
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
                color: const Color(0xFF2E7D32),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(l10n.premiumActiveLabel, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(l10n.premiumVsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _comparisonTable(context, l10n),
            if (premium.isLaunchCampaignActive) ...[
              const SizedBox(height: 8),
              Text(l10n.premiumCampaignFreeNote,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            if (!premium.isLaunchCampaignActive && !premium.hasPurchasedPremium) ...[
              const SizedBox(height: 24),
              Text(l10n.premiumPlanSectionTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (!premium.storeAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.premiumStoreUnavailable,
                    style: TextStyle(fontSize: 12, color: Colors.orange[300]),
                  ),
                ),
              if (premium.purchaseError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    premium.purchaseError!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              _planCard(
                context,
                l10n,
                l10n.premiumYearlyTitle,
                '¥5,500',
                l10n.premiumYearlyDescription,
                true,
                premium,
                PremiumService.yearlyProductId,
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
                              SnackBar(content: Text(l10n.premiumRestoredSnackbar)),
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

  /// リリース記念キャンペーンバナー（仕様書13：課金一時停止期間中は全員へ
  /// プレミアム機能を無料開放する）。
  /// 「YYYY/MM/DD HH:MM」の形式でキャンペーン終了日時を数値表記し、
  /// 「まで」の前置き・後置きは各言語の`premiumCampaignEndLabel`に委譲する
  /// （西暦表記。以前は「～12月31日23:59まで」と年が無く、年をまたぐと
  /// 誤解を招く表記だった）。kMonetizationEnabledFromの1分前が実際の
  /// 終了時刻。
  String _campaignEndLabel(AppLocalizations l10n) {
    final end = kMonetizationEnabledFrom.subtract(const Duration(minutes: 1));
    final mo = end.month.toString().padLeft(2, '0');
    final dd = end.day.toString().padLeft(2, '0');
    final hh = end.hour.toString().padLeft(2, '0');
    final mm = end.minute.toString().padLeft(2, '0');
    return l10n.premiumCampaignEndLabel('${end.year}/$mo/$dd $hh:$mm');
  }

  Widget _campaignBanner(BuildContext context, AppLocalizations l10n) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.celebration, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.premiumCampaignBannerTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              l10n.premiumCampaignBannerBody,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            // 年をまたいでも誤解が生じないよう西暦から表示する（例：
            // 「2026/12/31 23:59」）。kMonetizationEnabledFromの
            // 前日23:59が実際のキャンペーン終了日時のため、そこから算出する。
            Text(_campaignEndLabel(l10n), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _comparisonTable(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (l10n.premiumFeatureDrawing, '○', '○'), (l10n.premiumFeatureTimeline, '○', '○'), (l10n.premiumFeatureExport, '○', '○'),
      (l10n.premiumFeatureMaxDuration, l10n.premiumValueDuration90Sec, l10n.premiumValueUnlimited),
      (l10n.premiumFeatureEndLogo, l10n.premiumValueYes, l10n.premiumValueRemovable),
      (l10n.premiumFeatureWatermark, '×', '○'),
      (l10n.premiumFeatureToneCurve, '×', '○'), (l10n.premiumFeatureLevelCorrection, '×', '○'),
      (l10n.premiumFeatureAds, l10n.premiumValueYes, l10n.premiumValueNo),
    ];

    return Table(
      border: TableBorder.all(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(8)),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
          children: [
            Padding(padding: const EdgeInsets.all(8), child: Text(l10n.premiumComparisonFeature, style: const TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: const EdgeInsets.all(8), child: Text(l10n.premiumComparisonFree, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
            const Padding(padding: EdgeInsets.all(8), child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        ...items.map((item) => TableRow(children: [
          Padding(padding: const EdgeInsets.all(8), child: Text(item.$1, style: const TextStyle(fontSize: 12))),
          Padding(padding: const EdgeInsets.all(8), child: Text(item.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          Padding(padding: const EdgeInsets.all(8), child: Text(item.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
        ])),
      ],
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
    String productId,
  ) {
    final busy = premium.purchasePending;
    return Card(
      elevation: isRecommended ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecommended ? const BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isRecommended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                        child: Text(l10n.premiumPlanRecommendedBadge, style: const TextStyle(fontSize: 10, color: Colors.black)),
                      ),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (description.isNotEmpty)
                      Text(description,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
