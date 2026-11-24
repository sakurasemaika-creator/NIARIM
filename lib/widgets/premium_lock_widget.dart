import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/premium_service.dart';
import '../config/font_fallback.dart';
import 'keep_together_text.dart';

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
      onLockedTap: () => showPremiumBanner(context, feature: feature),
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
  required PremiumFeature feature,
  String? title,
  String? reason,
  String? continueLabel,
}) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (dialog) {
      final labels = AppLocalizations.of(dialog)!;
      final (featureTitle, featureBody) = premiumFeatureCopy(labels, feature);
      return _PremiumBannerDialog(
        title: title ?? featureTitle,
        body: reason ?? featureBody,
        continueLabel: continueLabel,
        onChoose: (value) => Navigator.pop(dialog, value),
      );
    },
  );
  if (!context.mounted) return false;
  if (choice == 'premium') context.push('/premium');
  if (choice == 'rewards') context.push('/rewards');
  return choice == 'continue';
}

/// Premium限定機能の名前と、使えるようになる条件の説明。
(String, String) premiumFeatureCopy(
  AppLocalizations labels,
  PremiumFeature feature,
) => switch (feature) {
  PremiumFeature.endCardEdit => (
    labels.premiumFeatureEndLogo,
    labels.premiumBannerEndCardBody,
  ),
  PremiumFeature.watermark => (
    labels.premiumFeatureWatermark,
    labels.premiumBannerWatermarkBody,
  ),
  PremiumFeature.toneCurve => (
    labels.premiumFeatureToneCurve,
    labels.premiumBannerToneCurveBody,
  ),
  PremiumFeature.levelAdjustment => (
    labels.premiumFeatureLevelCorrection,
    labels.premiumBannerLevelsBody,
  ),
  PremiumFeature.unlimitedDuration => (
    labels.premiumFeatureMaxDuration,
    labels.timelineDurationLimitBodyFree,
  ),
  PremiumFeature.customAutomation => (
    labels.customAutomationTitle,
    labels.premiumBannerAutomationBody,
  ),
};

/// Premium限定機能の画面を無料会員が開いたときに、画面の代わりに出す案内。
///
/// 薄くした画面に鍵を重ねるだけだと、何ができる機能か・どうすれば使えるかが
/// 分からず、押せない画面に見えた。機能の名前と使える条件を出し、プレミアムの
/// 紹介と特典（オパールでの期間限定の解放）へ進む道を並べる。
class PremiumFeatureIntro extends StatelessWidget {
  const PremiumFeatureIntro({
    super.key,
    required this.feature,
    required this.icon,
  });

  final PremiumFeature feature;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (title, body) = premiumFeatureCopy(labels, feature);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: colors.onPrimaryContainer),
                ),
                PositionedDirectional(
                  end: -4,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 14,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: localizedHeadingStyle(
                context,
                TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('premiumFeatureIntroPremium'),
            icon: const Icon(Icons.workspace_premium_outlined),
            onPressed: () => context.push('/premium'),
            label: Text(
              labels.premiumBannerMembershipDetails,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('premiumFeatureIntroRewards'),
            icon: const Icon(Icons.diamond_outlined),
            onPressed: () => context.push('/rewards'),
            label: Text(
              labels.premiumBannerBenefitDetails,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBannerDialog extends StatelessWidget {
  const _PremiumBannerDialog({
    required this.title,
    required this.body,
    this.continueLabel,
    required this.onChoose,
  });

  final String title;
  final String body;
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
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontFamily: headingFontFamilyFor(
                        Localizations.maybeLocaleOf(context),
                      ),
                      fontFamilyFallback: headingFontFallbackFor(
                        Localizations.maybeLocaleOf(context),
                      ),
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
                  Text(body),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.workspace_premium_outlined),
                    onPressed: () => onChoose('premium'),
                    label: messageText(
                      labels.premiumBannerMembershipDetails,
                      keepLastPhrase: true,
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
                          child: messageText(
                            labels.premiumBannerBenefitDetails,
                            keepLastPhrase: true,
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
