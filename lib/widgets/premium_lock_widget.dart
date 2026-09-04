import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/premium_service.dart';
import '../config/font_fallback.dart';

/// Premium限定機能の共通ロックウィジェット。
/// 無料会員にはlockアイコン付きで表示し、タップで共通Premiumバナーを表示する。
class PremiumLockWidget extends StatelessWidget {
  final Widget child;
  final PremiumFeature feature;

  const PremiumLockWidget({
    super.key,
    required this.child,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();
    if (premium.isFeatureAvailable(feature)) return child;

    return GestureDetector(
      onTap: () => showPremiumBanner(context),
      child: Stack(
        children: [
          Opacity(opacity: 0.5, child: child),
          Positioned(
            right: 4,
            top: 4,
            child: Icon(
              Icons.lock,
              size: 16,
              color: ThemeService.activeColorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium限定機能タップ時に表示する共通バナーダイアログ。
/// アプリ全体で統一して使用する。個別説明ダイアログは表示しない。
void showPremiumBanner(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => _PremiumBannerDialog(
      onClose: () => Navigator.pop(ctx),
      onRegister: () {
        Navigator.pop(ctx);
        // Premium画面（実際の購入処理はPremiumService.buyで行う）へ遷移。
        // ctx ではなく呼び出し元の context を使う（ダイアログ close 後も有効）。
        // go()だとナビゲーション履歴が丸ごと置き換わり、キャンバス編集中
        // など画面の奥深くから開いた場合に戻る手段が無くなってしまう
        // （home_drawer.dart側の通常導線はpush()）ため、こちらもpush()に
        // 揃える。
        context.push('/premium');
      },
    ),
  );
}

class _PremiumBannerDialog extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onRegister;

  const _PremiumBannerDialog({required this.onClose, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium紹介バナー画像（タップでPremium登録画面へ）
              GestureDetector(
                onTap: onRegister,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/images/premium_banner.webp',
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: ThemeService.activeColorScheme.onSurfaceVariant,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: ThemeService.activeColorScheme.tertiary,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'NIARIM Premium',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'premium_banner.webp',
                              style: TextStyle(
                                fontSize: 11,
                                color: ThemeService
                                    .activeColorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Primary action only; closing is handled by the compact top-right X.
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRegister,
                    child: Text(l10n.premiumBannerRegisterButton),
                  ),
                ),
              ),
            ],
          ),
          // このダイアログの×は**バナー画像の上**に重なる。素のIconButtonだと
          // 画像の絵柄しだいでほとんど見えなくなる（実際に、画像が読めない
          // ときのプレースホルダー上でほぼ判別できない状態だった）。
          // 画像に左右されないよう、surface/onSurfaceの組み合わせの丸い
          // 下地を必ず敷く。
          Positioned(
            right: 4,
            top: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeService.activeColorScheme.surface.withValues(
                  alpha: 0.85,
                ),
              ),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: ThemeService.activeColorScheme.onSurface,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
