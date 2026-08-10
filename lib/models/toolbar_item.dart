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
        ToolbarItemId.select => l10n.toolbarItemSelect,
        ToolbarItemId.transform => l10n.toolbarItemTransform,
        ToolbarItemId.text => l10n.toolbarItemText,
        ToolbarItemId.shape => l10n.toolbarItemShape,
      };
}

/// ワークスペース設定＞ツールバー編集のプレビュー表示用アイコン
/// （実際のキャンバス画面のツールバー、toolbar_widget.dartと同じ
/// アイコンを使う。選択ツールは既定状態＝矩形選択のアイコンとする）。
/// 消しゴムと選択ツールのアイコンはタスク#95で入れ替えた
/// （消しゴムに割り当てられていたauto_fix_highが「魔法の杖」風で、
/// 選択ツールの自動選択〔マジックワンド〕用アイコンと紛らわしかった）。
extension ToolbarItemIcon on ToolbarItemId {
  IconData get icon => switch (this) {
        ToolbarItemId.pen => Icons.brush,
        ToolbarItemId.eraser => Icons.crop_square,
        ToolbarItemId.bucket => Icons.format_color_fill,
        ToolbarItemId.eyedropper => Icons.colorize,
        ToolbarItemId.finger => Icons.back_hand,
        ToolbarItemId.select => Icons.auto_fix_high,
        ToolbarItemId.transform => Icons.transform,
        ToolbarItemId.text => Icons.text_fields,
        ToolbarItemId.shape => Icons.category,
      };
}
