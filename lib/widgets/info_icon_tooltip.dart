import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/font_fallback.dart';
import '../l10n/app_localizations.dart';

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
  // 表示中の吹き出し。画面の上に専用の画面として積むので、戻る操作・Esc・
  // 外側のタップで閉じ、キーボードのフォーカスも吹き出しへ移って戻る
  // （Overlayで重ねていた頃は、戻る操作が下の画面へ届いていた）。
  Route<void>? _route;

  void _toggle() {
    final shown = _route;
    if (shown != null) {
      if (shown.isActive) Navigator.of(context).removeRoute(shown);
      return;
    }
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;

    final position = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // 狭いウィンドウ（DeXの小さな窓等）でも吹き出しが画面に収まるよう、
    // 幅は画面幅に合わせて縮め、clampの上限が下限を下回らないようにする
    // （下回るとclampが例外を投げていた）。
    final bubbleWidth = math.min(240.0, screen.width - 16);
    final left = (position.dx + size.width / 2 - bubbleWidth / 2)
        .clamp(8.0, math.max(8.0, screen.width - bubbleWidth - 8.0))
        .toDouble();
    // アイコンの上下で空いている方に出し、その高さに収める（収まらない
    // 長い説明は吹き出しの中でスクロール）。文字を大きくした横画面では、
    // 下に出した吹き出しが画面の下へはみ出して最後まで読めなかった。
    final below = position.dy + size.height + 6;
    final spaceBelow = screen.height - padding.bottom - keyboard - below - 8;
    final spaceAbove = position.dy - 6 - padding.top - 8;
    final showAbove = spaceAbove > spaceBelow;
    final maxHeight = math.max(48.0, showAbove ? spaceAbove : spaceBelow);
    final message = widget.message;

    final route = _BubbleRoute(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (ctx) => Stack(
        children: [
          Positioned(
            left: left,
            top: showAbove ? null : below,
            bottom: showAbove ? screen.height - position.dy + 6 : null,
            width: bubbleWidth,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).maybePop(),
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.shadow.withValues(alpha: 0.38),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            message,
                            // 通常サイズの説明文はすべて白光明朝を使う。
                            // くらむぼんは見出し・項目名など大きく目立たせたい
                            // 文字のみに限定する。
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onPrimary,
                              fontSize: 12,
                              fontFamily: 'HakkouMincho',
                              fontFamilyFallback: kBodyFontFallback,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.close,
                        size: 14,
                        color: Theme.of(ctx).colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    setState(() => _route = route);
    navigator.push(route).whenComplete(() {
      if (mounted && _route == route) setState(() => _route = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 見た目は小さな「i」のまま、押せる範囲は指で押しやすい40px四方にする
    // （以前は約20px四方で押し損じやすかった）。読み上げでは説明を開く
    // ボタンとして伝える。
    return KeyedSubtree(
      key: _anchorKey,
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context)!.commonShowExplanation,
        hint: widget.message,
        // 子の読み上げを除くとInkWellのタップも除かれるので、ここで渡す
        // （渡さないとスクリーンリーダー・スイッチ操作から開けない）。
        onTap: _toggle,
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          child: SizedBox.square(
            dimension: math.max(40, widget.size + 4),
            child: Icon(
              Icons.info_outline,
              size: widget.size,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 吹き出しを出す画面。外側のタップ・戻る・Escで閉じる。位置は画面全体の
/// 座標で決めるので、折りたたみ端末のヒンジで画面を分けない
/// （`RawDialogRoute`は分けた片側に置くため、もう片側のアイコンの吹き出しが
/// ずれたり切れたりする）。
class _BubbleRoute extends PopupRoute<void> {
  _BubbleRoute({required this.builder, required this.barrierLabel});

  final WidgetBuilder builder;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: builder(context),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}
