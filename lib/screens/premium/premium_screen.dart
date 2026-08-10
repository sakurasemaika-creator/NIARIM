import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/monetization_gate.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();

    return Scaffold(
      appBar: AppBar(title: const Text('NIARIM Premium'), actions: const [HelpButton(topic: 'プレミアム')]),
      body: desktopCentered(
        context,
        SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (premium.isLaunchCampaignActive) ...[
              _campaignBanner(context),
              const SizedBox(height: 24),
            ] else if (premium.hasPurchasedPremium) ...[
              const Card(
                color: Color(0xFF2E7D32),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Premium有効', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text('無料版 vs プレミアム', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _comparisonTable(context),
            if (premium.isLaunchCampaignActive) ...[
              const SizedBox(height: 8),
              Text('※ キャンペーン期間中は無料版でも上記プレミアム機能を全てご利用いただけます',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            if (!premium.isLaunchCampaignActive && !premium.hasPurchasedPremium) ...[
              const SizedBox(height: 24),
              const Text('プラン', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (!premium.storeAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'ストアに接続できません（実機・ストア審査環境以外では購入できません）',
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
                '年額プラン（おすすめ）',
                '¥5,500',
                '実質2か月分無料',
                true,
                premium,
                PremiumService.yearlyProductId,
              ),
              const SizedBox(height: 12),
              _planCard(
                context,
                '月額プラン',
                '¥550/月',
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
                              const SnackBar(content: Text('購入情報を復元しました（該当する購入がある場合）')),
                            );
                          }
                        }
                      : null,
                  child: const Text('購入を復元'),
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
  /// 「YYYY年M月D日H:MMまで」の形式でキャンペーン終了日時を表示する
  /// （西暦表記。以前は「～12月31日23:59まで」と年が無く、年をまたぐと
  /// 誤解を招く表記だった）。kMonetizationEnabledFromの1分前が実際の
  /// 終了時刻。
  String _campaignEndLabel() {
    final end = kMonetizationEnabledFrom.subtract(const Duration(minutes: 1));
    final hh = end.hour.toString().padLeft(2, '0');
    final mm = end.minute.toString().padLeft(2, '0');
    return '～${end.year}年${end.month}月${end.day}日$hh:$mmまで';
  }

  Widget _campaignBanner(BuildContext context) {
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
              const Expanded(
                child: Text('リリース記念！有料会員限定機能解放キャンペーン',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              '期間中は無料版でも全てのプレミアム機能（尺無制限・エンドロゴ編集・'
              'ウォーターマーク・トーンカーブ・レベル補正）を無料でご利用いただけます。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            // 年をまたいでも誤解が生じないよう西暦から表示する（例：
            // 「2026年12月31日23:59まで」）。kMonetizationEnabledFromの
            // 前日23:59が実際のキャンペーン終了日時のため、そこから算出する。
            Text(_campaignEndLabel(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _comparisonTable(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      ('アニメ制作・描画機能', '○', '○'), ('タイムライン', '○', '○'), ('動画書き出し', '○', '○'),
      ('最大尺', '1.5分', '無制限'), ('公式エンドロゴ', 'あり', '削除可'), ('ウォーターマーク', '×', '○'),
      ('トーンカーブ', '×', '○'), ('レベル補正', '×', '○'), ('広告', 'あり', 'なし'),
    ];

    return Table(
      border: TableBorder.all(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(8)),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
          children: const [
            Padding(padding: EdgeInsets.all(8), child: Text('機能', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(8), child: Text('無料', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(8), child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
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
                        child: const Text('おすすめ', style: TextStyle(fontSize: 10, color: Colors.black)),
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
