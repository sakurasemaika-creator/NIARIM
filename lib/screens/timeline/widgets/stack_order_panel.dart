import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../engine/timeline_stack.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/scene.dart';
import '../../../models/scene_stack.dart';
import '../../../models/timeline_row_kind.dart';
import '../../../services/project_service.dart';
import '../../../widgets/layer_mask_editor.dart';

/// Edits a scene's 重なり順 in place of the timeline's tracks, with the
/// preview above it in view: the frame's drawing and each text, image and
/// video row as one item each, front first, for the whole scene or from the
/// current frame on; and the mask of the frame's drawing.
class TimelineStackOrderPanel extends StatefulWidget {
  const TimelineStackOrderPanel({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.currentFrame,
    required this.onClose,
    required this.onSeek,
  });

  final String projectId;
  final String sceneId;
  final ValueListenable<int> currentFrame;
  final VoidCallback onClose;
  final ValueChanged<int> onSeek;

  @override
  State<TimelineStackOrderPanel> createState() =>
      _TimelineStackOrderPanelState();
}

class _TimelineStackOrderPanelState extends State<TimelineStackOrderPanel> {
  /// Whether the order being edited is the one from the current frame on
  /// (else the whole scene's). Starts on the current frame's when a change
  /// already begins there.
  bool? _fromFrame;

  /// The rows with materials in [scene], as 重なり順 keys, and the names of
  /// the materials on each.
  Map<String, List<String>> _rowsOf(Scene scene) {
    final rows = <String, List<String>>{};
    for (final frame in scene.frames) {
      for (final layer in frame.layers) {
        final key = stackKeyOf(layer);
        if (key == null) continue;
        (rows[key] ??= []).add(layer.name);
      }
    }
    return rows;
  }

  String _labelOf(ProjectService ps, String key) {
    final l10n = AppLocalizations.of(context)!;
    if (key == kStackFrame) return l10n.timelineStackFrameUnit;
    final track = parseStackTrackKey(key);
    if (track == null) return key;
    final (kind, base) = switch (track.kind) {
      StackTrackKind.text => (TimelineRowKind.text, l10n.timelineMaterialText),
      StackTrackKind.image => (
        TimelineRowKind.image,
        l10n.projectListMaterialImage,
      ),
      StackTrackKind.video => (
        TimelineRowKind.video,
        l10n.projectListMaterialVideo,
      ),
    };
    final names = ps.rowNamesOf(widget.projectId, widget.sceneId, kind);
    final custom = track.row < names.length ? names[track.row] : null;
    return custom ?? '$base${track.row + 1}';
  }

  IconData _iconOf(String key) {
    if (key == kStackFrame) return Icons.brush;
    return switch (parseStackTrackKey(key)?.kind) {
      StackTrackKind.text => Icons.text_fields,
      StackTrackKind.image => Icons.image,
      StackTrackKind.video => Icons.videocam,
      null => Icons.help_outline,
    };
  }

  void _setOrder(
    ProjectService ps,
    Scene scene,
    bool fromFrame,
    int frame,
    List<String> order,
  ) {
    final stack = scene.stack;
    if (!fromFrame) {
      ps.updateSceneStack(
        widget.projectId,
        widget.sceneId,
        stack.copyWith(order: order),
      );
      return;
    }
    final changes = [
      for (final c in stack.changes)
        if (c.frameIndex != frame) c,
      StackChange(frameIndex: frame, order: order),
    ]..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    ps.updateSceneStack(
      widget.projectId,
      widget.sceneId,
      stack.copyWith(changes: changes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final scene = ps.sceneOf(widget.projectId, widget.sceneId);
    if (scene == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: ValueListenableBuilder<int>(
        valueListenable: widget.currentFrame,
        builder: (context, frame, _) {
          final rows = _rowsOf(scene);
          final present = rows.keys.toSet();
          final fromFrame = _fromFrame ?? scene.stack.changeAt(frame) != null;
          final order = fromFrame
              ? stackOrderAt(scene, frame, present)
              : normalizeStackOrder(scene.stack.order, {
                  ...present,
                  kStackFrame,
                });
          void move(int from, int to) {
            if (to < 0 || to >= order.length || from == to) return;
            final next = [...order];
            final key = next.removeAt(from);
            next.insert(to, key);
            _setOrder(ps, scene, fromFrame, frame, next);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.timelineStackOrderTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: l10n.commonClose,
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.movie_outlined, size: 16),
                            label: Text(l10n.timelineStackScopeScene),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: Text(
                              l10n.timelineStackScopeFromFrame(frame + 1),
                            ),
                          ),
                        ],
                        selected: {fromFrame},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            setState(() => _fromFrame = s.first),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          l10n.timelineStackOrderHint,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: order.length,
                        onReorderItem: move,
                        itemBuilder: (context, i) {
                          final key = order[i];
                          final names = rows[key] ?? const <String>[];
                          return Card(
                            key: ValueKey('stack-$key'),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: key == kStackFrame
                                ? scheme.secondaryContainer
                                : scheme.surfaceContainerHigh,
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(
                                left: 4,
                                right: 0,
                              ),
                              leading: ReorderableDragStartListener(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.drag_indicator,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Icon(_iconOf(key), size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _labelOf(ps, key),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: names.isEmpty
                                  ? null
                                  : Text(
                                      names.join('・'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward),
                                    tooltip: l10n.timelineStackMoveUp,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: i == 0
                                        ? null
                                        : () => move(i, i - 1),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward),
                                    tooltip: l10n.timelineStackMoveDown,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: i == order.length - 1
                                        ? null
                                        : () => move(i, i + 1),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (!fromFrame && scene.stack.order.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: Text(l10n.timelineStackResetScene),
                            onPressed: () => ps.updateSceneStack(
                              widget.projectId,
                              widget.sceneId,
                              scene.stack.copyWith(order: const []),
                            ),
                          ),
                        ),
                      if (scene.stack.changes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.timelineStackChangesLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final c in scene.stack.changes)
                              InputChip(
                                avatar: const Icon(Icons.flag, size: 16),
                                label: Text(
                                  l10n.timelineStackScopeFromFrame(
                                    c.frameIndex + 1,
                                  ),
                                ),
                                selected: c.frameIndex == frame && fromFrame,
                                showCheckmark: false,
                                onPressed: () {
                                  setState(() => _fromFrame = true);
                                  widget.onSeek(c.frameIndex);
                                },
                                deleteButtonTooltipMessage:
                                    l10n.timelineStackRemoveChange,
                                onDeleted: () => ps.updateSceneStack(
                                  widget.projectId,
                                  widget.sceneId,
                                  scene.stack.copyWith(
                                    changes: [
                                      for (final other in scene.stack.changes)
                                        if (other.frameIndex != c.frameIndex)
                                          other,
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const Divider(height: 24),
                      Text(
                        l10n.timelineStackFrameMaskTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LayerMaskEditor(
                        mask: scene.stack.frameMask,
                        hint: l10n.timelineStackFrameMaskHint,
                        onChanged: (m) => ps.updateSceneStack(
                          widget.projectId,
                          widget.sceneId,
                          scene.stack.copyWith(frameMask: m),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
