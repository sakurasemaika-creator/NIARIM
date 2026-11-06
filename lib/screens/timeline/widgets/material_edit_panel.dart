import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../engine/layer_range_resolver.dart';
import '../../../engine/timeline_material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/bundled_fonts.dart';
import '../../../models/layer.dart';
import '../../../models/layer_keyframe.dart';
import '../../../models/text_object.dart';
import '../../../models/timeline_row_kind.dart';
import '../../../services/font_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/confirm_delete.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/layer_mask_editor.dart';
import '../../canvas/widgets/color_picker_panel.dart';
import '../../../config/accent_text_theme.dart';

enum _Section { text, transform, mask, video }

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

  @override
  State<TimelineMaterialEditPanel> createState() =>
      _TimelineMaterialEditPanelState();
}

class _TimelineMaterialEditPanelState extends State<TimelineMaterialEditPanel> {
  late final ProjectService _projects;
  FontService? _fonts;
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
    if (oldWidget.layerId != widget.layerId) {
      _flushText();
      _draft = null;
      _section = null;
      _textCtrl.text = _find()?.layer.textObject?.text ?? '';
    }
  }

  @override
  void dispose() {
    _flushText();
    _textCtrl.dispose();
    super.dispose();
  }

  ({Layer layer, LayerHome home})? _find() {
    final home = _projects.homeOf(widget.projectId, widget.layerId);
    if (home == null) return null;
    final layer = _projects
        .layersOf(widget.projectId, home.sceneId, home.frameIndex)
        .where((l) => l.id == widget.layerId)
        .firstOrNull;
    if (layer == null) return null;
    return (layer: layer, home: home);
  }

  void _update(Layer Function(Layer layer) change) {
    final found = _find();
    if (found == null) return;
    final next = change(found.layer);
    _projects.updateLayer(
      projectId: widget.projectId,
      sceneId: found.home.sceneId,
      frameIndex: found.home.frameIndex,
      layer: next,
    );
    widget.onLayerChanged?.call(next);
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
      tm.replaceLayerPixels(
        _projects.tileKeyFor(
          widget.projectId,
          found.home.sceneId,
          found.home.frameIndex,
          widget.layerId,
        ),
        bytes ?? Uint8List(w * h * 4),
      );
      _update(
        (l) => l.copyWith(
          textObject: text,
          name: timelineTextName(text.text, _fallbackName),
        ),
      );
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
        DropdownButtonFormField<String>(
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

  void _editTransform(LayerKeyframe Function(LayerKeyframe kf) change) {
    final frame = widget.currentFrame.value;
    _update(
      (l) => l.copyWith(keyframes: editMaterialTransform(l, frame, change)),
    );
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
      onChanged: (v) => _editTransform((k) => apply(k, v.roundToDouble())),
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
          onChanged: (v) =>
              _editTransform((k) => k.copyWith(x: v.roundToDouble())),
        ),
        LabeledSlider(
          label: l10n.timelineCameraMoveYLabel,
          value: kf.y.clamp(-h, h),
          min: -h,
          max: h,
          divisions: (h * 2).round(),
          valueText: '${kf.y.round()}',
          onChanged: (v) =>
              _editTransform((k) => k.copyWith(y: v.roundToDouble())),
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
          ),
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
          onChanged: (v) => _update((l) => l.copyWith(opacity: v.round())),
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
          onChanged: (v) =>
              _update((l) => l.copyWith(videoVolume: v.round() / 100)),
        ),
        if (last > 0) ...[
          LabeledSlider(
            label: l10n.timelineClipUseStartLabel,
            value: useStart.toDouble(),
            min: 0,
            max: last.toDouble(),
            divisions: last,
            valueText: 'F${useStart + 1}',
            onChanged: (v) => _update(
              (l) => l.copyWith(sourceTrimStart: v.round().clamp(0, useEnd)),
            ),
          ),
          LabeledSlider(
            label: l10n.timelineClipUseEndLabel,
            value: useEnd.toDouble(),
            min: 0,
            max: last.toDouble(),
            divisions: last,
            valueText: 'F${useEnd + 1}',
            onChanged: (v) => _update(
              (l) => l.copyWith(sourceTrimEnd: v.round().clamp(useStart, last)),
            ),
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
    final isText = layer.type == LayerType.timelineText;
    final isVideo = layer.type == LayerType.timelineVideo;
    final sections = [
      if (isText) _Section.text,
      _Section.transform,
      _Section.mask,
      if (isVideo) _Section.video,
    ];
    final section = sections.contains(_section) ? _section! : sections.first;
    final scheme = Theme.of(context).colorScheme;
    String sectionLabel(_Section s) => switch (s) {
      _Section.text => l10n.timelineEditSectionText,
      _Section.transform => l10n.timelineEditSectionTransform,
      _Section.mask => l10n.timelineEditSectionMask,
      _Section.video => l10n.projectListMaterialVideo,
    };
    IconData sectionIcon(_Section s) => switch (s) {
      _Section.text => Icons.text_fields,
      _Section.transform => Icons.open_with,
      _Section.mask => Icons.vignette_outlined,
      _Section.video => Icons.videocam,
    };
    return Material(
      color: scheme.surfaceContainerLow,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
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
                      itemName: layer.name,
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
  }
}
