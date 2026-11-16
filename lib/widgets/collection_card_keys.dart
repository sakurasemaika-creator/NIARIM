import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// カードを選ぶ（長押しと同じ。選んでいる間は選ぶ・外すの切り替え）。
class SelectCollectionCardIntent extends Intent {
  const SelectCollectionCardIntent();
}

const _selectShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.space): SelectCollectionCardIntent(),
};

/// キーボードのフォーカスが[card]の中の、カードの本体（InkWell・ListTile等）に
/// あるか。カードの中の操作（星・︙・ボタン・チェックボックス）は本体ではない。
bool _bodyFocused(Element card) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null || !card.mounted) return false;
  var onBody = true;
  var inCard = false;
  void check(Element element) {
    final widget = element.widget;
    if (widget is IconButton ||
        widget is ButtonStyleButton ||
        widget is PopupMenuButton ||
        widget is Checkbox) {
      onBody = false;
    }
  }

  if (focused is Element) check(focused);
  focused.visitAncestorElements((element) {
    if (identical(element, card)) {
      inCard = true;
      return false;
    }
    check(element);
    return onBody;
  });
  return inCard && onBody;
}

/// 一覧のカード・行の本体（自分でフォーカスを持つInkWell・ListTile等）の
/// キーボードの操作：本体に止まっているときSpaceで[onSelect]を呼び（Enterは
/// 今までどおり開く。以前はSpaceもEnterと同じく開くだけで、キーボードでは
/// カードを選べなかった）、キーボードで操作している間だけカードの外側に輪を
/// 描いて止まっていることを示す（本体のフォーカスの色はカードの表紙・中身の
/// 下に隠れ、どのカードにいるか見えなかった）。
///
/// 中の星・︙・ボタン・チェックボックスに止まっているときは何もせず、Space
/// はそれらを押す。止まり先は増やさない。
class CollectionCardKeyboard extends StatefulWidget {
  const CollectionCardKeyboard({
    super.key,
    required this.onSelect,
    required this.borderRadius,
    required this.child,
  });

  /// nullなら選ぶ操作は無い（SpaceはEnterと同じく本体を押す）。
  final VoidCallback? onSelect;

  /// 輪の角の丸み（カードの角）。
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<CollectionCardKeyboard> createState() => _CollectionCardKeyboardState();
}

class _CollectionCardKeyboardState extends State<CollectionCardKeyboard> {
  bool _ring = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_update);
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_update);
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }

  void _highlightModeChanged(FocusHighlightMode mode) => _update();

  void _update() {
    if (!mounted) return;
    final ring =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional &&
        _bodyFocused(context as Element);
    if (ring != _ring) setState(() => _ring = ring);
  }

  @override
  Widget build(BuildContext context) {
    final select = widget.onSelect;
    return Shortcuts(
      shortcuts: select == null ? const {} : _selectShortcuts,
      child: Actions(
        actions: {
          if (select != null)
            SelectCollectionCardIntent: _SelectCardAction(
              context as Element,
              select,
            ),
        },
        child: _FocusRing(
          show: _ring,
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 本体に止まっているときだけ選ぶ（[_bodyFocused]）。
class _SelectCardAction extends Action<SelectCollectionCardIntent> {
  _SelectCardAction(this.card, this.onSelect);

  final Element card;
  final VoidCallback onSelect;

  @override
  bool isEnabled(SelectCollectionCardIntent intent) => _bodyFocused(card);

  @override
  Object? invoke(SelectCollectionCardIntent intent) {
    onSelect();
    return null;
  }
}

/// カードの外側の輪（浮かぶボタン・絞り込みのチップと同じ、地の上の文字の
/// 色・3px）。
class _FocusRing extends StatelessWidget {
  const _FocusRing({
    required this.show,
    required this.borderRadius,
    required this.child,
  });

  final bool show;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: show
        ? BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface,
              width: 3,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          )
        : const BoxDecoration(),
    child: child,
  );
}

/// 自分ではフォーカスを持たない（GestureDetectorで押す）カードを、Tabで
/// 止まる本体にする：Enterで[onActivate]（押したときと同じ）、Spaceで
/// [onSelect]（長押しと同じ）。キーボードで操作している間だけ外側に輪を描く。
/// マウス・指で操作しているときは描かない。
class CollectionCardFocus extends StatefulWidget {
  const CollectionCardFocus({
    super.key,
    required this.onActivate,
    required this.onSelect,
    required this.borderRadius,
    required this.child,
  });

  final VoidCallback? onActivate;
  final VoidCallback? onSelect;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<CollectionCardFocus> createState() => _CollectionCardFocusState();
}

class _CollectionCardFocusState extends State<CollectionCardFocus> {
  bool _ring = false;

  @override
  Widget build(BuildContext context) {
    final activate = widget.onActivate;
    final select = widget.onSelect;
    return FocusableActionDetector(
      enabled: activate != null || select != null,
      shortcuts: select == null ? null : _selectShortcuts,
      actions: {
        if (activate != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              activate();
              return null;
            },
          ),
        if (select != null)
          SelectCollectionCardIntent:
              CallbackAction<SelectCollectionCardIntent>(
                onInvoke: (_) {
                  select();
                  return null;
                },
              ),
      },
      onShowFocusHighlight: (show) {
        if (show != _ring) setState(() => _ring = show);
      },
      child: _FocusRing(
        show: _ring,
        borderRadius: widget.borderRadius,
        child: widget.child,
      ),
    );
  }
}

/// 一覧の行・カードの本体に、Spaceで選ぶ操作と止まった印を足す
/// （[CollectionCardKeyboard]）、自分ではフォーカスを持たないカードを
/// Tabで止まる本体にする（[CollectionCardFocus]）。
extension CollectionCardKeyboardOn on Widget {
  Widget cardKeyboard({
    required VoidCallback? onSelect,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) => CollectionCardKeyboard(
    onSelect: onSelect,
    borderRadius: borderRadius,
    child: this,
  );

  Widget focusableCard({
    required VoidCallback? onActivate,
    required VoidCallback? onSelect,
    required BorderRadius borderRadius,
  }) => CollectionCardFocus(
    onActivate: onActivate,
    onSelect: onSelect,
    borderRadius: borderRadius,
    child: this,
  );
}
