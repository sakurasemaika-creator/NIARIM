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
///
/// ︙が下から出るシートを開く行は、[openMenuAt]で同じ項目のメニューを押した
/// 所に出す（シートは画面の下から出るので、上の方の行では押した所から離れる）。
class SecondaryClickMenu extends StatelessWidget {
  const SecondaryClickMenu({super.key, required this.child, this.openMenuAt});

  final Widget child;

  /// 右クリックで、︙と同じ項目のメニューを押した所（画面の座標）に出す。
  /// nullなら行の中の︙を探して開く。
  final void Function(Offset globalPosition)? openMenuAt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        final open = openMenuAt;
        if (open != null) {
          open(details.globalPosition);
        } else {
          openAt(context, details.globalPosition);
        }
      },
      child: child,
    );
  }

  /// [items]のメニューを[globalPosition]（画面の座標）に出し、選んだ項目を
  /// 返す（選ばずに閉じたらnull）。
  static Future<T?> showItemsAt<T>(
    BuildContext context,
    Offset globalPosition,
    List<PopupMenuEntry<T>> items, {
    T? initialValue,
  }) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(globalPosition);
    return showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        local.dx,
        local.dy,
        overlay.size.width - local.dx,
        overlay.size.height - local.dy,
      ),
      items: items,
      initialValue: initialValue,
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
    final result = await showItemsAt<String>(
      context,
      globalPosition,
      entries,
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
