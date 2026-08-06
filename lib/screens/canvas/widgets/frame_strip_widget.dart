import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/project_service.dart';

class FrameStripWidget extends StatelessWidget {
  final int currentFrame;
  final String projectId;
  final String sceneId;
  final ValueChanged<int> onFrameSelected;
  final VoidCallback onTimelineTap;
  // フレーム複数選択モード（仕様書18：大量処理実行時のフレーム一括選択）
  final bool multiSelectMode;
  final Set<int> selectedFrames;
  final ValueChanged<int>? onFrameToggle;

  const FrameStripWidget({
    super.key,
    required this.currentFrame,
    required this.projectId,
    required this.sceneId,
    required this.onFrameSelected,
    required this.onTimelineTap,
    this.multiSelectMode = false,
    this.selectedFrames = const {},
    this.onFrameToggle,
  });

  void _showHoldDialog(BuildContext context, ProjectService service, int frameIndex, int currentHold) {
    int hold = currentHold;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('F${frameIndex + 1} 保持セル数'),
          content: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: hold > 1 ? () => setS(() => hold--) : null,
              ),
              Expanded(child: Center(child: Text('$hold', style: const TextStyle(fontSize: 24)))),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: hold < 99 ? () => setS(() => hold++) : null,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                service.setFrameHold(projectId, sceneId, frameIndex, hold);
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();
    final total = service.frameCount(projectId, sceneId);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: total + 1, // +1 は追加ボタン
              itemBuilder: (context, index) {
                if (index == total) {
                  return GestureDetector(
                    onTap: () => service.addFrame(projectId, sceneId),
                    child: Container(
                      width: 48,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[600]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: Icon(Icons.add, color: Colors.grey)),
                    ),
                  );
                }
                final isChecked = selectedFrames.contains(index);
                final isSelected = multiSelectMode ? isChecked : index == currentFrame;
                final hold = service.frameHold(projectId, sceneId, index);
                return GestureDetector(
                  onTap: multiSelectMode
                      ? () => onFrameToggle?.call(index)
                      : () => onFrameSelected(index),
                  onLongPress: multiSelectMode
                      ? null
                      : () => _showHoldDialog(context, service, index, hold),
                  child: Container(
                    width: 48,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[isSelected ? 700 : 850],
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        if (hold > 1)
                          Center(
                            child: Text('$hold',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold)),
                          ),
                        if (multiSelectMode)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Icon(
                              isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 14,
                              color: isChecked ? Theme.of(context).colorScheme.primary : Colors.grey[400],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onTimelineTap,
            tooltip: 'タイムラインモード',
          ),
        ],
      ),
    );
  }
}
