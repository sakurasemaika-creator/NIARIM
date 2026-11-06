import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../engine/timeline_stack.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/scene.dart';
import '../../../models/scene_stack.dart';
import '../../../models/timeline_row_kind.dart';
import '../../../services/project_service.dart';
import '../../../widgets/layer_mask_editor.dart';
import '../../../config/accent_text_theme.dart';

/// Where the order being edited is used.
enum _StackTarget {
  /// Every frame of this scene (the scene's order).
  currentScene,

  /// Frames ○〜○ of this scene (「フレーム範囲」, typed or dragged).
  range,

  /// Every frame of each of several chosen scenes.
  scenes,

  /// Every frame of every scene.
  allFrames,
}

/// Edits the 重なり順 in place of the timeline's tracks, with the preview
/// above it in view: the frame's drawing and each text, image and video row
/// as one item each, front first. The order is used for the whole current
/// scene, a range of its frames, several chosen scenes or every frame of
/// every scene; below it is the mask of the frame's drawing.
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
  /// Where the order is used. Starts on 「フレーム範囲」 when the frame shown
  /// is in a range, else 「現在のシーン全体」.
  _StackTarget? _target;

  /// The range being edited (its place in the scene's ranges, which are
  /// sorted and do not overlap, so editing one keeps the places).
  int? _selected;

  /// The scenes chosen for 「シーン複数選択」 (this scene to begin with).
  Set<String>? _chosenScenes;

  /// Whether items are being picked (a long press on one starts it), and
  /// the picked items' 重なり順 keys: the arrows, a drag and the bar below
  /// move them together.
  bool _selecting = false;
  final Set<String> _picked = {};

  /// The order list shown in this build and how to change it, for the
  /// selection bar under the panel.
  ({List<String> order, ValueChanged<List<String>> apply})? _shown;

  void _toggle(String key) => setState(() {
    if (!_picked.remove(key)) {
      _picked.add(key);
    } else if (_picked.isEmpty) {
      _selecting = false;
    }
  });

  void _deselectAll() => setState(() {
    _picked.clear();
    _selecting = false;
  });

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

  String _labelOf(ProjectService ps, String sceneId, String key) {
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
    final names = ps.rowNamesOf(widget.projectId, sceneId, kind);
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

  void _save(ProjectService ps, SceneStack stack) =>
      ps.updateSceneStack(widget.projectId, widget.sceneId, stack);

  void _seek(int frame) {
    if (frame != widget.currentFrame.value) widget.onSeek(frame);
  }

  /// Adds a range at [frame] (the one frame, between its neighbours) with
  /// the order shown there now.
  void _addRange(ProjectService ps, Scene scene, int frame, Set<String> keys) {
    final range = StackRange(
      start: frame,
      end: frame,
      order: stackOrderAt(scene, frame, keys),
    );
    final next = [...scene.stack.ranges, range]
      ..sort((a, b) => a.start.compareTo(b.start));
    _save(ps, scene.stack.copyWith(ranges: next));
    setState(() => _selected = next.indexOf(range));
  }

  /// Moves range [index]'s start or end, kept inside the scene and clear of
  /// the ranges either side (the end follows a start moved past it).
  void _setBounds(
    ProjectService ps,
    Scene scene,
    int index,
    int lastFrame, {
    int? start,
    int? end,
  }) {
    final ranges = scene.stack.ranges;
    final range = ranges[index];
    final low = index > 0 ? ranges[index - 1].end + 1 : 0;
    final high = math.min(
      lastFrame,
      index + 1 < ranges.length ? ranges[index + 1].start - 1 : lastFrame,
    );
    // Frames deleted after the ranges were set can leave no room.
    if (high < low) return;
    final newStart = (start ?? range.start).clamp(low, high);
    final newEnd = math
        .max(newStart, end ?? math.min(range.end, lastFrame))
        .clamp(newStart, high);
    if (newStart == range.start && newEnd == range.end) return;
    final next = [...ranges]
      ..[index] = range.copyWith(start: newStart, end: newEnd);
    _save(ps, scene.stack.copyWith(ranges: next));
    _seek(start != null && newStart != range.start ? newStart : newEnd);
  }

  void _removeRange(ProjectService ps, Scene scene, int index) {
    final next = [...scene.stack.ranges]..removeAt(index);
    _save(ps, scene.stack.copyWith(ranges: next));
    setState(
      () => _selected = next.isEmpty ? null : index.clamp(0, next.length - 1),
    );
  }

  Widget _orderList(
    ProjectService ps,
    String sceneId,
    List<String> order,
    Map<String, List<String>> rows,
    ValueChanged<List<String>> onReordered,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    _shown = (order: order, apply: onReordered);
    final picked = _picked.intersection(order.toSet());
    // A picked item's arrows move every picked item; another item's move
    // just that one.
    List<String> step(String key, {required bool forward}) =>
        stepStackSelection(
          order,
          picked.contains(key) ? picked : {key},
          forward: forward,
        );

    final list = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: order.length,
      onReorderItem: (from, to) {
        if (from != to) {
          onReordered(dragStackSelection(order, picked, from, to));
        }
      },
      itemBuilder: (context, i) {
        final key = order[i];
        final names = rows[key] ?? const <String>[];
        final isPicked = _selecting && picked.contains(key);
        final up = step(key, forward: true);
        final down = step(key, forward: false);
        return Card(
          key: ValueKey('stack-$key'),
          margin: const EdgeInsets.symmetric(vertical: 3),
          color: key == kStackFrame
              ? scheme.secondaryContainer
              : scheme.surfaceContainerHigh,
          shape: isPicked
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: scheme.primary, width: 2),
                )
              : null,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 4, right: 0),
            onLongPress: _selecting
                ? null
                : () => setState(() {
                    _selecting = true;
                    _picked
                      ..clear()
                      ..add(key);
                  }),
            onTap: _selecting ? () => _toggle(key) : null,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _selecting ? 4 : 8,
                      vertical: 8,
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // The whole item toggles too, so the box can be small.
                if (_selecting)
                  Checkbox(
                    value: isPicked,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => _toggle(key),
                  ),
              ],
            ),
            title: Row(
              children: [
                Icon(_iconOf(key), size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _labelOf(ps, sceneId, key),
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
                  onPressed: listEquals(up, order)
                      ? null
                      : () => onReordered(up),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: l10n.timelineStackMoveDown,
                  visualDensity: VisualDensity.compact,
                  onPressed: listEquals(down, order)
                      ? null
                      : () => onReordered(down),
                ),
              ],
            ),
          ),
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        list,
        if (!_selecting) _hint(l10n.timelineStackMultiSelectHint),
      ],
    );
  }

  /// The bar under the panel while items are picked: how many, select or
  /// deselect all, and moving them to the front, forward, backward or to
  /// the back together.
  Widget _selectionBar() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final shown = _shown!;
    final order = shown.order;
    final picked = _picked.intersection(order.toSet());
    Widget action(IconData icon, String label, List<String> next) => Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          minimumSize: const Size(0, 48),
        ),
        onPressed: listEquals(next, order) ? null : () => shown.apply(next),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.timelineStackSelectedCount(picked.length),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: picked.length == order.length
                        ? null
                        : () => setState(() => _picked.addAll(order)),
                    child: Text(l10n.timelineStackSelectAll),
                  ),
                  TextButton(
                    onPressed: _deselectAll,
                    child: Text(l10n.timelineStackDeselectAll),
                  ),
                ],
              ),
              Row(
                children: [
                  action(
                    Icons.vertical_align_top,
                    l10n.timelineStackBringToFront,
                    stackSelectionToEnd(order, picked, front: true),
                  ),
                  action(
                    Icons.arrow_upward,
                    l10n.timelineStackMoveUp,
                    stepStackSelection(order, picked, forward: true),
                  ),
                  action(
                    Icons.arrow_downward,
                    l10n.timelineStackMoveDown,
                    stepStackSelection(order, picked, forward: false),
                  ),
                  action(
                    Icons.vertical_align_bottom,
                    l10n.timelineStackSendToBack,
                    stackSelectionToEnd(order, picked, front: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _resetButton(VoidCallback onPressed) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      icon: const Icon(Icons.restart_alt, size: 18),
      label: Text(AppLocalizations.of(context)!.timelineStackResetScene),
      onPressed: onPressed,
    ),
  );

  /// The order list for every frame of [targets] (the current scene, chosen
  /// scenes or all of them): this scene's order (or the first target's)
  /// over the rows any of them has; a change sets it in all of them.
  List<Widget> _scenesOrder(
    ProjectService ps,
    Scene scene,
    List<Scene> targets,
    String hint,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final basis = targets.any((s) => s.id == scene.id) ? scene : targets.first;
    final rows = <String, List<String>>{};
    for (final s in targets) {
      _rowsOf(s).forEach((key, names) => (rows[key] ??= []).addAll(names));
    }
    final order = normalizeStackOrder(basis.stack.order, {
      ...rows.keys,
      kStackFrame,
    });
    void apply(List<String> next) {
      for (final s in targets) {
        ps.updateSceneStack(
          widget.projectId,
          s.id,
          s.stack.copyWith(order: next),
        );
      }
    }

    return [
      _hint(hint),
      if (targets.any((s) => s.stack.ranges.isNotEmpty))
        _hint(l10n.timelineStackRangesTakePriority),
      _orderList(ps, basis.id, order, rows, apply),
      if (targets.any((s) => s.stack.order.isNotEmpty))
        _resetButton(() => apply(const [])),
    ];
  }

  List<Widget> _rangeSection(
    ProjectService ps,
    Scene scene,
    int frame,
    int? picked,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final rows = _rowsOf(scene);
    final lastFrame = math.max(
      0,
      ps.frameCount(widget.projectId, widget.sceneId) - 1,
    );
    final ranges = scene.stack.ranges;
    final selected = picked != null && picked < ranges.length ? picked : null;
    final keys = {...rows.keys, kStackFrame};
    final range = selected == null ? null : ranges[selected];
    // Within the scene: frames deleted after a range was set can leave it
    // reaching (or starting) past the last frame.
    int shownStart(StackRange r) => math.min(r.start, lastFrame);
    int shownEnd(StackRange r) =>
        math.max(shownStart(r), math.min(r.end, lastFrame));
    String label(StackRange r) =>
        l10n.timelineStackRangeLabel(shownStart(r) + 1, shownEnd(r) + 1);
    final start = range == null ? 0 : shownStart(range);
    final end = range == null ? 0 : shownEnd(range);
    return [
      _hint(l10n.timelineStackRangeHint),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (var i = 0; i < ranges.length; i++)
            ChoiceChip(
              avatar: Icon(
                Icons.date_range,
                size: 16,
                color: i == selected ? AccentTextTheme.of(context) : null,
              ),
              label: Text(label(ranges[i])),
              selected: i == selected,
              showCheckmark: false,
              onSelected: (_) {
                setState(() => _selected = i);
                _seek(shownStart(ranges[i]));
              },
            ),
          // A new range starts at the frame shown (move the seek bar to
          // choose it); a frame already in a range has its range above.
          if (scene.stack.rangeAt(frame) == null)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.timelineStackRangeAdd(frame + 1)),
              onPressed: () => _addRange(ps, scene, frame, keys),
            ),
        ],
      ),
      if (range == null)
        _hint(l10n.timelineStackRangeEmpty)
      else ...[
        const SizedBox(height: 10),
        // Typed frame numbers (○フレーム目〜○フレーム目), and a two-thumb
        // slider for dragging them.
        Row(
          children: [
            Expanded(
              child: _FrameNumberField(
                key: ValueKey('range-start-$selected'),
                label: l10n.layerPanelRangeStartFrameLabel,
                value: start + 1,
                max: lastFrame + 1,
                onChanged: (v) =>
                    _setBounds(ps, scene, selected!, lastFrame, start: v - 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(l10n.layerPanelRangeTilde),
            ),
            Expanded(
              child: _FrameNumberField(
                key: ValueKey('range-end-$selected'),
                label: l10n.layerPanelRangeEndFrameLabel,
                value: end + 1,
                max: lastFrame + 1,
                onChanged: (v) =>
                    _setBounds(ps, scene, selected!, lastFrame, end: v - 1),
              ),
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues((start + 1).toDouble(), (end + 1).toDouble()),
          min: 1,
          max: math.max(2, lastFrame + 1).toDouble(),
          divisions: math.max(1, lastFrame),
          labels: RangeLabels('F${start + 1}', 'F${end + 1}'),
          onChanged: (v) {
            final newStart = (v.start.round() - 1).clamp(0, lastFrame);
            final newEnd = (v.end.round() - 1).clamp(0, lastFrame);
            if (newStart != start) {
              _setBounds(ps, scene, selected!, lastFrame, start: newStart);
            } else if (newEnd != end) {
              _setBounds(ps, scene, selected!, lastFrame, end: newEnd);
            }
          },
        ),
        _hint(l10n.timelineStackRangeOrderHint(label(range))),
        _orderList(
          ps,
          scene.id,
          normalizeStackOrder(range.order, keys),
          rows,
          (next) => _save(
            ps,
            scene.stack.copyWith(
              ranges: [...ranges]..[selected!] = range.copyWith(order: next),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
            label: Text(
              l10n.timelineStackRangeDelete,
              style: TextStyle(color: scheme.error),
            ),
            onPressed: () => _removeRange(ps, scene, selected!),
          ),
        ),
      ],
    ];
  }

  List<Widget> _chosenScenesSection(ProjectService ps, Scene scene) {
    final l10n = AppLocalizations.of(context)!;
    final all = ps.scenesOf(widget.projectId);
    final chosen = {
      for (final id in _chosenScenes ?? {widget.sceneId})
        if (all.any((s) => s.id == id)) id,
    };
    if (chosen.isEmpty) chosen.add(widget.sceneId);
    return [
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final s in all)
            FilterChip(
              label: Text(s.displayName),
              selected: chosen.contains(s.id),
              // At least one scene stays chosen.
              onSelected: chosen.length == 1 && chosen.contains(s.id)
                  ? null
                  : (on) => setState(
                      () => _chosenScenes = on
                          ? {...chosen, s.id}
                          : ({...chosen}..remove(s.id)),
                    ),
            ),
        ],
      ),
      ..._scenesOrder(
        ps,
        scene,
        all.where((s) => chosen.contains(s.id)).toList(),
        l10n.timelineStackScenesHint,
      ),
    ];
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
          final inRange = scene.stack.ranges.indexWhere(
            (r) => r.contains(frame),
          );
          final target =
              _target ??
              (inRange >= 0 ? _StackTarget.range : _StackTarget.currentScene);
          // Until one is picked, the range the shown frame is in.
          final selected = _selected ?? (inRange >= 0 ? inRange : null);
          // Built first: it sets [_shown] for the selection bar.
          _shown = null;
          final section = switch (target) {
            _StackTarget.currentScene => _scenesOrder(ps, scene, [
              scene,
            ], l10n.timelineStackOrderHint),
            _StackTarget.range => _rangeSection(ps, scene, frame, selected),
            _StackTarget.scenes => _chosenScenesSection(ps, scene),
            _StackTarget.allFrames => _scenesOrder(
              ps,
              scene,
              ps.scenesOf(widget.projectId),
              l10n.timelineStackAllFramesHint,
            ),
          };
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.timelineStackTargetLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      RadioGroup<_StackTarget>(
                        groupValue: target,
                        onChanged: (v) => setState(() => _target = v),
                        child: Column(
                          children: [
                            for (final (value, icon, text) in [
                              (
                                _StackTarget.currentScene,
                                Icons.movie_outlined,
                                l10n.timelineStackScopeScene,
                              ),
                              (
                                _StackTarget.range,
                                Icons.date_range,
                                l10n.timelineStackScopeRange,
                              ),
                              (
                                _StackTarget.scenes,
                                Icons.library_add_check_outlined,
                                l10n.timelineStackTargetScenes,
                              ),
                              (
                                _StackTarget.allFrames,
                                Icons.select_all,
                                l10n.timelineStackTargetAllFrames,
                              ),
                            ])
                              RadioListTile<_StackTarget>(
                                value: value,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                title: Row(
                                  children: [
                                    Icon(icon, size: 18),
                                    const SizedBox(width: 6),
                                    Flexible(child: Text(text)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...section,
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
                        onChanged: (m) =>
                            _save(ps, scene.stack.copyWith(frameMask: m)),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selecting && _shown != null) _selectionBar(),
            ],
          );
        },
      ),
    );
  }
}

/// A frame number typed by hand (1 to [max]): taken when the keyboard's
/// done key is pressed or the field is left, and following [value] when it
/// changes elsewhere (the slider) while the field is not being typed in.
class _FrameNumberField extends StatefulWidget {
  const _FrameNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_FrameNumberField> createState() => _FrameNumberFieldState();
}

class _FrameNumberFieldState extends State<_FrameNumberField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: '${widget.value}',
  );
  final FocusNode _focus = FocusNode();

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _FrameNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _ctrl.text != '${widget.value}') {
      _ctrl.text = '${widget.value}';
    }
  }

  void _commit() {
    if (!mounted) return;
    final typed = int.tryParse(_ctrl.text);
    if (typed == null) {
      _ctrl.text = '${widget.value}';
      return;
    }
    final v = typed.clamp(1, widget.max);
    _ctrl.text = '$v';
    if (v != widget.value) widget.onChanged(v);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    focusNode: _focus,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: widget.label,
      prefixText: 'F',
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onSubmitted: (_) => _commit(),
  );
}
