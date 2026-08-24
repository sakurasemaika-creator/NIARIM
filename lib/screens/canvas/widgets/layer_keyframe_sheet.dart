import 'package:flutter/material.dart';
import '../../../engine/layer_keyframe_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/layer.dart' as model;
import '../../../models/layer_keyframe.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/stepped_slider.dart';

/// レイヤー単位の位置・拡大縮小・回転キーフレーム（パーツ単位アニメーション）を
/// 一覧・追加・編集・削除するシート。カメラキーフレームと違い専用のタイムライン
/// トラックは持たせず、レイヤーパネルの「詳細設定」から開く一覧形式にすることで、
/// レイヤーの数だけトラックが増える複雑さを避けている。
/// [onChanged]は保存後のキーフレーム一覧を呼び出し元へ渡すコールバック。
void showLayerKeyframeSheet(
  BuildContext context, {
  required model.Layer layer,
  required int currentFrame,
  required int totalFrames,
  required int canvasWidth,
  required int canvasHeight,
  required ValueChanged<List<LayerKeyframe>> onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _LayerKeyframeListSheet(
      layerName: layer.name,
      initialKeyframes: layer.keyframes,
      currentFrame: currentFrame,
      totalFrames: totalFrames,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      onChanged: onChanged,
    ),
  );
}

/// レイヤーグループのキーフレームを一覧・追加・編集・削除するシート。
/// 中身は[showLayerKeyframeSheet]と共通（対象が1レイヤーかグループかの
/// 違いだけで、キーフレームの構造・補間方法は同じため）。
void showLayerGroupKeyframeSheet(
  BuildContext context, {
  required String groupName,
  required List<LayerKeyframe> initialKeyframes,
  required int currentFrame,
  required int totalFrames,
  required int canvasWidth,
  required int canvasHeight,
  required ValueChanged<List<LayerKeyframe>> onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _LayerKeyframeListSheet(
      layerName: groupName,
      initialKeyframes: initialKeyframes,
      currentFrame: currentFrame,
      totalFrames: totalFrames,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      onChanged: onChanged,
    ),
  );
}

class _LayerKeyframeListSheet extends StatefulWidget {
  final String layerName;
  final List<LayerKeyframe> initialKeyframes;
  final int currentFrame;
  final int totalFrames;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<List<LayerKeyframe>> onChanged;
  const _LayerKeyframeListSheet({
    required this.layerName,
    required this.initialKeyframes,
    required this.currentFrame,
    required this.totalFrames,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onChanged,
  });

  @override
  State<_LayerKeyframeListSheet> createState() => _LayerKeyframeListSheetState();
}

class _LayerKeyframeListSheetState extends State<_LayerKeyframeListSheet> {
  late List<LayerKeyframe> _keyframes = [...widget.initialKeyframes];
  final _engine = LayerKeyframeEngine();

  void _persist() {
    _keyframes.sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    widget.onChanged(_keyframes);
    setState(() {});
  }

  void _addAtCurrentFrame() {
    // 既存キーフレームから現在フレームの補間値を初期値にすることで、
    // 「今見えている位置」からの微調整として編集を始められるようにする。
    final base = _engine.valueAt(_keyframes, widget.currentFrame);
    final kf = base.copyWith(frameIndex: widget.currentFrame);
    _editKeyframe(kf, isNew: true);
  }

  void _editKeyframe(LayerKeyframe kf, {required bool isNew}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LayerKeyframeEditSheet(
        keyframe: kf,
        totalFrames: widget.totalFrames,
        canvasWidth: widget.canvasWidth,
        canvasHeight: widget.canvasHeight,
        onSave: (newKf) {
          setState(() {
            _keyframes = _keyframes.where((k) => k.frameIndex != kf.frameIndex && k.frameIndex != newKf.frameIndex).toList()
              ..add(newKf);
          });
          _persist();
        },
        onDelete: isNew
            ? null
            : () {
                setState(() => _keyframes = _keyframes.where((k) => k.frameIndex != kf.frameIndex).toList());
                _persist();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [..._keyframes]..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.layerKeyframeSheetTitle(widget.layerName),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.layerKeyframeSheetDesc,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.layerKeyframeAddAtCurrentFrame(widget.currentFrame + 1)),
                onPressed: _addAtCurrentFrame,
              ),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(l10n.layerKeyframeEmpty,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: sorted.length,
                    itemBuilder: (ctx, i) {
                      final kf = sorted[i];
                      return ListTile(
                        leading: const Icon(Icons.diamond_outlined, size: 18),
                        title: Text('F${kf.frameIndex + 1}'),
                        subtitle: Text(
                          'X:${kf.x.round()} Y:${kf.y.round()} '
                          '${l10n.layerKeyframeScaleShort}:${kf.scale.toStringAsFixed(2)} '
                          '${l10n.layerKeyframeRotationShort}:${kf.rotation.round()}°',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _editKeyframe(kf, isNew: false),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() => _keyframes = _keyframes.where((k) => k.frameIndex != kf.frameIndex).toList());
                            _persist();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LayerKeyframeEditSheet extends StatefulWidget {
  final LayerKeyframe keyframe;
  final int totalFrames;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<LayerKeyframe> onSave;
  final VoidCallback? onDelete;
  const _LayerKeyframeEditSheet({
    required this.keyframe,
    required this.totalFrames,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_LayerKeyframeEditSheet> createState() => _LayerKeyframeEditSheetState();
}

class _LayerKeyframeEditSheetState extends State<_LayerKeyframeEditSheet> {
  late LayerKeyframe _kf = widget.keyframe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxFrame = (widget.totalFrames - 1).clamp(0, 1 << 30);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(l10n.layerKeyframeEditTitle(_kf.frameIndex + 1),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon'))),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete!();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _row(l10n.layerKeyframeFrameLabel, _kf.frameIndex.toDouble(), 0, maxFrame.toDouble(), maxFrame + 1,
                    (v) => setState(() => _kf = _kf.copyWith(frameIndex: v.round())), 'F${_kf.frameIndex + 1}', isInt: true),
                _row('X', _kf.x, -widget.canvasWidth.toDouble(), widget.canvasWidth.toDouble(), 0,
                    (v) => setState(() => _kf = _kf.copyWith(x: v)), _kf.x.round().toString()),
                _row('Y', _kf.y, -widget.canvasHeight.toDouble(), widget.canvasHeight.toDouble(), 0,
                    (v) => setState(() => _kf = _kf.copyWith(y: v)), _kf.y.round().toString()),
                _row(l10n.layerKeyframeScaleLabel, _kf.scale, 0.1, 3.0, 0,
                    (v) => setState(() => _kf = _kf.copyWith(scale: v)), '${(_kf.scale * 100).round()}%', isInt: false, step: 0.05),
                _row(l10n.layerKeyframeRotationLabel, _kf.rotation, -180, 180, 0,
                    (v) => setState(() => _kf = _kf.copyWith(rotation: v)), '${_kf.rotation.round()}°'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSave(_kf);
                },
                child: Text(l10n.commonSave),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, double min, double max, int divisions,
      ValueChanged<double> onChanged, String valueText, {bool isInt = false, double step = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: SteppedSlider(
              value: value.clamp(min, max),
              min: min, max: max,
              divisions: divisions > 0 ? divisions : null,
              step: step,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: EditableSliderValue(
              text: valueText,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.right,
              value: value, min: min, max: max, isInt: isInt,
              onChanged: (v) => onChanged(v.toDouble()),
            ),
          ),
        ],
      ),
    );
  }
}
