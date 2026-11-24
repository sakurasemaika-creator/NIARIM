import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';

/// PC/DeXモードかどうかを判定する。ワークスペース設定で手動指定されていれば
/// 画面の向きに関わらずそれを優先する。未指定（自動）の場合は、画面が
/// 横向き（幅>高さ）かつマウス・スタイラス（ペンタブ等）のポインティング
/// デバイス接続を検知している（SettingsService.hasNonTouchPointer、
/// app.dartのListenerがポインターイベントのkindを渡して更新する）ときの
/// みPCモードとし、それ以外は常にスマホモードとする。
/// [listen]は既定でtrue（build時の使用を想定し、設定変更時に再ビルド
/// される）。イベントハンドラ（onPressed等）から呼ぶ場合はfalseを渡す
/// こと（build外でwatch()すると例外になる）。
///
/// 窓の幅が[kMinPcWorkspaceWidth]より狭いときは、PCモードを選んでいても
/// スマホの画面にする（PCの作業画面はキャンバスの横に2つのドック、
/// タイムラインは3つの欄を並べるので、狭い窓ではドックの中身がはみ出し
/// 使えなかった）。
bool isWideScreen(BuildContext context, {bool listen = true}) {
  final settings = listen
      ? context.watch<SettingsService>()
      : context.read<SettingsService>();
  final size = MediaQuery.sizeOf(context);
  if (size.width < kMinPcWorkspaceWidth) return false;
  final forced = settings.forcePcMode;
  if (forced != null) return forced;
  final isLandscape = size.width > size.height;
  return isLandscape && settings.hasNonTouchPointer;
}

/// PCの作業画面（キャンバスの両側のドック・タイムラインの3つの欄）が
/// 収まる一番狭い窓の幅。
const double kMinPcWorkspaceWidth = 600;

/// 手のひらツール（画面移動専用）を実際にツールバーへ表示してよいかを
/// 判定する。強制スマホモード（forcePcMode==false）では
/// 常に非表示。PCモード固定（true）または自動判定（null）の場合は、
/// その時点の画面が横向き（幅>高さ）のときのみ表示する。これにより、
/// 普段スマホ（縦画面）で使っているユーザーが、液タブへ接続してDeX
/// モード等で横画面になった際に自動でツールが現れるようにする。
/// [listen]は既定でtrue。isWideScreen同様、イベントハンドラから呼ぶ
/// 場合はfalseを渡すこと。
bool canShowPanTool(BuildContext context, {bool listen = true}) {
  final settings = listen
      ? context.watch<SettingsService>()
      : context.read<SettingsService>();
  final forced = settings.forcePcMode;
  if (forced == false) return false;
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height;
}

/// 設定画面等のリスト系コンテンツを、広い画面で中央に配置する。
/// 幅の上限はタッチ操作のタブレットにも適用する。
///
/// あわせて、Android標準のジェスチャーナビゲーション/戻るボタン等の
/// システムUIとアプリ内のボタン・テキストが重なる不具合対策として
/// SafeAreaで包む（Scaffoldはbody全体を自動ではセーフエリア化しないため、
/// 画面下端のボタンがシステムナビゲーションバーと重なる場合がある）。
/// この関数を使う画面はここで一括対応される。
Widget desktopCentered(
  BuildContext context,
  Widget child, {
  double maxWidth = 720,
}) {
  if (MediaQuery.sizeOf(context).width <= maxWidth) {
    return SafeArea(child: child);
  }
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

/// Align a trailing floating action with the end of [desktopCentered] content.
Widget desktopCenteredFloatingAction(
  BuildContext context,
  Widget child, {
  double maxWidth = 720,
}) {
  final availableWidth =
      MediaQuery.sizeOf(context).width -
      MediaQuery.paddingOf(context).horizontal;
  final inset = ((availableWidth - maxWidth) / 2).clamp(0.0, double.infinity);
  return Padding(
    padding: EdgeInsetsDirectional.only(end: inset),
    child: child,
  );
}
