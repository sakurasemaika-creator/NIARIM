import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
    // 低い画面では一覧を別にスクロールさせず、ダイアログ全体を1つで送る
    // （一覧だけが見えて、知らせや「適用」へ届かなくなる）。
    final shortScreen = screen.height < 520;
    // 狭い画面では周りの余白を詰めて、行の名前に幅を残す。
    final horizontalInset = screen.width < 480 ? 16.0 : 40.0;
    // 行の幅（ダイアログは画面の幅いっぱいに広がる）。名前に十分な幅を
    // 残せるときだけ、行の操作を右端に並べる。スクロールするダイアログは
    // 中身の大きさを先に測るので、LayoutBuilderでは決められない。
    final rowWidth = screen.width - horizontalInset * 2 - 48;
    final actionsBeside =
        rowWidth >= 240 + 140 * MediaQuery.textScalerOf(context).scale(1);
    final rows = [
      for (final p in palettes)
        _paletteRow(l10n, p, actionsBeside: actionsBeside),
    ];

    // 見出しから操作のボタンまでを1つのスクロールに入れる。低い画面・大きな
    // 文字では入りきらず、ボタンを下に固定すると一覧も知らせも出なかった。
    return AlertDialog(
      scrollable: true,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: shortScreen ? 16 : 24,
      ),
      title: Text(l10n.pixelArtPalettePickerTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (palettes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.pixelArtPalettePickerEmpty),
              )
            else if (shortScreen)
              ...rows
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                // 行の選択色はMaterialへ描かれる。一覧の中にMaterialを置いて
                // 切り抜かないと、送って隠れた行の色が見出しの上にはみ出す。
                child: Material(
                  type: MaterialType.transparency,
                  clipBehavior: Clip.hardEdge,
                  // スクロールするダイアログは中身の大きさを先に測るので、
                  // 見える分だけ作る一覧（ListView）は中に置けない。外側と
                  // 同じコントローラーを取り合わないよう、primaryにもしない。
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: rows,
                    ),
                  ),
                ),
              ),
            if (_shareError != null) ...[
              const SizedBox(height: 12),
              ExportShareNotice(
                key: _shareNoticeKey,
                message: exportShareFailureText(l10n, _shareError!),
              ),
            ],
            const SizedBox(height: 24),
            OverflowBar(
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
                          : () => Navigator.of(context).pop(selected.colors),
                      child: Text(l10n.pixelArtPalettePickerApplyButton),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
