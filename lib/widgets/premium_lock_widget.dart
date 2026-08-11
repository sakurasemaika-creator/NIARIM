import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/premium_service.dart';

/// Premium限定機能の共通ロックウィジェット。
/// 無料会員には🔒アイコン付きで表示し、タップで共通Premiumバナーを表示する。
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
          const Positioned(right: 4, top: 4, child: Icon(Icons.lock, size: 16, color: Colors.amber)),
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
        // ctx ではなく呼び出し元の context を使う（ダイアログ close 後も有効）
        context.go('/premium');
      },
    ),
  );
}

class _PremiumBannerDialog extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onRegister;

  const _PremiumBannerDialog({
    required this.onClose,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium紹介バナー画像（タップでPremium登録画面へ）
          GestureDetector(
            onTap: onRegister,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.asset(
                'assets/images/premium_banner.webp',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[850],
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 48),
                        SizedBox(height: 8),
                        Text('NIARIM Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('premium_banner.webp', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ボタン行
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClose,
                    child: Text(l10n.commonClose),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onRegister,
                    child: Text(l10n.premiumBannerRegisterButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
