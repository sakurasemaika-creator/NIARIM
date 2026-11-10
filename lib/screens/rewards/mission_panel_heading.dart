import 'package:flutter/material.dart';

import '../../widgets/action_beside_or_below.dart';

/// ミッション画面の欄（作品広場の滞在・ウィークリー／マンスリー・累計ログイン
/// ボーナス）の見出し。先頭のアイコン・題・右端の操作（更新ボタン）を並べる。
///
/// アイコンは題の文の先頭に置き、操作は題が単語の途中で切れるときだけ題の
/// 下（行の終わりの側）へ回す。アイコンと更新ボタンを行の両端に固定すると、
/// 題はカードの幅から80pxを引いた列に押し込まれ、フランス語の文字1.75倍・
/// 2倍で「Missions heb|domadaires」のように単語の途中で切れた。
class MissionPanelHeading extends StatelessWidget {
  const MissionPanelHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.action,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => ActionBesideOrBelow(
    text: Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Icon(icon, color: iconColor),
            ),
          ),
          TextSpan(text: title),
        ],
      ),
      style: Theme.of(context).textTheme.titleMedium,
    ),
    action: action,
  );
}
