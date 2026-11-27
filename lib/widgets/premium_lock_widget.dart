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
  const PremiumFeatureIntro({super.key, required this.feature});

  final PremiumFeature feature;

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
          // 機能でできあがるものが一目で分かるときだけ見本を出す（透かしは
          // 描いたコマの隅に名前が重なった見本）。ほかの機能に飾りの大きな
          // 印は置かない（何を表すか読み取れず、文と同じことしか言わない）。
          if (feature == PremiumFeature.watermark) ...[
            const Center(child: WatermarkFrameSample()),
            const SizedBox(height: 20),
          ],
          Semantics(
            header: true,
            child: messageText(
              title,
              keepLineStarts: true,
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
          // 長音符・小さいかなで行を始めない（「ウォータ / ーマーク」と折れた）。
          messageText(
            body,
            keepLineStarts: true,
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
          // 主な操作（塗り）は1つだけにし、もう1つの道は文字のボタン。
          TextButton.icon(
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

/// 透かしの見本：描いたコマ（用紙の色に墨の線）の右下に、作者の名前の
/// 透かしが重なっている（それだけが見える。飾りの番号・跡は描かない）。
class WatermarkFrameSample extends StatelessWidget {
  const WatermarkFrameSample({super.key, this.width = 240});

  /// 見本の幅（高さは幅の5分の3）。
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width * 0.625,
        child: CustomPaint(
          painter: _WatermarkFramePainter(
            paper: theme.cardTheme.color ?? scheme.surface,
            rule:
                theme.dividerTheme.color ??
                scheme.outlineVariant.withValues(alpha: .6),
            ink: scheme.onSurface,
            textDirection: Directionality.of(context),
            fontFamily: localizedHeadingStyle(
              context,
              const TextStyle(),
            ).fontFamily,
          ),
        ),
      ),
    );
  }
}

class _WatermarkFramePainter extends CustomPainter {
  const _WatermarkFramePainter({
    required this.paper,
    required this.rule,
    required this.ink,
    required this.textDirection,
    required this.fontFamily,
  });

  final Color paper;
  final Color rule;
  final Color ink;
  final TextDirection textDirection;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(frame, Paint()..color = paper);
    canvas.drawRRect(
      frame.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = rule,
    );
    // 手で描いたような線：丘と小さな玉（描いた絵）。透かしの見本なので、
    // 絵の側には印・番号を足さない（何の図か読み取りにくくなる）。
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.08, h * 0.74)
        ..cubicTo(w * 0.3, h * 0.56, w * 0.5, h * 0.8, w * 0.92, h * 0.6),
      pen,
    );
    canvas.drawCircle(Offset(w * 0.42, h * 0.38), h * 0.11, pen);
    // 透かし：右下に作者の名前を、絵の邪魔をしない薄さで重ねる。
    final watermark = TextPainter(
      text: TextSpan(
        text: '@artist',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: ink.withValues(alpha: 0.42),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    watermark.paint(
      canvas,
      Offset(w - watermark.width - 12, h - watermark.height - 10),
    );
    watermark.dispose();
  }

  @override
  bool shouldRepaint(_WatermarkFramePainter old) =>
      old.paper != paper ||
      old.rule != rule ||
      old.ink != ink ||
      old.textDirection != textDirection ||
      old.fontFamily != fontFamily;
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
                  // 日本語の語も途中で折らない（「自分のウォーターマー / クを…」と
                  // 折れた）。
                  keepTogetherWords(
                    title,
                    keep: const [],
                    japaneseWords:
                        Localizations.maybeLocaleOf(context)?.languageCode ==
                        'ja',
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
