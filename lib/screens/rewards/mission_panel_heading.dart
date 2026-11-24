import 'package:flutter/material.dart';

import '../../utils/line_break.dart';
import '../../widgets/action_beside_or_below.dart';

/// ミッション画面の欄（作品広場の滞在・ウィークリー／マンスリー・累計ログイン
/// ボーナス）の見出し。題と右端の操作（更新ボタン）を並べる。
///
/// 題の前に印は置かない（カレンダー・時計の印は題の文を繰り返すだけの飾り
/// だった）。操作は題が単語の途中で切れるときだけ題の下（行の終わりの側）へ
/// 回す。更新ボタンを行の端に固定すると、題は残りの列に押し込まれ、
/// フランス語の文字1.75倍・2倍で「Missions heb|domadaires」のように単語の
/// 途中で切れた。
class MissionPanelHeading extends StatelessWidget {
  const MissionPanelHeading({
    super.key,
    required this.title,
    required this.action,
  });

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => ActionBesideOrBelow(
    // 韓国語の題は語の途中で折らない（「누적 로그인 / 보너스」の所で
    // だけ折る）。読み上げは元の題のまま。
    text: Text.rich(
      TextSpan(text: keepKoreanWordsTogether(title), semanticsLabel: title),
      style: Theme.of(context).textTheme.titleMedium,
    ),
    action: action,
  );
}
