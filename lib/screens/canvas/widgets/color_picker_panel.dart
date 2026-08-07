import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/color_palette.dart';
import '../../../services/palette_service.dart';

/// カラーピッカーパネル（仕様書20：色管理仕様）。
/// カラーピッカー（HSV/RGB/HEX）・最近使った色・パレットの3セクション構成。
class ColorPickerPanel extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onClose;
  // スポイトボタン：カラーピッカー内からキャンバス上の色を取得できる（仕様書20）
  final VoidCallback? onEyedropperTap;

  const ColorPickerPanel({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    required this.onClose,
    this.onEyedropperTap,
  });

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

enum _PickerFormat { hsv, rgb }

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  late double _hue;
  late double _saturation;
  late double _value;
  late int _r, _g, _b;
  final _hexController = TextEditingController();
  _PickerFormat _format = _PickerFormat.hsv;

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
    _r = (color.r * 255).round();
    _g = (color.g * 255).round();
    _b = (color.b * 255).round();
  }

  Color get _currentColor => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  void _applyHsv() {
    setState(() {});
    final color = _currentColor;
    _r = (color.r * 255).round();
    _g = (color.g * 255).round();
    _b = (color.b * 255).round();
    _hexController.text = _colorToHex(color);
    widget.onColorChanged(color);
  }

  void _applyRgb() {
    final color = Color.fromARGB(255, _r, _g, _b);
    setState(() {
      final hsv = HSVColor.fromColor(color);
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    });
    _hexController.text = _colorToHex(color);
    widget.onColorChanged(color);
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
    final paletteService = context.watch<PaletteService>();
    return Card(
      elevation: 8,
      child: Container(
        width: 288,
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('色選択', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // スポイトボタン（仕様書20：カラーピッカー内のスポイトボタン）
                  if (widget.onEyedropperTap != null)
                    IconButton(
                      icon: const Icon(Icons.colorize, size: 18),
                      tooltip: 'スポイト',
                      onPressed: widget.onEyedropperTap,
                    ),
                  IconButton(icon: const Icon(Icons.close, size: 16), onPressed: widget.onClose),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 264,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white, HSVColor.fromAHSV(1, _hue, 1, 1).toColor()]),
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundDecoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 8),
              // HSV / RGB 切替（仕様書20：「HSV / RGB / HEXの3形式に対応・スライダー操作」）
              SegmentedButton<_PickerFormat>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: _PickerFormat.hsv, label: Text('HSV', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: _PickerFormat.rgb, label: Text('RGB', style: TextStyle(fontSize: 11))),
                ],
                selected: {_format},
                onSelectionChanged: (v) => setState(() => _format = v.first),
              ),
              const SizedBox(height: 8),
              if (_format == _PickerFormat.hsv) ...[
                _slider('H', _hue, 0, 360, (v) { _hue = v; _applyHsv(); }, (_) => _commitToRecent()),
                _slider('S', _saturation, 0, 1, (v) { _saturation = v; _applyHsv(); }, (_) => _commitToRecent()),
                _slider('V', _value, 0, 1, (v) { _value = v; _applyHsv(); }, (_) => _commitToRecent()),
              ] else ...[
                _slider('R', _r.toDouble(), 0, 255, (v) { _r = v.round(); _applyRgb(); }, (_) => _commitToRecent()),
                _slider('G', _g.toDouble(), 0, 255, (v) { _g = v.round(); _applyRgb(); }, (_) => _commitToRecent()),
                _slider('B', _b.toDouble(), 0, 255, (v) { _b = v.round(); _applyRgb(); }, (_) => _commitToRecent()),
              ],
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
                    tooltip: 'コピー',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '#${_hexController.text}'));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('HEXをコピーしました')));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste, size: 16),
                    tooltip: '貼り付け',
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
              Text('最近使った色',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              if (paletteService.recentColors.isEmpty)
                Text('まだありません', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline))
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
              _paletteSection(context, paletteService),
            ],
          ),
        ),
      ),
    );
  }

  /// パレットセクション（仕様書20：「ユーザーが任意の色を登録できる」
  /// 「パレットの作成・名前変更・削除が可能」「複数パレットを切替えて使用」
  /// 「色の追加・削除・ドラッグで並び替えが可能」「お気に入り登録に対応」）。
  Widget _paletteSection(BuildContext context, PaletteService paletteService) {
    final active = paletteService.activePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('パレット',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              tooltip: '新しいパレット',
              onPressed: () => _showCreatePaletteDialog(context, paletteService),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 16),
              tooltip: 'パレット管理',
              onPressed: active == null ? null : () => _showPaletteMenu(context, paletteService, active),
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
          Text('色がまだありません。「＋」で現在の色を追加できます。',
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
        const SizedBox(height: 4),
        if (active != null)
          TextButton.icon(
            onPressed: () {
              paletteService.addColorToPalette(active.id, _currentColor.toARGB32());
            },
            icon: const Icon(Icons.add, size: 14),
            label: const Text('現在の色をパレットに追加', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  void _showCreatePaletteDialog(BuildContext context, PaletteService paletteService) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しいパレット'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'パレット名', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) paletteService.createPalette(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showPaletteMenu(BuildContext context, PaletteService paletteService, ColorPalette palette) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(palette.isFavorite ? Icons.star : Icons.star_border, color: Colors.amber),
              title: Text(palette.isFavorite ? 'お気に入り解除' : 'お気に入り登録'),
              onTap: () { Navigator.pop(ctx); paletteService.toggleFavorite(palette.id); },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('名前変更'),
              onTap: () {
                Navigator.pop(ctx);
                final ctrl = TextEditingController(text: palette.name);
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('名前変更'),
                    content: TextField(controller: ctrl, autofocus: true,
                        decoration: const InputDecoration(border: OutlineInputBorder())),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('キャンセル')),
                      FilledButton(
                        onPressed: () {
                          if (ctrl.text.isNotEmpty) paletteService.renamePalette(palette.id, ctrl.text);
                          Navigator.pop(dctx);
                        },
                        child: const Text('変更'),
                      ),
                    ],
                  ),
                ).then((_) => ctrl.dispose());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: paletteService.palettes.length > 1
                  ? () { Navigator.pop(ctx); paletteService.deletePalette(palette.id); }
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
      ],
    );
  }

  String _colorToHex(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}
