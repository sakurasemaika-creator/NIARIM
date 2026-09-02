import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 広告バナー設置場所の検討用モック（試験配置）。
/// 実際のAdMob広告（AdvertisingService/AdBannerWidget）とは無関係で、
/// SDKの読み込みも課金も発生しない、見た目とサイズだけを模した
/// プレースホルダー。実際のAdSize.banner（320×50dp、非アダプティブ固定
/// サイズ）と同じ比率で表示し、実配置時の窮屈さ・干渉を事前に見た目で
/// 判断できるようにする。設置場所を正式決定したら、このモックは
/// 実際のAdBannerWidget（またはネイティブ広告等）へ置き換えること。
class AdBannerMockWidget extends StatelessWidget {
  const AdBannerMockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 320,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border.all(color: Colors.amber, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        l10n.adMockPlaceholderLabel,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}
