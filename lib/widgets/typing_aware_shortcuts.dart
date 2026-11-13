import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// [CallbackShortcuts]と同じくキー割り当てで処理を呼ぶが、文字入力欄に
/// フォーカスがある間は何もせず、キーをその入力欄へ通す。
///
/// 画面全体を`CallbackShortcuts`で包むと、入力欄より画面の割り当ての方が
/// 先にキーを受け取る（アプリ全体の文字編集のショートカットは画面より
/// 外側にあるため）。ホーム画面の検索欄でCtrl+Aを押すと文字の全選択では
/// なく作品の全選択になり、検索で隠れている作品まで選ばれていた。
///
/// [screenFocus]を渡すと、入力を終えたときに画面のフォーカスを取り戻す。
/// 入力欄でEnterを押す・欄の外をクリックするとFlutterはフォーカスを画面の
/// スコープそのもの（この割り当てより上）へ落とすので、そのままでは画面を
/// 一度押すまでショートカットが効かなかった（キャンバスの色コード欄・
/// レイヤーの検索欄で実際に起きていた）。
///
/// また、画面の中でフォーカスを持っていた部品が消えた・押せなくなったとき
/// （押したことで消えるボタン・選択中の操作バー・作り直される一覧の見出し等）
/// も画面のフォーカスへ戻す。Flutterはその前にフォーカスのあった部品（Tabで
/// 来る途中のタブ・「起動画面に戻る」等）へ移すので、続けて押したEnterで
/// 見えていない別の操作が動いた（ホームでゴミ箱のタブが開いた）。
class TypingAwareShortcuts extends StatefulWidget {
  const TypingAwareShortcuts({
    super.key,
    required this.bindings,
    this.screenFocus,
    required this.child,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;

  /// 画面のショートカットを受けるフォーカス（[child]の中の`Focus`）。
  final FocusNode? screenFocus;
  final Widget child;

  /// いま文字入力欄にフォーカスがあるか。
  static bool get isTyping {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  State<TypingAwareShortcuts> createState() => _TypingAwareShortcutsState();
}

class _TypingAwareShortcutsState extends State<TypingAwareShortcuts> {
  ModalRoute<Object?>? _route;

  // 画面（[TypingAwareShortcuts.screenFocus]）の中で最後にフォーカスを
  // 持っていた部品と、その部品が入っていたフォーカスの範囲。
  FocusNode? _lastInside;
  FocusScopeNode? _lastInsideScope;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reclaimFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reclaimFocus);
    super.dispose();
  }

  // フォーカスが画面のスコープそのものへ落ちたら（入力を終えた）、または
  // 画面の中でフォーカスを持っていた部品が消えた・押せなくなってFlutterが
  // フォーカスを別の部品へ移したら、画面のフォーカスへ戻す。上に別の画面・
  // ダイアログがある間は何もしない（閉じて戻ったときに確かめる）。
  void _reclaimFocus() {
    final node = widget.screenFocus;
    if (node == null || !mounted || node.context == null) return;
    final primary = FocusManager.instance.primaryFocus;
    final previous = _lastInside;
    final previousScope = _lastInsideScope;
    if (primary != null &&
        (primary == node || primary.ancestors.contains(node))) {
      _lastInside = primary;
      _lastInsideScope = primary.enclosingScope;
    }
    final scope = node.enclosingScope;
    if (scope == null) return;
    if (_route != null && !_route!.isCurrent) return;
    final fellToScope = primary == scope;
    // 消えた（木から外れた）・押せなくなった部品からの移動だけを戻す。
    // 利用者がTab・クリックで移ったときは前の部品はそのまま残っている。
    // 文字の入力欄へ移ったとき（検索を開いた等）はそのままにする。画面の
    // 中の別の範囲（引き出し等）が閉じて開いたボタンへ戻るときは、Flutterの
    // 戻し方のままにする。
    final lostFocusedControl =
        previous != null &&
        previousScope == scope &&
        previous != primary &&
        previous != node &&
        primary != node &&
        (previous.parent == null || !previous.canRequestFocus) &&
        !TypingAwareShortcuts.isTyping;
    if (!fellToScope && !lostFocusedControl) return;
    // フォーカスの変更を通知している最中には変えない。
    scheduleMicrotask(() {
      if (mounted &&
          node.context != null &&
          FocusManager.instance.primaryFocus == primary &&
          (_route == null || _route!.isCurrent)) {
        node.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (TypingAwareShortcuts.isTyping) return KeyEventResult.ignored;
        for (final entry in widget.bindings.entries) {
          if (entry.key.accepts(event, HardwareKeyboard.instance)) {
            entry.value();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
