import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/color_palette.dart';
import '../services/export_share_service.dart';
import '../services/pixel_art_palette_service.dart';
import '../widgets/confirm_delete.dart';
import 'export_share_feedback.dart';
import 'pixel_art_palette_edit_dialog.dart';
import 'qr_import_dialog.dart';
import 'qr_share_dialog.dart';
import 'scrollable_sheet_body.dart';

/// 「パレットから選ぶ」のポップアップ。保存済みのドット絵専用パレット一覧
/// （[PixelArtPaletteService]）から1つタップして選択し、「適用」を押すと
/// そのパレットの色リストを[Navigator.pop]の戻り値として返す
/// （呼び出し側はこれを[PixelColorMode.explicit]の色として複製する
/// スナップショット方式。以後パレットを編集してもこの適用結果には
/// 影響しない）。各行には編集・削除ボタンがあり、新規パレットは
/// 「追加」ボタンから[PixelArtPaletteEditDialog]で作成する。
class PixelArtPalettePickerDialog extends StatefulWidget {
  const PixelArtPalettePickerDialog({super.key});

  /// 一覧の高さの上限（パレットが多くても、ダイアログを画面いっぱいにしない）。
  static const double maxListExtent = 360;

  /// 一覧の1行分の高さの目安（名前1行・色見本・上下の余白。行の操作を名前の
  /// 下に置くときはその段も）。下のボタンを固定するかどうかの境目に使う。
  static double oneRowExtent({
    required double textScale,
    required bool actionsBeside,
  }) => math.max(72, 16 + 24 * textScale + 14 + (actionsBeside ? 0 : 48));

  /// 下のボタン（追加・読み込み・キャンセル・適用）を、送らなくても見える所に
  /// 固定できるか。
  ///
  /// ダイアログに使える高さ[available]に、見出し[header]と下のボタン[footer]を
  /// 置いて、一覧に1行分[oneRow]が残れば固定する。共有できなかった知らせ
  /// [notice]が出ている間は、知らせを置いても半行分が残れば固定のまま（一覧と
  /// 知らせで残りを分け合う）。残らないときは、見出しからボタンまでを1つの
  /// スクロールで送る。
  static bool pinsFooter({
    required double available,
    required double header,
    required double footer,
    required double notice,
    required double oneRow,
  }) {
    final room = available - header - footer;
    return room >= oneRow && (notice <= 0 || room - notice >= oneRow / 2);
  }

  @override
  State<PixelArtPalettePickerDialog> createState() =>
      _PixelArtPalettePickerDialogState();
}

class _PixelArtPalettePickerDialogState
    extends State<PixelArtPalettePickerDialog> {
  String? _selectedId;
  // パレットを共有できなかった理由。このダイアログは開いたままなので、
  // SnackBar（ダイアログの幕の下に隠れる）ではなくダイアログの中に出す。
  Object? _shareError;
  final _shareNoticeKey = GlobalKey();

  static String _shareKey(ColorPalette palette) =>
      'pixel-palette:${palette.id}';

  /// .niapixelpaletteへ書き出してから共有する。書き出しの失敗と、共有できない
  /// 端末・共有の失敗は別のことなので、別の文で知らせる（共有の方は
  /// ダイアログの中に出し、次に共有を始めるときに消す）。終わるまで、
  /// そのパレットの共有ボタンは押せない。
  Future<void> _sharePaletteFile(
    AppLocalizations l10n,
    PixelArtPaletteService service,
    ColorPalette palette,
  ) async {
    await ExportShareService.runExclusive(_shareKey(palette), () async {
      if (!mounted) return;
      setState(() => _shareError = null);
      final File file;
      try {
        file = await service.exportPalette(palette.id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.colorPickerShareFailedSnackbar(e.toString())),
          ),
        );
        return;
      }
      if (!mounted) return;
      final error = await shareExportedFileCatching(context, file);
      if (error == null || !mounted) return;
      setState(() => _shareError = error);
      revealExportShareNotice(_shareNoticeKey);
    });
    // 共有が終わったので、共有ボタンをまた押せるようにする。
    if (mounted) setState(() {});
  }

  void _openEditor({ColorPalette? existing}) {
    showDialog(
      context: context,
      builder: (_) => PixelArtPaletteEditDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete(ColorPalette palette) async {
    final ok = await confirmDelete(context, itemName: palette.name);
    if (!ok || !mounted) return;
    await context.read<PixelArtPaletteService>().deletePalette(palette.id);
    if (_selectedId == palette.id) setState(() => _selectedId = null);
  }

  void _showShareSheet(ColorPalette palette) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<PixelArtPaletteService>();
    final payload = jsonEncode(palette.toJson());
    final qrAvailable = payload.length <= kQrShareSafeCharLimit;
    showModalBottomSheet(
      context: context,
      // 低い画面・大きな文字では2行が入りきらないので、送れるようにする。
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.colorPickerShareViaFile),
              onTap: () {
                Navigator.pop(ctx);
                _sharePaletteFile(l10n, service, palette);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n.colorPickerShareViaQr),
              subtitle: qrAvailable ? null : Text(l10n.qrShareTooLargeHint),
              onTap: qrAvailable
                  ? () {
                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        builder: (_) => QrShareDialog(
                          title: palette.name,
                          payload: payload,
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showImportSheet() {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<PixelArtPaletteService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.colorPickerImportViaFile),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['niapixelpalette'],
                );
                final path = result?.files.firstOrNull?.path;
                if (path == null) return;
                try {
                  await service.importPaletteFile(path);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.colorPickerImportFailedSnackbar(e.toString()),
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n.colorPickerImportViaQr),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => QrImportDialog(
                    title: l10n.colorPickerImportViaQr,
                    onImport: (text) async {
                      await service.importPaletteJson(text);
                      return true;
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _paletteRow(
    AppLocalizations l10n,
    ColorPalette p, {
    required bool actionsBeside,
  }) => _PaletteRow(
    palette: p,
    selected: p.id == _selectedId,
    actionsBeside: actionsBeside,
    onSelect: () => setState(() => _selectedId = p.id),
    actions: [
      IconButton(
        icon: const Icon(Icons.share_outlined, size: 20),
        tooltip: l10n.colorPickerSharePaletteTooltip,
        onPressed: ExportShareService.isRunning(_shareKey(p))
            ? null
            : () => _showShareSheet(p),
      ),
      IconButton(
        icon: const Icon(Icons.edit_outlined, size: 20),
        tooltip: l10n.commonEdit,
        onPressed: () => _openEditor(existing: p),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        tooltip: l10n.commonDelete,
        onPressed: () => _confirmDelete(p),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palettes = context.watch<PixelArtPaletteService>().palettes;
    final selected = palettes.where((p) => p.id == _selectedId).firstOrNull;
    final screen = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // 文字を大きくしているときは左右と上の余白を詰める（Materialの
    // ダイアログの見出し・本文と同じ決まり）。
    final side = 24 * lerpDouble(1, 1 / 3, (textScale.clamp(1, 2) - 1))!;
    final titleStyle =
        DialogTheme.of(context).titleTextStyle ??
        Theme.of(context).textTheme.headlineSmall!;

    // 見出し・一覧・知らせ・下のボタンを自分で並べる（[_PickerSections]）。
    // Materialのダイアログの「下のボタン」は常に固定で、とても低い画面では
    // 一覧も知らせも出せなくなり、中身を丸ごと送る作りにすると、今度は
    // 「適用」が一覧の下へ流れて、パレットを選ぶたびに送ることになった。
    return AlertDialog(
      // 狭い・低い画面では周りの余白を詰めて、中身に場所を残す。
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 480 ? 16 : 40,
        vertical: screen.height < 520 ? 16 : 24,
      ),
      contentPadding: EdgeInsets.zero,
      // 行の選択色が、ダイアログの角の丸みの外へ出ないようにする。
      clipBehavior: Clip.antiAlias,
      content: SizedBox(
        width: double.maxFinite,
        child: LayoutBuilder(
          builder: (context, box) {
            // 名前に十分な幅を残せるときだけ、行の操作を右端に並べる。
            final actionsBeside =
                box.maxWidth - side * 2 >= 240 + 140 * textScale;
            return SingleChildScrollView(
              // 一覧も縦に送るので、どちらも画面のコントローラーを使わない。
              primary: false,
              child: _PickerSections(
                viewportExtent: box.maxHeight,
                minListExtent: PixelArtPalettePickerDialog.oneRowExtent(
                  textScale: textScale,
                  actionsBeside: actionsBeside,
                ),
                maxListExtent: PixelArtPalettePickerDialog.maxListExtent,
                header: Padding(
                  key: const Key('pixelPaletteHeader'),
                  padding: EdgeInsets.fromLTRB(side, side, side, 16),
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      l10n.pixelArtPalettePickerTitle,
                      style: titleStyle,
                    ),
                  ),
                ),
                list: Padding(
                  key: const Key('pixelPaletteList'),
                  padding: EdgeInsets.symmetric(horizontal: side),
                  // 行の選択色はMaterialへ描かれる。一覧の中にMaterialを
                  // 置いて切り抜かないと、送って隠れた行の色が見出しや
                  // 下のボタンの上にはみ出す。
                  child: Material(
                    type: MaterialType.transparency,
                    clipBehavior: Clip.hardEdge,
                    child: palettes.isEmpty
                        ? SingleChildScrollView(
                            primary: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(l10n.pixelArtPalettePickerEmpty),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            primary: false,
                            padding: EdgeInsets.zero,
                            itemCount: palettes.length,
                            itemBuilder: (context, index) => _paletteRow(
                              l10n,
                              palettes[index],
                              actionsBeside: actionsBeside,
                            ),
                          ),
                  ),
                ),
                notice: _shareError == null
                    ? const SizedBox.shrink(key: Key('pixelPaletteNotice'))
                    : Padding(
                        key: const Key('pixelPaletteNotice'),
                        padding: EdgeInsets.fromLTRB(side, 12, side, 0),
                        child: ExportShareNotice(
                          key: _shareNoticeKey,
                          message: exportShareFailureText(l10n, _shareError!),
                        ),
                      ),
                footer: Padding(
                  key: const Key('pixelPaletteFooter'),
                  padding: EdgeInsets.fromLTRB(side, 24, side, 24),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 8,
                    overflowSpacing: 4,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openEditor(),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.commonAdd),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_outlined),
                            tooltip: l10n.colorPickerImportPaletteTooltip,
                            onPressed: _showImportSheet,
                          ),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.commonCancel),
                          ),
                          FilledButton(
                            onPressed: selected == null
                                ? null
                                : () => Navigator.of(
                                    context,
                                  ).pop(selected.colors),
                            child: Text(l10n.pixelArtPalettePickerApplyButton),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 見出し・一覧・知らせ・下のボタンを縦に並べる。
///
/// [PixelArtPalettePickerDialog.pinsFooter]が真なら、一覧だけを残りの高さ
/// （最大[maxListExtent]）に収めて自分の中で送らせ、全体は[viewportExtent]
/// （ダイアログに使える高さ）に収まる＝下のボタンは送らなくても見える。
/// 偽なら、一覧を縮めずに全部を並べる（外側のスクロールが全体を送る）。
/// 子の実際の高さで決めるので、言語・文字の大きさ・ボタンの折り返しで
/// 高さが変わっても、はみ出さない。
class _PickerSections extends MultiChildRenderObjectWidget {
  _PickerSections({
    required this.viewportExtent,
    required this.minListExtent,
    required this.maxListExtent,
    required Widget header,
    required Widget list,
    required Widget notice,
    required Widget footer,
  }) : super(children: [header, list, notice, footer]);

  final double viewportExtent;
  final double minListExtent;
  final double maxListExtent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPickerSections(viewportExtent, minListExtent, maxListExtent);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPickerSections renderObject,
  ) {
    renderObject
      ..viewportExtent = viewportExtent
      ..minListExtent = minListExtent
      ..maxListExtent = maxListExtent;
  }
}

class _PickerSectionData extends ContainerBoxParentData<RenderBox> {}

class _RenderPickerSections extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PickerSectionData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PickerSectionData> {
  _RenderPickerSections(
    this._viewportExtent,
    this._minListExtent,
    this._maxListExtent,
  );

  double get viewportExtent => _viewportExtent;
  double _viewportExtent;
  set viewportExtent(double value) {
    if (value == _viewportExtent) return;
    _viewportExtent = value;
    markNeedsLayout();
  }

  double get minListExtent => _minListExtent;
  double _minListExtent;
  set minListExtent(double value) {
    if (value == _minListExtent) return;
    _minListExtent = value;
    markNeedsLayout();
  }

  double get maxListExtent => _maxListExtent;
  double _maxListExtent;
  set maxListExtent(double value) {
    if (value == _maxListExtent) return;
    _maxListExtent = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PickerSectionData) {
      child.parentData = _PickerSectionData();
    }
  }

  @override
  void performLayout() {
    final header = firstChild!;
    final list = childAfter(header)!;
    final notice = childAfter(list)!;
    final footer = childAfter(notice)!;
    final section = BoxConstraints.tightFor(width: constraints.maxWidth);
    header.layout(section, parentUsesSize: true);
    notice.layout(section, parentUsesSize: true);
    footer.layout(section, parentUsesSize: true);
    final pinned = PixelArtPalettePickerDialog.pinsFooter(
      available: viewportExtent,
      header: header.size.height,
      footer: footer.size.height,
      notice: notice.size.height,
      oneRow: minListExtent,
    );
    final room =
        viewportExtent -
        header.size.height -
        notice.size.height -
        footer.size.height;
    list.layout(
      pinned
          ? section.copyWith(maxHeight: math.min(room, maxListExtent))
          : section,
      parentUsesSize: true,
    );
    var y = 0.0;
    for (final child in [header, list, notice, footer]) {
      (child.parentData! as _PickerSectionData).offset = Offset(0, y);
      y += child.size.height;
    }
    size = constraints.constrain(Size(constraints.maxWidth, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// パレット1件の行。[actionsBeside]のときだけ、共有・編集・削除を右端に
/// 並べる。狭い画面・大きな文字では名前の下の行へ移す（右端に3つ並べると、
/// スマホの幅では名前の幅がほとんど残らなかった）。
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.palette,
    required this.selected,
    required this.actionsBeside,
    required this.onSelect,
    required this.actions,
  });

  final ColorPalette palette;
  final bool selected;
  final bool actionsBeside;
  final VoidCallback onSelect;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final swatches = _ColorSwatchRow(colors: palette.colors);
    final tileTheme = ListTileTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final iconColor = selected
        ? tileTheme.selectedColor ?? scheme.primary
        : tileTheme.iconColor ?? scheme.onSurfaceVariant;
    return ListTile(
      selected: selected,
      onTap: onSelect,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(palette.name),
      subtitle: actionsBeside
          ? swatches
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                swatches,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  // 右端に並べたときと同じ色（行のアイコンの色）で描く。
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(foregroundColor: iconColor),
                    ),
                    child: Wrap(children: actions),
                  ),
                ),
              ],
            ),
      trailing: actionsBeside
          ? Row(mainAxisSize: MainAxisSize.min, children: actions)
          : null,
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final List<int> colors;

  const _ColorSwatchRow({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      children: [
        for (final c in colors.take(12))
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(c),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
      ],
    );
  }
}
