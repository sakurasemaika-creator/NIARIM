import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/advertising_service.dart';

/// 無料版の固定バナー広告（仕様書13）。
/// 呼び出し側で`if (adService.shouldShowAds) const AdBannerWidget()`のように
/// プレミアム時はwidgetツリーから完全に除外すること。
class AdBannerWidget extends StatefulWidget {
  final AdPosition position;
  const AdBannerWidget({super.key, this.position = AdPosition.bottom});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdvertisingService>().showBanner(widget.position);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ad = context.watch<AdvertisingService>().bannerAd;
    if (ad == null) {
      return Container(
        height: 50,
        width: double.infinity,
        color: Colors.grey[900],
        child: Center(
          child: Text(l10n.progressDialogAdLoading, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: Colors.grey[900],
      alignment: Alignment.center,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
