import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

/// 画面幅がこの値以上の場合、PC/DeXモード向けのプロ仕様レイアウト
/// （パネルをフローティング表示ではなく常時ドッキング表示にする等）へ切り替える。
const double kDesktopBreakpoint = 840;

/// PC/DeXモードかどうかを判定する。ワークスペース設定で手動指定されていれば
/// それを優先し（仕様書02）、未指定（自動）の場合は画面幅で判定する。
bool isWideScreen(BuildContext context) {
  final forced = context.watch<SettingsService>().forcePcMode;
  if (forced != null) return forced;
  return MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
}

/// 設定画面等のリスト系コンテンツをPC/DeXモードで中央寄せ・横幅制限する。
/// スマホの狭い画面ではそのまま全幅表示する。
///
/// あわせて、Android標準のジェスチャーナビゲーション/戻るボタン等の
/// システムUIとアプリ内のボタン・テキストが重なる不具合対策として
/// SafeAreaで包む。以前はScaffold.bodyへ直接置かれるだけの画面が
/// 多く、画面下端のボタンがシステムナビゲーションバーと重なる場合が
/// あった（Scaffoldはbody全体を自動ではセーフエリア化しない）。この
/// 関数を使う画面はここで一括対応される。
Widget desktopCentered(BuildContext context, Widget child, {double maxWidth = 720}) {
  if (!isWideScreen(context)) return SafeArea(child: child);
  return SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}
