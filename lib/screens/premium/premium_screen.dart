import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/monetization_gate.dart';
import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

/// プレミアム画面（ハンバーガーメニューから開く）。
///
/// 年額プラン（¥5,500）が「月額（¥550）×12か月＝¥6,600」より¥1,100
/// （＝月額2か月分）お得であることを、取り消し線付きの元価格・月あたり
/// 換算額（`premiumYearlyOriginalPrice`・`premiumYearlyPerMonthLabel`）で
/// 具体的に示す。月額・年額の価格自体（¥550・¥5,500）は消費税込みの表示。
/// 導入バナー（`_heroSection`）・比較表のアイコン化・おすすめプラン
/// カードのグラデーション演出でページ全体のデザインを作り込んでいる。
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = context.watch<PremiumService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // topic: 'プレミアム' はhelp_screen.dart側の項目タイトル（日本語固定の
      // 内部検索キー）と一致させる必要があるため、翻訳対象から除外している。
      appBar: AppBar(title: Text(l10n.premiumScreenTitle), actions: const [HelpButton(topic: 'プレミアム')]),
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
              // キャンペーン終了後、契約中の会員には登録日・次回更新日
              // （サーバー側レシート検証が未実装の間は暦計算による推定値）を
              // 表示する。バナー色は固定の緑ではなく、テーマの差し色に対して
              // 自動でコントラストが確保されるonPrimaryを文字色に使う。
              Card(
                color: scheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.check_circle, color: scheme.onPrimary),
                        const SizedBox(width: 8),
                        Text(l10n.premiumActiveLabel,
                            style: TextStyle(
                                color: scheme.onPrimary, fontSize: 16, fontFamily: 'Kuramubon', fontWeight: FontWeight.w700)),
                      ]),
                      if (premium.purchaseDate != null) ...[
                        const SizedBox(height: 8),
                        Text(l10n.premiumRegisteredDateLabel(_formatDate(premium.purchaseDate!)),
                            style: TextStyle(color: scheme.onPrimary, fontSize: 13)),
                      ],
                      if (premium.nextRenewalDate != null) ...[
                        const SizedBox(height: 2),
                        Text(l10n.premiumNextRenewalDateLabel(_formatDate(premium.nextRenewalDate!)),
                            style: TextStyle(color: scheme.onPrimary, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (!premium.hasPurchasedPremium && !premium.isLaunchCampaignActive) ...[
              _heroSection(context, l10n),
              const SizedBox(height: 24),
            ],
            Text(l10n.premiumVsTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
            const SizedBox(height: 16),
            _comparisonTable(context, l10n),
            if (premium.isLaunchCampaignActive) ...[
              const SizedBox(height: 8),
              Text(l10n.premiumCampaignFreeNote,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            if (!premium.isLaunchCampaignActive && !premium.hasPurchasedPremium) ...[
              const SizedBox(height: 24),
              Text(l10n.premiumPlanSectionTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
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
                l10n.premiumYearlyPrice,
                l10n.premiumYearlyDescription,
                true,
                premium,
                PremiumService.yearlyProductId,
                originalPrice: l10n.premiumYearlyOriginalPrice,
                perMonthLabel: l10n.premiumYearlyPerMonthLabel,
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
  /// 「YYYY/MM/DD HH:MM」の形式（西暦表記、年をまたいでも誤解を招かない）
  /// でキャンペーン終了日時を数値表記し、「まで」の前置き・後置きは
  /// 各言語の`premiumCampaignEndLabel`に委譲する。kMonetizationEnabledFrom
  /// の1分前が実際の終了時刻。
  String _campaignEndLabel(AppLocalizations l10n) {
    final end = kMonetizationEnabledFrom.subtract(const Duration(minutes: 1));
    final mo = end.month.toString().padLeft(2, '0');
    final dd = end.day.toString().padLeft(2, '0');
    final hh = end.hour.toString().padLeft(2, '0');
    final mm = end.minute.toString().padLeft(2, '0');
    return l10n.premiumCampaignEndLabel('${end.year}/$mo/$dd $hh:$mm');
  }

  /// 登録日・次回更新日の表示用（西暦YYYY/MM/DD表記）。
  String _formatDate(DateTime d) {
    final mo = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mo/$dd';
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Kuramubon')),
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

  /// 未加入・キャンペーン非開催時にのみ表示する導入バナー。アイコン付きの
  /// 見出し＋一言説明で、いきなり比較表から始まるより「プレミアムで何が
  /// 変わるか」を先に印象づける。キャンペーン中は`_campaignBanner`が
  /// 同種の役割を既に果たすため、二重表示を避けている。
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
          BoxShadow(color: scheme.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
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
                  boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.4), blurRadius: 10)],
                ),
                child: Icon(Icons.workspace_premium_rounded, color: scheme.onPrimary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.premiumHeroTitle,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
                    const SizedBox(height: 4),
                    Text(l10n.premiumHeroSubtitle,
                        style: TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 「何が変わるか」を一目で伝える3つのハイライト。文章だけでなく、
          // 視覚的な塊として要点を先に見せる。
          Row(
            children: [
              Expanded(child: _heroHighlight(context, Icons.all_inclusive, l10n.premiumHeroHighlightDuration)),
              const SizedBox(width: 8),
              Expanded(child: _heroHighlight(context, Icons.hide_image_outlined, l10n.premiumHeroHighlightWatermark)),
              const SizedBox(width: 8),
              Expanded(child: _heroHighlight(context, Icons.tune, l10n.premiumHeroHighlightGrading)),
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
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, height: 1.3)),
        ],
      ),
    );
  }

  /// 比較表セルの1マス分：「○」「×」は文字ではなくアイコンで視覚的に
  /// 分かりやすくし、それ以外（数値・「無制限」等の具体的な値）は
  /// これまで通りテキストで表示する。
  Widget _comparisonCell(BuildContext context, String value) {
    final scheme = Theme.of(context).colorScheme;
    if (value == '○') {
      return Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20);
    }
    if (value == '×') {
      return Icon(Icons.remove_circle_outline_rounded, color: scheme.outlineVariant, size: 20);
    }
    return Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12));
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

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: scheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
        children: [
          TableRow(
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
            children: [
              Padding(padding: const EdgeInsets.all(12), child: Text(l10n.premiumComparisonFeature, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kuramubon'))),
              Padding(padding: const EdgeInsets.all(12), child: Text(l10n.premiumComparisonFree, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kuramubon', color: scheme.onSurfaceVariant))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 14, color: scheme.primary),
                    const SizedBox(height: 2),
                    Text(l10n.premiumComparisonPremium,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kuramubon', color: scheme.primary)),
                  ],
                ),
              ),
            ],
          ),
          // 各行のプレミアム列だけ淡くテーマの差し色を敷き、無料/プレミアムの
          // 差が視線を動かさなくても分かるようにする。
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final zebra = i.isOdd ? scheme.surfaceContainerLowest : null;
            return TableRow(children: [
              Container(
                color: zebra,
                padding: const EdgeInsets.all(12),
                child: Text(item.$1, style: const TextStyle(fontSize: 12)),
              ),
              Container(
                color: zebra,
                padding: const EdgeInsets.all(12),
                child: Center(child: _comparisonCell(context, item.$2)),
              ),
              Container(
                color: Color.alphaBlend(scheme.primary.withValues(alpha: 0.05), zebra ?? scheme.surface),
                padding: const EdgeInsets.all(12),
                child: Center(child: _comparisonCell(context, item.$3)),
              ),
            ]);
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
    String? perMonthLabel,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final busy = premium.purchasePending;
    return Card(
      elevation: isRecommended ? 6 : 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
        child: Container(
          // おすすめプラン（年額）は淡いグラデーションで視覚的に目立たせる。
          decoration: isRecommended
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primaryContainer.withValues(alpha: 0.6), scheme.surface],
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: Colors.black),
                            const SizedBox(width: 3),
                            Text(l10n.premiumPlanRecommendedBadge,
                                style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kuramubon', fontSize: 15)),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(description,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.primary)),
                      ),
                    if (perMonthLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(perMonthLabel, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (originalPrice != null)
                      Text(originalPrice,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          )),
                    Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
