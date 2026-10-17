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

  // フォーカスが画面のスコープそのものへ落ちたら（入力を終えた）、画面の
  // フォーカスへ戻す。上に別の画面・ダイアログがある間は何もしない。
  void _reclaimFocus() {
    final node = widget.screenFocus;
    if (node == null || !mounted || node.context == null) return;
    final scope = node.enclosingScope;
    final primary = FocusManager.instance.primaryFocus;
    if (scope == null || primary != scope) return;
    if (_route != null && !_route!.isCurrent) return;
    // フォーカスの変更を通知している最中には変えない。
    scheduleMicrotask(() {
      if (mounted &&
          node.context != null &&
          FocusManager.instance.primaryFocus == scope) {
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
