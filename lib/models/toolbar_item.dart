import 'package:flutter/material.dart' show IconData, Icons;

/// ツールバーに表示するツール項目（仕様書08：ワークスペース設定＞ツールバー編集）。
/// 表示ON/OFF・並び順をカスタマイズ可能な項目のみを列挙する。
/// （色インジケーター・ブラシ設定・レイヤー・オニオンスキン・ツール早替え・
/// タイムラインは常設の操作導線のためカスタマイズ対象外）
enum ToolbarItemId {
  pen,
  eraser,
  bucket,
  eyedropper,
  finger,
  select,
  move,
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
        ToolbarItemId.move => '移動',
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
extension ToolbarItemIcon on ToolbarItemId {
  IconData get icon => switch (this) {
        ToolbarItemId.pen => Icons.brush,
        ToolbarItemId.eraser => Icons.auto_fix_high,
        ToolbarItemId.bucket => Icons.format_color_fill,
        ToolbarItemId.eyedropper => Icons.colorize,
        ToolbarItemId.finger => Icons.back_hand,
        ToolbarItemId.select => Icons.crop_square,
        ToolbarItemId.move => Icons.open_with,
        ToolbarItemId.transform => Icons.transform,
        ToolbarItemId.ruler => Icons.straighten,
        ToolbarItemId.text => Icons.text_fields,
        ToolbarItemId.shape => Icons.category,
        ToolbarItemId.filter => Icons.blur_on,
      };
}
