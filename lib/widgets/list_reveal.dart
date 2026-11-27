import 'package:flutter/widgets.dart';

/// 一覧の最後に足した物（複製・新しく作った素材）を、見える所まで送る。
///
/// 足した行の高さは次のフレームで決まるので、2回のフレームに分けて最後まで
/// 送る（1回だけだと見積もった長さで止まり、最後の行が隠れることがある）。
void revealListEnd(ScrollController controller) {
  void jump() {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.pixels != position.maxScrollExtent) {
      controller.jumpTo(position.maxScrollExtent);
    }
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    jump();
    WidgetsBinding.instance.addPostFrameCallback((_) => jump());
  });
}
