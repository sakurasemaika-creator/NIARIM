import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/first_use_tooltip_service.dart';

/// 各機能の初回使用時に、対象UIの近くへ吹き出しで簡易説明を表示する共通ウィジェット
/// （仕様書02「吹き出し説明」・11「初心者導線（3段階）」）。
/// - 表示は一度のみ。タップで閉じ、二度と表示しない（再確認はヘルプページから）。
/// - 子ウィジェット自体のタップ操作は妨げない（吹き出し自体をタップした時のみ閉じる）。
class FirstUseTooltip extends StatefulWidget {
  /// この吹き出しを一意に識別するキー（例：'ruler_tool'）。
  final String tooltipKey;
  final String message;
  final Widget child;

  const FirstUseTooltip({
    super.key,
    required this.tooltipKey,
    required this.message,
    required this.child,
  });

  @override
  State<FirstUseTooltip> createState() => _FirstUseTooltipState();
}

class _FirstUseTooltipState extends State<FirstUseTooltip> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  void _maybeShow() {
    if (!mounted) return;
    final service = context.read<FirstUseTooltipService>();
    if (service.hasSeen(widget.tooltipKey)) return;
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
  }

  void _dismiss() {
    _entry?.remove();
    _entry = null;
    if (mounted) context.read<FirstUseTooltipService>().markSeen(widget.tooltipKey);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _anchorKey, child: widget.child);
  }
}
