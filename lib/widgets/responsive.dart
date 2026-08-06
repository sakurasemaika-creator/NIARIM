import 'package:flutter/material.dart';

/// 画面幅がこの値以上の場合、PC/DeXモード向けのプロ仕様レイアウト
/// （パネルをフローティング表示ではなく常時ドッキング表示にする等）へ切り替える。
const double kDesktopBreakpoint = 840;

bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
