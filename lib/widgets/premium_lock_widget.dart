import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/premium_service.dart';
import '../config/font_fallback.dart';

/// Premium限定機能の共通ロックウィジェット。
///
/// 無料会員にも項目自体は表示したまま南京錠アイコンを重ねる。ロック中は
/// [child] 自身の操作は遮断する一方、項目全体のタップは受け取り、共通の
/// Premium紹介バナーを表示する。有料会員では元の[child]をそのまま返す。
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
    return PremiumLockState(
      locked: !premium.isFeatureAvailable(feature),
      onLockedTap: () => showPremiumBanner(context),
      child: child,
    );
  }
}

/// Premiumロック状態の見た目とタップ時挙動を一元化する低レベル部品。
///
/// ロック中も項目は表示し、南京錠を表示する。[child]へのポインター入力は
/// 遮断して本来のPremium操作を実行させず、代わりに外側のタップ領域から
/// [onLockedTap]を1回だけ呼ぶ。
class PremiumLockState extends StatelessWidget {
  final Widget child;
  final bool locked;
  final VoidCallback? onLockedTap;

  const PremiumLockState({
    super.key,
    required this.child,
    required this.locked,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return Semantics(
      enabled: true,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onLockedTap,
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: true,
              child: Opacity(opacity: 0.5, child: child),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.lock,
                  size: 16,
                  color: ThemeService.activeColorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared offer for locked features. A limited export is an explicit choice.
Future<bool> showPremiumBanner(
  BuildContext context, {
  String? reason,
  String? continueLabel,
}) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (dialog) => _PremiumBannerDialog(
      reason: reason,
      continueLabel: continueLabel,
      onChoose: (value) => Navigator.pop(dialog, value),
    ),
  );
  if (!context.mounted) return false;
  if (choice == 'premium') context.push('/premium');
  if (choice == 'rewards') context.push('/rewards');
  return choice == 'continue';
}

class _PremiumBannerDialog extends StatelessWidget {
  const _PremiumBannerDialog({
    this.reason,
    this.continueLabel,
    required this.onChoose,
  });

  final String? reason;
  final String? continueLabel;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 460),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: colors.primaryContainer,
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: colors.onPrimaryContainer,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NIARIM Premium',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => onChoose('close'),
                        icon: Icon(
                          Icons.close,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels.premiumBannerHeadline,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(reason ?? labels.premiumBannerBenefits),
                  const SizedBox(height: 14),
                  Text(
                    labels.premiumPackHalfPrice,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    labels.premiumPackPriceBasis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.workspace_premium_outlined),
                    onPressed: () => onChoose('premium'),
                    label: Text(
                      labels.premiumBannerMembershipDetails,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.diamond_outlined),
                    onPressed: () => onChoose('rewards'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            labels.premiumBannerBenefitDetails,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Badge(
                          label: Text(labels.premiumComparisonFree),
                          backgroundColor: colors.secondaryContainer,
                          textColor: colors.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        onChoose(continueLabel == null ? 'close' : 'continue'),
                    child: Text(continueLabel ?? labels.commonClose),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
