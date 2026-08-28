import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/stepped_slider.dart';
import 'canvas_area.dart' show kCanvasOutsideColor;

/// ブラシの太さ・不透明度スライダー。描画エリアを圧迫しないよう、
/// デフォルトでは折りたたまれた1行の要約表示にし、ユーザーが開閉
/// ボタンをタップした時だけ2本のスライダーを展開する（描画エリア最大化のため）。
/// 展開時もスライダー同士の縦の間隔を
/// 詰め、省スペースにしている。
///
/// 【背景色の不一致修正】以前はcolorScheme.surfaceContainerHighestで
/// 明るいパネル風の背景を敷いていたが、ツールバー（ToolbarWidget）が
/// 「アイコンは背景を持たず、キャンバス外周と同じkCanvasOutsideColorに
/// 溶け込む」方針へ統一されたのに合わせ、こちらも同じ背景色・白系の
/// 固定文字色へ変更した（この帯はcanvas_screen.dart側でツールバーと同じ
/// くキャンバスの外側領域に置かれるため、テーマ依存の色ではなく
/// kCanvasOutsideColor上で確実に読める固定色を使う）。
class BrushSizeSlider extends StatefulWidget {
  final double brushSize;
  final int opacity;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<int> onOpacityChanged;

  const BrushSizeSlider({
    super.key,
    required this.brushSize,
    required this.opacity,
    required this.onSizeChanged,
    required this.onOpacityChanged,
  });

  @override
  State<BrushSizeSlider> createState() => _BrushSizeSliderState();
}

class _BrushSizeSliderState extends State<BrushSizeSlider> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fgColor = Colors.white;
    const fgColorVariant = Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      color: kCanvasOutsideColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 折りたたみ中も現在値が一目でわかる要約行。タップで開閉する。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: fgColor),
                  const SizedBox(width: 4),
                  Text('${widget.brushSize.round()}',
                      style: const TextStyle(fontSize: 11, color: fgColor)),
                  const SizedBox(width: 10),
                  const Icon(Icons.opacity, size: 12, color: fgColor),
                  const SizedBox(width: 4),
                  Text('${widget.opacity}%',
                      style: const TextStyle(fontSize: 11, color: fgColor)),
                  const Spacer(),
                  Text(l10n.canvasBrushSliderToggleLabel,
                      style: const TextStyle(fontSize: 10, color: fgColorVariant)),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16, color: fgColor),
                ],
              ),
            ),
          ),
          if (_expanded)
            SliderTheme(
              // トラック・つまみ・オーバーレイを小さくし、スライダー同士の
              // 縦の間隔を詰めて省スペースにする。
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        Expanded(
                          child: SteppedSlider(min: 1, max: 500, value: widget.brushSize, onChanged: widget.onSizeChanged),
                        ),
                        // 数値部分をタップすると直接入力できる。
                        SizedBox(
                          width: 36,
                          child: EditableSliderValue(
                            text: '${widget.brushSize.round()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: fgColor),
                            value: widget.brushSize, min: 1, max: 500,
                            onChanged: (v) => widget.onSizeChanged(v.toDouble()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        Expanded(
                          child: SteppedSlider(
                              min: 1, max: 100, value: widget.opacity.toDouble(),
                              onChanged: (v) => widget.onOpacityChanged(v.round())),
                        ),
                        SizedBox(
                          width: 36,
                          child: EditableSliderValue(
                            text: '${widget.opacity}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: fgColor),
                            value: widget.opacity, min: 1, max: 100,
                            onChanged: (v) => widget.onOpacityChanged(v.round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
