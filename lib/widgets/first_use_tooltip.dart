import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/first_use_tooltip_service.dart';

/// 各機能の「初回タップ」時に、対象UIの近くへ吹き出しで簡易説明を表示する
/// 共通ウィジェット（仕様書02「吹き出し説明」・11「初心者導線（3段階）」）。
/// - 表示のタイミングは、対象ツールを実際に初めてタップした瞬間
///   （ボタンが画面に表示されただけでは表示しない。タスク#92：以前は
///   ウィジェットが描画された時点で表示していたため、キャンバス画面を
///   開いた瞬間に複数の吹き出しが一斉に表示されてしまっていた）。
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

  /// 対象ツールをタップした瞬間に呼ばれる。タップ自体（ツール選択・長押し
  /// メニュー等）の処理は子ウィジェット側のジェスチャー検出でそのまま
  /// 続行されるため、ここでは吹き出し表示の判定のみ行う。
  void _handleTapDown(TapDownDetails _) => _maybeShow();

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
      builder: (ctx) => Stack(
        children: [
          // 吹き出し自体だけでなく、画面内のどこをタップしても閉じられる
          // ようにする全画面の透明バリア（ユーザー指示）。閉じるボタン
          // （吹き出し自体のタップ）は従来通り機能させつつ、これを背面に
          // 敷くことで「どこでも閉じられる」を実現する。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismiss,
            ),
          ),
          Positioned(
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
                          // 通常サイズの説明文はすべて白光明朝を使う（ユーザー指示：
                          // くらむぼんは見出し・項目名など大きく目立たせたい文字の
                          // みに限定する）。
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onPrimary,
                            fontSize: 12,
                            fontFamily: 'HakkouMincho',
                            fontFamilyFallback: const ['NotoSerifJP'],
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
        ],
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
    // translucentにすることで、この検出用GestureDetectorが子ウィジェット
    // 自体のタップ・長押し等のジェスチャー認識を妨げない（onTapDownのみを
    // 追加で受け取り、それ以外は子側の通常のジェスチャー処理へ委ねる）。
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _handleTapDown,
      child: KeyedSubtree(key: _anchorKey, child: widget.child),
    );
  }
}
