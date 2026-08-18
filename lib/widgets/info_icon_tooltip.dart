import 'package:flutter/material.dart';

/// 「ここだけはUIだけでは伝わりにくい」という箇所に置く、小さな「i」アイコン。
/// タップすると、初回タップ時の吹き出し説明（[FirstUseTooltip]）と同じ見た目の
/// 吹き出しを表示する。[FirstUseTooltip]と異なり、何度でも・いつでもタップして
/// 再確認できる（「一度だけ表示して二度と出ない」という初回説明とは役割が違う
/// ため、あえて別ウィジェットとして用意している）。
///
/// 画面に余白があり、かつ操作の意味をUI・文言の改善だけでは十分に伝えきれない
/// 箇所にのみ最小限で配置する（多用するとかえって「読まないと分からないUI」に
/// なってしまうため）。
class InfoIconTooltip extends StatefulWidget {
  final String message;
  final double size;

  const InfoIconTooltip({super.key, required this.message, this.size = 16});

  @override
  State<InfoIconTooltip> createState() => _InfoIconTooltipState();
}

class _InfoIconTooltipState extends State<InfoIconTooltip> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _entry;

  void _toggle() {
    if (_entry != null) {
      _dismiss();
      return;
    }
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    final position = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screenWidth = MediaQuery.of(context).size.width;
    const bubbleWidth = 240.0;
    final left = (position.dx + size.width / 2 - bubbleWidth / 2)
        .clamp(8.0, screenWidth - bubbleWidth - 8.0);

    _entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: position.dy + size.height + 6,
        width: bubbleWidth,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      // チュートリアル・説明テキスト用フォント（仕様書24：くらむぼん）
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onPrimary,
                        fontSize: 12,
                        fontFamily: 'Kuramubon',
                      ),
                    ),
                  ),
                  Icon(Icons.close, size: 14, color: Theme.of(ctx).colorScheme.onPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlayState.insert(_entry!);
    setState(() {});
  }

  void _dismiss() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _anchorKey,
      child: InkWell(
        borderRadius: BorderRadius.circular(widget.size),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.info_outline,
            size: widget.size,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
