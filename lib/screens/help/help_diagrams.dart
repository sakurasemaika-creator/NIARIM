import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// ヘルプページの図解。
///
/// Tips画面の`TipDiagramKind`（`tip_diagrams.dart`）は「その機能が何を
/// もたらすか」という抽象的な概念図だったのに対し、こちらは「実際の画面の
/// どこにその項目があるか」を示す簡易的な画面模式図（＋当該ボタンの箇所に
/// 白縁取りの赤丸マーカー、指定通り）を目的とする。画像アセットを使わず
/// CustomPaint（テーマの色に自動追従）で描く方針もTipsを踏襲している。
///
/// 60件超のヘルプ項目それぞれに専用の模式図を1つずつ手描きするのは現実的
/// でないため、実際の画面の種類ごとに汎用テンプレート（[HelpScreenTemplate]）
/// を少数用意し、各テンプレートが持つ「要素スロット」のうち何番目を指す
/// かだけを各ヘルプ項目側で指定する（[HelpDiagramSpec.slotIndex]）方式にした。
/// 各スロットは単なる色付き四角ではなく、実際にアプリ内で使われている
/// アイコン（Material Icons／Font Awesome。toolbar_item.dartの実アイコン
/// 割り当てに合わせたもの）をCanvas上へ描画し、実画面に近い見た目にする。
/// 個々のヘルプ項目側でテンプレート既定のアイコンと異なるものを示したい
/// 場合は[HelpDiagramSpec.icon]で上書きできる。
enum HelpScreenTemplate {
  /// キャンバス下部ツールバー（アイコンが横一列）。ペン・消しゴム・バケツ等の
  /// 描画ツール系の項目で使う。7スロット。
  toolbarRow,
  /// キャンバス上部バー（右寄りにアイコンが横一列）。編集メニュー経由の項目
  /// （変形・回転、筆圧カーブ導線等）や自動保存で使う。4スロット。
  topBar,
  /// レイヤーパネル（行が縦に並ぶリスト、各行にサムネイル＋名前＋目アイコン）。
  /// レイヤー関連の項目で使う。4スロット。
  layerPanelList,
  /// フローティングパネル（タイトル行＋設定行2つ＋スライダー行）。オニオン
  /// スキン・定規・各種設定画面など、単独のパネル/画面で完結する項目で使う。
  /// 4スロット（0=タイトル/閉じる、1・2=設定行、3=スライダー）。
  floatingPanel,
  /// タイムラインのトラック帯（横長の帯にクリップが並ぶ）。タイムライン・
  /// シーン・フレーム操作・素材・カメラキーフレーム・演出フィルター等で使う。
  /// 5スロット。
  timelineTrack,
  /// セーブツリー／スロットのリスト（サムネイル＋行が縦に並ぶ）。保存関連の
  /// 項目で使う。3スロット。
  saveList,
  /// 書き出し形式選択（チップが横に3つ並ぶ）。書き出し関連の項目で使う。
  /// 3スロット。
  exportPicker,
  /// キャンバス作画エリア（白／市松の矩形＋下に小さなツールバー）。描画領域・
  /// 背景色・トーン塗り等、キャンバスの表示そのものに関する項目で使う。
  /// 2スロット（0=キャンバス本体、1=下の小さなツールバー）。
  canvasArea,
  /// カード一覧（矩形カードが2×2に並ぶ）。ホーム画面・プロジェクト管理系の
  /// 項目で使う。4スロット。
  cardGrid,
}

/// 1つのヘルプ項目に添える図解の指定。[slotIndex]は[template]が持つ要素
/// スロットのうち、どれが「当該ボタン・要素」かを指す（0始まり、範囲外は
/// 自動的にクランプされる）。[icon]を指定すると、そのスロットのアイコンを
/// テンプレート既定のものから差し替えられる（省略時はテンプレート既定の
/// 実アイコンをそのまま使う）。
class HelpDiagramSpec {
  final HelpScreenTemplate template;
  final int slotIndex;
  final IconData? icon;
  const HelpDiagramSpec(this.template, this.slotIndex, {this.icon});
}

class HelpDiagram extends StatelessWidget {
  final HelpDiagramSpec spec;
  const HelpDiagram(this.spec, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: const Size(double.infinity, 92),
      painter: _HelpDiagramPainter(spec, scheme),
    );
  }
}

class _HelpDiagramPainter extends CustomPainter {
  final HelpDiagramSpec spec;
  final ColorScheme scheme;
  _HelpDiagramPainter(this.spec, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    switch (spec.template) {
      case HelpScreenTemplate.toolbarRow:
        _paintToolbarRow(canvas, size);
      case HelpScreenTemplate.topBar:
        _paintTopBar(canvas, size);
      case HelpScreenTemplate.layerPanelList:
        _paintLayerPanelList(canvas, size);
      case HelpScreenTemplate.floatingPanel:
        _paintFloatingPanel(canvas, size);
      case HelpScreenTemplate.timelineTrack:
        _paintTimelineTrack(canvas, size);
      case HelpScreenTemplate.saveList:
        _paintRowList(canvas, size, rows: 3, icons: _saveIcons, twoLines: true);
      case HelpScreenTemplate.exportPicker:
        _paintExportPicker(canvas, size);
      case HelpScreenTemplate.canvasArea:
        _paintCanvasArea(canvas, size);
      case HelpScreenTemplate.cardGrid:
        _paintCardGrid(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _HelpDiagramPainter oldDelegate) =>
      oldDelegate.spec.template != spec.template ||
      oldDelegate.spec.slotIndex != spec.slotIndex ||
      oldDelegate.spec.icon != spec.icon ||
      oldDelegate.scheme != scheme;

  // ── 共通パーツ ──────────────────────────────────────────────
  Paint get _fillMuted => Paint()..color = scheme.surfaceContainerHighest;
  Paint get _fillPrimaryFaint => Paint()..color = scheme.primary.withValues(alpha: 0.35);
  Paint get _strokeOutline => Paint()
    ..color = scheme.outlineVariant
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  /// 該当ボタンの箇所を指し示す縁取り付きの丸マーカーを描く。
  /// 色固定ではなく、テーマの背景色（縁取り）とエラー色（丸自体、
  /// どのテーマでも目立つよう用意されている警告・注目色）を使う。
  void _highlightMarker(Canvas canvas, Offset center, {double r = 11}) {
    final outline = Paint()
      ..color = scheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final mark = Paint()
      ..color = scheme.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, r, outline);
    canvas.drawCircle(center, r, mark);
  }

  /// [icon]の実際のグリフ（Material Icons／Font Awesome）をCanvasへ直接
  /// 描画する。画像アセットを使わずに「実際のアイコン」を再現するための
  /// 手段（Icon()ウィジェットと同じ仕組みをTextPainterで直接行う）。
  void _drawIcon(Canvas canvas, IconData icon, Offset center, {double size = 18, Color? color}) {
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color ?? scheme.onSurfaceVariant,
        ),
      )
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  int _clampSlot(int max) => spec.slotIndex.clamp(0, max - 1);

  // ── テンプレート ────────────────────────────────────────────

  /// キャンバス下部ツールバーの実アイコン（toolbar_widget.dartの
  /// _buildToolItemと同じ並び・同じアイコン：ペン・消しゴム・バケツ・
  /// スポイト・選択・指ツール・図形）。バケツ・図形はMaterial Icons標準の
  /// 汎用アイコン（塗り・三角形）ではなく、実装がFont Awesomeへ変更した
  /// ペンキ缶（fillDrip）・複数図形（shapes）を使う（models/toolbar_item.dart
  /// のToolbarItemIcon._iconData参照）。
  static final List<IconData> _toolbarIcons = [
    Icons.brush,
    FontAwesomeIcons.eraser.data,
    FontAwesomeIcons.fillDrip.data,
    Icons.colorize,
    Icons.highlight_alt,
    Icons.pan_tool_alt,
    FontAwesomeIcons.shapes.data,
  ];

  /// canvas_icon_button.dartと同じ「アイコンの形にぴったり沿う半透明の
  /// 黒い縁取り」を8方向へのわずかなオフセット重ね描きで再現する。実画面の
  /// ツールバーは背景を一切持たず、この縁取りだけでキャンバス上の視認性を
  /// 確保しているため、図解でも同じ手法を使うことで見た目を近づける。
  static const List<Offset> _iconOutlineOffsets = [
    Offset(-1, -1), Offset(0, -1), Offset(1, -1),
    Offset(-1, 0), Offset(1, 0),
    Offset(-1, 1), Offset(0, 1), Offset(1, 1),
  ];

  void _drawOutlinedIcon(Canvas canvas, IconData icon, Offset center, {double size = 15, required Color color}) {
    for (final o in _iconOutlineOffsets) {
      _drawIcon(canvas, icon, center + o, size: size, color: scheme.surfaceContainerHighest.withValues(alpha: 0.85));
    }
    _drawIcon(canvas, icon, center, size: size, color: color);
  }

  void _paintToolbarRow(Canvas canvas, Size size) {
    const slots = 7;
    final y = size.height * 0.62;
    // 実画面のツールバーはアイコン自体に背景を持たせず、キャンバスの
    // 内容の上に直接浮かべる構成（canvas_icon_button.dart参照）。図解では
    // 「キャンバスの中身」の代わりに濃色の帯を敷き、その上に同じ描画方式
    // （縁取り＋テーマの文字色／選択時は差し色。色固定をやめてテーマと
    // 連動させたcanvas_icon_button.dartの実装に合わせている）でアイコンを
    // 乗せる。
    final barRect = Rect.fromLTWH(4, y - 20, size.width - 8, 40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(6)),
      Paint()..color = scheme.inverseSurface.withValues(alpha: 0.82),
    );
    final w = barRect.width / slots;
    final target = _clampSlot(slots);
    for (int i = 0; i < slots; i++) {
      final cx = barRect.left + w * (i + 0.5);
      final isTarget = i == target;
      final icon = (isTarget ? spec.icon : null) ?? _toolbarIcons[i];
      _drawOutlinedIcon(canvas, icon, Offset(cx, y), color: isTarget ? scheme.primary : scheme.onInverseSurface);
      if (isTarget) _highlightMarker(canvas, Offset(cx, y));
    }
  }

  // canvas_screen.dart _buildTopBar()の実際の並び：左詰めにUndo・Redo、
  // Spacerを挟んで右詰めに定規・設定（編集メニュー、背景色・オニオンスキン・
  // フィルター・自由変形などを集約）・ヘルプ。4スロットは
  // 0=Undo・1=Redo・2=定規・3=設定に対応させる（ヘルプボタン自体はヘルプ
  // 項目の対象にならないため常時非ハイライトで添えるのみ）。
  static const List<IconData> _topBarIcons = [Icons.undo, Icons.redo, Icons.straighten, Icons.settings];

  void _paintTopBar(Canvas canvas, Size size) {
    const slots = 4;
    final y = size.height * 0.24;
    final barRect = Rect.fromLTWH(4, 4, size.width - 8, 24);
    canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(5)), _fillMuted);
    final target = _clampSlot(slots);
    // 左詰め2つ（Undo・Redo）
    const leftX = [18.0, 40.0];
    for (int i = 0; i < 2; i++) {
      final isTarget = i == target;
      final icon = (isTarget ? spec.icon : null) ?? _topBarIcons[i];
      _drawIcon(canvas, icon, Offset(leftX[i], y), size: 14, color: isTarget ? scheme.primary : scheme.onSurfaceVariant);
      if (isTarget) _highlightMarker(canvas, Offset(leftX[i], y), r: 12);
    }
    // 右詰め2つ＋ヘルプ（定規・設定・ヘルプの順）
    final rightX = [size.width - 46, size.width - 24, size.width - 4];
    for (int i = 2; i < slots; i++) {
      final isTarget = i == target;
      final icon = (isTarget ? spec.icon : null) ?? _topBarIcons[i];
      _drawIcon(canvas, icon, Offset(rightX[i - 2], y), size: 14, color: isTarget ? scheme.primary : scheme.onSurfaceVariant);
      if (isTarget) _highlightMarker(canvas, Offset(rightX[i - 2], y), r: 12);
    }
    _drawIcon(canvas, Icons.help_outline, Offset(rightX[2], y), size: 12,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.5));
    // 下に画面本体の枠だけ添えて「上部バー」であることを示す。
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.2, size.height * 0.48, size.width * 0.6, size.height * 0.44),
          const Radius.circular(6)),
      _strokeOutline,
    );
  }

  // layer_panel.dartの実際の行構成：目（表示切替）アイコン→レイヤー種別
  // アイコン→サムネイル→名前、の順で左から並ぶ（ListTile.leadingがRowで
  // それらをまとめている）。
  static const List<IconData> _layerTypeIcons = [
    Icons.brush_outlined, // 通常レイヤー
    Icons.folder_outlined, // フォルダ
    Icons.groups_outlined, // 共通レイヤー
    Icons.auto_fix_high_outlined, // 自動塗り
  ];
  static const List<IconData> _saveIcons = [Icons.save_outlined, Icons.history, Icons.bookmark_border];

  void _paintLayerPanelList(Canvas canvas, Size size) {
    const rows = 4;
    final rowH = size.height / rows;
    final target = _clampSlot(rows);
    for (int i = 0; i < rows; i++) {
      final top = i * rowH + 2;
      final rowRect = Rect.fromLTWH(4, top, size.width - 8, rowH - 4);
      final isTarget = i == target;
      canvas.drawRRect(RRect.fromRectAndRadius(rowRect, const Radius.circular(5)),
          isTarget ? _fillPrimaryFaint : _fillMuted);
      final cy = rowRect.center.dy;
      // 目（表示切替）アイコン：実画面と同じく行の一番左
      _drawIcon(canvas, Icons.visibility_outlined, Offset(rowRect.left + 12, cy), size: 12,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75));
      // レイヤー種別アイコン
      final typeIcon = _layerTypeIcons[i % _layerTypeIcons.length];
      _drawIcon(canvas, typeIcon, Offset(rowRect.left + 26, cy), size: 11, color: scheme.onSurfaceVariant);
      // サムネイル（対象行はここへ実アイコンを重ねて示す）
      final thumb = Rect.fromLTWH(rowRect.left + 34, rowRect.top + 4, rowRect.height - 8, rowRect.height - 8);
      canvas.drawRRect(RRect.fromRectAndRadius(thumb, const Radius.circular(3)), _strokeOutline);
      if (isTarget && spec.icon != null) {
        _drawIcon(canvas, spec.icon!, thumb.center, size: thumb.height * 0.5, color: scheme.primary);
      }
      // 名前のテキスト行
      final lineX = thumb.right + 8;
      canvas.drawLine(Offset(lineX, cy), Offset(rowRect.right - 20, cy),
          Paint()..color = scheme.onSurfaceVariant..strokeWidth = 2);
      // 行末のドラッグハンドル（実画面と同じ、並べ替え用）
      _drawIcon(canvas, Icons.drag_indicator, Offset(rowRect.right - 12, cy), size: 12,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55));
      if (isTarget) _highlightMarker(canvas, thumb.center, r: thumb.height * 0.6 + 4);
    }
  }

  // save_tree_screen.dartの実際の行構成：サムネイル→タイトル（1行目）・
  // 更新日時等（2行目）のListTile。レイヤーパネルと異なり目アイコンは無い。
  void _paintRowList(Canvas canvas, Size size,
      {required int rows, required List<IconData> icons, bool twoLines = false}) {
    final rowH = size.height / rows;
    final target = _clampSlot(rows);
    for (int i = 0; i < rows; i++) {
      final top = i * rowH + 3;
      final rowRect = Rect.fromLTWH(6, top, size.width - 12, rowH - 6);
      final isTarget = i == target;
      canvas.drawRRect(RRect.fromRectAndRadius(rowRect, const Radius.circular(5)),
          isTarget ? _fillPrimaryFaint : _fillMuted);
      final thumb = Rect.fromLTWH(rowRect.left + 6, rowRect.top + 4, rowRect.height - 8, rowRect.height - 8);
      canvas.drawRRect(RRect.fromRectAndRadius(thumb, const Radius.circular(3)), _strokeOutline);
      final icon = (isTarget ? spec.icon : null) ?? icons[i % icons.length];
      _drawIcon(canvas, icon, thumb.center, size: thumb.height * 0.55,
          color: isTarget ? scheme.primary : scheme.onSurfaceVariant);
      final lineX = thumb.right + 8;
      final linePaint = Paint()..color = scheme.onSurfaceVariant..strokeWidth = 2;
      canvas.drawLine(Offset(lineX, rowRect.top + rowRect.height * 0.35),
          Offset(rowRect.right - 10, rowRect.top + rowRect.height * 0.35), linePaint);
      if (twoLines) {
        canvas.drawLine(Offset(lineX, rowRect.top + rowRect.height * 0.65),
            Offset(lineX + (rowRect.width * 0.3), rowRect.top + rowRect.height * 0.65),
            Paint()..color = scheme.onSurfaceVariant.withValues(alpha: 0.6)..strokeWidth = 2);
      }
      if (isTarget) _highlightMarker(canvas, thumb.center, r: thumb.height * 0.6 + 4);
    }
  }

  // panel_close_bar.dartの実設計：閉じるボタン（×）はタイトル行の右端では
  // なく、パネル最上部・中央に単独で配置される（全パネル共通で
  // 「ポップアップ中央の×ボタンで閉じる」に統一）。閉じる操作自体が
  // ヘルプ項目の対象になることはまず無いため、ハイライト対象外の固定要素
  // として常に描く。
  void _paintFloatingPanel(Canvas canvas, Size size) {
    const slots = 4;
    final panel = Rect.fromLTWH(size.width * 0.08, 2, size.width * 0.84, size.height - 4);
    canvas.drawRRect(RRect.fromRectAndRadius(panel, const Radius.circular(8)), _fillMuted);
    canvas.drawRRect(RRect.fromRectAndRadius(panel, const Radius.circular(8)), _strokeOutline);
    final target = _clampSlot(slots);
    // 最上部中央：閉じるボタン（実画面と同じ配置。常時表示・非ハイライト）
    final closeY = panel.top + panel.height * 0.1;
    _drawIcon(canvas, Icons.close, Offset(panel.center.dx, closeY), size: 12,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.6));
    // 0: タイトル行（アイコン＋見出しテキスト）
    final titleY = panel.top + panel.height * 0.3;
    _drawIcon(canvas, target == 0 ? (spec.icon ?? Icons.tune) : Icons.tune, Offset(panel.left + 16, titleY),
        size: 14, color: target == 0 ? scheme.primary : scheme.onSurfaceVariant);
    canvas.drawLine(Offset(panel.left + 30, titleY), Offset(panel.left + panel.width * 0.6, titleY),
        Paint()..color = scheme.onSurfaceVariant..strokeWidth = 2.5);
    if (target == 0) _highlightMarker(canvas, Offset(panel.left + 16, titleY), r: 10);
    // 1・2: 設定行
    final row1Y = panel.top + panel.height * 0.52;
    _rowMark(canvas, panel, row1Y, target == 1, target == 1 ? spec.icon : null);
    final row2Y = panel.top + panel.height * 0.68;
    _rowMark(canvas, panel, row2Y, target == 2, target == 2 ? spec.icon : null);
    // 3: スライダー行
    final sliderY = panel.top + panel.height * 0.86;
    final sliderPaint = Paint()..color = scheme.outlineVariant..strokeWidth = 2;
    canvas.drawLine(Offset(panel.left + 12, sliderY), Offset(panel.right - 12, sliderY), sliderPaint);
    final handleX = panel.left + panel.width * 0.6;
    canvas.drawCircle(Offset(handleX, sliderY), 5,
        target == 3 ? (Paint()..color = scheme.primary) : (Paint()..color = scheme.onSurfaceVariant));
    if (target == 3) _highlightMarker(canvas, Offset(handleX, sliderY));
  }

  void _rowMark(Canvas canvas, Rect panel, double y, bool isTarget, IconData? icon) {
    final linePaint = Paint()
      ..color = isTarget ? scheme.primary : scheme.onSurfaceVariant
      ..strokeWidth = 3;
    canvas.drawLine(Offset(panel.left + 12, y), Offset(panel.left + panel.width * 0.55, y), linePaint);
    if (icon != null) {
      _drawIcon(canvas, icon, Offset(panel.right - 22, y), size: 13, color: scheme.primary);
    }
    if (isTarget) _highlightMarker(canvas, Offset(panel.right - 20, y), r: 9);
  }

  static const List<IconData> _timelineIcons = [
    Icons.image_outlined,
    Icons.auto_awesome,
    Icons.crop_free,
    Icons.perm_media_outlined,
    Icons.videocam_outlined,
  ];

  void _paintTimelineTrack(Canvas canvas, Size size) {
    const slots = 5;
    final y = size.height * 0.55;
    canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), _strokeOutline);
    final w = (size.width - 16) / slots;
    final target = _clampSlot(slots);
    for (int i = 0; i < slots; i++) {
      final cx = 8 + w * (i + 0.5);
      final isTarget = i == target;
      final clip = Rect.fromCenter(center: Offset(cx, y), width: w - 10, height: 22);
      canvas.drawRRect(RRect.fromRectAndRadius(clip, const Radius.circular(3)),
          isTarget ? (Paint()..color = scheme.primary) : _fillMuted);
      final icon = (isTarget ? spec.icon : null) ?? _timelineIcons[i];
      _drawIcon(canvas, icon, Offset(cx, y), size: 13, color: isTarget ? scheme.onPrimary : scheme.onSurfaceVariant);
      if (isTarget) _highlightMarker(canvas, Offset(cx, y), r: 16);
    }
  }

  // 実画面（export_screen.dart）の書き出し形式選択はRadioListTileの縦並び
  // （MP4・GIF・透過WebMの順）のため、横並びチップではなくラジオボタン付きの
  // 縦リストとして再現する。
  static const List<IconData> _exportIcons = [Icons.movie_outlined, Icons.gif_box_outlined, Icons.layers_outlined];

  void _paintExportPicker(Canvas canvas, Size size) {
    const rows = 3;
    final rowH = size.height / rows;
    final target = _clampSlot(rows);
    for (int i = 0; i < rows; i++) {
      final isTarget = i == target;
      final cy = rowH * (i + 0.5);
      // ラジオボタン
      final radioCenter = Offset(20, cy);
      canvas.drawCircle(radioCenter, 6, Paint()
        ..color = isTarget ? scheme.primary : scheme.onSurfaceVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
      if (isTarget) canvas.drawCircle(radioCenter, 3, Paint()..color = scheme.primary);
      // アイコン
      final icon = (isTarget ? spec.icon : null) ?? _exportIcons[i];
      _drawIcon(canvas, icon, Offset(40, cy), size: 15, color: isTarget ? scheme.primary : scheme.onSurfaceVariant);
      // タイトル・サブタイトル行（実画面はRadioListTileでtitle+subtitleの2段）
      final lineX = 54.0;
      canvas.drawLine(Offset(lineX, cy - 4), Offset(size.width - 16, cy - 4),
          Paint()..color = scheme.onSurfaceVariant..strokeWidth = 2);
      canvas.drawLine(Offset(lineX, cy + 6), Offset(lineX + (size.width - lineX) * 0.5, cy + 6),
          Paint()..color = scheme.onSurfaceVariant.withValues(alpha: 0.55)..strokeWidth = 1.5);
      if (isTarget) _highlightMarker(canvas, Offset(40, cy), r: 14);
      if (i < rows - 1) {
        canvas.drawLine(Offset(8, rowH * (i + 1)), Offset(size.width - 8, rowH * (i + 1)), _strokeOutline);
      }
    }
  }

  void _paintCanvasArea(Canvas canvas, Size size) {
    final canvasRect = Rect.fromLTWH(size.width * 0.18, 4, size.width * 0.64, size.height * 0.72);
    // 市松模様（透過・背景色を意識させる）
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(canvasRect, const Radius.circular(6)));
    final cell = canvasRect.width / 6;
    final checker = Paint()..color = scheme.outlineVariant.withValues(alpha: 0.4);
    for (int gy = 0; gy * cell < canvasRect.height; gy++) {
      for (int gx = 0; gx < 6; gx++) {
        if ((gx + gy).isEven) continue;
        canvas.drawRect(
            Rect.fromLTWH(canvasRect.left + gx * cell, canvasRect.top + gy * cell, cell, cell), checker);
      }
    }
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(canvasRect, const Radius.circular(6)), _strokeOutline);
    final toolbarRect = Rect.fromLTWH(size.width * 0.28, size.height * 0.84, size.width * 0.44, size.height * 0.14);
    canvas.drawRRect(RRect.fromRectAndRadius(toolbarRect, const Radius.circular(4)), _fillMuted);
    // 下部ミニツールバーに実際のツールアイコンを小さく3つ並べる
    for (int i = 0; i < 3; i++) {
      final cx = toolbarRect.left + toolbarRect.width * (i + 0.5) / 3;
      _drawIcon(canvas, _toolbarIcons[i], Offset(cx, toolbarRect.center.dy), size: 9,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8));
    }
    final target = _clampSlot(2);
    if (target == 0) {
      if (spec.icon != null) _drawIcon(canvas, spec.icon!, canvasRect.center, size: 20, color: scheme.primary);
      _highlightMarker(canvas, canvasRect.center, r: 18);
    } else {
      _highlightMarker(canvas, toolbarRect.center, r: 10);
    }
  }

  static const List<IconData> _cardIcons = [
    Icons.movie_creation_outlined,
    Icons.folder_outlined,
    Icons.ios_share_outlined,
    Icons.workspace_premium_outlined,
  ];

  // project_list_widget.dartの実カード構成：サムネイル領域（上部、
  // お気に入りは右上に星バッジ）＋名前ラベル行（下部、カードの外ではなく
  // 内側の帯）。
  void _paintCardGrid(Canvas canvas, Size size) {
    const cols = 2, rows = 2;
    final target = _clampSlot(cols * rows);
    final cw = (size.width - 24) / cols;
    final ch = (size.height - 16) / rows;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final i = r * cols + c;
        final rect = Rect.fromLTWH(8 + c * (cw + 8), 4 + r * (ch + 8), cw, ch);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        final isTarget = i == target;
        canvas.drawRRect(rr, _fillMuted);
        canvas.drawRRect(rr, isTarget ? (Paint()
          ..color = scheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2) : _strokeOutline);
        // サムネイル領域（下の名前帯を除いた上側）
        final thumbRect = Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height - 14);
        final icon = (isTarget ? spec.icon : null) ?? _cardIcons[i % _cardIcons.length];
        _drawIcon(canvas, icon, thumbRect.center, size: 16, color: isTarget ? scheme.primary : scheme.onSurfaceVariant);
        // お気に入り星バッジ（右上）
        _drawIcon(canvas, Icons.star, Offset(rect.right - 9, rect.top + 8), size: 9,
            color: Colors.amber.withValues(alpha: 0.8));
        // 名前ラベル行（下部の帯）
        canvas.drawLine(Offset(rect.left + 6, rect.bottom - 7), Offset(rect.right - 16, rect.bottom - 7),
            Paint()..color = scheme.onSurfaceVariant.withValues(alpha: 0.7)..strokeWidth = 1.5);
        if (isTarget) _highlightMarker(canvas, thumbRect.center, r: 12);
      }
    }
  }
}
