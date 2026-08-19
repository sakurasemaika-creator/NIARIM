import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../screens/tips/tips_screen.dart' show allTipEntries;
import '../services/advertising_service.dart';
import '../services/premium_service.dart';

/// 処理中ダイアログ（仕様書13：フィルター適用／動画書き出し／GIF生成／
/// 透過WebM生成／大量処理実行時に表示、プログレスバー下部に正方形広告）。
/// プレミアム会員は広告が表示されない分のスペースへ、10秒おきにランダムで
/// Tipsを表示する（無料会員は正方形広告でスペースが取られるため対象外）。
class ProgressDialog extends StatefulWidget {
  final String title;
  final double progress;
  final String? subtitle;
  // キャンセルボタン（仕様書06・13：誤タップ対応）。nullの場合は非表示
  // （キャンセルに対応していない処理からの呼び出しとの後方互換のため）。
  final VoidCallback? onCancel;
  // キャンセル要求後、実際に中断できないフェーズ（例：最終エンコード中）
  // であることをユーザーに伝えるための注記。
  final String? cancelHint;

  const ProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    this.subtitle,
    this.onCancel,
    this.cancelHint,
  });

  @override
  State<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<ProgressDialog> {
  Timer? _tipTimer;
  // Tips一覧はl10nに依存するがダイアログ表示中に言語が変わることはないため、
  // 毎buildで再構築せず一度だけ計算してキャッシュする（進捗更新のたびに
  // 高頻度で呼ばれるbuild()の負荷を抑える）。
  List<(String, String)>? _tips;
  int? _tipIndex;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdvertisingService>().showSquareAd();
      _startTipRotationIfNeeded();
    });
  }

  void _startTipRotationIfNeeded() {
    if (!mounted) return;
    if (!context.read<PremiumService>().isPremium) return;
    final l10n = AppLocalizations.of(context)!;
    final tips = allTipEntries(l10n);
    if (tips.isEmpty) return;
    setState(() {
      _tips = tips;
      _tipIndex = _random.nextInt(tips.length);
    });
    _tipTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = _random.nextInt(tips.length));
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adService = context.watch<AdvertisingService>();
    final ad = adService.squareAd;
    final tips = _tips;
    final tipIndex = _tipIndex;
    final tip = (tips != null && tipIndex != null && tipIndex < tips.length) ? tips[tipIndex] : null;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: widget.progress),
          const SizedBox(height: 8),
          Text('${(widget.progress * 100).round()}%'),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          // プレミアム会員限定：広告の代わりにTipsを表示するスペースを使う。
          if (tip != null) ...[
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(tip.$1),
                width: 250,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(l10n.progressDialogTipLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(tip.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(tip.$2, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ] else if (adService.shouldShowAds) ...[
            const SizedBox(height: 16),
            if (ad == null)
              Container(
                width: 250,
                height: 250,
                color: Colors.grey[800],
                child: Center(
                  child: Text(l10n.progressDialogAdLoading, style: const TextStyle(color: Colors.grey)),
                ),
              )
            else
              SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
          ],
          if (widget.cancelHint != null) ...[
            const SizedBox(height: 8),
            Text(widget.cancelHint!,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
      actions: widget.onCancel == null
          ? null
          : [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(l10n.commonCancel),
              ),
            ],
    );
  }
}
