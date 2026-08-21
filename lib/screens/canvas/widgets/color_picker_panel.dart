import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/color_palette.dart';
import '../../../services/palette_service.dart';
import '../../../widgets/confirm_delete.dart';
import '../../../widgets/editable_slider_value.dart';
import 'hsv_color_wheel.dart';
import 'panel_close_bar.dart';

/// カラーピッカーパネル（仕様書20：色管理仕様）。
/// カラーピッカー（HSV/RGB/HEX）・最近使った色・パレットの3セクション構成。
class ColorPickerPanel extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onClose;
  // スポイトボタン：カラーピッカー内からキャンバス上の色を取得できる（仕様書20）
  final VoidCallback? onEyedropperTap;
  // 上部中央の×閉じるボタンを表示するかどうか。呼び出し元がキャンセル・
  // 適用ボタンを別途下部に用意する場合（自動塗りグラデーションの色選択
  // 等）は、上の×ボタンがあると「押すと変更が消えるのか適用されるのか
  // 分かりにくい」ため非表示にできるようにしている。
  final bool showCloseBar;

  const ColorPickerPanel({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    required this.onClose,
    this.onEyedropperTap,
    this.showCloseBar = true,
  });

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  late double _hue;
  late double _saturation;
  late double _value;
  late double _alpha; // 0.0〜1.0（仕様書20：カラーピッカーは常に透明色も選択できる）
  late int _r, _g, _b;
  final _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFromColor(widget.currentColor);
    _hexController.text = _colorToHex(widget.currentColor);
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
    _alpha = color.a;
    _r = (color.r * 255).round();
    _g = (color.g * 255).round();
    _b = (color.b * 255).round();
  }

  Color get _currentColor => HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor();

  void _applyHsv() {
    // 透明色を選択中にHSVを操作した場合は、不透明色へ自動的に戻す。
    setState(() { if (_alpha == 0) _alpha = 1.0; });
    final color = _currentColor;
    _r = (color.r * 255).round();
    _g = (color.g * 255).round();
    _b = (color.b * 255).round();
    _hexController.text = _colorToHex(color);
    widget.onColorChanged(color);
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
    widget.onColorChanged(color);
  }

  void _applyAlpha() {
    setState(() {});
    widget.onColorChanged(_currentColor);
    _hexController.text = _colorToHex(_currentColor);
  }

  /// カラーサークル左下の透明トグルボタン（仕様書20）：タップで現在色を
  /// 透明（alpha=0）にする。既に透明の場合はタップ前の不透明色へ戻す。
  void _toggleTransparent() {
    setState(() => _alpha = _alpha == 0 ? 1.0 : 0.0);
    widget.onColorChanged(_currentColor);
    _hexController.text = _colorToHex(_currentColor);
    _commitToRecent();
  }

  void _applyColor(Color color) {
    setState(() => _syncFromColor(color));
    _hexController.text = _colorToHex(color);
    widget.onColorChanged(color);
  }

  /// 色の確定操作（スライダーの操作終了・HEX確定・スウォッチ選択）時に
  /// 「最近使った色」履歴へ登録する（仕様書20：直近10色）。
  void _commitToRecent() {
    context.read<PaletteService>().addRecentColor(_currentColor.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final paletteService = context.watch<PaletteService>();
    return Card(
      elevation: 8,
      child: Container(
        width: 288,
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxHeight: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showCloseBar) PanelCenterCloseBar(onClose: widget.onClose),
              Row(
                children: [
                  Text(l10n.colorPickerTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // スポイトボタン（仕様書20：カラーピッカー内のスポイトボタン）
                  if (widget.onEyedropperTap != null)
                    IconButton(
                      icon: const Icon(Icons.colorize, size: 18),
                      tooltip: l10n.toolbarItemEyedropper,
                      onPressed: widget.onEyedropperTap,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // HSVサークルとRGBスライダーは別タブへ分けず常に両方表示し、
              // どちらを操作してももう片方へ即座に反映することで、RGB側が
              // 実質的にHSV操作のプレビューにもなるようにする。
              // 正方形（彩度・明度）＋外側カラーサークル（色相）でタップ選択できる
              // 方式（仕様書20・タスク#91：従来のスライダー方式から刷新）。円の
              // 外側・左下の空きスペースには透明色切り替えボタンを配置する。
              Center(
                child: HsvColorWheel(
                  hue: _hue,
                  saturation: _saturation,
                  value: _value,
                  onHueChanged: (h) { _hue = h; _applyHsv(); },
                  onSvChanged: (s, v) { _saturation = s; _value = v; _applyHsv(); },
                  onChangeEnd: _commitToRecent,
                  isTransparent: _alpha == 0,
                  onToggleTransparent: _toggleTransparent,
                ),
              ),
              const SizedBox(height: 8),
              _slider('R', _r.toDouble(), 0, 255, (v) { _r = v.round(); _applyRgb(); }, (_) => _commitToRecent()),
              _slider('G', _g.toDouble(), 0, 255, (v) { _g = v.round(); _applyRgb(); }, (_) => _commitToRecent()),
              _slider('B', _b.toDouble(), 0, 255, (v) { _b = v.round(); _applyRgb(); }, (_) => _commitToRecent()),
              const SizedBox(height: 4),
              // 不透明度スライダー（仕様書20：カラーピッカーは常に透明色も選択
              // できるようにする）。チェッカー柄の上にプレビューを
              // 重ねて透明度が視覚的に分かるようにする。見出しラベルを添え、
              // 現在色プレビューは一目で分かるよう大きめに表示する。
              Text(l10n.colorPickerOpacityLabel,
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CustomPaint(painter: _CheckerboardPainter(), child: ColoredBox(color: _currentColor)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      min: 0, max: 1, value: _alpha,
                      label: '${(_alpha * 100).round()}%',
                      onChanged: (v) { _alpha = v; _applyAlpha(); },
                      onChangeEnd: (_) => _commitToRecent(),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: EditableSliderValue(
                      text: '${(_alpha * 100).round()}%',
                      style: const TextStyle(fontSize: 11),
                      value: (_alpha * 100).round(), min: 0, max: 100,
                      onChanged: (v) { _alpha = v / 100; _applyAlpha(); _commitToRecent(); },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('#'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (hex) {
                        final color = _hexToColor(hex);
                        if (color != null) {
                          _applyColor(color);
                          _commitToRecent();
                        }
                      },
                    ),
                  ),
                  // HEXコピー・貼り付け（仕様書20：「HEXは入力・コピー・貼り付けすべて対応」）
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l10n.commonCopy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '#${_hexController.text}'));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l10n.colorPickerHexCopiedSnackbar)));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste, size: 16),
                    tooltip: l10n.commonPaste,
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
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
              Text(l10n.colorPickerRecentColorsLabel,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              if (paletteService.recentColors.isEmpty)
                Text(l10n.colorPickerRecentColorsEmpty, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: paletteService.recentColors.map((argb) {
                    final color = Color(argb);
                    return GestureDetector(
                      onTap: () => _applyColor(color),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
        ),
      ),
    );
  }

  /// パレットセクション（仕様書20：「ユーザーが任意の色を登録できる」
  /// 「パレットの作成・名前変更・削除が可能」「複数パレットを切替えて使用」
  /// 「色の追加・削除・ドラッグで並び替えが可能」「お気に入り登録に対応」）。
  Widget _paletteSection(BuildContext context, AppLocalizations l10n, PaletteService paletteService) {
    final active = paletteService.activePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.colorPickerPaletteLabel,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              tooltip: l10n.colorPickerNewPaletteTooltip,
              onPressed: () => _showCreatePaletteDialog(context, l10n, paletteService),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 16),
              tooltip: l10n.colorPickerManagePaletteTooltip,
              onPressed: active == null ? null : () => _showPaletteMenu(context, l10n, paletteService, active),
            ),
          ],
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
                    if (p.isFavorite) const Icon(Icons.star, size: 10, color: Colors.amber),
                    Text(p.name, style: const TextStyle(fontSize: 10)),
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
          Text(l10n.colorPickerPaletteEmptyHint,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i < active.colors.length; i++)
                GestureDetector(
                  onTap: () => _applyColor(Color(active.colors[i])),
                  onLongPress: () => paletteService.removeColorFromPalette(active.id, i),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(active.colors[i]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                  ),
                ),
            ],
          ),
        if (active != null && active.colors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(l10n.colorPickerPaletteLongPressHint,
                style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.outline)),
          ),
        const SizedBox(height: 4),
        if (active != null)
          TextButton.icon(
            onPressed: () {
              paletteService.addColorToPalette(active.id, _currentColor.toARGB32());
            },
            icon: const Icon(Icons.add, size: 14),
            label: Text(l10n.colorPickerAddCurrentColorButton, style: const TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  void _showCreatePaletteDialog(BuildContext context, AppLocalizations l10n, PaletteService paletteService) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.colorPickerNewPaletteTooltip),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.colorPickerPaletteNameLabel, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) paletteService.createPalette(ctrl.text);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showPaletteMenu(BuildContext context, AppLocalizations l10n, PaletteService paletteService, ColorPalette palette) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(palette.isFavorite ? Icons.star : Icons.star_border, color: Colors.amber),
              title: Text(palette.isFavorite ? l10n.colorPickerFavoriteRemove : l10n.colorPickerFavoriteAdd),
              onTap: () { Navigator.pop(ctx); paletteService.toggleFavorite(palette.id); },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.commonRename),
              onTap: () {
                Navigator.pop(ctx);
                final ctrl = TextEditingController(text: palette.name);
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text(l10n.commonRename),
                    content: TextField(controller: ctrl, autofocus: true,
                        decoration: const InputDecoration(border: OutlineInputBorder())),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx), child: Text(l10n.commonCancel)),
                      FilledButton(
                        onPressed: () {
                          if (ctrl.text.isNotEmpty) paletteService.renamePalette(palette.id, ctrl.text);
                          Navigator.pop(dctx);
                        },
                        child: Text(l10n.commonChange),
                      ),
                    ],
                  ),
                ).then((_) => ctrl.dispose());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
              // お気に入り登録中は削除できない。
              onTap: paletteService.palettes.length > 1
                  ? () async {
                      Navigator.pop(ctx);
                      if (palette.isFavorite) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
                        return;
                      }
                      if (!await confirmDelete(context, itemName: palette.name)) return;
                      paletteService.deletePalette(palette.id);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, ValueChanged<double>? onChangeEnd) {
    return Row(
      children: [
        SizedBox(width: 14, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(child: Slider(min: min, max: max, value: value, onChanged: onChanged, onChangeEnd: onChangeEnd)),
        // 数値部分をタップすると直接入力できる。
        SizedBox(
          width: 32,
          child: EditableSliderValue(
            text: value.round().toString(),
            style: const TextStyle(fontSize: 11),
            value: value, min: min, max: max,
            onChanged: (v) { onChanged(v.toDouble()); onChangeEnd?.call(v.toDouble()); },
          ),
        ),
      ],
    );
  }

  /// RRGGBB（不透明時）またはRRGGBBAA（透明色を含む場合）で出力する
  /// （仕様書20：カラーピッカーは常に透明色も選択できる）。
  String _colorToHex(Color color) {
    final rgb = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    final a = (color.a * 255).round();
    if (a >= 255) return rgb;
    return '$rgb${a.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
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

/// 透明度プレビュー用のチェッカー柄背景（仕様書20：カラーピッカーは常に
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
