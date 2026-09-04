import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// SafeAreaの上端を除いた、横長広告専用領域の高さ。
const double kPersistentHorizontalAdMockExtent = 74;

/// すべての通常画面に横長広告の専用領域を確保するフレーム。
///
/// 広告を各画面のAppBar・FAB・ツールバーへ直接置くと、画面ごとの実装漏れや
/// 操作ボタンとの近接が起きるため、ページ本体とは別の固定領域へ分離する。
/// 画面最上部のステータスバー／切り欠き領域は[SafeArea]で避け、ページ側
/// からは上部paddingを取り除いて二重の余白が生じないようにする。
/// 実広告へ切り替える際は[_AdBannerMockSlot]の中身だけを差し替えればよい。
class AdMockPageFrame extends StatelessWidget {
  final Widget child;

  const AdMockPageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _AdBannerMockSlot(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// [MaterialPageRoute]で開く、ルーター外の画面にも広告フレームを適用する。
MaterialPageRoute<T> adMockMaterialPageRoute<T>({
  required WidgetBuilder builder,
}) {
  return MaterialPageRoute<T>(
    builder: (context) => AdMockPageFrame(child: builder(context)),
  );
}

class _AdBannerMockSlot extends StatelessWidget {
  const _AdBannerMockSlot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            // ステータスバーとはSafeAreaに加えて8dp、直下のAppBarや
            // 戻るボタンとは16dp離し、広告の誤タップを防ぐ。
            // 320dp幅の端末でもAdSize.bannerの実寸を確保できるよう、
            // 左右にはpaddingを置かない。実広告で利用可能幅が320dp未満に
            // なる場合は縮小せず、適応型バナーへ切り替えること。
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            child: SizedBox(
              key: const Key('persistent-horizontal-ad-mock'),
              width: double.infinity,
              height: 50,
              child: const Center(child: AdBannerMockWidget()),
            ),
          ),
        ),
      ),
    );
  }
}

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
      key: Key('fixed-banner-ad-mock'),
      width: 320,
      height: 50,
      decoration: BoxDecoration(
        color: ThemeService.activeColorScheme.onSurfaceVariant,
        border: Border.all(
          color: ThemeService.activeColorScheme.tertiary,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        l10n.adMockPlaceholderLabel,
        style: TextStyle(
          color: ThemeService.activeColorScheme.onSurface.withValues(
            alpha: 0.70,
          ),
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 書き出し・フィルター等の処理中画面に置く中型レクタングル広告モック。
/// 実際のAdSize.mediumRectangleと同じ300×250dpで、縮小せずに表示する。
class AdMediumRectangleMockWidget extends StatelessWidget {
  const AdMediumRectangleMockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Container(
        key: Key('medium-rectangle-ad-mock'),
        width: 300,
        height: 250,
        decoration: BoxDecoration(
          color: ThemeService.activeColorScheme.onSurfaceVariant,
          border: Border.all(
            color: ThemeService.activeColorScheme.tertiary,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          l10n.adMediumRectangleMockPlaceholderLabel,
          style: TextStyle(
            color: ThemeService.activeColorScheme.onSurface.withValues(
              alpha: 0.70,
            ),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
