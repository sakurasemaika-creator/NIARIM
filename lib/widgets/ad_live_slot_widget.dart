import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_provider.dart';

/// Each visible placement owns its own BannerAd. Sharing one ad across
/// overlapping routes would mount the same AdWidget twice during navigation.
class AdMobLiveSlot extends StatefulWidget {
  const AdMobLiveSlot({super.key, required this.rectangle});

  final bool rectangle;

  @override
  State<AdMobLiveSlot> createState() => _AdMobLiveSlotState();
}

class _AdMobLiveSlotState extends State<AdMobLiveSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: widget.rectangle
          ? AdMobProvider.mediumRectangleAdUnitId
          : AdMobProvider.bannerAdUnitId,
      size: widget.rectangle ? AdSize.mediumRectangle : AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _loaded = true);
          }
        },
        onAdFailedToLoad: (failedAd, _) {
          if (identical(_ad, failedAd)) {
            _ad = null;
          }
          failedAd.dispose();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.rectangle ? 300.0 : 320.0;
    final height = widget.rectangle ? 250.0 : 50.0;
    final ad = _ad;
    return SizedBox(
      width: width,
      height: height,
      child: _loaded && ad != null ? AdWidget(ad: ad) : null,
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }
}
