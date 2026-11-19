import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../engine/layer_compositor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/layer.dart';
import '../../../services/project_service.dart';
import '../../../services/theme_service.dart';
import '../../../config/font_fallback.dart';
import '../../../widgets/docked_panel_scope.dart';
import '../../../widgets/frame_preview_background.dart';

/// A small view of the drawing area with the current canvas viewport.
class CanvasPreviewNavigator extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final ValueListenable<Rect?> viewport;
  final ValueChanged<Offset> onNavigate;
  final VoidCallback onClose;
  final bool showCloseButton;

  const CanvasPreviewNavigator({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.viewport,
    required this.onNavigate,
    required this.onClose,
    this.showCloseButton = true,
  });

  @override
  State<CanvasPreviewNavigator> createState() => _CanvasPreviewNavigatorState();
}

class _CanvasPreviewNavigatorState extends State<CanvasPreviewNavigator> {
  ui.Image? _image;
  bool _building = false;
  Timer? _timer;
  List<Layer>? _renderedLayers;
  int? _renderedRevision;
  int? _renderedPaper;
  bool _reportedError = false;

  (String, String, int) get _frame =>
      (widget.projectId, widget.sceneId, widget.frameIndex);

  @override
  void initState() {
    super.initState();
    _rebuild();
    // Refresh strokes at a bounded rate while keeping idle previews cached.
    _timer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _rebuild(),
    );
  }

  @override
  void didUpdateWidget(CanvasPreviewNavigator old) {
    super.didUpdateWidget(old);
    if (old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex ||
        old.projectId != widget.projectId) {
      _image?.dispose();
      _image = null;
      _rebuild();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _rebuild() async {
    if (_building || !mounted) return;
    _building = true;
    final frame = _frame;
    final (projectId, sceneId, frameIndex) = frame;
    try {
      final ps = context.read<ProjectService>();
      final tm = ps.tileManagerOf(projectId);
      final layers = ps.layersOf(projectId, sceneId, frameIndex);
      final background = ps.projects
          .where((project) => project.id == projectId)
          .firstOrNull
          ?.backgroundColor;
      final paper = LayerCompositor.paperForBlendModes(layers, background);
      final revision = tm.rasterRevision;
      if (_image != null &&
          revision == _renderedRevision &&
          paper == _renderedPaper &&
          listEquals(layers, _renderedLayers)) {
        return;
      }
      final width = tm.canvasWidth, height = tm.canvasHeight;
      final full = await LayerCompositor.composite(
        tm,
        layers,
        (layer) => ps.tileKeyFor(projectId, sceneId, frameIndex, layer.id),
        width,
        height,
        paperColor: paper,
      );
      const maxSide = 200;
      final scale = maxSide / (width > height ? width : height);
      final outW = (width * scale).round().clamp(1, maxSide);
      final outH = (height * scale).round().clamp(1, maxSide);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        full,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      full.dispose();
      final picture = recorder.endRecording();
      final ui.Image image;
      try {
        image = await picture.toImage(outW, outH);
      } finally {
        picture.dispose();
      }
      if (!mounted || frame != _frame) {
        image.dispose();
        return;
      }
      final old = _image;
      _renderedLayers = List.of(layers);
      _renderedRevision = revision;
      _renderedPaper = paper;
      _reportedError = false;
      setState(() => _image = image);
      old?.dispose();
    } catch (error, stack) {
      if (!_reportedError) {
        debugPrint('Canvas preview rendering failed: $error');
        debugPrintStack(stackTrace: stack);
        _reportedError = true;
      }
    } finally {
      _building = false;
      if (mounted && frame != _frame) unawaited(_rebuild());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.watch<ThemeService>().current;
    final scheme = Theme.of(context).colorScheme;
    final preview = _preview(scheme);
    // PC/DeXモードのドックでは、見出しと閉じるボタンはペインが持つ。
    // 縮小した絵はペインの大きさに収めて中央へ置く。
    if (DockedPanelScope.of(context)) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Center(child: preview),
      );
    }
    return Material(
      color: theme.panelBgColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            color: theme.menuBgColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 14, color: theme.menuTextColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.canvasPreviewNavigatorTitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.menuTextColor,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.showCloseButton)
                  Tooltip(
                    message: l10n.commonClose,
                    child: InkWell(
                      onTap: widget.onClose,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.menuTextColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: Center(child: preview)),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme scheme) {
    final image = _image;
    return AspectRatio(
      aspectRatio: image == null ? 1 : image.width / image.height,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: image == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  void navigate(Offset position) {
                    if (size.isEmpty) return;
                    widget.onNavigate(
                      Offset(
                        (position.dx / size.width).clamp(0.0, 1.0),
                        (position.dy / size.height).clamp(0.0, 1.0),
                      ),
                    );
                  }

                  return GestureDetector(
                    key: const ValueKey('canvasPreviewNavigatorImage'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => navigate(details.localPosition),
                    onPanStart: (details) => navigate(details.localPosition),
                    onPanUpdate: (details) => navigate(details.localPosition),
                    child: FramePreviewBackground(
                      backgroundColor:
                          context
                              .watch<ProjectService>()
                              .projects
                              .where((p) => p.id == widget.projectId)
                              .firstOrNull
                              ?.backgroundColor ??
                          0xFFFFFFFF,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(image: image, fit: BoxFit.fill),
                          ValueListenableBuilder<Rect?>(
                            valueListenable: widget.viewport,
                            builder: (context, viewport, _) => CustomPaint(
                              painter: _ViewportBorder(
                                viewport,
                                scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ViewportBorder extends CustomPainter {
  const _ViewportBorder(this.viewport, this.color);

  final Rect? viewport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = viewport;
    if (rect == null) return;
    final bounds = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );
    final border = ui.Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;
    canvas.drawRect(bounds, border);
    border
      ..strokeWidth = 1.5
      ..color = color;
    canvas.drawRect(bounds, border);
  }

  @override
  bool shouldRepaint(_ViewportBorder old) =>
      viewport != old.viewport || color != old.color;
}
