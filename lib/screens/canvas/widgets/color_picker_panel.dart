import '../../../services/shared_asset_card_service.dart';
import 'package:niarim/services/theme_service.dart';

import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../engine/undo_manager.dart' as app_undo;
import '../../../l10n/app_localizations.dart';
import '../../../models/color_palette.dart';
import '../../../services/export_share_service.dart';
import '../../../services/palette_service.dart';
import '../../../widgets/confirm_delete.dart';
import '../../../widgets/export_share_feedback.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/name_entry_dialog.dart';
import '../../../widgets/qr_import_dialog.dart';
import '../../../widgets/qr_share_dialog.dart';
import '../../../widgets/scrollable_sheet_body.dart';
import 'hsv_color_wheel.dart';
import '../../../widgets/docked_panel_scope.dart';
import 'panel_close_bar.dart';
import '../../../widgets/list_ink_clip.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/file_failure_reason.dart';

/// カラーピッカーパネル。
/// カラーピッカー（HSV/RGB/HEX）・最近使った色・パレットの3セクション構成。
class ColorPickerPanel extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onClose;
  // スポイトボタン：カラーピッカー内からキャンバス上の色を取得できる
  final VoidCallback? onEyedropperTap;
  // 上部中央の×閉じるボタンを表示するかどうか。呼び出し元がキャンセル・
  // 適用ボタンを別途下部に用意する場合（自動塗りグラデーションの色選択
  // 等）は、上の×ボタンがあると「押すと変更が消えるのか適用されるのか
  // 分かりにくい」ため非表示にできるようにしている。
  final bool showCloseBar;

  /// 見出しの行（「色選択」と今の色の帯）の代わりに出す部品。テーマの
  /// 色を選ぶときに、選んでいる色がアプリのどこに効くかの見本を出す。
  final Widget? header;

  /// 不透明な色だけを選ぶ（作品の背景色）。不透明度のスライダーと透明の
  /// ボタンを出さず、パレット・最近使った色・HEXから選んだ半透明の色も
  /// 不透明にして渡す。
  final bool opaqueOnly;

  const ColorPickerPanel({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    required this.onClose,
    this.onEyedropperTap,
    this.showCloseBar = true,
    this.header,
    this.opaqueOnly = false,
  });

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  late double _hue;
  late double _saturation;
  late double _value;
  late double _alpha; // 0.0〜1.0（カラーピッカーは常に透明色も選択できる）
  late int _r, _g, _b;
  // HSV／RGBのどちらのスライダーを出すか（アプリを閉じるまで覚える）。
  static bool _lastShowHsvSliders = true;
  bool _showHsvSliders = _lastShowHsvSliders;
  // つまみ・スライダーの調整で「最近使った色」へ入れた色。同じ調整の続き
  // （描く・別の色を選ぶまで）は、足さずにこの色を置き換える（以前は
  // スライダーを離すたびに足され、ほとんど同じ色で埋まった）。
  int? _adjustingRecent;
  int _adjustingUndoCount = -1;
  final _hexController = TextEditingController();
  // パレットを共有できなかった理由。このパネルはダイアログの中にも出るので、
  // SnackBar（ダイアログの幕の下に隠れる）ではなくパネルの中に出す。
  Object? _shareError;
  final _shareNoticeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _syncFromColor(widget.currentColor);
    _hexController.text = _colorToHex(widget.currentColor);
  }

  @override
  void didUpdateWidget(covariant ColorPickerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentColor != widget.currentColor &&
        _currentColor.toARGB32() != widget.currentColor.toARGB32()) {
      _syncFromColor(widget.currentColor);
      _hexController.text = _colorToHex(widget.currentColor);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _syncFromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _alpha = widget.opaqueOnly ? 1.0 : color.a;
    _r = (color.r * 255).round();
    _g = (color.g * 255).round();
    _b = (color.b * 255).round();
  }

  void _emit(Color color) =>
      widget.onColorChanged(widget.opaqueOnly ? color.withAlpha(255) : color);

  Color get _currentColor =>
      HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor();

  void _applyHsv() {
    // 透明色を選択中にHSVを操作した場合は、不透明色へ自動的に戻す。
    setState(() {
      if (_alpha == 0) _alpha = 1.0;
    });
    final color = _currentColor;
    _r = (color.r * 255).round();
    _g = (color.g * 255).round();
    _b = (color.b * 255).round();
    _hexController.text = _colorToHex(color);
    _emit(color);
  }

  void _applyRgb() {
    // HSVと同様、RGB操作でも透明色からは自動的に不透明へ戻す。
    if (_alpha == 0) _alpha = 1.0;
    final color = Color.fromARGB((_alpha * 255).round(), _r, _g, _b);
    setState(() {
      final hsv = HSVColor.fromColor(color);
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    });
    _hexController.text = _colorToHex(color);
    _emit(color);
  }

  void _applyAlpha() {
    setState(() {});
    _emit(_currentColor);
    _hexController.text = _colorToHex(_currentColor);
  }

  /// カラーサークル左下の透明トグルボタン：タップで現在色を
  /// 透明（alpha=0）にする。既に透明の場合はタップ前の不透明色へ戻す。
  void _toggleTransparent() {
    setState(() => _alpha = _alpha == 0 ? 1.0 : 0.0);
    _emit(_currentColor);
    _hexController.text = _colorToHex(_currentColor);
    _commitToRecent();
  }

  void _applyColor(Color color) {
    setState(() => _syncFromColor(color));
    _hexController.text = _colorToHex(color);
    _emit(color);
  }

  /// 色の確定操作（スライダーの操作終了・HEX確定・スウォッチ選択）時に
  /// 「最近使った色」履歴へ登録する（直近10色）。
  void _commitToRecent({bool adjusting = false}) {
    final argb = _currentColor.toARGB32();
    final undoCount = context.read<app_undo.UndoManager?>()?.undoCount ?? 0;
    final replacing =
        adjusting &&
            _adjustingRecent != null &&
            undoCount == _adjustingUndoCount
        ? _adjustingRecent
        : null;
    context.read<PaletteService>().addRecentColor(argb, replacing: replacing);
    _adjustingRecent = adjusting ? argb : null;
    _adjustingUndoCount = undoCount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final paletteService = context.watch<PaletteService>();
    final docked = DockedPanelScope.of(context);
    return PanelSurface(
      width: 288,
      maxHeight: 680,
      selfScrolling: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, docked ? 4 : 8, 12, 12),
        // 閉じるボタンと見出し（今の色）は固定し、その下だけをスクロール
        // させる。全体を1つのスクロールにしていた頃は、色コードの欄へ
        // 入ると欄を見せるためにスクロールし、閉じるボタンが上へ隠れた。
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showCloseBar)
              PanelCenterCloseBar(onClose: widget.onClose),
            if (!docked && widget.header != null) ...[
              widget.header!,
              const SizedBox(height: 8),
            ] else if (!docked) ...[
              Row(
                children: [
                  Text(
                    l10n.colorPickerTitle,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Semantics(
                        label: l10n.colorPickerCurrentColorSemanticsLabel(
                          '#${_colorToHex(_currentColor)}',
                        ),
                        child: SizedBox(
                          key: const ValueKey('selected-color-preview-chip'),
                          // A height-only box inside Flexible can collapse to
                          // zero width, hiding the preview entirely on phones.
                          width: 200,
                          height: 20,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: CustomPaint(
                              painter: _CheckerboardPainter(),
                              child: ColoredBox(color: _currentColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              // 半分隠れたボタンを押した色が、固定した見出し・閉じる
              // ボタンの上へはみ出さないよう、スクロールの中に限る。
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // カラーサークルは常時表示。右下のピルで数値スライダーを
                    // HSV/RGBから切り替える。現在色の値はモード変更で変えない。
                    // 正方形（彩度・明度）＋外側カラーサークル（色相）でタップ選択できる
                    // 方式。円の
                    // 外側・左下の空きスペースには透明色切り替えボタンを配置する。
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) => HsvColorWheel(
                          // Leave room for the HSV/RGB pill below the hue ring even
                          // in a compact PC dock; mobile keeps the larger wheel.
                          // The mode pills use the panel's full width, not the
                          // ring width; the wheel can therefore fill more space.
                          size: math.min(236.0, constraints.maxWidth),
                          controlsWidth: constraints.maxWidth,
                          onEyedropperTap: widget.onEyedropperTap,
                          eyedropperTooltip: l10n.toolbarItemEyedropper,
                          hue: _hue,
                          saturation: _saturation,
                          value: _value,
                          onHueChanged: (h) {
                            _hue = h;
                            _applyHsv();
                          },
                          onSvChanged: (s, v) {
                            _saturation = s;
                            _value = v;
                            _applyHsv();
                          },
                          onChangeEnd: () => _commitToRecent(adjusting: true),
                          isTransparent: _alpha == 0,
                          onToggleTransparent: widget.opaqueOnly
                              ? null
                              : _toggleTransparent,
                          showHsvSliders: _showHsvSliders,
                          onSliderModeChanged: (hsv) => setState(
                            () => _showHsvSliders = _lastShowHsvSliders = hsv,
                          ),
                        ),
                      ),
                    ),
                    // Wheel controls already clear the ring: no extra spacer.
                    if (_showHsvSliders) ...[
                      _slider('H', _hue.roundToDouble(), 0, 360, (v) {
                        _hue = v.roundToDouble();
                        _applyHsv();
                      }, (_) => _commitToRecent(adjusting: true)),
                      _slider(
                        'S',
                        (_saturation * 100).roundToDouble(),
                        0,
                        100,
                        (v) {
                          _saturation = v.round() / 100;
                          _applyHsv();
                        },
                        (_) => _commitToRecent(adjusting: true),
                      ),
                      _slider('V', (_value * 100).roundToDouble(), 0, 100, (v) {
                        _value = v.round() / 100;
                        _applyHsv();
                      }, (_) => _commitToRecent(adjusting: true)),
                    ] else ...[
                      _slider('R', _r.toDouble(), 0, 255, (v) {
                        _r = v.round();
                        _applyRgb();
                      }, (_) => _commitToRecent(adjusting: true)),
                      _slider('G', _g.toDouble(), 0, 255, (v) {
                        _g = v.round();
                        _applyRgb();
                      }, (_) => _commitToRecent(adjusting: true)),
                      _slider('B', _b.toDouble(), 0, 255, (v) {
                        _b = v.round();
                        _applyRgb();
                      }, (_) => _commitToRecent(adjusting: true)),
                    ],
                    const SizedBox(height: 4),
                    // 不透明度スライダー（カラーピッカーは常に透明色も選択
                    // できるようにする）。チェッカー柄の上にプレビューを
                    // 重ねて透明度が視覚的に分かるようにする。見出しラベルを添え、
                    // 現在色プレビューは一目で分かるよう大きめに表示する。
                    // 0〜1で持つが、直接入力と同じく百分率で動かす。
                    if (!widget.opaqueOnly)
                      LabeledSlider(
                        padding: EdgeInsets.zero,
                        label: l10n.colorPickerOpacityLabel,
                        labelStyle: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        value: _alpha * 100,
                        min: 0,
                        max: 100,
                        sliderLabel: '${(_alpha * 100).round()}%',
                        valueText: '${(_alpha * 100).round()}%',
                        valueStyle: const TextStyle(fontSize: 11),
                        onChanged: (v) {
                          _alpha = v / 100;
                          _applyAlpha();
                        },
                        onChangeEnd: (_) => _commitToRecent(adjusting: true),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('#'),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _hexController,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[0-9a-fA-F#]'),
                              ),
                              LengthLimitingTextInputFormatter(9),
                            ],
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (hex) {
                              final color = _hexToColor(hex);
                              if (color != null) {
                                _applyColor(color);
                                _commitToRecent();
                              } else {
                                _hexController.text = _colorToHex(
                                  _currentColor,
                                );
                              }
                            },
                          ),
                        ),
                        // HEXコピー・貼り付け（入力・コピー・貼り付けすべて対応）
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.commonCopy,
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: '#${_colorToHex(_currentColor)}',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.colorPickerHexCopiedSnackbar,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.paste, size: 16),
                          tooltip: l10n.commonPaste,
                          onPressed: () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            final text = data?.text;
                            if (text == null) return;
                            final color = _hexToColor(text);
                            if (color != null) {
                              _hexController.text = _colorToHex(color);
                              _applyColor(color);
                              _commitToRecent();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.colorPickerRecentColorsLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (paletteService.recentColors.isEmpty)
                      Text(
                        l10n.colorPickerRecentColorsEmpty,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: paletteService.recentColors.map((argb) {
                          final color = Color(argb);
                          return GestureDetector(
                            // 押した色を先頭へ移す。
                            onTap: () {
                              _applyColor(color);
                              _commitToRecent();
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _paletteSection(context, l10n, paletteService),
                  ],
                ),
              ).clipListInk(),
            ),
          ],
        ),
      ),
    );
  }

  /// パレットセクション（「ユーザーが任意の色を登録できる」
  /// 「パレットの作成・名前変更・削除が可能」「複数パレットを切替えて使用」
  /// 「色の追加・削除・ドラッグで並び替えが可能」「お気に入り登録に対応」）。
  Widget _paletteSection(
    BuildContext context,
    AppLocalizations l10n,
    PaletteService paletteService,
  ) {
    final active = paletteService.activePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.colorPickerPaletteLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              tooltip: l10n.colorPickerNewPaletteTooltip,
              onPressed: () =>
                  _showCreatePaletteDialog(context, l10n, paletteService),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 16),
              tooltip: l10n.colorPickerImportPaletteTooltip,
              onPressed: () =>
                  _showImportPaletteSheet(context, l10n, paletteService),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 16),
              tooltip: l10n.colorPickerManagePaletteTooltip,
              onPressed: active == null
                  ? null
                  : () =>
                        _showPaletteMenu(context, l10n, paletteService, active),
            ),
          ],
        ),
        if (_shareError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ExportShareNotice(
              key: _shareNoticeKey,
              message: exportShareFailureText(l10n, _shareError!),
            ),
          ),
        // パレット切替（複数パレットをチップで切替）
        if (paletteService.palettes.length > 1)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: paletteService.palettes.map((p) {
              final isActive = p.id == paletteService.activePaletteId;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.isFavorite)
                      Icon(
                        Icons.star,
                        size: 10,
                        color: ThemeService.activeColorScheme.tertiary,
                      ),
                    Text(
                      p.name,
                      style: localizedHeadingStyle(
                        context,
                        const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                selected: isActive,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => paletteService.setActivePalette(p.id),
              );
            }).toList(),
          ),
        const SizedBox(height: 4),
        if (active == null)
          const SizedBox.shrink()
        else if (active.colors.isEmpty)
          Text(
            l10n.colorPickerPaletteEmptyHint,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i < active.colors.length; i++)
                GestureDetector(
                  onTap: () => _applyColor(Color(active.colors[i])),
                  onLongPress: () =>
                      paletteService.removeColorFromPalette(active.id, i),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(active.colors[i]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (active != null && active.colors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.colorPickerPaletteLongPressHint,
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        const SizedBox(height: 4),
        if (active != null)
          TextButton.icon(
            onPressed: () {
              paletteService.addColorToPalette(
                active.id,
                _currentColor.toARGB32(),
              );
            },
            icon: const Icon(Icons.add, size: 14),
            label: Text(
              l10n.colorPickerAddCurrentColorButton,
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }

  void _showCreatePaletteDialog(
    BuildContext context,
    AppLocalizations l10n,
    PaletteService paletteService,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => NameEntryDialog(
        title: l10n.colorPickerNewPaletteTooltip,
        labelText: l10n.colorPickerPaletteNameLabel,
        confirmLabel: l10n.commonCreate,
        cancelLabel: l10n.commonCancel,
        onSubmit: paletteService.createPalette,
      ),
    );
  }

  void _showPaletteMenu(
    BuildContext context,
    AppLocalizations l10n,
    PaletteService paletteService,
    ColorPalette palette,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                palette.isFavorite ? Icons.star : Icons.star_border,
                color: ThemeService.activeColorScheme.tertiary,
              ),
              title: Text(
                palette.isFavorite
                    ? l10n.colorPickerFavoriteRemove
                    : l10n.colorPickerFavoriteAdd,
              ),
              onTap: () {
                Navigator.pop(ctx);
                paletteService.toggleFavorite(palette.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.commonRename),
              onTap: () {
                Navigator.pop(ctx);
                showDialog<void>(
                  context: context,
                  builder: (_) => NameEntryDialog(
                    title: l10n.commonRename,
                    labelText: l10n.colorPickerPaletteNameLabel,
                    confirmLabel: l10n.commonChange,
                    cancelLabel: l10n.commonCancel,
                    initialName: palette.name,
                    onSubmit: (name) =>
                        paletteService.renamePalette(palette.id, name),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.colorPickerSharePaletteTooltip),
              onTap: () {
                Navigator.pop(ctx);
                _showSharePaletteSheet(context, l10n, palette);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.commonDelete),
              // お気に入り登録中は削除できない。
              onTap: paletteService.palettes.length > 1
                  ? () async {
                      Navigator.pop(ctx);
                      if (palette.isFavorite) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.commonFavoriteDeleteBlocked),
                          ),
                        );
                        return;
                      }
                      if (!await confirmDelete(
                        context,
                        itemName: palette.name,
                      )) {
                        return;
                      }
                      paletteService.deletePalette(palette.id);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// パレットの共有方法選択（ファイル共有／QRコード共有）。
  /// QRコードは、パレットは基本的にバイナリ資産を持たない小さな
  /// JSON設定であるため候補として提示するが、色数が多くQRの安全な
  /// 文字数上限（[kQrShareSafeCharLimit]）を超える場合は非活性にし、
  /// ファイル共有のみを案内する。
  void _showSharePaletteSheet(
    BuildContext context,
    AppLocalizations l10n,
    ColorPalette palette,
  ) {
    final paletteService = context.read<PaletteService>();
    final payload = jsonEncode(palette.toJson());
    final qrAvailable = payload.length <= kQrShareSafeCharLimit;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              // 書き出しと共有が終わるまで、同じパレットをもう一度は出さない。
              enabled: !ExportShareService.isRunning(_shareKey(palette)),
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.colorPickerShareViaFile),
              onTap: () {
                Navigator.pop(ctx);
                _sharePaletteFile(l10n, paletteService, palette);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.shareCardExportMenu),
              onTap: () {
                Navigator.pop(ctx);
                SharedAssetCardService.exportSettings(
                  context,
                  kind: 'palette',
                  name: palette.name,
                  settings: palette.toJson(),
                );
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

  static String _shareKey(ColorPalette palette) => 'palette:${palette.id}';

  /// .niapaletteへ書き出してから共有する。書き出しの失敗と、共有できない
  /// 端末・共有の失敗は別のことなので、別の文で知らせる（共有の方は
  /// パネルの中に出し、次に共有を始めるときに消す）。
  Future<void> _sharePaletteFile(
    AppLocalizations l10n,
    PaletteService paletteService,
    ColorPalette palette,
  ) => ExportShareService.runExclusive(_shareKey(palette), () async {
    if (!mounted) return;
    setState(() => _shareError = null);
    final File file;
    try {
      file = await paletteService.exportPalette(palette.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.colorPickerShareFailedSnackbar(fileFailureReason(l10n, e)),
          ),
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

  /// パレットの取り込み方法選択（ファイルから選択／QRコードの読み取り
  /// テキストを貼り付け）。
  void _showImportPaletteSheet(
    BuildContext context,
    AppLocalizations l10n,
    PaletteService paletteService,
  ) {
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
                  allowedExtensions: ['niapalette', 'png'],
                );
                final path = result?.files.firstOrNull?.path;
                if (path == null) return;
                try {
                  await paletteService.importPaletteJson(
                    await SharedAssetCardService.readSettingsFile(
                      path,
                      kind: 'palette',
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.colorPickerImportFailedSnackbar(
                          fileFailureReason(l10n, e),
                        ),
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
                      await paletteService.importPaletteJson(text);
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

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  ) {
    // 数値部分をタップすると直接入力できる。
    return LabeledSlider(
      padding: EdgeInsets.zero,
      label: label,
      value: value,
      min: min,
      max: max,
      valueText: value.round().toString(),
      valueStyle: const TextStyle(fontSize: 11),
      divisions: (max - min).round(),
      step: 1,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }

  /// RRGGBB（不透明時）またはRRGGBBAA（透明色を含む場合）で出力する
  /// （カラーピッカーは常に透明色も選択できる）。
  String _colorToHex(Color color) {
    final rgb = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    final a = (color.a * 255).round();
    if (a >= 255 || widget.opaqueOnly) return rgb;
    return '$rgb${a.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    hex = hex.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return null;
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) return Color(value);
    } else if (hex.length == 8) {
      // RRGGBBAA
      final rgb = hex.substring(0, 6);
      final a = hex.substring(6, 8);
      final value = int.tryParse('$a$rgb', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}

/// 透明度プレビュー用のチェッカー柄背景（カラーピッカーは常に
/// 透明色も選択できるようにし、透明度を視覚的に分かりやすくする）。
class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 4.0;
    final light = Paint()..color = const Color(0xFFCCCCCC);
    final dark = Paint()..color = const Color(0xFF999999);
    canvas.drawRect(Offset.zero & size, light);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final isDark = ((x / cell).floor() + (y / cell).floor()) % 2 == 0;
        if (isDark) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}
