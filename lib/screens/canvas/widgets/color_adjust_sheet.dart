import 'dart:async';
import 'dart:math' as math;
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
import '../../../widgets/stepped_slider.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';

/// 色調調整（キャンバス上部バーの設定/編集メニューから開く）。
/// 彩度・明度・コントラストをライブプレビューしながら調整し、
/// 「適用」（現在のレイヤーへ直接焼き込む）・「キャンセル」に加えて、
/// 「描画フィルターに追加する」「演出フィルターに追加する」で
/// 調整内容を新規フィルターとして保存できる。
class ColorAdjustSheet extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final String? layerId;
  final int frameIndex;
  final int totalFrames;
  final VoidCallback onClose;

  const ColorAdjustSheet({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.layerId,
    required this.frameIndex,
    required this.totalFrames,
    required this.onClose,
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
  ui.Image? _previewImage;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadPreviewBase();
  }

  @override
  void dispose() {
    _previewImage?.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewBase() async {
    final layerId = widget.layerId;
    if (layerId == null) return;
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth;
    final h = tm.canvasHeight;
    if (w <= 0 || h <= 0) return;
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
      layerId,
    );
    final img = await tm.compositeLayerToImage(key);

    const maxSize = 150;
    final scale = maxSize / math.max(w, h);
    final pw = (w * scale).round().clamp(1, maxSize);
    final ph = (h * scale).round().clamp(1, maxSize);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()),
      ui.Paint(),
    );
    img.dispose();
    final picture = recorder.endRecording();
    final small = await picture.toImage(pw, ph);
    final byteData = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    small.dispose();
    if (byteData == null || !mounted) return;
    _previewBase = byteData.buffer.asUint8List();
    _previewW = pw;
    _previewH = ph;
    await _updatePreview();
  }

  Future<void> _updatePreview() async {
    final base = _previewBase;
    if (base == null || !mounted) return;
    final filtered = _engine.applyColorAdjust(
      base,
      _previewW,
      _previewH,
      saturation: _saturation,
      brightness: _brightness,
      contrast: _contrast,
    );
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      filtered,
      _previewW,
      _previewH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final img = await completer.future;
    if (!mounted) {
      img.dispose();
      return;
    }
    setState(() {
      _previewImage?.dispose();
      _previewImage = img;
    });
  }

  Future<void> _apply() async {
    final layerId = widget.layerId;
    if (layerId == null) return;
    setState(() => _applying = true);
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
      layerId,
    );
    await tm.applyColorAdjustToLayer(
      key,
      saturation: _saturation,
      brightness: _brightness,
      contrast: _contrast,
    );
    if (!mounted) return;
    widget.onClose();
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
    widget.onClose();
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
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 8,
      child: SizedBox(
        width: 280,
        height: 420,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelCenterCloseBar(onClose: widget.onClose),
              Text(
                l10n.canvasColorAdjustTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              const Divider(),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _previewImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: RawImage(
                            image: _previewImage,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _slider(
                        l10n.filterColorAdjustSaturationLabel,
                        _saturation,
                        (v) {
                          setState(() => _saturation = v);
                          _updatePreview();
                        },
                      ),
                      _slider(
                        l10n.filterColorAdjustBrightnessLabel,
                        _brightness,
                        (v) {
                          setState(() => _brightness = v);
                          _updatePreview();
                        },
                      ),
                      _slider(l10n.filterColorAdjustContrastLabel, _contrast, (
                        v,
                      ) {
                        setState(() => _contrast = v);
                        _updatePreview();
                      }),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: widget.onClose,
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: _applying || widget.layerId == null
                        ? null
                        : _apply,
                    child: Text(l10n.filterApplyButton),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${value.round()}',
            style: const TextStyle(fontSize: 11),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: SteppedSlider(
              value: value,
              min: -100,
              max: 100,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
