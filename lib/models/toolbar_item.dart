import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../l10n/app_localizations.dart';

/// ツールバーに表示するツール項目。
/// 表示ON/OFF・並び順をカスタマイズ可能な項目のみを列挙する。
/// （色インジケーター・ブラシ設定・レイヤー・ツール早替えは常設の操作導線
/// のためカスタマイズ対象外）
/// 移動（move）は、2本指でのキャンバス平行移動と役割が重複するツール専用
/// ボタンのためここには含めない。DrawingTool.move自体（機能）は削除して
/// おらず、引き続き到達可能。
/// 定規（ruler）はキャンバス上部バーの常設ボタンのため、ここには含めない
/// （重複ボタン防止）。
/// フィルター（filter）・オニオンスキンは上部バーの「設定/編集」メニューに
/// 集約されているため、フィルターはここには含めない（オニオンスキンは
/// 元々カスタマイズ対象外の常設項目）。
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
/// 〔マジックワンド〕用アイコンと紛らわしかったため変更）。消しゴム・
/// 図形・定規はMaterial Iconsに適切なグリフがない／曖昧なため、
/// Font Awesome Free（font_awesome_flutter、CC BY 4.0。クレジットは
/// 設定＞利用規約・ライセンス画面に表示）のアイコンを使う。
extension ToolbarItemIcon on ToolbarItemId {
  // Material Iconsの標準アイコンを使う項目はIconDataを、Font Awesome
  // （font_awesome_flutter）を使う項目はFaIconDataを返す。FaIconDataは
  // 通常のIcon()では正しく描画されない（クリッピング崩れ）ため、[buildIcon]
  // 経由で常に適切なウィジェットへ変換して使うこと。
  Object get _iconData => switch (this) {
    ToolbarItemId.pen => Icons.brush,
    ToolbarItemId.eraser => FontAwesomeIcons.eraser,
    // バケツ塗り：Material Iconsの汎用的な「塗り」アイコンより、
    // Font Awesomeのペンキ缶（滴付き）の方がバケツ塗りらしいため変更。
    ToolbarItemId.bucket => FontAwesomeIcons.fillDrip,
    ToolbarItemId.eyedropper => Icons.colorize,
    // 指先ツール（歪み）：人差し指を立てたアイコンを使う
    // （以前のback_handは掌全体を広げた「手のひら」の形で紛らわしく、
    // 手のひらツール〔画面移動〕の方へ移した）。
    ToolbarItemId.finger => Icons.pan_tool_alt,
    ToolbarItemId.pan => Icons.back_hand,
    ToolbarItemId.select => Icons.highlight_alt,
    ToolbarItemId.transform => Icons.transform,
    ToolbarItemId.text => Icons.text_fields,
    // 図形ツール：Font Awesomeの「shapes」（複数の図形を重ねた見た目）が
    // Material Iconsのcategory（三角形1つ）よりも図形選択ツールらしいため変更。
    ToolbarItemId.shape => FontAwesomeIcons.shapes,
  };

  /// [_iconData]の種類（Material／Font Awesome）を意識せず、常に正しく
  /// 描画できるアイコンウィジェットを組み立てる。
  Widget buildIcon({required double size, Color? color}) {
    final data = _iconData;
    return data is FaIconData
        ? FaIcon(data, size: size, color: color)
        : Icon(data as IconData, size: size, color: color);
  }
}
