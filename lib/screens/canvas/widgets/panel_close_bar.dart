import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'docked_panel_close_scope.dart';

/// ツール詳細設定ポップアップ（ブラシ・カラーピッカー・フィルター・
/// レイヤー・オニオンスキン・早替えツール・定規・スタンプ・トーンの
/// 各パネル）共通の閉じるボタン。
///
/// 見た目はパネル上部右端の小さい×に統一する。アイコン自体は小さくても
/// 押せる所は48×48（他のボタンと同じ最小の大きさ）を取り、モバイルの
/// フローティング表示ではCanvasScreen側の透明バリアによる「パネル外タップで
/// 閉じる」操作も併用する。題のあるパネルは[PanelHeaderRow]で題と同じ行に置く。
class PanelCenterCloseBar extends StatelessWidget {
  final VoidCallback onClose;
  const PanelCenterCloseBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    // The dock chrome already owns hide/collapse actions. Do not show a
    // redundant internal ×, but keep it on standalone mobile panels.
    if (DockedPanelCloseScope.isDocked(context)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: l10n.commonClose,
        onPressed: onClose,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: kMinInteractiveDimension,
          minHeight: kMinInteractiveDimension,
        ),
      ),
    );
  }
}

/// 浮かぶパネルの見出しの行：題を左に、閉じる×を同じ行の右端に置く。
///
/// ×だけの行を題の上に置くと、44pxの空いた帯ができ、ペン（タブの右に×）と
/// 定規・オニオンスキン・早替えツール（題の上に×）で並びも違って見えた。
/// [actions]（定規の「削除」・オニオンスキンの入切等）は題と×の間に置く。
///
/// ドックでは窓の見出しが題と閉じるボタンを持つので、×は出さず、題も
/// [showTitleWhenDocked]のときだけ出す（窓の見出しと同じ題が2つ並んでいた）。
/// 題も操作も無ければ行ごと出さない。
class PanelHeaderRow extends StatelessWidget {
  const PanelHeaderRow({
    super.key,
    required this.title,
    required this.onClose,
    this.actions = const [],
    this.showTitleWhenDocked = false,
    this.padding = const EdgeInsetsDirectional.only(start: 12),
  });

  final Widget title;
  final VoidCallback onClose;
  final List<Widget> actions;

  /// ドックでも題を出す（題が隣の操作の名前を兼ねるとき。オニオンスキンの入切）。
  final bool showTitleWhenDocked;

  /// 行の余白。右は×の押せる所がパネルの端まで届くよう既定で0。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final docked = DockedPanelCloseScope.isDocked(context);
    final showTitle = !docked || showTitleWhenDocked;
    if (!showTitle && actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: Row(
          children: [
            Expanded(child: showTitle ? title : const SizedBox.shrink()),
            ...actions,
            PanelCenterCloseBar(onClose: onClose),
          ],
        ),
      ),
    );
  }
}
