import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/menu_card.dart';
import '../../widgets/icon_notice.dart';
import '../../widgets/legal_consent.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../utils/line_break.dart';

/// プレミアム画面。ユーザー作品そのものを除くUI色はColorSchemeへ集約する。
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _planHeading = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _planHeading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = context.watch<PremiumService>();
    final scheme = Theme.of(context).colorScheme;

    final monthlyPrice = premium.storeAvailable
        ? premium.products
              .where((product) => product.id == PremiumService.monthlyProductId)
              .firstOrNull
              ?.price
        : null;
    final yearlyPrice = premium.storeAvailable
        ? premium.products
              .where((product) => product.id == PremiumService.yearlyProductId)
              .firstOrNull
              ?.price
        : null;

    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.premiumScreenTitle),
        actions: const [HelpButton(topic: 'プレミアム')],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (premium.hasPurchasedPremium) ...[
                Card(
                  color: scheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: scheme.onPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.premiumActiveLabel,
                                style: localizedHeadingStyle(
                                  context,
                                  TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (premium.purchaseDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.premiumRegisteredDateLabel(
                              _formatDate(l10n, premium.purchaseDate!),
                            ),
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (premium.nextRenewalDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.premiumNextRenewalDateLabel(
                              _formatDate(l10n, premium.nextRenewalDate!),
                            ),
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (!premium.hasPurchasedPremium) ...[
                _heroSection(context, l10n),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('premiumSeePlansButton'),
                  onPressed: () {
                    final target = _planHeading.context;
                    if (target != null) {
                      _planHeading.requestFocus();
                      Scrollable.ensureVisible(
                        target,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(l10n.rewardNavigationPremiumPlans),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                l10n.premiumVsTitle,
                style: localizedHeadingStyle(
                  context,
                  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _comparisonTable(context, l10n),
              const SizedBox(height: 8),
              Text(
                l10n.premiumDurationExportNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!premium.hasPurchasedPremium) ...[
                const SizedBox(height: 24),
                Focus(
                  focusNode: _planHeading,
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.premiumPlanSectionTitle,
                      style: localizedHeadingStyle(
                        context,
                        TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (yearlyPrice == null || monthlyPrice == null) ...[
                  Text(
                    l10n.premiumStoreUnavailable,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: premium.refreshStoreProducts,
                      child: Text(l10n.communityRetry),
                    ),
                  ),
                ],
                if (premium.purchasePending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.premiumCheckoutPending)),
                        ],
                      ),
                    ),
                  ),
                if (premium.purchaseError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IconNotice(
                      _purchaseErrorText(l10n, premium.purchaseError!),
                      fontSize: 12,
                      liveRegion: true,
                    ),
                  ),
                _planCard(
                  context,
                  l10n,
                  l10n.premiumYearlyTitle,
                  yearlyPrice,
                  true,
                  premium,
                  PremiumService.yearlyProductId,
                ),
                const SizedBox(height: 12),
                _planCard(
                  context,
                  l10n,
                  l10n.premiumMonthlyTitle,
                  monthlyPrice,
                  false,
                  premium,
                  PremiumService.monthlyProductId,
                ),
                const SizedBox(height: 12),
                messageText(
                  l10n.premiumAutoRenewNote,
                  key: const Key('premiumAutoRenewNote'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed:
                        premium.storeAvailable && !premium.purchasePending
                        ? () async {
                            var message = l10n.premiumRestoredSnackbar;
                            try {
                              await premium.restorePurchases();
                            } catch (_) {
                              message = l10n.premiumRestoreFailed;
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          }
                        : null,
                    child: Text(l10n.premiumRestorePurchases),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 読点（、，,）の後ろで区切った句。[KeepTogetherText]へ渡すと、句の
  /// 途中では行を変えない（1行に入らない句だけは字の間で折る）。
  static List<String> _clauses(String text) => [
    for (final m in RegExp(r'[^、，,]+[、，,]?').allMatches(text))
      if (m[0]!.trim().length > 1) m[0]!,
  ];

  String _purchaseErrorText(
    AppLocalizations l10n,
    String error,
  ) => switch (error) {
    PremiumService.checkoutStartFailed => l10n.premiumCheckoutStartFailed,
    PremiumService.signInRequired => l10n.premiumErrorSignInRequired,
    PremiumService.storeUnavailable => l10n.premiumErrorStoreUnavailable,
    PremiumService.productUnavailable => l10n.premiumErrorProductUnavailable,
    PremiumService.verifierUnavailable => l10n.premiumErrorVerifierUnavailable,
    PremiumService.purchaseNotConfirmed => l10n.premiumErrorNotConfirmed,
    PremiumService.noValidPurchase => l10n.premiumErrorNoValidPurchase,
    PremiumService.verificationFailed => l10n.premiumErrorVerificationFailed,
    _ => l10n.premiumErrorPurchaseFailed,
  };

  // The date in the language's own order (ja 2026/11/23, en 11/23/2026,
  // fr 23/11/2026, ko 2026. 11. 23.).
  String _formatDate(AppLocalizations l10n, DateTime d) =>
      DateFormat.yMd(l10n.localeName).format(d);

  Widget _heroSection(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      // 平らな淡い面と細い縁で区切る（ぼかした影とグラデーションは、
      // 中の文より面の飾りが先に目に入った）。
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.alphaBlend(
          scheme.primaryContainer.withValues(alpha: 0.55),
          scheme.surface,
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final badge = ExcludeSemantics(
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: const Icon(Icons.workspace_premium_rounded, size: 25),
                ),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Semantics(
                    header: true,
                    // 日本語・中国語は読点の後でだけ行を変える（字の間で
                    // 折ると「もっと自 / 由な制作を」と語の途中で切れた）。
                    child: KeepTogetherText(
                      l10n.premiumHeroTitle,
                      keep: _clauses(l10n.premiumHeroTitle),
                      style: localizedHeadingStyle(
                        context,
                        TextStyle(
                          fontSize: 20,
                          height: 1.24,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l10n.premiumHeroSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              final textScale = MediaQuery.textScalerOf(context).scale(20) / 20;
              if ((constraints.maxWidth - 58) / textScale < 190) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [badge, copy],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  badge,
                  Expanded(child: copy),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth /
                      MediaQuery.textScalerOf(context).scale(1) <
                  365;
              final highlights = [
                (Icons.schedule, l10n.premiumHeroHighlightDuration),
                (Icons.hide_image_outlined, l10n.premiumHeroHighlightWatermark),
                (Icons.tune, l10n.premiumHeroHighlightGrading),
              ];
              final tiles = [
                for (final (icon, label) in highlights)
                  _heroHighlight(context, icon, label, stacked: stacked),
              ];
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 6,
                      children: tiles,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        for (final tile in tiles) Expanded(child: tile),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _heroHighlight(
    BuildContext context,
    IconData icon,
    String label, {
    required bool stacked,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Flex(
        direction: stacked ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(icon, size: 20, color: AccentTextTheme.of(context)),
          Flexible(
            flex: stacked ? 1 : 0,
            child: Text(
              stacked ? label.replaceAll('\n', ' ') : label,
              textAlign: stacked ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCell(
    BuildContext context,
    String value, {
    bool premiumColumn = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = premiumColumn
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    if (value == '○') {
      return Icon(
        Icons.check_circle_rounded,
        color: premiumColumn
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        size: 20,
      );
    }
    if (value == '×') {
      return Icon(
        Icons.remove_circle_outline_rounded,
        color: premiumColumn ? scheme.onPrimaryContainer : scheme.outline,
        size: 20,
      );
    }
    return Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: foreground),
    );
  }

  /// 狭い幅・大きな文字の比較の一覧で、列の名前と値を1つの札にしたもの。
  Widget _comparisonPill(
    BuildContext context,
    String column,
    String value, {
    bool premiumColumn = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 10, 5),
      decoration: BoxDecoration(
        color: premiumColumn
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Flexible(
            child: Text(
              column,
              style: localizedHeadingStyle(
                context,
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: premiumColumn
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Flexible(
            child: _comparisonCell(
              context,
              value,
              premiumColumn: premiumColumn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonTable(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (l10n.premiumFeatureDrawing, '○', '○'),
      (l10n.premiumFeatureTimeline, '○', '○'),
      (l10n.premiumFeatureExport, '○', '○'),
      (
        l10n.premiumFeatureMaxDuration,
        l10n.premiumValueDuration90Sec,
        l10n.premiumValueDuration2Hours,
      ),
      (
        l10n.premiumFeatureEndLogo,
        l10n.premiumValueYes,
        l10n.premiumValueRemovable,
      ),
      (l10n.premiumFeatureWatermark, '×', '○'),
      (l10n.premiumFeatureToneCurve, '×', '○'),
      (l10n.premiumFeatureLevelCorrection, '×', '○'),
      (l10n.helpCustomAutomationTitle, '×', '○'),
      (l10n.premiumFeatureAds, l10n.premiumValueYes, l10n.premiumValueNo),
      (
        l10n.premiumFeatureCommunityUpload,
        l10n.premiumValueUploadFree,
        l10n.premiumValueUploadPremium,
      ),
    ];
    String spoken(String value) => switch (value) {
      '○' => l10n.premiumValueYes,
      '×' => l10n.premiumValueNo,
      _ => value,
    };
    String rowLabel((String, String, String) item) =>
        '${item.$1}\n${l10n.premiumComparisonFree} ${spoken(item.$2)}\n${l10n.premiumComparisonPremium} ${spoken(item.$3)}';
    final premiumBg = scheme.primaryContainer;
    Widget cardList() {
      return MenuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) ...[
              if (item != items.first)
                Divider(height: 1, color: scheme.outlineVariant),
              Semantics(
                container: true,
                label: rowLabel(item),
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  // 表と同じ記号と色で、無料とプレミアムの値を並べる
                  // （文字だけの「無料 あり」「プレミアム あり」は、どちらが
                  // 有利かが一目で分からなかった）。
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      messageText(
                        item.$1,
                        keepLineStarts: true,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _comparisonPill(
                            context,
                            l10n.premiumComparisonFree,
                            item.$2,
                          ),
                          _comparisonPill(
                            context,
                            l10n.premiumComparisonPremium,
                            item.$3,
                            premiumColumn: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (MediaQuery.textScalerOf(context).scale(14) >= 21) return cardList();
    return LayoutBuilder(
      builder: (context, constraints) {
        // 表の語が列に入らない幅（320pxの仏語など）では、見出し・機能名を
        // 語の途中で折る代わりに、項目ごとの一覧で出す。
        // 表は外側のカードの余白の内側に並ぶ。
        final cardMargin =
            (Theme.of(context).cardTheme.margin ?? const EdgeInsets.all(4))
                .horizontal;
        if (!_comparisonTableFits(
          context,
          l10n,
          items,
          constraints.maxWidth - cardMargin,
        )) {
          return cardList();
        }
        return MenuCard(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Table(
            // セルの高さは既定（top）だと**各セルが自分の中身ぶんしか高さを
            // 持たない**ため、機能名が2行に折り返した行だけ、他の列の背景色が
            // 行の下端まで届かず白い帯が残る（実際に「アニメ制作・描画機能」の
            // 行で発生していた）。intrinsicHeightにすると全セルが行内で最も
            // 高いセルと同じ高さになり、背景が必ず行いっぱいに塗られる。
            // fillは「全セルがfillだと行の高さが0になる」ため使わないこと。
            defaultVerticalAlignment:
                TableCellVerticalAlignment.intrinsicHeight,
            border: TableBorder(
              horizontalInside: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            // 値の列（記号・「90秒」「2時間」等の短い語）は中身の幅だけ取り、
            // 残りを機能名へ回す。3列を同じ割合で分けていた頃は、機能名が
            // 7字ほどで折れ「ウォータ / ーマーク」と長音で始まる行ができた。
            columnWidths: const {
              0: FlexColumnWidth(),
              1: MinColumnWidth(
                IntrinsicColumnWidth(),
                FractionColumnWidth(0.3),
              ),
              2: MinColumnWidth(
                IntrinsicColumnWidth(),
                FractionColumnWidth(0.34),
              ),
            },
            children: [
              TableRow(
                children: [
                  Container(
                    color: scheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.premiumComparisonFeature,
                      style: localizedHeadingStyle(
                        context,
                        TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: scheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.premiumComparisonFree,
                      textAlign: TextAlign.center,
                      style: localizedHeadingStyle(
                        context,
                        TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: premiumBg,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.premiumComparisonPremium,
                          textAlign: TextAlign.center,
                          style: localizedHeadingStyle(
                            context,
                            TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ...items.asMap().entries.map((entry) {
                final zebra = entry.key.isOdd
                    ? scheme.surfaceContainerLowest
                    : scheme.surface;
                final item = entry.value;
                return TableRow(
                  children: [
                    Container(
                      color: zebra,
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.centerLeft,
                      // 長音符・小さいかな・閉じ括弧で行を始めない。
                      child: KeepTogetherText(
                        item.$1,
                        keep: lineStartKeepParts(item.$1),
                        semanticsLabel: rowLabel(item),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      color: zebra,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: ExcludeSemantics(
                        child: Center(child: _comparisonCell(context, item.$2)),
                      ),
                    ),
                    Container(
                      color: premiumBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: ExcludeSemantics(
                        child: Center(
                          child: _comparisonCell(
                            context,
                            item.$3,
                            premiumColumn: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// 比較表を語の途中で折らずに組めるか。値の列は中身の幅（上限は表の幅の
  /// 3割前後）、機能名の列は残りの幅として、見出しと各行の折れない部分
  /// （欧文の語、つないだ数と単位）がそれぞれの列に入るかを測る。
  bool _comparisonTableFits(
    BuildContext context,
    AppLocalizations l10n,
    List<(String, String, String)> items,
    double width,
  ) {
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final heading = base.merge(
      localizedHeadingStyle(
        context,
        const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    final body = base.merge(const TextStyle(fontSize: 14, height: 1.45));
    final painters = <TextPainter>[];
    TextPainter laid(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      painters.add(painter);
      return painter;
    }

    double widest(String text, TextStyle style) => laid(text, style).width;
    double unbreakable(String text, TextStyle style) {
      final painter = laid(text, style);
      return widestUnbreakableWidth(
        painter,
        reported: painter.minIntrinsicWidth,
      );
    }

    bool isMark(String v) => v == '○' || v == '×';
    try {
      const valuePadding = 24.0;
      // 見出し（1語）と日本語・中国語の短い値（「2時間」「削除可」）は
      // 字の間でも折らない1つの語として扱う。
      final cjk = RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]');
      double word(String text, TextStyle style) =>
          cjk.hasMatch(text) ? widest(text, style) : unbreakable(text, style);
      const featurePadding = 24.0;
      double column(String header, Iterable<String> values) => [
        widest(header, heading),
        for (final v in values)
          if (!isMark(v)) widest(v, body),
        20.0,
      ].reduce((a, b) => a > b ? a : b);
      final freeCap = width * 0.3;
      final premiumCap = width * 0.34;
      final free = column(l10n.premiumComparisonFree, items.map((i) => i.$2));
      final premium = column(
        l10n.premiumComparisonPremium,
        items.map((i) => i.$3),
      );
      final freeWidth = (free + valuePadding).clamp(0.0, freeCap);
      final premiumWidth = (premium + valuePadding).clamp(0.0, premiumCap);
      if (widest(l10n.premiumComparisonFree, heading) + valuePadding >
              freeCap ||
          widest(l10n.premiumComparisonPremium, heading) + valuePadding >
              premiumCap) {
        return false;
      }
      for (final item in items) {
        if (!isMark(item.$2) &&
            word(item.$2, body) + valuePadding > freeWidth) {
          return false;
        }
        if (!isMark(item.$3) &&
            word(item.$3, body) + valuePadding > premiumWidth) {
          return false;
        }
      }
      final feature = width - freeWidth - premiumWidth - featurePadding;
      if (widest(l10n.premiumComparisonFeature, heading) > feature) {
        return false;
      }
      for (final item in items) {
        if (unbreakable(item.$1, body) > feature) return false;
      }
      return true;
    } finally {
      for (final painter in painters) {
        painter.dispose();
      }
    }
  }

  Widget _planCard(
    BuildContext context,
    AppLocalizations l10n,
    String title,
    String? price,
    bool isRecommended,
    PremiumService premium,
    String productId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final busy = premium.purchasePending;
    final available = price != null;
    final featured = isRecommended && available;
    return MenuCard(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: featured
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Semantics(
        button: true,
        enabled: available && !busy,
        child: InkWell(
          onTap: (!available || busy)
              ? null
              : () async {
                  if (!await ensureLegalConsent(context) || !context.mounted) {
                    return;
                  }
                  final ok = await premium.buy(productId);
                  if (!ok && context.mounted && premium.purchaseError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _purchaseErrorText(l10n, premium.purchaseError!),
                        ),
                      ),
                    );
                  }
                },
          child: Container(
            color: featured
                ? Color.alphaBlend(
                    scheme.primaryContainer.withValues(alpha: 0.4),
                    scheme.surface,
                  )
                : null,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (featured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: AccentTextTheme.of(context),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  l10n.premiumPlanRecommendedBadge,
                                  style: localizedHeadingStyle(
                                    context,
                                    TextStyle(
                                      fontSize: 12,
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        title,
                        style: localizedHeadingStyle(
                          context,
                          TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Expanded(
                    child: Text(
                      price,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
