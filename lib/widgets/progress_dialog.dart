import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/advertising_service.dart';

/// 処理中ダイアログ（仕様書13：フィルター適用／動画書き出し／GIF生成／
/// 透過WebM生成／大量処理実行時に表示、プログレスバー下部に正方形広告）。
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdvertisingService>().showSquareAd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adService = context.watch<AdvertisingService>();
    final ad = adService.squareAd;

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
          if (adService.shouldShowAds) ...[
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
