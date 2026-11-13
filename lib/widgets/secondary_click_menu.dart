import 'package:flutter/material.dart';

/// 一覧の行・カードを右クリック（マウスの副ボタン）したとき、その行の︙と
/// 同じメニューを開く。
///
/// 行の中の︙（`PopupMenuButton<String>`）を探し、同じ項目のメニューを押した所に
/// 出して、選んだ項目を︙と同じ処理へ渡す。︙が下から出るシートを開くボタン
/// （`Icons.more_vert`の[IconButton]）なら、そのボタンを押したのと同じにする。
/// ︙が無い（選んでいる間・選ぶ専用の画面）・押せない（保存中）ときは何もしない。
///
/// 右クリックを自分で使う行（作品の書き出したファイルの「選ぶ」）は、その行の
/// 中の処理が先に受け取るので変わらない（離したときに開くので、長く押しても
/// 両方は動かない）。
class SecondaryClickMenu extends StatelessWidget {
  const SecondaryClickMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) => openAt(context, details.globalPosition),
      child: child,
    );
  }

  /// [context]の中の︙のメニューを[globalPosition]で開く。開いたらtrue。
  static bool openAt(BuildContext context, Offset globalPosition) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is PopupMenuButton<String> ||
          (widget is IconButton &&
              widget.icon is Icon &&
              (widget.icon as Icon).icon == Icons.more_vert)) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    final element = found;
    if (element == null) return false;
    final widget = element.widget;
    if (widget is PopupMenuButton<String>) {
      if (!widget.enabled) return false;
      _showPopup(element, widget, globalPosition);
      return true;
    }
    final onPressed = (widget as IconButton).onPressed;
    if (onPressed == null) return false;
    onPressed();
    return true;
  }

  static Future<void> _showPopup(
    BuildContext context,
    PopupMenuButton<String> button,
    Offset globalPosition,
  ) async {
    final entries = button.itemBuilder(context);
    if (entries.isEmpty) return;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(globalPosition);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        local.dx,
        local.dy,
        overlay.size.width - local.dx,
        overlay.size.height - local.dy,
      ),
      items: entries,
      initialValue: button.initialValue,
    );
    if (!context.mounted) return;
    if (result == null) {
      button.onCanceled?.call();
    } else {
      button.onSelected?.call(result);
    }
  }
}
