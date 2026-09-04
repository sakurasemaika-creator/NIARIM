import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/advertising_service.dart';

/// 無料版の固定バナー広告。
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
    final banner = ad == null
        ? Container(
            height: 50,
            width: double.infinity,
            color: ThemeService.activeColorScheme.onSurfaceVariant,
            child: Center(
              child: Text(
                l10n.progressDialogAdLoading,
                style: TextStyle(
                  color: ThemeService.activeColorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          )
        : Container(
            width: double.infinity,
            color: ThemeService.activeColorScheme.onSurfaceVariant,
            alignment: Alignment.center,
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          );

    // Androidの3ボタン／ジェスチャーナビゲーションや画面切り欠きの領域へ
    // 広告が重なると、広告が隠れるだけでなく誤タップの原因にもなる。
    // 配置方向に応じたSafeAreaを共通部品側で必ず確保する。
    return SafeArea(
      top: widget.position == AdPosition.top,
      bottom: widget.position == AdPosition.bottom,
      child: banner,
    );
  }
}
