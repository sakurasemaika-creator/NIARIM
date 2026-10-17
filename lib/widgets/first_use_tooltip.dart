import 'dart:async';

import 'package:flutter/gestures.dart';
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
  // タップ判定用（Listenerでポインターを直接観測する。理由はbuild参照）。
  int? _pointer;
  Offset? _downPosition;
  // 長押し判定はTimerで行う。PointerEvent.timeStampはウィジェットテストでは
  // 常に0のままなので（TestGesture.upの既定値）、時刻の差分で長押しを
  // 判定するとテスト上は必ず「短いタップ」に見えてしまい検証できない。
  // Timerなら実機では実時間、テストではFakeAsyncの時計に従うため両方で
  // 同じ判定になる。
  Timer? _longPressTimer;
  bool _longPressElapsed = false;
  // 表示中・表示待ちの説明（同じ説明を二重に出さない。ボタンが作り直されて
  // 別のStateになっても効くよう、Stateではなく説明のキーで覚える）。
  // 表示待ちはrouteがnull。画面ごと破棄されると閉じた通知が来ないことが
  // あるので、Navigatorや画面がもう無ければ表示中とは見なさない。
  static final Map<String, ({NavigatorState navigator, Route<void>? route})>
  _showing = {};

  static bool _isShowing(String key) {
    final entry = _showing[key];
    if (entry == null) return false;
    final route = entry.route;
    final live = route == null ? entry.navigator.mounted : route.isActive;
    if (!live) _showing.remove(key);
    return live;
  }

  void _maybeShow() {
    if (!mounted) return;
    final key = widget.tooltipKey;
    // 既に表示中・表示待ちの間は重ねて出さない。
    if (_isShowing(key)) return;
    final service = context.read<FirstUseTooltipService>();
    if (service.hasSeen(key)) return;
    // 中央表示になったので位置決めには使わないが、「対象ウィジェットが
    // 実際にレイアウトされている（＝画面に出ている）」ことの確認には
    // 引き続き使う。剥がれかけの要素に対して説明を出さないためのガード。
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;
    // カードに要るものは押した時点で取っておく。押したボタンの画面が
    // 次のフレームまでに作り直されると（タイムラインの全画面表示の
    // ボタン等）このウィジェットは無くなるが、説明はそれでも出す
    // （以前は出せずに終わり、表示済みにもならなかった）。
    final message = widget.message;
    final barrierColor = Theme.of(
      context,
    ).colorScheme.scrim.withValues(alpha: 0.45);
    final barrierLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;
    _showing[key] = (navigator: navigator, route: null);
    // 同じタップで子がダイアログ等を開いた場合も、その上にカードを出す
    // （次のフレームまで待つ）。カードは専用の画面として積むので、戻る操作・
    // Esc・カードの外のタップで閉じ、キーボードのフォーカスもカードに移り
    // （背面の画面のショートカットは効かない）、閉じれば元へ戻る。
    // 以前は画面の上へOverlayで重ねていたため、戻る操作は下の画面
    // （PopScopeで戻る操作を受ける画面）やダイアログへ届き、Escも効かず、
    // Android 16の予測型「戻る」ではアプリごと閉じていた。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) {
        _showing.remove(key);
        return;
      }
      final route = RawDialogRoute<void>(
        barrierDismissible: true,
        // ダークテーマでも暗く見えるよう、テーマの文字色ではなく
        // 幕（scrim）の色を使う（文字色だと白っぽい幕になっていた）。
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
        transitionDuration: const Duration(milliseconds: 150),
        transitionBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (context, _, _) => _FirstUseCard(message: message),
      );
      _showing[key] = (navigator: navigator, route: route);
      navigator.push(route).whenComplete(() {
        if (_showing[key]?.route == route) _showing.remove(key);
        // 閉じ方（カード・外側・戻る・Esc）に関わらず、読んだものとして扱う。
        service.markSeen(key);
      });
    });
  }

  void _resetPointer() {
    _pointer = null;
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **GestureDetectorを使ってはならない**（過去に使っていて機能が丸ごと
    // 死んでいた）。GestureDetectorのタップ認識はジェスチャーアリーナへ
    // 参加するため、子・親のタップ認識と必ずどちらか一方しか勝てない。
    // アリーナは「ヒットテスト経路の内側から順に追加され、先に入った方が
    // 勝つ」ため、
    //   - 子がタップを扱う場合（IconButton・InkWell等）＝子が勝ち、
    //     吹き出しは**一度も表示されない**
    //   - 親がタップを扱う場合（TabBarは各タブをInkWellで包むので親側）＝
    //     吹き出し側が勝ち、**タブが切り替わらなくなる**
    // という二通りの壊れ方をする（実際に前者で8箇所の吹き出しが全滅し、
    // 後者でペンサブツールパネルのトーン・スタンプタブがタップで
    // 切り替わらなくなっていた）。
    //
    // そこでアリーナに参加しないListenerでポインターを観測する。
    // Listenerはヒットテスト経路上の全員へ配送されるので、子のタップも
    // 親のタップも一切妨げない。タップかどうかは
    // 「移動量がkTouchSlop以内」「離すまでにkLongPressTimeoutが経過して
    // いない」で判定する。後者の条件により、「長押しで機能を開くボタンは
    // 長押し操作時にチュートリアルを出さない」という要件も従来どおり
    // 満たせる。
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointer = event.pointer;
        _downPosition = event.position;
        _longPressElapsed = false;
        _longPressTimer?.cancel();
        _longPressTimer = Timer(kLongPressTimeout, () {
          _longPressElapsed = true;
        });
      },
      onPointerUp: (event) {
        if (event.pointer != _pointer) return;
        _resetPointer();
        final down = _downPosition;
        if (down == null || _longPressElapsed) return;
        if ((event.position - down).distance > kTouchSlop) return;
        _maybeShow();
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointer) _resetPointer();
      },
      child: KeyedSubtree(key: _anchorKey, child: widget.child),
    );
  }
}

/// 初回の説明カード。カード自体・右下の「閉じる」・カードの外のタップ・
/// 戻る操作・Escで閉じる。
class _FirstUseCard extends StatelessWidget {
  const _FirstUseCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);
    // 画面幅いっぱいまでは広げず、読みやすい行長（最大460px）に収める。
    final cardWidth = (screen.width - 40).clamp(240.0, 460.0);
    void close() => Navigator.of(context).maybePop();
    return Center(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.firstUseTipOperationGuideTitle,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: close,
            child: Container(
              width: cardWidth,
              constraints: BoxConstraints(maxHeight: screen.height - 80),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      // 説明文は本文フォント（白光明朝）。くらむぼんは
                      // 見出し・項目名など大きく目立たせたい文字に限定する。
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 17,
                        height: 1.5,
                        fontFamily: 'HakkouMincho',
                        fontFamilyFallback: kBodyFontFallback,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: scheme.onPrimary.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.firstUseTipOperationGuideTitle,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 14,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.firstUseTipOperationGuideBody,
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.92),
                        fontSize: 15,
                        height: 1.5,
                        fontFamily: 'HakkouMincho',
                        fontFamilyFallback: kBodyFontFallback,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        button: true,
                        onTap: close,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close,
                              size: 18,
                              color: scheme.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.commonClose,
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 15,
                                fontFamily: 'HakkouMincho',
                                fontFamilyFallback: kBodyFontFallback,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
