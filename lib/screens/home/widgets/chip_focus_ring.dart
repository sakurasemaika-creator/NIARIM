import 'package:flutter/material.dart';

/// ホームの絞り込みのチップ（お気に入り・ゴミ箱の種類）を、キーボードで
/// フォーカスしている間は縁に輪を描いて示す（フォーカスの見える化、
/// WCAG 2.4.7）。
///
/// チップのフォーカスの印（インクの下地に足す灰色）は、チップを含む一覧の
/// 見出しを作り直さずに移すと（プロジェクトの一覧の「お気に入り」を押した
/// とき）、チップ自身の地の色より先に描く順になり、地の色に塗りつぶされて
/// 見えなくなった（インクの下地は足した順に描く）。縁の輪はチップの形の
/// 一部として描くので、移しても消えない。選んだ（差し色で塗った）チップでも
/// 灰色の印より見分けやすい。マウス・指で操作しているとき
/// （[FocusHighlightMode.touch]）は、インクの印と同じく出さない。
class ChipFocusRing extends StatefulWidget {
  const ChipFocusRing({super.key, required this.builder});

  /// チップを作る。[side]をチップの`side`に渡す（フォーカスの無いときは
  /// テーマの縁のまま）。
  final Widget Function(BuildContext context, WidgetStateBorderSide side)
  builder;

  @override
  State<ChipFocusRing> createState() => _ChipFocusRingState();
}

class _ChipFocusRingState extends State<ChipFocusRing> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }

  void _highlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    // 地（ページ）の上の文字の色：塗っていないチップ（白い地）とも、選んだ
    // チップ（差し色の塗り）とも、ページの地とも分かれる。
    final ring = Theme.of(context).colorScheme.onSurface;
    return widget.builder(
      context,
      WidgetStateBorderSide.resolveWith(
        // 縁の外側に描く（内側に描くと、チップが縁の太さだけ広がって並びが
        // 動く）。
        (states) => keyboard && states.contains(WidgetState.focused)
            ? BorderSide(
                color: ring,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : null,
      ),
    );
  }
}
