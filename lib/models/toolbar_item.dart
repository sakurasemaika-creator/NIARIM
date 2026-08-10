import 'package:flutter/material.dart' show IconData, Icons;

/// ツールバーに表示するツール項目（仕様書08：ワークスペース設定＞ツールバー編集）。
/// 表示ON/OFF・並び順をカスタマイズ可能な項目のみを列挙する。
/// （色インジケーター・ブラシ設定・レイヤー・オニオンスキン・ツール早替え・
/// タイムラインは常設の操作導線のためカスタマイズ対象外）
/// 移動（move）は仕様書08・タスク#95により削除した：2本指でのキャンバス
/// 平行移動（タスク#89で実装済み）と役割が重複するツール専用ボタンのため。
/// DrawingTool.move自体（機能）は削除しておらず、引き続き到達可能。
enum ToolbarItemId {
  pen,
  eraser,
  bucket,
  eyedropper,
  finger,
  select,
  transform,
  ruler,
  text,
  shape,
  filter,
}

extension ToolbarItemLabel on ToolbarItemId {
  String get label => switch (this) {
        ToolbarItemId.pen => 'Gペン',
        ToolbarItemId.eraser => '消しゴム',
        ToolbarItemId.bucket => 'バケツ',
        ToolbarItemId.eyedropper => 'スポイト',
        ToolbarItemId.finger => '指',
        ToolbarItemId.select => '選択',
        ToolbarItemId.transform => '変形',
        ToolbarItemId.ruler => '定規',
        ToolbarItemId.text => 'テキスト',
        ToolbarItemId.shape => '図形',
        ToolbarItemId.filter => 'フィルター',
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
        ToolbarItemId.ruler => Icons.straighten,
        ToolbarItemId.text => Icons.text_fields,
        ToolbarItemId.shape => Icons.category,
        ToolbarItemId.filter => Icons.blur_on,
      };
}
