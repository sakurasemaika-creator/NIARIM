import 'dart:math' as math;

import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';

import '../../../engine/layer_keyframe_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/layer.dart' as model;
import '../../../models/layer_keyframe.dart';
import '../../../services/project_service.dart';
import '../../../widgets/keyframe_preview.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../config/font_fallback.dart';

/// イージング種別の表示名（一覧の行・編集シートの選択チップの両方で使う）。
String layerKeyframeEasingLabel(
  AppLocalizations l10n,
  LayerKeyframeEasing easing,
) => switch (easing) {
  LayerKeyframeEasing.linear => l10n.layerKeyframeEasingLinear,
  LayerKeyframeEasing.easeIn => l10n.layerKeyframeEasingEaseIn,
  LayerKeyframeEasing.easeOut => l10n.layerKeyframeEasingEaseOut,
  LayerKeyframeEasing.easeInOut => l10n.layerKeyframeEasingEaseInOut,
  LayerKeyframeEasing.bounceOut => l10n.layerKeyframeEasingBounceOut,
};

/// "How it goes on to the next keyframe": the five curves as chips. Layers,
/// materials and the camera choose it the same way.
class KeyframeEasingChoices extends StatelessWidget {
  final LayerKeyframeEasing easing;
  final ValueChanged<LayerKeyframeEasing> onChanged;

  const KeyframeEasingChoices({
    super.key,
    required this.easing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.layerKeyframeEasingLabel,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final choice in LayerKeyframeEasing.values)
              ChoiceChip(
                key: ValueKey('keyframeEasing-${choice.name}'),
                label: Text(
                  layerKeyframeEasingLabel(l10n, choice),
                  style: const TextStyle(fontSize: 11),
                ),
                selected: easing == choice,
                onSelected: (_) => onChanged(choice),
              ),
          ],
        ),
      ],
    );
  }
}

/// レイヤー単位の位置・拡大縮小・回転キーフレーム（パーツ単位アニメーション）を
/// 一覧・追加・編集・削除するシート。カメラキーフレームと違い専用のタイムライン
/// トラックは持たせず、レイヤーパネルの「詳細設定」から開く一覧形式にすることで、
/// レイヤーの数だけトラックが増える複雑さを避けている。
/// [onChanged]は保存後のキーフレーム一覧を呼び出し元へ渡すコールバック。
void showLayerKeyframeSheet(
  BuildContext context, {
  required model.Layer layer,
  required ProjectService projects,
  required String projectId,
  required String sceneId,
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
      projects: projects,
      projectId: projectId,
      sceneId: sceneId,
      layerId: layer.id,
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
  required ProjectService projects,
  required String projectId,
  required String sceneId,
  required String groupId,
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
      projects: projects,
      projectId: projectId,
      sceneId: sceneId,
      groupId: groupId,
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
  final ProjectService projects;
  final String projectId;
  final String sceneId;
  final String? layerId;
  final String? groupId;
  final String layerName;
  final List<LayerKeyframe> initialKeyframes;
  final int currentFrame;
  final int totalFrames;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<List<LayerKeyframe>> onChanged;
  const _LayerKeyframeListSheet({
    required this.projects,
    required this.projectId,
    required this.sceneId,
    this.layerId,
    this.groupId,
    required this.layerName,
    required this.initialKeyframes,
    required this.currentFrame,
    required this.totalFrames,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onChanged,
  });

  @override
  State<_LayerKeyframeListSheet> createState() =>
      _LayerKeyframeListSheetState();
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
        projects: widget.projects,
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        layerId: widget.layerId,
        groupId: widget.groupId,
        keyframe: kf,
        totalFrames: widget.totalFrames,
        canvasWidth: widget.canvasWidth,
        canvasHeight: widget.canvasHeight,
        onSave: (newKf) {
          setState(() {
            _keyframes =
                _keyframes
                    .where(
                      (k) =>
                          (isNew || k.frameIndex != kf.frameIndex) &&
                          k.frameIndex != newKf.frameIndex,
                    )
                    .toList()
                  ..add(newKf);
          });
          _persist();
        },
        onDelete: isNew
            ? null
            : () {
                setState(
                  () => _keyframes = _keyframes
                      .where((k) => k.frameIndex != kf.frameIndex)
                      .toList(),
                );
                _persist();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [..._keyframes]
      ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeService.activeColorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.layerKeyframeSheetTitle(widget.layerName),
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.layerKeyframeSheetDesc,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(
                  l10n.layerKeyframeAddAtCurrentFrame(widget.currentFrame + 1),
                ),
                onPressed: _addAtCurrentFrame,
              ),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      l10n.layerKeyframeEmpty,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                          '${l10n.layerKeyframeRotationShort}:${kf.rotation.round()}° '
                          '${layerKeyframeEasingLabel(l10n, kf.easing)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _editKeyframe(kf, isNew: false),
                        trailing: IconButton(
                          tooltip: l10n.commonDelete,
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            setState(
                              () => _keyframes = _keyframes
                                  .where((k) => k.frameIndex != kf.frameIndex)
                                  .toList(),
                            );
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
  final ProjectService projects;
  final String projectId;
  final String sceneId;
  final String? layerId;
  final String? groupId;
  final LayerKeyframe keyframe;
  final int totalFrames;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<LayerKeyframe> onSave;
  final VoidCallback? onDelete;
  const _LayerKeyframeEditSheet({
    required this.projects,
    required this.projectId,
    required this.sceneId,
    required this.layerId,
    required this.groupId,
    required this.keyframe,
    required this.totalFrames,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_LayerKeyframeEditSheet> createState() =>
      _LayerKeyframeEditSheetState();
}

class _LayerKeyframeEditSheetState extends State<_LayerKeyframeEditSheet> {
  late LayerKeyframe _kf = widget.keyframe;
  late LayerKeyframe _gestureStart = _kf;

  void _transform(Offset delta, double scale, double degrees) {
    final start = _gestureStart;
    // A group transform is applied outside the selected layer's transform.
    final group = widget.layerId == null
        ? null
        : widget.projects.groupContainingLayer(
            widget.projectId,
            widget.sceneId,
            widget.layerId!,
          );
    if (group != null && group.keyframes.isNotEmpty) {
      final parent = LayerKeyframeEngine().valueAt(
        group.keyframes,
        _kf.frameIndex,
      );
      final angle = -parent.rotation * math.pi / 180;
      final zoom = parent.scale == 0 ? 1.0 : parent.scale;
      delta = Offset(
        (delta.dx * math.cos(angle) - delta.dy * math.sin(angle)) / zoom,
        (delta.dx * math.sin(angle) + delta.dy * math.cos(angle)) / zoom,
      );
    }
    setState(
      () => _kf = start.copyWith(
        x: (start.x + delta.dx).clamp(
          -widget.canvasWidth.toDouble(),
          widget.canvasWidth.toDouble(),
        ),
        y: (start.y + delta.dy).clamp(
          -widget.canvasHeight.toDouble(),
          widget.canvasHeight.toDouble(),
        ),
        scale: (start.scale * scale).clamp(.1, 3.0),
        rotation: (start.rotation + degrees + 180) % 360 - 180,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final frameCount = widget.totalFrames.clamp(1, 1 << 30);
    final frameNumber = (_kf.frameIndex + 1).clamp(1, frameCount);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.91,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeService.activeColorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.layerKeyframeEditTitle(_kf.frameIndex + 1),
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: l10n.commonDelete,
                    icon: const Icon(Icons.delete),
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
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KeyframePreview(
                projects: widget.projects,
                projectId: widget.projectId,
                sceneId: widget.sceneId,
                frameIndex: _kf.frameIndex,
                layerId: widget.layerId,
                groupId: widget.groupId,
                layerTransform: _kf,
                onGestureStart: () => _gestureStart = _kf,
                onTransform: _transform,
              ),
            ),
          ),
          const KeyframePreviewHint(),
          Expanded(
            flex: 4,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _row(
                  l10n.layerKeyframeFrameLabel,
                  frameNumber.toDouble(),
                  1,
                  frameCount.toDouble(),
                  frameCount - 1,
                  (v) => setState(
                    () => _kf = _kf.copyWith(frameIndex: v.round() - 1),
                  ),
                  'F$frameNumber',
                  isInt: true,
                ),
                _row(
                  'X',
                  _kf.x,
                  -widget.canvasWidth.toDouble(),
                  widget.canvasWidth.toDouble(),
                  0,
                  (v) => setState(() => _kf = _kf.copyWith(x: v)),
                  _kf.x.round().toString(),
                ),
                _row(
                  'Y',
                  _kf.y,
                  -widget.canvasHeight.toDouble(),
                  widget.canvasHeight.toDouble(),
                  0,
                  (v) => setState(() => _kf = _kf.copyWith(y: v)),
                  _kf.y.round().toString(),
                ),
                _row(
                  l10n.layerKeyframeScaleLabel,
                  _kf.scale,
                  0.1,
                  3.0,
                  0,
                  (v) => setState(() => _kf = _kf.copyWith(scale: v)),
                  '${(_kf.scale * 100).round()}%',
                  isInt: false,
                  step: 0.05,
                ),
                _row(
                  l10n.layerKeyframeRotationLabel,
                  _kf.rotation,
                  -180,
                  180,
                  0,
                  (v) => setState(() => _kf = _kf.copyWith(rotation: v)),
                  '${_kf.rotation.round()}°',
                ),
                const SizedBox(height: 8),
                KeyframeEasingChoices(
                  easing: _kf.easing,
                  onChanged: (easing) =>
                      setState(() => _kf = _kf.copyWith(easing: easing)),
                ),
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

  Widget _row(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
    String valueText, {
    bool isInt = false,
    double step = 1,
  }) {
    return LabeledSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions > 0 ? divisions : null,
      step: step,
      onChanged: onChanged,
      valueText: valueText,
      valueStyle: const TextStyle(fontSize: 11),
      isInt: isInt,
    );
  }
}
