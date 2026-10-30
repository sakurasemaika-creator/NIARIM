import 'package:flutter/material.dart';

/// パネルがPC/DeXモードの作業画面のドックに入っていることを伝える。
/// ドックのペインは自分で見出し・閉じるボタンを持つので、パネルは
/// スマホ用の浮かぶカード・閉じるボタン・固定の大きさをやめて、ペインを
/// いっぱいに使う（[PanelSurface]・`PanelCenterCloseBar`が読む）。
class DockedPanelScope extends InheritedWidget {
  const DockedPanelScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DockedPanelScope>() != null;

  @override
  bool updateShouldNotify(DockedPanelScope oldWidget) => false;
}

/// ツールのパネルの下地。スマホでは[width]×[height]の浮かぶカード、
/// PC/DeXモードのドックではペインいっぱいの平らな面になる。
///
/// [height]を持つパネル（一覧を`Expanded`で伸ばす作り）はペインの高さに
/// 合わせて並べ、持たないパネル（中身の高さで決まる作り）はペインより
/// 高いときだけスクロールする。
class PanelSurface extends StatelessWidget {
  const PanelSurface({
    super.key,
    required this.width,
    this.height,
    this.maxHeight,
    this.elevation = 8,
    this.surfaceTintColor,
    this.color,
    this.borderRadius,
    this.selfScrolling = false,
    required this.child,
  });

  final double width;
  final double? height;
  final double? maxHeight;
  final double elevation;
  final Color? surfaceTintColor;

  /// 浮かぶときの面の色と角（指定するとカードではなく[Material]で描く）。
  final Color? color;
  final BorderRadius? borderRadius;

  /// 中身が自分でスクロールする（ドックではペインの高さをそのまま渡す）。
  final bool selfScrolling;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (DockedPanelScope.of(context)) {
      if (height != null || selfScrolling) {
        return SizedBox.expand(child: child);
      }
      return SingleChildScrollView(child: child);
    }
    final sized = ConstrainedBox(
      constraints: BoxConstraints.tightFor(
        width: width,
        height: height,
      ).copyWith(maxHeight: height ?? maxHeight),
      child: child,
    );
    if (color != null || borderRadius != null) {
      return Material(
        elevation: elevation,
        borderRadius: borderRadius,
        color: color,
        child: sized,
      );
    }
    return Card(
      elevation: elevation,
      surfaceTintColor: surfaceTintColor,
      child: sized,
    );
  }
}
