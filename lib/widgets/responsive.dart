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
bool isWideScreen(BuildContext context, {bool listen = true}) {
  final settings =
      listen ? context.watch<SettingsService>() : context.read<SettingsService>();
  final forced = settings.forcePcMode;
  if (forced != null) return forced;
  final size = MediaQuery.sizeOf(context);
  final isLandscape = size.width > size.height;
  return isLandscape && settings.hasNonTouchPointer;
}

/// 手のひらツール（画面移動専用）を実際にツールバーへ表示してよいかを
/// 判定する。強制スマホモード（forcePcMode==false）では
/// 常に非表示。PCモード固定（true）または自動判定（null）の場合は、
/// その時点の画面が横向き（幅>高さ）のときのみ表示する。これにより、
/// 普段スマホ（縦画面）で使っているユーザーが、液タブへ接続してDeX
/// モード等で横画面になった際に自動でツールが現れるようにする。
/// [listen]は既定でtrue。isWideScreen同様、イベントハンドラから呼ぶ
/// 場合はfalseを渡すこと。
bool canShowPanTool(BuildContext context, {bool listen = true}) {
  final settings =
      listen ? context.watch<SettingsService>() : context.read<SettingsService>();
  final forced = settings.forcePcMode;
  if (forced == false) return false;
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height;
}

/// 設定画面等のリスト系コンテンツをPC/DeXモードで中央寄せ・横幅制限する。
/// スマホの狭い画面ではそのまま全幅表示する。
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
