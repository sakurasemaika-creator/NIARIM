import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/first_use_tooltip_service.dart';

/// 各機能の「初回タップ」時に、対象UIの近くへ吹き出しで簡易説明を表示する
/// 共通ウィジェット。
/// - 表示のタイミングは、対象ツールを実際に初めてタップした瞬間
///   （ボタンが画面に表示されただけでは表示しない）。
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

  void _maybeShow() {
    if (!mounted) return;
    // 既に表示中の吹き出しがある間は再表示しない。ここをガードしないと、
    // 吹き出し表示中に同じボタンをもう一度タップした際、古いOverlayEntryを
    // 参照ごと上書きしてしまい、古い方が二度と閉じられずに残り続ける
    // （タップしても消えないように見える）不具合になっていた。
    if (_entry != null) return;
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
          // ようにする全画面の透明バリア。閉じるボタン
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
                          // 通常サイズの説明文はすべて白光明朝を使う。
                          // くらむぼんは見出し・項目名など大きく目立たせたい文字の
                          // みに限定する。
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
    // 自体のタップ・長押し等のジェスチャー認識を妨げない。
    // onTapDown（押した瞬間に無条件で発火し、後から長押し/ドラッグに
    // 負けてもキャンセルされない）ではなく onTap を使うのがポイント：
    // onTapは同じジェスチャーアリーナ内の長押し認識に「負けた」場合は
    // 呼ばれないため、「長押しで機能を開くボタンは、長押し操作時に
    // チュートリアル自体を表示しない」という要件を満たせる。
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _maybeShow,
      child: KeyedSubtree(key: _anchorKey, child: widget.child),
    );
  }
}
