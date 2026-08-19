import 'package:flutter/material.dart' show IconData, Icons;
import '../l10n/app_localizations.dart';

/// ツールバーに表示するツール項目（仕様書08：ワークスペース設定＞ツールバー編集）。
/// 表示ON/OFF・並び順をカスタマイズ可能な項目のみを列挙する。
/// （色インジケーター・ブラシ設定・レイヤー・ツール早替えは常設の操作導線
/// のためカスタマイズ対象外）
/// 移動（move）は仕様書08・タスク#95により削除した：2本指でのキャンバス
/// 平行移動（タスク#89で実装済み）と役割が重複するツール専用ボタンのため。
/// DrawingTool.move自体（機能）は削除しておらず、引き続き到達可能。
/// 定規（ruler）は仕様書08・タスク#95によりキャンバス上部バーの常設ボタン
/// へ昇格したため、ここからは削除した（重複ボタン防止）。
/// フィルター（filter）・オニオンスキンは仕様書08・タスク#95により上部
/// バーの「設定/編集」メニューへ集約したため、フィルターはここから削除
/// した（オニオンスキンは元々カスタマイズ対象外の常設項目だった）。
enum ToolbarItemId {
  pen,
  eraser,
  bucket,
  eyedropper,
  finger,
  // 手のひらツール（画面移動専用）。強制スマホモードでは
  // 設定自体を変更不可（グレーアウト）にし、それ以外（PCモード固定・
  // 自動判定）では設定可能。実際にツールバーへ表示するかは横画面か
  // どうかで動的に決まる（widgets/responsive.dartのcanShowPanTool参照）。
  // 2本指ドラッグでの画面移動はスマホモードでも可能だが、DeXモード等
  // 液タブ接続時に手のひらツールが自動で使えるようにするための項目。
  pan,
  select,
  transform,
  text,
  shape,
}

extension ToolbarItemLabel on ToolbarItemId {
  String label(AppLocalizations l10n) => switch (this) {
        ToolbarItemId.pen => l10n.toolbarItemPen,
        ToolbarItemId.eraser => l10n.toolbarItemEraser,
        ToolbarItemId.bucket => l10n.toolbarItemBucket,
        ToolbarItemId.eyedropper => l10n.toolbarItemEyedropper,
        ToolbarItemId.finger => l10n.toolbarItemFinger,
        ToolbarItemId.pan => l10n.toolbarItemPan,
        ToolbarItemId.select => l10n.toolbarItemSelect,
        ToolbarItemId.transform => l10n.toolbarItemTransform,
        ToolbarItemId.text => l10n.toolbarItemText,
        ToolbarItemId.shape => l10n.toolbarItemShape,
      };
}

/// ワークスペース設定＞ツールバー編集のプレビュー表示用アイコン
/// （実際のキャンバス画面のツールバー、toolbar_widget.dartと同じ
/// アイコンを使う。選択ツールは既定状態＝矩形選択のアイコンとする）。
/// 選択ツールはhighlight_alt（角に選択ハンドルが付いた矩形）を使う
/// （以前のauto_fix_highは「魔法の杖」風で、選択ツールの自動選択
/// 〔マジックワンド〕用アイコンと紛らわしかったため変更）。消しゴムは
/// このプレビュー用途では標準アイコン（backspace_outlined）を使うが、
/// 実際のツールバー本体（toolbar_widget.dart）では専用の自作アイコン
/// （EraserIcon）を使っている。
extension ToolbarItemIcon on ToolbarItemId {
  IconData get icon => switch (this) {
        ToolbarItemId.pen => Icons.brush,
        ToolbarItemId.eraser => Icons.backspace_outlined,
        ToolbarItemId.bucket => Icons.format_color_fill,
        ToolbarItemId.eyedropper => Icons.colorize,
        // 指先ツール（歪み）：人差し指を立てたアイコンを使う
        // （以前のback_handは掌全体を広げた「手のひら」の形で紛らわしく、
        // 手のひらツール〔画面移動〕の方へ移した）。
        ToolbarItemId.finger => Icons.pan_tool_alt,
        ToolbarItemId.pan => Icons.back_hand,
        ToolbarItemId.select => Icons.highlight_alt,
        ToolbarItemId.transform => Icons.transform,
        ToolbarItemId.text => Icons.text_fields,
        ToolbarItemId.shape => Icons.category,
      };
}
