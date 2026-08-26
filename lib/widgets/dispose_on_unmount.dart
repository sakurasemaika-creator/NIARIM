import 'package:flutter/widgets.dart';

/// showDialog等で使うTextEditingControllerを、ウィジェットが実際にツリー
/// から取り除かれるタイミング（ダイアログの閉じるトランジション完了後）で
/// 安全に破棄するための汎用ラッパー。
///
/// `showDialog(...).then((_) => controller.dispose())`のように
/// Future解決直後（＝Navigator.pop()を呼んだ直後）に即座に破棄すると、
/// 閉じるトランジションアニメーション中はまだ子孫のTextFieldがcontrollerを
/// 参照しており、その間に何らかの理由で祖先が再ビルドされると
/// 「TextEditingController was used after being disposed」になることがある
/// （Future解決のタイミングは、実際にウィジェットがツリーから外れる
/// タイミングより早い）。Stateのdispose()はウィジェットが実際に取り除かれる
/// まで呼ばれないため、破棄をここへ委ねることでこの競合を避けられる。
class DisposeOnUnmount extends StatefulWidget {
  final TextEditingController controller;
  final WidgetBuilder builder;

  const DisposeOnUnmount({super.key, required this.controller, required this.builder});

  @override
  State<DisposeOnUnmount> createState() => _DisposeOnUnmountState();
}

class _DisposeOnUnmountState extends State<DisposeOnUnmount> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
