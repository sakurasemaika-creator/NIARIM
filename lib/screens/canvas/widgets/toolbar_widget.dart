import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/tone_service.dart';
import '../canvas_screen.dart';

class ToolbarWidget extends StatelessWidget {
  final DrawingTool currentTool;
  final Color currentColor;
  final ValueChanged<DrawingTool> onToolSelected;
  final VoidCallback onColorTap;
  final VoidCallback onBrushTap;
  final VoidCallback onLayerTap;
  final VoidCallback onTimelineTap;
  final VoidCallback onPenLongPress;
  final VoidCallback onOnionSkinTap;
  final VoidCallback onTextTap;
  final VoidCallback onRulerTap;
  final VoidCallback onShapeTap;

  const ToolbarWidget({
    super.key,
    required this.currentTool,
    required this.currentColor,
    required this.onToolSelected,
    required this.onColorTap,
    required this.onBrushTap,
    required this.onLayerTap,
    required this.onTimelineTap,
    required this.onPenLongPress,
    required this.onOnionSkinTap,
    required this.onTextTap,
    required this.onRulerTap,
    required this.onShapeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ペンボタン：長押しでサブツールパネル表示
            GestureDetector(
              onLongPress: onPenLongPress,
              child: _toolButton(Icons.brush, DrawingTool.pen, 'ペン（長押しでサブツール）'),
            ),
            _toolButton(Icons.auto_fix_high, DrawingTool.eraser, '消しゴム'),
            // バケツボタン：長押しでベタ塗り／トーン切り替えメニュー表示
            GestureDetector(
              onLongPress: () => _showBucketToneMenu(context),
              child: _toolButton(Icons.format_color_fill, DrawingTool.bucket, 'バケツ（長押しでベタ/トーン切替）'),
            ),
            _toolButton(Icons.colorize, DrawingTool.eyedropper, 'スポイト'),
            _toolButton(Icons.back_hand, DrawingTool.finger, '指'),
            _selectToolButton(context),
            _toolButton(Icons.open_with, DrawingTool.move, '移動'),
            _toolButton(Icons.transform, DrawingTool.transform, '変形'),
            _toolButton(Icons.straighten, DrawingTool.ruler, '定規',
                onTap: onRulerTap),
            _toolButton(Icons.text_fields, DrawingTool.text, 'テキスト',
                onTap: onTextTap),
            _toolButton(Icons.category, DrawingTool.shape, '図形（タップで種別選択）',
                onTap: onShapeTap),
            const SizedBox(width: 4),
            // 色インジケーター
            GestureDetector(
              onTap: onColorTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.tune, size: 20), onPressed: onBrushTap, tooltip: 'ブラシ設定'),
            IconButton(icon: const Icon(Icons.layers, size: 20), onPressed: onLayerTap, tooltip: 'レイヤー'),
            // オニオンスキン
            IconButton(icon: const Icon(Icons.layers_outlined, size: 20), onPressed: onOnionSkinTap, tooltip: 'オニオンスキン'),
            // ツール早替えボタン（↺）
            IconButton(icon: const Icon(Icons.loop, size: 20), onPressed: () {}, tooltip: 'ツール早替え'),
            IconButton(icon: const Icon(Icons.movie, size: 20), onPressed: onTimelineTap, tooltip: 'タイムライン'),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, DrawingTool tool, String tooltip,
      {VoidCallback? onTap}) {
    final isSelected = currentTool == tool;
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onTap ?? () => onToolSelected(tool),
      tooltip: tooltip,
      color: isSelected ? Colors.blue : null,
      style: isSelected ? IconButton.styleFrom(backgroundColor: Colors.blue.withValues(alpha: 0.15)) : null,
    );
  }

  Widget _selectToolButton(BuildContext context) {
    final isSelected = currentTool == DrawingTool.selectRect ||
        currentTool == DrawingTool.selectLasso ||
        currentTool == DrawingTool.selectMagicWand;
    final icon = switch (currentTool) {
      DrawingTool.selectLasso => Icons.gesture,
      DrawingTool.selectMagicWand => Icons.auto_awesome,
      _ => Icons.crop_square,
    };
    return GestureDetector(
      onLongPress: () => _showSelectMenu(context),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: () => onToolSelected(DrawingTool.selectRect),
        tooltip: '選択（長押しで種別変更）',
        color: isSelected ? Colors.blue : null,
        style: isSelected ? IconButton.styleFrom(backgroundColor: Colors.blue.withValues(alpha: 0.15)) : null,
      ),
    );
  }

  /// バケツツールのベタ塗り／トーン切り替えメニュー（仕様書04・17）。
  void _showBucketToneMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer<ToneService>(
        builder: (ctx, toneService, _) {
          final tones = toneService.tones;
          final useTone = toneService.bucketUseTone;
          final lastBucketTone = toneService.lastBucketTone;
          return SafeArea(
            child: SizedBox(
              height: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.format_color_fill, size: 18),
                    title: const Text('ベタ塗り', style: TextStyle(fontSize: 13)),
                    selected: !useTone,
                    onTap: () {
                      toneService.setBucketUseTone(false);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text('トーン一覧', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: tones.length,
                      itemBuilder: (context, index) {
                        final tone = tones[index];
                        final isSelected = useTone && lastBucketTone?.id == tone.id;
                        return GestureDetector(
                          onTap: () {
                            toneService.setBucketUseTone(true);
                            toneService.setLastBucketTone(tone);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey[600]!,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey[800],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.grid_on, size: 16),
                                const SizedBox(height: 2),
                                Text(tone.name, style: const TextStyle(fontSize: 7),
                                    textAlign: TextAlign.center, maxLines: 2),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSelectMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.crop_square), title: const Text('矩形選択'), onTap: () { onToolSelected(DrawingTool.selectRect); Navigator.pop(ctx); }),
            ListTile(leading: const Icon(Icons.gesture), title: const Text('投げ縄選択'), onTap: () { onToolSelected(DrawingTool.selectLasso); Navigator.pop(ctx); }),
            ListTile(leading: const Icon(Icons.auto_awesome), title: const Text('自動選択（マジックワンド）'), onTap: () { onToolSelected(DrawingTool.selectMagicWand); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }
}
