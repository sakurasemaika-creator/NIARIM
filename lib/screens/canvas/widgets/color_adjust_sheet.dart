import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../engine/filter_engine.dart';
import '../../../engine/filter_selection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/effect_filter_instance.dart';
import '../../../models/filter_def.dart';
import '../../../services/filter_service.dart';
import '../../../services/project_service.dart';
import '../../../utils/duplicate_name.dart';
import '../../../utils/filter_display_name.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/name_entry_dialog.dart';
import '../../../config/font_fallback.dart';

/// 色調調整はスマホ・PC共通の画面下部コントロールバーを使う。
/// 別の正方形プレビューは作らず、変更中の画像を実際のキャンバスへ渡す。
class ColorAdjustSheet extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final String? layerId;
  final int frameIndex;
  final int totalFrames;
  final VoidCallback onClose;
  final VoidCallback? onApplied;
  final bool bottomBar;
  final Uint8List? selectionMask;

  /// Ownership of non-null preview images is transferred to the parent.
  final ValueChanged<ui.Image?>? onCanvasPreviewChanged;

  const ColorAdjustSheet({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.layerId,
    required this.frameIndex,
    required this.totalFrames,
    required this.onClose,
    this.onApplied,
    this.bottomBar = false,
    this.selectionMask,
    this.onCanvasPreviewChanged,
  });

  @override
  State<ColorAdjustSheet> createState() => _ColorAdjustSheetState();
}

class _ColorAdjustSheetState extends State<ColorAdjustSheet> {
  final FilterEngine _engine = FilterEngine();
  double _saturation = 0;
  double _brightness = 0;
  double _contrast = 0;
  Uint8List? _previewBase;
  int _previewW = 0;
  int _previewH = 0;
  int _previewGeneration = 0;
  bool _applying = false;
  bool _naming = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreviewBase());
  }

  @override
  void didUpdateWidget(ColorAdjustSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.sceneId != widget.sceneId ||
        oldWidget.layerId != widget.layerId ||
        oldWidget.frameIndex != widget.frameIndex) {
      _previewGeneration++;
      _previewBase = null;
      unawaited(_loadPreviewBase());
    } else if (!identical(oldWidget.selectionMask, widget.selectionMask)) {
      unawaited(_updatePreview());
    }
  }

  bool _isLocked(ProjectService projects, String layerId) => projects
      .layersOf(widget.projectId, widget.sceneId, widget.frameIndex)
      .any((layer) => layer.id == layerId && layer.isLocked);

  Uint8List _adjustPixels(Uint8List base) {
    final adjusted = _engine.applyColorAdjust(
      base,
      _previewW,
      _previewH,
      saturation: _saturation,
      brightness: _brightness,
      contrast: _contrast,
    );
    final mask = widget.selectionMask;
    return mask == null || mask.length != _previewW * _previewH
        ? adjusted
        : restrictToSelection(base, adjusted, selectionCoverage(mask));
  }

  @override
  void dispose() {
    _previewGeneration++;
    super.dispose();
  }

  Future<void> _loadPreviewBase() async {
    final layerId = widget.layerId;
    if (layerId == null) return;
    final generation = ++_previewGeneration;
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
      layerId,
    );
    // Always use the real canvas aspect ratio and pixels. No 120x120
    // preview box or stretching to a square.
    final img = await tm.compositeLayerToImage(key);
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted || generation != _previewGeneration || data == null) return;
      _previewW = img.width;
      _previewH = img.height;
      _previewBase = Uint8List.fromList(data.buffer.asUint8List());
    } finally {
      img.dispose();
    }
    if (mounted && generation == _previewGeneration) {
      unawaited(_updatePreview());
    }
  }

  Future<void> _updatePreview() async {
    final base = _previewBase;
    if (base == null || !mounted || widget.onCanvasPreviewChanged == null) {
      return;
    }
    final generation = ++_previewGeneration;
    final layerId = widget.layerId;
    if (layerId == null || _isLocked(context.read<ProjectService>(), layerId)) {
      widget.onCanvasPreviewChanged?.call(null);
      return;
    }
    final pixels = _adjustPixels(base);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _previewW,
      _previewH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    if (!mounted ||
        generation != _previewGeneration ||
        _isLocked(context.read<ProjectService>(), layerId)) {
      image.dispose();
      return;
    }
    widget.onCanvasPreviewChanged?.call(image);
  }

  void _cancel() {
    widget.onCanvasPreviewChanged?.call(null);
    widget.onClose();
  }

  Future<void> _apply() async {
    final layerId = widget.layerId;
    if (layerId == null || _applying) return;
    final projects = context.read<ProjectService>();
    if (_isLocked(projects, layerId)) {
      widget.onCanvasPreviewChanged?.call(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.canvasLayerLockedNotice),
        ),
      );
      return;
    }
    final base = _previewBase;
    if (base == null) return;
    setState(() => _applying = true);
    try {
      final committed = _adjustPixels(base);
      // Persist through ProjectService (one undoable editing operation)
      // rather than directly mutating TileManager without an undo entry.
      projects.replaceLayerPixels(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layerId: layerId,
        pixels: committed,
        selection: widget.selectionMask,
      );
      widget.onApplied?.call();
      _cancel(); // The canvas replaces the temporary image with saved pixels.
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String _suggestedFilterName(AppLocalizations l10n) {
    final settings = [
      (l10n.filterColorAdjustSaturationLabel, _saturation.round()),
      (l10n.filterColorAdjustBrightnessLabel, _brightness.round()),
      (l10n.filterColorAdjustContrastLabel, _contrast.round()),
    ];
    final changed = [
      for (final (label, value) in settings)
        if (value != 0) '$label ${value > 0 ? '+' : ''}$value',
    ];
    return changed.isEmpty
        ? l10n.filterNameColorAdjust
        : '${l10n.filterNameColorAdjust} (${changed.join(', ')})';
  }

  Future<void> _nameFilter({
    required String title,
    required Iterable<String> Function() takenNames,
    required void Function(String name) add,
    required String Function(String name) notice,
  }) async {
    if (_naming) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    String? addedName;
    setState(() => _naming = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => NameEntryDialog(
          title: title,
          initialName: uniqueNumberedName(
            _suggestedFilterName(l10n),
            takenNames(),
          ),
          confirmLabel: l10n.commonAdd,
          cancelLabel: l10n.commonCancel,
          failureText: (_) => l10n.timelineSaveFailedDialogBody,
          onSubmit: (name) async {
            final unique = uniqueNumberedName(name, takenNames());
            add(unique);
            addedName = unique;
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _naming = false);
    }
    final name = addedName;
    if (!mounted || name == null) return;
    messenger.showSnackBar(SnackBar(content: Text(notice(name))));
    _cancel();
  }

  Future<void> _addToDrawFilter() {
    final l10n = AppLocalizations.of(context)!;
    final filters = context.read<FilterService>();
    return _nameFilter(
      title: l10n.canvasColorAdjustAddToDrawFilter,
      takenNames: () => {
        for (final f in filters.filters) ...[
          f.name,
          filterDisplayName(l10n, f),
        ],
      },
      add: (name) => filters.addFilter(
        FilterDef(
          id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          kind: FilterKind.colorAdjust,
          caSaturation: _saturation,
          caBrightness: _brightness,
          caContrast: _contrast,
        ),
        select: false,
      ),
      notice: l10n.canvasColorAdjustDrawFilterAdded,
    );
  }

  Future<void> _addToEffectFilter() {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.read<ProjectService>();
    final projectId = widget.projectId;
    final sceneId = widget.sceneId;
    final start = widget.frameIndex;
    return _nameFilter(
      title: l10n.canvasColorAdjustAddToEffectFilter,
      takenNames: () sync* {
        for (final filter in projects.effectFiltersOf(projectId, sceneId)) {
          if (filter.name != null) yield filter.name!;
          if (filter.type == EffectFilterType.colorAdjust) {
            yield l10n.filterNameColorAdjust;
          }
        }
      },
      add: (name) {
        final total = projects.frameCount(projectId, sceneId);
        if (start < 0 || start >= total) {
          throw StateError('Color adjustment target frame no longer exists');
        }
        projects.addEffectFilter(
          projectId,
          sceneId,
          EffectFilterInstance(
            id: 'effect_${DateTime.now().microsecondsSinceEpoch}',
            type: EffectFilterType.colorAdjust,
            name: name,
            startFrame: start,
            endFrame: (start + 11).clamp(start, total - 1),
            param1: _saturation,
            param2: _brightness,
            param3: _contrast,
          ),
        );
      },
      notice: l10n.canvasColorAdjustEffectFilterAdded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            l10n.canvasColorAdjustTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: localizedHeadingStyle(
              context,
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        // 調整をフィルターとして残す2つは、題の右のメニューにまとめる
        // （下の操作の行は取り消し・適用の1行だけにして、スライダーの場所を
        // 取らない）。
        PopupMenuButton<bool>(
          key: const ValueKey('color-adjust-save-menu'),
          icon: const Icon(Icons.more_vert, size: 20),
          enabled: !_naming,
          onSelected: (effect) =>
              effect ? _addToEffectFilter() : _addToDrawFilter(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: false,
              child: Text(l10n.canvasColorAdjustAddToDrawFilter),
            ),
            PopupMenuItem(
              value: true,
              enabled: widget.totalFrames > 0,
              child: Text(l10n.canvasColorAdjustAddToEffectFilter),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: l10n.commonCancel,
          onPressed: _cancel,
        ),
      ],
    );
    // 取り消し・適用はスクロールの外に固定し、右へそろえる（ダイアログと同じ
    // 並び）。以前はフィルターとして残す2つと合わせて4つを中央寄せで
    // スライダーの下に並べ、360pxでは残す2つがスクロールの下に隠れていた。
    final actions = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: [
          TextButton(onPressed: _cancel, child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: _applying || widget.layerId == null ? null : _apply,
            child: Text(l10n.filterApplyButton),
          ),
        ],
      ),
    );
    // 下地はフィルターの調整（FilterPanelの画面下部の帯）と同じく持たない
    // （画面の地＝キャンバスの外周の上に置く。以前はこの帯だけ
    // surfaceContainerHighの別の灰色だった）。
    return Material(
      key: const ValueKey('color-adjust-bottom-bar'),
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.38),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _slider(
                          l10n.filterColorAdjustSaturationLabel,
                          _saturation,
                          (v) {
                            setState(() => _saturation = v);
                            unawaited(_updatePreview());
                          },
                        ),
                        _slider(
                          l10n.filterColorAdjustBrightnessLabel,
                          _brightness,
                          (v) {
                            setState(() => _brightness = v);
                            unawaited(_updatePreview());
                          },
                        ),
                        _slider(
                          l10n.filterColorAdjustContrastLabel,
                          _contrast,
                          (v) {
                            setState(() => _contrast = v);
                            unawaited(_updatePreview());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return LabeledSlider(
      padding: const EdgeInsets.symmetric(vertical: 2),
      label: label,
      labelStyle: const TextStyle(fontSize: 11),
      value: value,
      min: -100,
      max: 100,
      valueText: '${value.round()}',
      valueStyle: const TextStyle(fontSize: 11),
      onChanged: onChanged,
    );
  }
}
