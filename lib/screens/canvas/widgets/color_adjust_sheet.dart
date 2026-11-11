import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../engine/filter_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/effect_filter_instance.dart';
import '../../../models/filter_def.dart';
import '../../../services/filter_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/labeled_slider.dart';
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
  final bool bottomBar;
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
    this.bottomBar = false,
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
    }
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
      widget.projectId, widget.sceneId, widget.frameIndex, layerId,
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
    final pixels = _engine.applyColorAdjust(
      base, _previewW, _previewH,
      saturation: _saturation,
      brightness: _brightness,
      contrast: _contrast,
    );
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _previewW,
      _previewH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    if (!mounted || generation != _previewGeneration) {
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
    setState(() => _applying = true);
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final key = ps.tileKeyFor(
      widget.projectId, widget.sceneId, widget.frameIndex, layerId,
    );
    try {
      await tm.applyColorAdjustToLayer(
        key,
        saturation: _saturation,
        brightness: _brightness,
        contrast: _contrast,
      );
      if (!mounted) return;
      _cancel(); // After committing, the saved pixels replace the preview.
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _addToDrawFilter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.read<FilterService>().addFilter(
      FilterDef(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: l10n.filterNameColorAdjust,
        kind: FilterKind.colorAdjust,
        caSaturation: _saturation,
        caBrightness: _brightness,
        caContrast: _contrast,
      ),
    );
    _cancel();
  }

  void _addToEffectFilter(BuildContext context) {
    context.read<ProjectService>().addEffectFilter(
      widget.projectId,
      widget.sceneId,
      EffectFilterInstance(
        id: 'effect_${DateTime.now().microsecondsSinceEpoch}',
        type: EffectFilterType.colorAdjust,
        startFrame: widget.frameIndex,
        endFrame: (widget.frameIndex + 11).clamp(0, widget.totalFrames - 1),
        param1: _saturation,
        param2: _brightness,
        param3: _contrast,
      ),
    );
    _cancel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Material(
      key: const ValueKey('color-adjust-bottom-bar'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.38),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.canvasColorAdjustTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.commonCancel,
                      onPressed: _cancel,
                    ),
                  ],
                ),
                _slider(l10n.filterColorAdjustSaturationLabel, _saturation, (v) {
                  setState(() => _saturation = v);
                  unawaited(_updatePreview());
                }),
                _slider(l10n.filterColorAdjustBrightnessLabel, _brightness, (v) {
                  setState(() => _brightness = v);
                  unawaited(_updatePreview());
                }),
                _slider(l10n.filterColorAdjustContrastLabel, _contrast, (v) {
                  setState(() => _contrast = v);
                  unawaited(_updatePreview());
                }),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 0,
                  children: [
                    TextButton(
                      onPressed: _cancel,
                      child: Text(l10n.commonCancel),
                    ),
                    FilledButton(
                      onPressed: _applying || widget.layerId == null
                          ? null : _apply,
                      child: Text(l10n.filterApplyButton),
                    ),
                    TextButton(
                      onPressed: () => _addToDrawFilter(context),
                      child: Text(
                        l10n.canvasColorAdjustAddToDrawFilter,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _addToEffectFilter(context),
                      child: Text(
                        l10n.canvasColorAdjustAddToEffectFilter,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
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
