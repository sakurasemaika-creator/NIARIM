import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../engine/layer_range_resolver.dart';
import '../../../engine/timeline_material.dart';
import '../../../engine/undo_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/bundled_fonts.dart';
import '../../../models/layer.dart';
import '../../../models/layer_keyframe.dart';
import '../../../models/layer_region_edit.dart';
import '../../../models/text_object.dart';
import '../../../models/timeline_row_kind.dart';
import '../../../services/font_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/confirm_delete.dart';
import '../../../engine/clip_speed.dart';
import '../../../engine/crop_frame.dart';
import '../../../widgets/labeled_slider.dart';
import 'clip_speed_control.dart';
import 'clip_time_range_control.dart';
import 'pitch_control.dart';
import 'material_region_controller.dart';
import 'keyframe_retime_dialog.dart';
import '../../../widgets/layer_mask_editor.dart';
import '../../canvas/widgets/color_picker_panel.dart';
import '../../../config/accent_text_theme.dart';
import '../../../widgets/typing_dialog_inset.dart';
import '../../../widgets/menu_surface.dart';
import '../../../widgets/responsive.dart';

enum _Section { text, transform, duration, crop, region, mask, video }

/// Colours offered with one tap for a timeline text and its outline.
const List<int> _textColours = [
  0xFFFFFFFF,
  0xFF000000,
  0xFFFF3B30,
  0xFFFFCC00,
  0xFF34C759,
  0xFF0A84FF,
  0xFFFF66CC,
  0xFF8E8E93,
];

/// Records the result of a slider or preview drag as one edit.
void recordTimelineMaterialEdit({
  required ProjectService projects,
  required UndoManager undo,
  required String projectId,
  required Layer before,
}) {
  final home = projects.homeOf(projectId, before.id);
  if (home == null) return;
  final after = projects
      .storedLayersOf(projectId, home.sceneId, home.frameIndex)
      .where((layer) => layer.id == before.id)
      .firstOrNull;
  if (after == null || identical(after, before)) return;

  void apply(Layer layer) {
    final home = projects.homeOf(projectId, layer.id);
    if (home == null) return;
    projects.updateLayer(
      projectId: projectId,
      sceneId: home.sceneId,
      frameIndex: home.frameIndex,
      layer: layer,
      recordUndo: false,
    );
  }

  undo.push(
    ProjectEditUndoAction(
      'Edit timeline material',
      () => apply(before),
      () => apply(after),
      retainedMaterialIds: {?before.materialId, ?after.materialId},
    ),
    projectId: projectId,
  );
}

/// Edits one timeline material (a text, an image or a video) in place of the
/// timeline's tracks, with the preview above it in view: the text and its
/// look, where it is (move, scale, turn about the X, Y and Z axes, with
/// keyframes to animate), its mask, and for a video its sound and the part
/// used. Every change is shown in the preview at once.
class TimelineMaterialEditPanel extends StatefulWidget {
  const TimelineMaterialEditPanel({
    super.key,
    required this.projectId,
    required this.layerId,
    required this.currentFrame,
    required this.onClose,
    required this.onDelete,
    required this.onDuplicate,
    required this.onSeek,
    required this.onShowStackOrder,
    required this.onMoveToRow,
    this.onLayerChanged,
    this.videoSpeedEndFrameAt,
    this.onVideoSpeedChange,
    this.cropFrameOf,
    this.onCropEditingChanged,
    this.regionController,
    this.totalFrames,
    this.framesPerSecond,
    this.onTimeRangeChange,
  });

  final String projectId;
  final String layerId;

  /// The frame shown in the preview (keyframes are recorded there).
  final ValueListenable<int> currentFrame;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final ValueChanged<int> onSeek;
  final VoidCallback onShowStackOrder;

  /// Moves the material to another row of its kind (one past the last row:
  /// a new row). Each row is one item of the 重なり順.
  final ValueChanged<int> onMoveToRow;

  /// Called with the material after each change (the timeline mirrors its
  /// name, opacity and a video's sound in the track).
  final ValueChanged<Layer>? onLayerChanged;

  /// A video's last timeline frame at a speed, and the change of its speed
  /// (null when the timeline does not offer it). The change returns why it
  /// was refused, or null.
  final int Function(double rate)? videoSpeedEndFrameAt;
  final String? Function(double rate)? onVideoSpeedChange;

  /// The drawn part of an image or video on its layer (canvas pixels): the
  /// crop's percentages are of this. Null uses the whole layer.
  final Rect Function(Layer layer)? cropFrameOf;

  /// Told when the crop section opens (true) or closes (false), so the
  /// preview's handles can move the crop's edges.
  final ValueChanged<bool>? onCropEditingChanged;

  /// Shared with the preview's handles for selecting and changing parts of
  /// an image or video (範囲選択). Null leaves the section out.
  final MaterialRegionController? regionController;

  /// The scene's frames and frame rate, and the change of the material's
  /// first and last frame on the timeline (from 0), which returns why it
  /// was refused, or null. Without them the 長さ調整 section is left out.
  final int? totalFrames;
  final double? framesPerSecond;
  final String? Function(int start, int end)? onTimeRangeChange;

  @override
  State<TimelineMaterialEditPanel> createState() =>
      _TimelineMaterialEditPanelState();
}

class _TimelineMaterialEditPanelState extends State<TimelineMaterialEditPanel> {
  late final ProjectService _projects;
  FontService? _fonts;
  UndoManager? _undo;
  Layer? _beforeSlider;
  _Section? _section;
  final TextEditingController _textCtrl = TextEditingController();

  /// The text as last edited (ahead of the layer while it is being drawn).
  TextObject? _draft;
  Timer? _rasterTimer;
  bool _rasterizing = false;
  bool _rasterPending = false;
  String _fallbackName = '';

  @override
  void initState() {
    super.initState();
    _projects = context.read<ProjectService>();
    _fonts = Provider.of<FontService?>(context, listen: false);
    _undo = context.read<UndoManager?>();
    final layer = _find()?.layer;
    final text = layer?.textObject;
    if (text != null) _textCtrl.text = text.text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fallbackName = AppLocalizations.of(context)!.timelineMaterialText;
  }

  @override
  void didUpdateWidget(covariant TimelineMaterialEditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layerId != widget.layerId ||
        oldWidget.projectId != widget.projectId) {
      _finishSlider(oldWidget.projectId, duringBuild: true);
      _flushText();
      _draft = null;
      _section = null;
      _textCtrl.text = _find()?.layer.textObject?.text ?? '';
    }
  }

  @override
  void dispose() {
    if (_cropShown) widget.onCropEditingChanged?.call(false);
    _finishSlider(widget.projectId, duringBuild: true);
    _flushText();
    _textCtrl.dispose();
    super.dispose();
  }

  ({Layer layer, LayerHome home})? _find() {
    final home = _projects.homeOf(widget.projectId, widget.layerId);
    if (home == null) return null;
    final layer = _projects
        .storedLayersOf(widget.projectId, home.sceneId, home.frameIndex)
        .where((l) => l.id == widget.layerId)
        .firstOrNull;
    if (layer == null) return null;
    return (layer: layer, home: home);
  }

  void _update(Layer Function(Layer layer) change, {bool preview = false}) {
    final found = _find();
    if (found == null) return;
    final next = change(found.layer);
    final recordsPreview = preview && _undo != null;
    if (recordsPreview) _beforeSlider ??= found.layer;
    _projects.updateLayer(
      projectId: widget.projectId,
      sceneId: found.home.sceneId,
      frameIndex: found.home.frameIndex,
      layer: next,
      recordUndo: !recordsPreview,
    );
    widget.onLayerChanged?.call(next);
  }

  void _finishSlider(String projectId, {bool duringBuild = false}) {
    final previous = _beforeSlider;
    _beforeSlider = null;
    final undo = _undo;
    if (previous == null || undo == null) return;
    final projects = _projects;
    void record() => recordTimelineMaterialEdit(
      projects: projects,
      undo: undo,
      projectId: projectId,
      before: previous,
    );
    if (duringBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => record());
    } else {
      record();
    }
  }

  void _finishSliderDrag(double _) => _finishSlider(widget.projectId);

  // ─── Crop ───────────────────────────────────────────────────────────────

  /// Whether the crop section was shown at the last build (the timeline is
  /// told when that changes).
  bool _cropShown = false;

  Widget _cropSection(Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final tm = _projects.tileManagerOf(widget.projectId);
    final width = tm.canvasWidth.toDouble();
    final height = tm.canvasHeight.toDouble();
    final frame =
        widget.cropFrameOf?.call(layer) ?? Rect.fromLTWH(0, 0, width, height);
    final cuts = cropCutsIn(layer.crop, frame, width, height);
    const most = 100 - minCropKeptPercent;

    Widget cutSlider({
      required Key key,
      required String label,
      required double value,
      required double opposite,
      required CropCuts Function(double v) withValue,
    }) => LabeledSlider(
      key: key,
      label: label,
      value: value.clamp(0, most - opposite),
      min: 0,
      max: math.max(1, most - opposite),
      step: 1,
      isInt: false,
      valueText: '${value.round()}%',
      onChanged: (v) => _update(
        (l) =>
            l.copyWith(crop: cropFromCuts(withValue(v), frame, width, height)),
        preview: true,
      ),
      onChangeEnd: _finishSliderDrag,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.timelineCropHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        cutSlider(
          key: const ValueKey('cropLeft'),
          label: l10n.timelineCropLeft,
          value: cuts.left,
          opposite: cuts.right,
          withValue: (v) =>
              (left: v, top: cuts.top, right: cuts.right, bottom: cuts.bottom),
        ),
        cutSlider(
          key: const ValueKey('cropRight'),
          label: l10n.timelineCropRight,
          value: cuts.right,
          opposite: cuts.left,
          withValue: (v) =>
              (left: cuts.left, top: cuts.top, right: v, bottom: cuts.bottom),
        ),
        cutSlider(
          key: const ValueKey('cropTop'),
          label: l10n.timelineCropTop,
          value: cuts.top,
          opposite: cuts.bottom,
          withValue: (v) =>
              (left: cuts.left, top: v, right: cuts.right, bottom: cuts.bottom),
        ),
        cutSlider(
          key: const ValueKey('cropBottom'),
          label: l10n.timelineCropBottom,
          value: cuts.bottom,
          opposite: cuts.top,
          withValue: (v) =>
              (left: cuts.left, top: cuts.top, right: cuts.right, bottom: v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('cropReset'),
            icon: const Icon(Icons.crop_free, size: 18),
            label: Text(l10n.timelineCropReset),
            onPressed: layer.crop == null
                ? null
                : () => _update((l) => l.copyWith(crop: null)),
          ),
        ),
      ],
    );
  }

  // ─── Region (範囲選択) ────────────────────────────────────────────────────

  /// How far a new copy is put from its part (a fraction of the picture),
  /// so it shows at once.
  static const double _copyOffset = 0.04;

  void _addRegionEdit(RegionEditKind kind) {
    final region = widget.regionController;
    final selection = region?.selection;
    final found = _find();
    if (region == null || selection == null || found == null) return;
    if (found.layer.regionEdits.length >= LayerRegionEdit.maxCount) return;
    final tm = _projects.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth.toDouble();
    final h = tm.canvasHeight.toDouble();
    final copy = kind == RegionEditKind.duplicate;
    final edit = LayerRegionEdit(
      id: 'region_${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      region: selection,
      // Whole pixels, so the copy is as sharp as its part.
      dx: copy ? (w * _copyOffset).roundToDouble() / w : 0,
      dy: copy ? (h * _copyOffset).roundToDouble() / h : 0,
    );
    _update((l) => l.copyWith(regionEdits: [...l.regionEdits, edit]));
    region.selection = null;
    region.activeEditId = edit.drawsPiece ? edit.id : null;
  }

  void _editRegion(
    String id,
    LayerRegionEdit Function(LayerRegionEdit edit) change, {
    bool preview = false,
  }) => _update(
    (l) => l.copyWith(
      regionEdits: [for (final e in l.regionEdits) e.id == id ? change(e) : e],
    ),
    preview: preview,
  );

  void _removeRegionEdit(String id) {
    _update(
      (l) => l.copyWith(
        regionEdits: [
          for (final e in l.regionEdits)
            if (e.id != id) e,
        ],
      ),
    );
    final region = widget.regionController;
    if (region?.activeEditId == id) region?.activeEditId = null;
  }

  /// Selects the material's whole drawn part (inside its crop).
  void _selectWholeRegion(Layer layer, MaterialRegionController region) {
    final tm = _projects.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth.toDouble();
    final h = tm.canvasHeight.toDouble();
    var frame = widget.cropFrameOf?.call(layer) ?? Rect.fromLTWH(0, 0, w, h);
    final crop = layer.crop;
    if (crop != null && crop.isValid) {
      final kept = frame.intersect(crop.rectIn(w, h));
      if (kept.width > 0 && kept.height > 0) frame = kept;
    }
    final whole = RegionSelection.box(
      region.shape == RegionShape.ellipse
          ? RegionShape.ellipse
          : RegionShape.rectangle,
      Rect.fromLTRB(
        (frame.left / w).clamp(0.0, 1.0),
        (frame.top / h).clamp(0.0, 1.0),
        (frame.right / w).clamp(0.0, 1.0),
        (frame.bottom / h).clamp(0.0, 1.0),
      ),
    );
    if (whole.isValid) region.selection = whole;
  }

  String _regionKindLabel(AppLocalizations l10n, RegionEditKind kind) =>
      switch (kind) {
        RegionEditKind.move => l10n.timelineRegionMove,
        RegionEditKind.duplicate => l10n.commonDuplicate,
        RegionEditKind.erase => l10n.commonDelete,
      };

  static IconData _regionKindIcon(RegionEditKind kind) => switch (kind) {
    RegionEditKind.move => Icons.open_with,
    RegionEditKind.duplicate => Icons.copy_all,
    RegionEditKind.erase => Icons.delete_outline,
  };

  String _regionShapeLabel(AppLocalizations l10n, RegionShape shape) =>
      switch (shape) {
        RegionShape.rectangle => l10n.timelineMaskRectangle,
        RegionShape.ellipse => l10n.timelineMaskEllipse,
        RegionShape.freehand => l10n.timelineRegionShapeFreehand,
      };

  static IconData _regionShapeIcon(RegionShape shape) => switch (shape) {
    RegionShape.rectangle => Icons.crop_square,
    RegionShape.ellipse => Icons.circle_outlined,
    RegionShape.freehand => Icons.gesture,
  };

  Widget _regionSection(Layer layer) {
    final region = widget.regionController;
    if (region == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: region,
      builder: (context, _) => _regionContent(layer, region),
    );
  }

  Widget _regionContent(Layer layer, MaterialRegionController region) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final edits = layer.regionEdits;
    final active = region.activeIn(edits);
    final selection = region.selection;
    final full = edits.length >= LayerRegionEdit.maxCount;
    final canAct = selection != null && !full;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active == null) ...[
          Text(l10n.timelineRegionHint, style: small),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final shape in RegionShape.values)
                ChoiceChip(
                  key: ValueKey('regionShape.${shape.name}'),
                  avatar: Icon(_regionShapeIcon(shape), size: 16),
                  label: Text(_regionShapeLabel(l10n, shape)),
                  selected: region.shape == shape,
                  showCheckmark: false,
                  onSelected: (_) => region.shape = shape,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (selection == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.timelineRegionNoSelection,
                key: const ValueKey('regionNoSelection'),
                style: small,
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('regionMove'),
                icon: Icon(_regionKindIcon(RegionEditKind.move), size: 18),
                label: Text(l10n.timelineRegionMove),
                onPressed: canAct
                    ? () => _addRegionEdit(RegionEditKind.move)
                    : null,
              ),
              OutlinedButton.icon(
                key: const ValueKey('regionDuplicate'),
                icon: Icon(_regionKindIcon(RegionEditKind.duplicate), size: 18),
                label: Text(l10n.commonDuplicate),
                onPressed: canAct
                    ? () => _addRegionEdit(RegionEditKind.duplicate)
                    : null,
              ),
              OutlinedButton.icon(
                key: const ValueKey('regionErase'),
                icon: Icon(_regionKindIcon(RegionEditKind.erase), size: 18),
                label: Text(l10n.commonDelete),
                onPressed: canAct
                    ? () => _addRegionEdit(RegionEditKind.erase)
                    : null,
              ),
              TextButton.icon(
                key: const ValueKey('regionSelectAll'),
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(l10n.timelineRegionSelectAll),
                onPressed: () => _selectWholeRegion(layer, region),
              ),
              TextButton.icon(
                key: const ValueKey('regionClearSelection'),
                icon: const Icon(Icons.deselect, size: 18),
                label: Text(l10n.timelineRegionClearSelection),
                onPressed: selection == null
                    ? null
                    : () => region.selection = null,
              ),
            ],
          ),
          if (full)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.timelineRegionLimit(LayerRegionEdit.maxCount),
                key: const ValueKey('regionLimit'),
                style: small,
              ),
            ),
        ] else
          _regionPieceControls(active, region),
        if (edits.isNotEmpty) ...[
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.timelineRegionEditsTitle(edits.length),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          for (final (i, edit) in edits.indexed)
            ListTile(
              key: ValueKey('regionEdit.${edit.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_regionKindIcon(edit.kind)),
              title: Text(
                l10n.timelineRegionEditNumbered(
                  i + 1,
                  _regionKindLabel(l10n, edit.kind),
                ),
              ),
              subtitle: Text(_regionShapeLabel(l10n, edit.region.shape)),
              selected: edit.id == active?.id,
              onTap: edit.drawsPiece
                  ? () {
                      region.selection = null;
                      region.activeEditId = edit.id;
                    }
                  : null,
              trailing: IconButton(
                key: ValueKey('regionEditRemove.${edit.id}'),
                icon: const Icon(Icons.close),
                tooltip: l10n.timelineRegionEditRemove,
                onPressed: () => _removeRegionEdit(edit.id),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey('regionRemoveAll'),
              icon: const Icon(Icons.layers_clear_outlined, size: 18),
              label: Text(l10n.timelineRegionRemoveAll),
              onPressed: () {
                _update((l) => l.copyWith(regionEdits: const []));
                region.activeEditId = null;
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Sliders and buttons for the moved or copied part being changed.
  Widget _regionPieceControls(
    LayerRegionEdit edit,
    MaterialRegionController region,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final tm = _projects.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth.toDouble();
    final h = tm.canvasHeight.toDouble();
    final x = edit.dx * w;
    final y = edit.dy * h;

    Widget sizeSlider(String key, String label, double scale, bool across) =>
        LabeledSlider(
          key: ValueKey(key),
          label: label,
          value: scale.abs().clamp(LayerRegionEdit.minScale, 5.0),
          min: LayerRegionEdit.minScale,
          max: 5.0,
          step: 0.01,
          isInt: false,
          valueText: '×${scale.abs().toStringAsFixed(2)}',
          onChanged: (v) => _editRegion(edit.id, (e) {
            final size = (v * 100).roundToDouble() / 100;
            return across
                ? e.copyWith(scaleX: e.scaleX < 0 ? -size : size)
                : e.copyWith(scaleY: e.scaleY < 0 ? -size : size);
          }, preview: true),
          onChangeEnd: _finishSliderDrag,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.timelineRegionAdjustHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        LabeledSlider(
          key: const ValueKey('regionMoveX'),
          label: l10n.timelineCameraMoveXLabel,
          value: x.clamp(-w, w),
          min: -w,
          max: w,
          divisions: (w * 2).round(),
          valueText: '${x.round()}',
          onChanged: (v) => _editRegion(
            edit.id,
            (e) => e.copyWith(dx: v.roundToDouble() / w),
            preview: true,
          ),
          onChangeEnd: _finishSliderDrag,
        ),
        LabeledSlider(
          key: const ValueKey('regionMoveY'),
          label: l10n.timelineCameraMoveYLabel,
          value: y.clamp(-h, h),
          min: -h,
          max: h,
          divisions: (h * 2).round(),
          valueText: '${y.round()}',
          onChanged: (v) => _editRegion(
            edit.id,
            (e) => e.copyWith(dy: v.roundToDouble() / h),
            preview: true,
          ),
          onChangeEnd: _finishSliderDrag,
        ),
        sizeSlider(
          'regionScaleX',
          l10n.timelineRegionScaleX,
          edit.scaleX,
          true,
        ),
        sizeSlider(
          'regionScaleY',
          l10n.timelineRegionScaleY,
          edit.scaleY,
          false,
        ),
        LabeledSlider(
          key: const ValueKey('regionRotation'),
          label: l10n.timelineCameraRotationLabel,
          value: edit.rotation.clamp(-180, 180),
          min: -180,
          max: 180,
          divisions: 360,
          valueText: '${edit.rotation.round()}°',
          onChanged: (v) => _editRegion(
            edit.id,
            (e) => e.copyWith(rotation: v.roundToDouble()),
            preview: true,
          ),
          onChangeEnd: _finishSliderDrag,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('regionFlipHorizontal'),
              icon: const Icon(Icons.flip, size: 18),
              label: Text(l10n.timelineRegionFlipHorizontal),
              onPressed: () =>
                  _editRegion(edit.id, (e) => e.copyWith(scaleX: -e.scaleX)),
            ),
            OutlinedButton.icon(
              key: const ValueKey('regionFlipVertical'),
              icon: const RotatedBox(
                quarterTurns: 1,
                child: Icon(Icons.flip, size: 18),
              ),
              label: Text(l10n.timelineRegionFlipVertical),
              onPressed: () =>
                  _editRegion(edit.id, (e) => e.copyWith(scaleY: -e.scaleY)),
            ),
            TextButton.icon(
              key: const ValueKey('regionResetTransform'),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(l10n.timelineRegionResetTransform),
              onPressed: edit.isIdentityTransform
                  ? null
                  : () => _editRegion(
                      edit.id,
                      (e) => e.copyWith(
                        dx: 0,
                        dy: 0,
                        scaleX: 1,
                        scaleY: 1,
                        rotation: 0,
                      ),
                    ),
            ),
            FilledButton.icon(
              key: const ValueKey('regionDone'),
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.timelineRegionDone),
              onPressed: () => region.activeEditId = null,
            ),
          ],
        ),
      ],
    );
  }

  // ─── Text ───────────────────────────────────────────────────────────────

  TextObject _textOf(Layer layer) {
    final tm = _projects.tileManagerOf(widget.projectId);
    return _draft ??
        layer.textObject ??
        newTimelineText(
          id: layer.id,
          text: _textCtrl.text,
          canvasWidth: tm.canvasWidth,
          canvasHeight: tm.canvasHeight,
        );
  }

  void _editText(TextObject Function(TextObject text) change) {
    final found = _find();
    if (found == null) return;
    setState(() => _draft = change(_textOf(found.layer)));
    _rasterTimer?.cancel();
    // Drawing the letters takes a moment: wait for a pause in typing or
    // dragging a slider, then draw once.
    _rasterTimer = Timer(const Duration(milliseconds: 120), _rasterize);
  }

  /// Draws a pending text change now (the panel is closing).
  void _flushText() {
    if (_rasterTimer?.isActive ?? false) {
      _rasterTimer!.cancel();
      _rasterize();
    }
  }

  Future<void> _rasterize() async {
    final text = _draft;
    if (text == null) return;
    if (_rasterizing) {
      _rasterPending = true;
      return;
    }
    _rasterizing = true;
    try {
      final found = _find();
      if (found == null) return;
      final tm = _projects.tileManagerOf(widget.projectId);
      final w = tm.canvasWidth;
      final h = tm.canvasHeight;
      final bytes = text.text.trim().isEmpty
          ? null
          : await rasterizeTimelineText(
              text,
              w,
              h,
              pixelMode: _fonts?.pixelModeForFamily(text.fontFamily) ?? false,
            );
      // The raster and the editable text must be restored together.
      final current = _find();
      if (current != null && identical(_draft, text)) {
        final updated = current.layer.copyWith(
          textObject: text,
          name: timelineTextName(text.text, _fallbackName),
        );
        _projects.replaceLayerPixels(
          projectId: widget.projectId,
          sceneId: current.home.sceneId,
          frameIndex: current.home.frameIndex,
          layerId: widget.layerId,
          pixels: bytes ?? Uint8List(w * h * 4),
          updatedLayer: updated,
        );
        _draft = null;
        if (mounted) widget.onLayerChanged?.call(updated);
      }
    } finally {
      _rasterizing = false;
    }
    if (_rasterPending) {
      _rasterPending = false;
      await _rasterize();
    }
  }

  Future<void> _pickColour(int current, ValueChanged<int> onPicked) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: typingDialogInsetPadding(ctx),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: ColorPickerPanel(
            currentColor: Color(current),
            onColorChanged: (picked) {
              onPicked(picked.toARGB32());
              Navigator.of(ctx).pop();
            },
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  Widget _colourRow(int current, ValueChanged<int> onPicked) {
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(int c, double size, {VoidCallback? onTap}) => Semantics(
      button: true,
      selected: c == current,
      child: GestureDetector(
        onTap: onTap ?? () => onPicked(c),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Color(c),
            shape: BoxShape.circle,
            border: Border.all(
              color: c == current ? scheme.primary : scheme.outline,
              width: c == current ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: AppLocalizations.of(context)!.colorPickerTitle,
          child: swatch(
            current,
            34,
            onTap: () => _pickColour(current, onPicked),
          ),
        ),
        for (final c in _textColours) swatch(c, 26),
      ],
    );
  }

  Widget _textSection(Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final text = _textOf(layer);
    final tm = _projects.tileManagerOf(widget.projectId);
    final maxSize =
        (tm.canvasHeight < tm.canvasWidth ? tm.canvasHeight : tm.canvasWidth)
            .clamp(40, 800)
            .toDouble();
    final outline = text.outline ?? const TextOutline();
    final fonts = _fonts;
    final families = {
      'Roboto',
      for (final f in kBundledFonts) f.family,
      if (fonts != null)
        for (final f in fonts.fonts) fonts.familyNameOf(f),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textCtrl,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.canvasTextInputHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _editText((t) => t.copyWith(text: v)),
        ),
        const SizedBox(height: 10),
        MenuSurface(
          child: DropdownButtonFormField<String>(
            key: ValueKey('font-${widget.layerId}'),
            initialValue: families.contains(text.fontFamily)
                ? text.fontFamily
                : 'Roboto',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.canvasTextFontLabel,
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: 'Roboto',
                child: Text(l10n.canvasTextStandardFont),
              ),
              for (final f in kBundledFonts)
                DropdownMenuItem(
                  value: f.family,
                  child: Text(
                    f.displayName,
                    style: TextStyle(fontFamily: f.family),
                  ),
                ),
              if (fonts != null)
                for (final f in fonts.fonts)
                  DropdownMenuItem(
                    value: fonts.familyNameOf(f),
                    child: Text(
                      f.displayName,
                      style: TextStyle(fontFamily: fonts.familyNameOf(f)),
                    ),
                  ),
            ],
            onChanged: (v) =>
                _editText((t) => t.copyWith(fontFamily: v ?? 'Roboto')),
          ),
        ),
        const SizedBox(height: 4),
        LabeledSlider(
          label: l10n.brushSettingsSizeLabel,
          value: text.fontSize.clamp(8, maxSize),
          min: 8,
          max: maxSize,
          valueText: '${text.fontSize.round()}',
          onChanged: (v) =>
              _editText((t) => t.copyWith(fontSize: v.roundToDouble())),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: Text(l10n.canvasTextBold),
              selected: text.isBold,
              onSelected: (v) => _editText((t) => t.copyWith(isBold: v)),
            ),
            FilterChip(
              label: Text(l10n.canvasTextItalic),
              selected: text.isItalic,
              onSelected: (v) => _editText((t) => t.copyWith(isItalic: v)),
            ),
            FilterChip(
              avatar: const Icon(Icons.text_rotate_vertical, size: 16),
              label: Text(l10n.canvasTextVertical),
              selected: text.direction == TextWritingDirection.vertical,
              onSelected: (v) => _editText(
                (t) => t.copyWith(
                  direction: v
                      ? TextWritingDirection.vertical
                      : TextWritingDirection.horizontal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.timelineColorLabel, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        _colourRow(
          text.color.toARGB32(),
          (c) => _editText((t) => t.copyWith(color: Color(c))),
        ),
        const SizedBox(height: 8),
        if (text.direction == TextWritingDirection.horizontal)
          Row(
            children: [
              Text(l10n.canvasTextAlign, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<TextAlign>(
                  segments: const [
                    ButtonSegment(
                      value: TextAlign.left,
                      icon: Icon(Icons.format_align_left, size: 16),
                    ),
                    ButtonSegment(
                      value: TextAlign.center,
                      icon: Icon(Icons.format_align_center, size: 16),
                    ),
                    ButtonSegment(
                      value: TextAlign.right,
                      icon: Icon(Icons.format_align_right, size: 16),
                    ),
                  ],
                  selected: {text.align},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) =>
                      _editText((t) => t.copyWith(align: v.first)),
                ),
              ),
            ],
          ),
        LabeledSlider(
          label: l10n.canvasTextLineHeight,
          value: text.lineHeight.clamp(0.8, 3.0),
          min: 0.8,
          max: 3.0,
          step: 0.1,
          isInt: false,
          valueText: text.lineHeight.toStringAsFixed(1),
          onChanged: (v) => _editText(
            (t) => t.copyWith(lineHeight: (v * 10).roundToDouble() / 10),
          ),
        ),
        LabeledSlider(
          label: l10n.canvasTextLetterSpacing,
          value: text.letterSpacing.clamp(-10, 60),
          min: -10,
          max: 60,
          valueText: text.letterSpacing.round().toString(),
          onChanged: (v) =>
              _editText((t) => t.copyWith(letterSpacing: v.roundToDouble())),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
            l10n.canvasTextOutline,
            style: const TextStyle(fontSize: 13),
          ),
          value: outline.enabled,
          onChanged: (v) => _editText(
            (t) => t.copyWith(
              outline: TextOutline(
                enabled: v,
                color: outline.color,
                width: outline.width,
              ),
            ),
          ),
        ),
        if (outline.enabled) ...[
          _colourRow(
            outline.color.toARGB32(),
            (c) => _editText(
              (t) => t.copyWith(
                outline: TextOutline(
                  enabled: true,
                  color: Color(c),
                  width: outline.width,
                ),
              ),
            ),
          ),
          LabeledSlider(
            label: l10n.canvasOutlineWidthLabel,
            value: outline.width.clamp(0, 40),
            min: 0,
            max: 40,
            valueText: '${outline.width.round()}',
            onChanged: (v) => _editText(
              (t) => t.copyWith(
                outline: TextOutline(
                  enabled: true,
                  color: outline.color,
                  width: v.roundToDouble(),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Row ────────────────────────────────────────────────────────────────

  Widget _rowPicker(Layer layer, LayerHome home) {
    final l10n = AppLocalizations.of(context)!;
    final (kind, base) = switch (layer.type) {
      LayerType.timelineText => (
        TimelineRowKind.text,
        l10n.timelineMaterialText,
      ),
      LayerType.timelineVideo => (
        TimelineRowKind.video,
        l10n.projectListMaterialVideo,
      ),
      _ => (TimelineRowKind.image, l10n.projectListMaterialImage),
    };
    final names = _projects.rowNamesOf(widget.projectId, home.sceneId, kind);
    final rows = names.length > layer.trackRow
        ? names.length
        : layer.trackRow + 1;
    return Row(
      children: [
        Text(
          l10n.timelineMaterialRowLabel,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: layer.trackRow,
            items: [
              for (var row = 0; row < rows; row++)
                DropdownMenuItem(
                  value: row,
                  child: Text(
                    (row < names.length ? names[row] : null) ??
                        '$base${row + 1}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              DropdownMenuItem(
                value: rows,
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 16),
                    const SizedBox(width: 4),
                    Text(l10n.timelineMaterialNewRow),
                  ],
                ),
              ),
            ],
            onChanged: (row) {
              if (row != null && row != layer.trackRow) widget.onMoveToRow(row);
            },
          ),
        ),
      ],
    );
  }

  // ─── Position ───────────────────────────────────────────────────────────

  void _editTransform(
    LayerKeyframe Function(LayerKeyframe kf) change, {
    bool preview = false,
  }) {
    final frame = widget.currentFrame.value;
    Layer transform(Layer layer) =>
        layer.copyWith(keyframes: editMaterialTransform(layer, frame, change));
    _update(transform, preview: preview);
  }

  /// Plays a chosen range of the material's keys faster or slower (one Undo
  /// step; values and easing are kept, keys outside the range stay put).
  Future<void> _retimeKeyframes(Layer layer, LayerHome home) async {
    final lastFrame =
        (_projects.sceneOf(widget.projectId, home.sceneId)?.frames.length ??
            1) -
        1;
    final choice = await showKeyframeRetimeDialog(
      context,
      keyFrames: [for (final k in layer.keyframes) k.frameIndex],
      exactTimes: {for (final k in layer.keyframes) k.frameIndex: k.exactTime},
      lastFrame: lastFrame,
    );
    if (choice == null || !mounted) return;
    _update((l) {
      // From the keys' times before rounding, so retiming back and forth
      // returns them to their frames.
      final moves = retimeKeyRangeExact(
        {for (final k in l.keyframes) k.frameIndex: k.exactTime},
        fromFrame: choice.fromFrame,
        toFrame: choice.toFrame,
        rate: choice.rate,
        lastFrame: lastFrame,
      );
      if (moves == null) return l;
      return l.copyWith(
        keyframes: retimedKeyframes(
          l.keyframes,
          moves,
          frameOf: (k) => k.frameIndex,
          exactOf: (k) => k.exactTime,
          withTime: (k, t) => k.copyWith(frameIndex: t.round(), exactFrame: t),
        ),
      );
    });
  }

  Widget _transformSection(Layer layer, LayerHome home, int frame) {
    final l10n = AppLocalizations.of(context)!;
    final tm = _projects.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth.toDouble();
    final h = tm.canvasHeight.toDouble();
    final kf = materialTransformAt(layer, frame);
    final keyframes = [...layer.keyframes]
      ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    final atFrame = materialKeyframeAt(layer, frame) != null;
    final animated = keyframes.length >= 2;
    final scheme = Theme.of(context).colorScheme;
    Widget angle(
      String label,
      double value,
      LayerKeyframe Function(LayerKeyframe k, double v) apply,
    ) => LabeledSlider(
      label: label,
      value: value.clamp(-180, 180),
      min: -180,
      max: 180,
      divisions: 360,
      valueText: '${value.round()}°',
      onChanged: (v) =>
          _editTransform((k) => apply(k, v.roundToDouble()), preview: true),
      onChangeEnd: _finishSliderDrag,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rowPicker(layer, home),
        const SizedBox(height: 4),
        Text(
          l10n.timelineGizmoHint,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: Icon(
                atFrame && animated
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
                size: 18,
              ),
              label: Text(
                atFrame && animated
                    ? l10n.timelineKeyframeRemoveHere(frame + 1)
                    : l10n.timelineKeyframeAddHere(frame + 1),
              ),
              onPressed: atFrame && !animated
                  ? null
                  : () => _update(
                      (l) => l.copyWith(
                        keyframes: atFrame
                            ? removeMaterialKeyframe(l, frame)
                            : addMaterialKeyframe(l, frame),
                      ),
                    ),
            ),
            if (animated)
              OutlinedButton.icon(
                key: const ValueKey('keyframeRetimeButton'),
                icon: const Icon(Icons.speed, size: 18),
                label: Text(l10n.keyframeRetimeTitle),
                onPressed: () => _retimeKeyframes(layer, home),
              ),
            if (animated)
              for (final k in keyframes)
                ActionChip(
                  avatar: Icon(
                    Icons.diamond,
                    size: 14,
                    color: k.frameIndex == frame
                        ? AccentTextTheme.of(context)
                        : scheme.onSurfaceVariant,
                  ),
                  label: Text('F${k.frameIndex + 1}'),
                  onPressed: () => widget.onSeek(k.frameIndex),
                ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            animated
                ? l10n.timelineKeyframeAnimHint(keyframes.length, frame + 1)
                : l10n.timelineKeyframeWholeHint,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        LabeledSlider(
          label: l10n.timelineCameraMoveXLabel,
          value: kf.x.clamp(-w, w),
          min: -w,
          max: w,
          divisions: (w * 2).round(),
          valueText: '${kf.x.round()}',
          onChanged: (v) => _editTransform(
            (k) => k.copyWith(x: v.roundToDouble()),
            preview: true,
          ),
          onChangeEnd: _finishSliderDrag,
        ),
        LabeledSlider(
          label: l10n.timelineCameraMoveYLabel,
          value: kf.y.clamp(-h, h),
          min: -h,
          max: h,
          divisions: (h * 2).round(),
          valueText: '${kf.y.round()}',
          onChanged: (v) => _editTransform(
            (k) => k.copyWith(y: v.roundToDouble()),
            preview: true,
          ),
          onChangeEnd: _finishSliderDrag,
        ),
        LabeledSlider(
          label: l10n.layerKeyframeScaleLabel,
          value: kf.scale.clamp(0.05, 5.0),
          min: 0.05,
          max: 5.0,
          step: 0.01,
          isInt: false,
          valueText: '×${kf.scale.toStringAsFixed(2)}',
          onChanged: (v) => _editTransform(
            (k) => k.copyWith(scale: (v * 100).roundToDouble() / 100),
            preview: true,
          ),
          onChangeEnd: _finishSliderDrag,
        ),
        angle(
          l10n.timelineTransformRotationX,
          kf.rotationX,
          (k, v) => k.copyWith(rotationX: v),
        ),
        angle(
          l10n.timelineTransformRotationY,
          kf.rotationY,
          (k, v) => k.copyWith(rotationY: v),
        ),
        angle(
          l10n.timelineTransformRotationZ,
          kf.rotation,
          (k, v) => k.copyWith(rotation: v),
        ),
        LabeledSlider(
          label: l10n.layerPanelOpacityLabel,
          value: layer.opacity.toDouble().clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 100,
          valueText: '${layer.opacity}%',
          onChanged: (v) =>
              _update((l) => l.copyWith(opacity: v.round()), preview: true),
          onChangeEnd: _finishSliderDrag,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(l10n.timelineTransformReset),
            onPressed: () => _editTransform(
              (k) => LayerKeyframe(frameIndex: k.frameIndex, easing: k.easing),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Duration (長さ調整) ─────────────────────────────────────────────────

  /// 長さ調整: the material's time range on the timeline and, for a video,
  /// its speed (spec: the two items of one section).
  Widget _durationSection(Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final heading = Theme.of(context).textTheme.titleSmall;
    final start = materialFirstFrame(layer);
    final end = math.max(start, (layer.rangeEnd ?? start + 1) - 1);
    final changeRange = widget.onTimeRangeChange;
    final total = widget.totalFrames;
    final endFrameAt = widget.videoSpeedEndFrameAt;
    final changeSpeed = widget.onVideoSpeedChange;
    final isVideo = layer.type == LayerType.timelineVideo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.timelineDurationRangeTitle, style: heading),
        const SizedBox(height: 6),
        if (changeRange != null && total != null)
          ClipTimeRangeControl(
            start: start,
            end: end,
            totalFrames: total,
            framesPerSecond: widget.framesPerSecond ?? 24,
            onApply: changeRange,
          ),
        if (isVideo && endFrameAt != null && changeSpeed != null) ...[
          const Divider(height: 24),
          Text(l10n.timelineClipSpeedLabel, style: heading),
          const SizedBox(height: 6),
          ClipSpeedControl(
            rate: layer.playbackRate,
            hasSound: layer.videoVolume > 0,
            endFrameAt: endFrameAt,
            onApply: changeSpeed,
            onMute: () => _update((l) => l.copyWith(videoVolume: 0)),
          ),
          SwitchListTile(
            key: const ValueKey('videoSoundFollowsSpeed'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.timelineVideoSoundFollowsSpeed),
            subtitle: Text(l10n.timelineVideoSoundFollowsSpeedHint),
            value: layer.videoSoundFollowsSpeed,
            onChanged: (on) =>
                _update((l) => l.copyWith(videoSoundFollowsSpeed: on)),
          ),
        ],
      ],
    );
  }

  // ─── Video ──────────────────────────────────────────────────────────────

  Widget _videoSection(Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final start = materialFirstFrame(layer);
    final end = (layer.rangeEnd ?? start + 1) - 1;
    final last = (end - start).clamp(0, 1 << 30);
    final useStart = (layer.sourceTrimStart ?? 0).clamp(0, last);
    final useEnd = (layer.sourceTrimEnd ?? last).clamp(useStart, last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledSlider(
          label: l10n.timelineClipVolumeLabel,
          value: (layer.videoVolume * 100).clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 100,
          valueText: '${(layer.videoVolume * 100).round()}%',
          onChanged: (v) => _update(
            (l) => l.copyWith(videoVolume: v.round() / 100),
            preview: true,
          ),
          onChangeEnd: _finishSliderDrag,
        ),
        // The sound's pitch, on its own: the speed keeps it.
        PitchControl(
          semitones: layer.videoPitchSemitones,
          soundRate: layer.videoSoundFollowsSpeed ? layer.playbackRate : 1,
          onChanged: (v) =>
              _update((l) => l.copyWith(videoPitchSemitones: v), preview: true),
          onCommit: (v) {
            _update((l) => l.copyWith(videoPitchSemitones: v), preview: true);
            _finishSlider(widget.projectId);
          },
        ),
        if (last > 0) ...[
          // Counted from F1 as shown, so a number typed in is the frame
          // shown (the stored frames count from 0).
          LabeledSlider(
            label: l10n.timelineClipUseStartLabel,
            value: (useStart + 1).toDouble(),
            min: 1,
            max: (last + 1).toDouble(),
            divisions: last,
            valueText: 'F${useStart + 1}',
            onChanged: (v) => _update(
              (l) =>
                  l.copyWith(sourceTrimStart: (v.round() - 1).clamp(0, useEnd)),
              preview: true,
            ),
            onChangeEnd: _finishSliderDrag,
          ),
          LabeledSlider(
            label: l10n.timelineClipUseEndLabel,
            value: (useEnd + 1).toDouble(),
            min: 1,
            max: (last + 1).toDouble(),
            divisions: last,
            valueText: 'F${useEnd + 1}',
            onChanged: (v) => _update(
              (l) => l.copyWith(
                sourceTrimEnd: (v.round() - 1).clamp(useStart, last),
              ),
              preview: true,
            ),
            onChangeEnd: _finishSliderDrag,
          ),
        ],
      ],
    );
  }

  // ─── Layout ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.watch<ProjectService>();
    final found = _find();
    if (found == null) return const SizedBox.shrink();
    final layer = found.layer;
    final restoredText = layer.textObject?.text;
    if (_draft == null &&
        restoredText != null &&
        _textCtrl.text != restoredText) {
      _textCtrl.value = TextEditingValue(
        text: restoredText,
        selection: TextSelection.collapsed(offset: restoredText.length),
      );
    }
    final isText = layer.type == LayerType.timelineText;
    final isVideo = layer.type == LayerType.timelineVideo;
    final sections = [
      if (isText) _Section.text,
      _Section.transform,
      if (widget.onTimeRangeChange != null && widget.totalFrames != null)
        _Section.duration,
      if (!isText) _Section.crop,
      if (!isText && widget.regionController != null) _Section.region,
      _Section.mask,
      if (isVideo) _Section.video,
    ];
    final section = sections.contains(_section) ? _section! : sections.first;
    final cropShown = section == _Section.crop;
    if (cropShown != _cropShown) {
      _cropShown = cropShown;
      // Not during build: the timeline swaps the preview's handles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCropEditingChanged?.call(cropShown);
      });
    }
    final region = widget.regionController;
    final regionShown = section == _Section.region;
    if (region != null && region.editing != regionShown) {
      // Not during build: the timeline swaps the preview's handles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) region.editing = regionShown;
      });
    }
    final scheme = Theme.of(context).colorScheme;
    String sectionLabel(_Section s) => switch (s) {
      _Section.text => l10n.timelineEditSectionText,
      _Section.transform => l10n.timelineEditSectionTransform,
      _Section.duration => l10n.timelineEditSectionDuration,
      _Section.crop => l10n.timelineEditSectionCrop,
      _Section.region => l10n.timelineEditSectionRegion,
      _Section.mask => l10n.timelineEditSectionMask,
      _Section.video => l10n.projectListMaterialVideo,
    };
    IconData sectionIcon(_Section s) => switch (s) {
      _Section.text => Icons.text_fields,
      _Section.transform => Icons.open_with,
      _Section.duration => Icons.timelapse,
      _Section.crop => Icons.crop,
      _Section.region => Icons.highlight_alt,
      _Section.mask => Icons.vignette_outlined,
      _Section.video => Icons.videocam,
    };
    // スマホではタイムラインの場所に出す操作の面（メニューの背景色）、PCでは
    // 「詳細」の窓の面のまま（以前はどちらもsurfaceContainerLowの3つ目の
    // 灰色だった）。
    final pc = isWideScreen(context);
    final panel = Material(
      color: pc
          ? Colors.transparent
          : Theme.of(context).cardTheme.color ?? scheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
            child: Row(
              children: [
                Icon(
                  isText
                      ? Icons.text_fields
                      : isVideo
                      ? Icons.videocam
                      : Icons.image,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isText
                        ? timelineTextName(_textCtrl.text, layer.name)
                        : layer.name,
                    overflow: TextOverflow.ellipsis,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.layers_outlined),
                  tooltip: l10n.timelineStackOrderTitle,
                  onPressed: widget.onShowStackOrder,
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: l10n.commonDuplicate,
                  onPressed: widget.onDuplicate,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.commonDelete,
                  onPressed: () async {
                    final ok = await confirmDelete(
                      context,
                      message: l10n.layerPanelDeleteConfirmTitle(layer.name),
                    );
                    if (ok && mounted) widget.onDelete();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: l10n.commonClose,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final s in sections)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      avatar: Icon(sectionIcon(s), size: 16),
                      label: Text(sectionLabel(s)),
                      selected: s == section,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _section = s),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 8),
          Expanded(
            child: SingleChildScrollView(
              // Each section starts at its top.
              key: ValueKey(section),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: switch (section) {
                _Section.text => _textSection(layer),
                _Section.transform => ValueListenableBuilder<int>(
                  valueListenable: widget.currentFrame,
                  builder: (context, frame, _) =>
                      _transformSection(layer, found.home, frame),
                ),
                _Section.duration => _durationSection(layer),
                _Section.crop => _cropSection(layer),
                _Section.region => _regionSection(layer),
                _Section.mask => LayerMaskEditor(
                  mask: layer.mask,
                  onChanged: (m) => _update((l) => l.copyWith(mask: m)),
                ),
                _Section.video => _videoSection(layer),
              },
            ),
          ),
        ],
      ),
    );
    return pc ? panel : MenuSurface(child: panel);
  }
}
