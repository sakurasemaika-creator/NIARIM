import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 共有タブの「受け取ったもの／自分が作成したもの」の切り替え。
///
/// 2つの名前が元の大きさのまま入る幅では文字で、入らない幅ではアイコンだけで
/// 出す（文字を縮めない。端末の種類ではなく、いまの幅と文字の大きさで決める）。
/// アイコンのときも、長押し（マウスではホバー）で元の名前を出し、読み上げの
/// 名前は元の名前のまま。以前は入らない幅で切り替え全体を縮めて描き、文字が
/// 設定より小さくなっていた（幅320px・文字2倍で約半分の大きさ）。
class SharedDirectionSwitch extends StatelessWidget {
  const SharedDirectionSwitch({
    super.key,
    required this.outgoing,
    required this.onChanged,
  });

  /// 「自分が作成したもの」を選んでいるか。
  final bool outgoing;
  final ValueChanged<bool> onChanged;

  /// 受け取ったもの（受信トレイへ入る）のアイコン。
  static const receivedIcon = Icons.move_to_inbox_outlined;

  /// 自分が作成したもの（送信トレイから出す）のアイコン。
  static const outgoingIcon = Icons.outbox_outlined;

  // 1つの区画の左右の余白（下のButtonStyleのpadding）。
  static const _segmentPadding = 20.0;

  // 区画の最小の幅（TextButtonの既定の最小の大きさ）。
  static const _segmentMinWidth = 64.0;

  /// [labels]の2つの名前を、文字の大きさを変えずに[maxWidth]へ並べられるか。
  /// 区画はどれも一番広い区画と同じ幅になる（SegmentedButtonの決まり）。
  static bool labelsFit(
    BuildContext context,
    List<String> labels,
    double maxWidth,
  ) {
    final theme = Theme.of(context);
    final style =
        theme.segmentedButtonTheme.style?.textStyle?.resolve(const {
          WidgetState.selected,
        }) ??
        theme.textTheme.labelLarge;
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    final segment = widest + _segmentPadding * 2;
    final needed =
        labels.length *
        (segment > _segmentMinWidth ? segment : _segmentMinWidth);
    // 区画の幅の端数の丸めぶんだけ余裕を見る。
    return needed + 1 <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final received = l10n.homeSharedReceivedFilter;
    final created = l10n.homeSharedCreatedFilter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = labelsFit(context, [
            received,
            created,
          ], constraints.maxWidth);
          ButtonSegment<bool> segment(bool value, String name, IconData icon) {
            final key = Key(
              value ? 'sharedOutgoingFilter' : 'sharedReceivedFilter',
            );
            return text
                ? ButtonSegment<bool>(
                    value: value,
                    label: Text(name, key: key, maxLines: 1),
                  )
                : ButtonSegment<bool>(
                    value: value,
                    icon: Icon(icon, key: key, semanticLabel: name),
                    tooltip: name,
                  );
          }

          return Center(
            // アイコンでも入らない幅（ほぼ無い）のときだけ縮める。
            child: FittedBox(
              fit: BoxFit.scaleDown,
              // 名前は読み上げにはアイコンのラベルとして1度だけ渡し、区画の
              // ツールチップ（長押し・ホバーで出す名前）は読み上げに入れない。
              // 両方に入れると、読み上げが名前を2度読んだ（Android 9より前の
              // TalkBackはラベルとツールチップをつないで読む）。
              child: TooltipTheme(
                data: TooltipTheme.of(
                  context,
                ).copyWith(excludeFromSemantics: true),
                child: SegmentedButton<bool>(
                  key: const Key('sharedDirectionSegmentedControl'),
                  showSelectedIcon: false,
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.standard,
                    shape: const WidgetStatePropertyAll(StadiumBorder()),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(
                        horizontal: _segmentPadding,
                        vertical: 12,
                      ),
                    ),
                  ),
                  segments: [
                    segment(false, received, receivedIcon),
                    segment(true, created, outgoingIcon),
                  ],
                  selected: {outgoing},
                  onSelectionChanged: (selection) =>
                      onChanged(selection.single),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
