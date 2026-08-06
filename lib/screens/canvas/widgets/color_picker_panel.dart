import 'package:flutter/material.dart';

class ColorPickerPanel extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onClose;

  const ColorPickerPanel({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    required this.onClose,
  });

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  late double _hue;
  late double _saturation;
  late double _value;
  final _hexController = TextEditingController();

  final List<Color> _recentColors = [
    Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green,
    Colors.yellow, Colors.purple, Colors.orange, Colors.pink, Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.currentColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController.text = _colorToHex(widget.currentColor);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('色選択', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 16), onPressed: widget.onClose),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 256,
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.white, HSVColor.fromAHSV(1, _hue, 1, 1).toColor()]),
                borderRadius: BorderRadius.circular(4),
              ),
              foregroundDecoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            _slider('H', _hue, 0, 360, (v) { setState(() => _hue = v); widget.onColorChanged(_currentColor); }),
            _slider('S', _saturation, 0, 1, (v) { setState(() => _saturation = v); widget.onColorChanged(_currentColor); }),
            _slider('V', _value, 0, 1, (v) { setState(() => _value = v); widget.onColorChanged(_currentColor); }),
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
                        final hsv = HSVColor.fromColor(color);
                        setState(() { _hue = hsv.hue; _saturation = hsv.saturation; _value = hsv.value; });
                        widget.onColorChanged(color);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('最近使った色', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _recentColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    final hsv = HSVColor.fromColor(color);
                    setState(() { _hue = hsv.hue; _saturation = hsv.saturation; _value = hsv.value; });
                    widget.onColorChanged(color);
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: Colors.grey[600]!),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Expanded(child: Slider(min: min, max: max, value: value, onChanged: onChanged)),
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
