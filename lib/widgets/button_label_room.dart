import 'package:flutter/widgets.dart';

/// ボタンのラベルの上下に取る余白。
///
/// くらむぼんのラベルは、アクセント（É）や下に伸びる字（p・j）が行の
/// 高さの外へ出る。Material 3のボタンは縦の余白が0なので、ラベルが2行以上に
/// なると（大きな文字のフランス語の「Échanger les pièces」「Récompenses en
/// préparation」等）、字がボタンの枠を越え、塗りのボタンではÉのアクセントが
/// 白い地に出て見えなくなった。字の大きさに合わせて上下に余白を取る（1行で
/// 文字の大きさが1倍ならボタンの最小の高さに収まり、見た目は変わらない）。
EdgeInsets buttonLabelRoom(BuildContext context) =>
    EdgeInsets.symmetric(vertical: MediaQuery.textScalerOf(context).scale(4));

/// ボタンのラベル（[child]）の上下に[buttonLabelRoom]の余白を取る。
class ButtonLabelRoom extends StatelessWidget {
  const ButtonLabelRoom({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: buttonLabelRoom(context), child: child);
}
