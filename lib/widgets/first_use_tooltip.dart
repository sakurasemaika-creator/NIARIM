import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/font_fallback.dart';
import '../l10n/app_localizations.dart';
import '../services/first_use_tooltip_service.dart';

/// 各機能の「初回タップ」時に、画面中央へ簡易説明カードを表示する共通
/// ウィジェット。
/// - 表示のタイミングは、対象ツールを実際に初めてタップした瞬間
///   （ボタンが画面に表示されただけでは表示しない）。
/// - 表示は一度のみ。タップで閉じ、二度と表示しない（再確認はヘルプページから）。
/// - 子ウィジェット自体のタップ操作は妨げない（カード・背面をタップした時のみ閉じる）。
///
/// 以前は対象ボタンの直下へ幅240px・文字12ptの小さな吹き出しを出していたが、
/// 「小さすぎて読めない」という指摘を受けて画面中央の大きめのカードへ変えた。
/// ツールバーは画面の端にあるため、直下に出すと画面端へ寄って余計に窮屈に
/// なるうえ、隣のボタンが隠れて操作の説明がしづらかった。
///
/// カードには各機能固有の説明に加えて、**共通の操作ガイド**
/// （シングルタップで切り替え／長押し・上スワイプで詳細設定）を必ず載せる。
/// これはツールバーの操作体系そのものが分かっていないと個別の説明も
/// 効かないため、どのチュートリアルからでも辿り着けるようにする狙い。
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
    // 中央表示になったので位置決めには使わないが、「対象ウィジェットが
    // 実際にレイアウトされている（＝画面に出ている）」ことの確認には
    // 引き続き使う。剥がれかけの要素に対して説明を出さないためのガード。
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    // 画面幅いっぱいまでは広げず、読みやすい行長（最大460px）に収める。
    final cardWidth = (screen.width - 40).clamp(240.0, 460.0);

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // カードの外側をタップしても閉じられるようにする全画面のバリア。
          // 中央表示にしたことで背面の面積が増えたため、以前より「どこでも
          // 閉じられる」ことの意味が大きい。うっすら暗くして、背面の操作が
          // 効かないこと・読むべき対象がカードであることを示す。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  width: cardWidth,
                  constraints: BoxConstraints(maxHeight: screen.height - 80),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message,
                          // 説明文は本文フォント（白光明朝）。くらむぼんは
                          // 見出し・項目名など大きく目立たせたい文字に限定する。
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onPrimary,
                            fontSize: 17,
                            height: 1.5,
                            fontFamily: 'HakkouMincho',
                            fontFamilyFallback: kBodyFontFallback,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Divider(
                          height: 1,
                          color: Theme.of(
                            ctx,
                          ).colorScheme.onPrimary.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.firstUseTipOperationGuideTitle,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onPrimary,
                            fontSize: 14,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.firstUseTipOperationGuideBody,
                          style: TextStyle(
                            color: Theme.of(
                              ctx,
                            ).colorScheme.onPrimary.withValues(alpha: 0.92),
                            fontSize: 15,
                            height: 1.5,
                            fontFamily: 'HakkouMincho',
                            fontFamilyFallback: kBodyFontFallback,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close,
                                size: 18,
                                color: Theme.of(ctx).colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.commonClose,
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.onPrimary,
                                  fontSize: 15,
                                  fontFamily: 'HakkouMincho',
                                  fontFamilyFallback: kBodyFontFallback,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    if (mounted) {
      context.read<FirstUseTooltipService>().markSeen(widget.tooltipKey);
    }
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
