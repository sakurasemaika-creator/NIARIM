import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:provider/provider.dart';
import '../services/premium_service.dart';
import '../services/advertising_service.dart';
import 'ad_live_slot_widget.dart';
import '../l10n/app_localizations.dart';

/// SafeAreaの上端を除いた、横長広告専用領域の高さ。
const double kPersistentHorizontalAdMockExtent = 74;
const double _fixedBannerWidth = 320;
const double _minimumPageHeightWithBanner = 320;

/// Supported Google fixed-size units (dp), chosen conservatively by physical
/// form factor. Full-banner and leaderboard are tablet/DeX widths only.
/// Never scale the Google ad: keep its container at exactly the requested size.
Size? bannerSizeForViewport({
  required double availableWidth,
  required double availableHeight,
  required bool tabletLayout,
}) {
  final banner = tabletLayout && availableWidth >= 728
      ? const Size(728, 90)
      : tabletLayout && availableWidth >= 468
      ? const Size(468, 60)
      : availableWidth >= _fixedBannerWidth
      ? const Size(320, 50)
      : null;
  if (banner == null ||
      availableHeight < banner.height + 24 + _minimumPageHeightWithBanner) {
    return null;
  }
  return banner;
}

/// アプリ全体で上部バナーを1つ保持する共通フレーム。
///
/// MaterialApp.router.builderに配置することで、GoRouterの画面遷移時や
/// ダイアログ表示中にも同じ広告ウィジェットを保持する。
/// 既存のAdMockPageFrameで個別にラップされたルートは、
/// [_PersistentAdRootMarker]を検出すると二重の広告枠を作らない。
/// UI単体テストでAdMockPageFrameだけを構築した場合は、
/// 従来どおり単独のレイアウト検証ができる。
class AdPersistentRootFrame extends StatelessWidget {
  final Widget child;
  final bool allowBanner;

  const AdPersistentRootFrame({
    super.key,
    required this.child,
    this.allowBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    return AdMockPageFrame(
      allowBanner: allowBanner,
      child: _PersistentAdRootMarker(child: child),
    );
  }
}

class _PersistentAdRootMarker extends InheritedWidget {
  const _PersistentAdRootMarker({required super.child});

  @override
  bool updateShouldNotify(_PersistentAdRootMarker oldWidget) => false;
}

/// 横長広告を配置できる通常画面に専用領域を確保するフレーム。
///
/// 広告を各画面のAppBar・FAB・ツールバーへ直接置くと、画面ごとの実装漏れや
/// 操作ボタンとの近接が起きるため、ページ本体とは別の固定領域へ分離する。
/// 画面最上部のステータスバー／切り欠き領域は[SafeArea]で避け、ページ側
/// からは上部paddingを取り除いて二重の余白が生じないようにする。
/// 実機ではGoogleテスト広告を使い、widget testにはモックを残す。
class AdMockPageFrame extends StatelessWidget {
  final Widget child;
  final bool allowBanner;

  const AdMockPageFrame({
    super.key,
    required this.child,
    this.allowBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    // The persistent root owns the only banner for the entire app.
    // Individual GoRouter/MaterialPageRoute wrappers remain for isolated
    // tests and legacy call sites, but must not create duplicate ads.
    if (context.dependOnInheritedWidgetOfExactType<_PersistentAdRootMarker>() !=
        null) {
      return child;
    }
    final isPremium = context.watch<PremiumService>().isPremium;
    // Standalone widget tests omit AdvertisingService; production always
    // provides it, and canRequestAds gates real SDK requests.
    final ads = context.watch<AdvertisingService?>();
    final safe = MediaQuery.paddingOf(context);
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the fixed banner at its intended size and leave enough room
        // for the page to scroll and expose its controls in short windows.
        final bannerSize = bannerSizeForViewport(
          availableWidth: constraints.maxWidth - safe.horizontal,
          availableHeight: constraints.maxHeight - safe.vertical,
          tabletLayout: media.size.shortestSide >= 600,
        );
        // A keyboard, accessibility IME or other system input surface can
        // put an ad beside rapidly touched text/controls; suppress it.
        final showSlot =
            allowBanner &&
            !isPremium &&
            media.viewInsets.bottom <= 0 &&
            (ads == null || ads.shouldShowAds) &&
            bannerSize != null;
        return Column(
          children: [
            if (showSlot)
              _AdBannerMockSlot(live: ads != null, size: bannerSize!)
            else
              const SizedBox.shrink(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: showSlot,
                child: child,
              ),
            ),
          ],
        );
      },
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
  const _AdBannerMockSlot({required this.live, required this.size});

  final bool live;
  final Size size;

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
              height: size.height,
              child: Center(
                child: live
                    ? AdMobLiveSlot(
                        key: ValueKey('top-${size.width}x${size.height}'),
                        rectangle: false,
                        bannerSize: size,
                      )
                    : AdBannerMockWidget(bannerSize: size),
              ),
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
  const AdBannerMockWidget({
    super.key,
    this.bannerSize = const Size(320, 50),
  });

  final Size bannerSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: Key('fixed-banner-ad-mock'),
      width: bannerSize.width,
      height: bannerSize.height,
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
    final ads = context.watch<AdvertisingService?>();
    if (context.watch<PremiumService>().isPremium ||
        (ads != null && !ads.shouldShowAds)) {
      return const SizedBox.shrink();
    }
    // A 300x250 medium rectangle cannot be cropped or shrunk. On narrow
    // windows/DeX split screen, suppress the ad rather than letting it
    // overflow or cover the cancel/progress controls.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 || constraints.maxHeight < 250) {
          return const SizedBox.shrink();
        }
        return _mediumRectangleForAvailableSpace(context, ads);
      },
    );
  }

  Widget _mediumRectangleForAvailableSpace(
      BuildContext context, AdvertisingService? ads) {
    // A progress AlertDialog is an alert/behavior-only surface. Google's
    // publisher-content rule prohibits live ads on such surfaces. Keep the
    // 300x250 placement available in debug with official TEST IDs for layout
    // review; fail closed in release even after production IDs are added.
    if (ads != null) {
      if (kReleaseMode) return const SizedBox.shrink();
      return const Center(child: AdMobLiveSlot(rectangle: true));
    }
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
