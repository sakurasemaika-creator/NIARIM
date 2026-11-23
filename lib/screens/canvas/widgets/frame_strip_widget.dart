import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../../../widgets/app_toast_messenger.dart';
import '../../../widgets/project_duration_limit_dialog.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../engine/layer_compositor.dart';
import '../../../engine/tile_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/layer.dart';
import '../../../services/premium_service.dart';
import '../../../services/project_service.dart';
import '../../../services/theme_service.dart';
import '../../../widgets/dispose_on_unmount.dart';
import '../../../widgets/frame_preview_background.dart';
import '../../../config/accent_text_theme.dart';
import '../../../widgets/typing_dialog_inset.dart';

class FrameStripWidget extends StatefulWidget {
  final int currentFrame;
  final String projectId;
  final String sceneId;
  final ValueChanged<int> onFrameSelected;
  final bool multiSelectMode;
  final Set<int> selectedFrames;
  final ValueChanged<int>? onFrameToggle;

  /// Whether the canvas is showing transparency (its checkerboard) instead
  /// of the project's background colour; the previews follow it.
  final bool showTransparency;
  const FrameStripWidget({
    super.key,
    required this.currentFrame,
    required this.projectId,
    required this.sceneId,
    required this.onFrameSelected,
    this.multiSelectMode = false,
    this.selectedFrames = const {},
    this.onFrameToggle,
    this.showTransparency = false,
  });
  @override
  State<FrameStripWidget> createState() => _FrameStripWidgetState();
}

class _FrameStripWidgetState extends State<FrameStripWidget> {
  final Map<int, int> _refreshTick = {};
  final ScrollController _scrollController = ScrollController();
  bool _userScrolled = false;
  bool _dragScrolled = false;
  int? _scrollSelectedFrame;
  Timer? _wheelSnap;

  /// Bumped when the strip's scroll metrics change. When frames are removed
  /// (undo of an add) the list shrinks and the scroll position is corrected
  /// during layout without notifying the controller, so the "+" cell, which
  /// is placed from the offset, would stay where it was and cover the current
  /// frame (the current-frame outline then looked as if it were on "+").
  final ValueNotifier<int> _metricsChanged = ValueNotifier<int>(0);
  static const double _itemExtent = 50;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(covariant FrameStripWidget old) {
    super.didUpdateWidget(old);
    if (old.multiSelectMode != widget.multiSelectMode) _wheelSnap?.cancel();
    if (old.currentFrame != widget.currentFrame ||
        old.sceneId != widget.sceneId) {
      final left = old.currentFrame;
      _refreshTick[left] = (_refreshTick[left] ?? 0) + 1;
      final followedScroll =
          old.sceneId == widget.sceneId &&
          _scrollSelectedFrame == widget.currentFrame;
      _scrollSelectedFrame = null;
      if (followedScroll) return;
      _wheelSnap?.cancel();
      _userScrolled = false;
      _dragScrolled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _scrollToCurrent() {
    if (!mounted || !_scrollController.hasClients) return;
    final target = (widget.currentFrame * _itemExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if ((target - _scrollController.offset).abs() < 0.001) return;
    _scrollController.jumpTo(target);
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _userScrolled = true;
      _wheelSnap?.cancel();
    } else if (notification is ScrollUpdateNotification && _userScrolled) {
      _dragScrolled |= notification.dragDetails != null;
      _selectNearestFrame();
    } else if (notification is ScrollEndNotification && _userScrolled) {
      _userScrolled = false;
      final wasDrag = _dragScrolled;
      _dragScrolled = false;
      if (wasDrag) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_userScrolled && !widget.multiSelectMode) _scrollToCurrent();
        });
      } else {
        // Wheel scrolling sends an end notification for each increment.
        // Snap after the increments stop so small deltas add up to a frame.
        _wheelSnap = Timer(const Duration(milliseconds: 120), () {
          if (!_userScrolled && !widget.multiSelectMode) _scrollToCurrent();
        });
      }
    }
    return false;
  }

  void _selectNearestFrame() {
    if (!mounted || widget.multiSelectMode || !_scrollController.hasClients) {
      return;
    }
    final total = context.read<ProjectService>().frameCount(
      widget.projectId,
      widget.sceneId,
    );
    if (total == 0) return;
    final nearest = (_scrollController.offset / _itemExtent).round().clamp(
      0,
      total - 1,
    );
    if (nearest != (_scrollSelectedFrame ?? widget.currentFrame)) {
      _scrollSelectedFrame = nearest;
      widget.onFrameSelected(nearest);
    }
  }

  @override
  void dispose() {
    _wheelSnap?.cancel();
    _scrollController.dispose();
    _metricsChanged.dispose();
    super.dispose();
  }

  bool _canAddFrames(BuildContext context, ProjectService service, int count) {
    final premium = context.read<PremiumService>();
    final maxSeconds = premium.maxProjectDurationSeconds;
    final isPremium = premium.isFeatureAvailable(
      PremiumFeature.unlimitedDuration,
    );
    final projected = service.projectedDurationSeconds(
      widget.projectId,
      frameDelta: count,
    );
    if (projected <= maxSeconds) return true;
    showProjectDurationLimit(context, hasUnlimitedDuration: isPremium);
    return false;
  }

  void _showBatchAddDialog(BuildContext context, ProjectService service) {
    final l10n = AppLocalizations.of(context)!;
    var count = 2;
    final controller = TextEditingController(text: '$count');
    void syncController() {
      final text = '$count';
      if (controller.text != text) {
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }

    showDialog<void>(
      context: context,
      // 閉じるアニメーション中もTextFieldがcontrollerを使うので、ダイアログが
      // 外れるまで破棄を待つ。
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) {
            void setCount(int value) {
              setS(() {
                count = value.clamp(1, 100);
                syncController();
              });
            }

            return AlertDialog(
              // スライダーを画面の横幅いっぱいに使えるよう、ダイアログを
              // 既定（左右40px空け、内容が狭ければ幅280）より広く取る。
              insetPadding: typingDialogInsetPadding(
                ctx,
                usual: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.library_add_rounded,
                    color: AccentTextTheme.of(ctx),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.frameStripBulkAddTitle)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      value: count.toDouble(),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label: '$count',
                      onChanged: (v) => setCount(v.round()),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded),
                          tooltip: l10n.commonDecrease,
                          onPressed: count > 1
                              ? () => setCount(count - 1)
                              : null,
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              suffixText: l10n.frameStripBulkAddUnit,
                              isDense: true,
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null) {
                                setS(() => count = parsed.clamp(1, 100));
                              }
                            },
                            onSubmitted: (_) => syncController(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          tooltip: l10n.commonIncrease,
                          onPressed: count < 100
                              ? () => setCount(count + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () {
                    final parsed = int.tryParse(controller.text);
                    final addCount = (parsed ?? count).clamp(1, 100);
                    if (!_canAddFrames(context, service, addCount)) return;
                    service.editTimeline(
                      widget.projectId,
                      l10n.frameStripBulkAddTitle,
                      () {
                        for (var i = 0; i < addCount; i++) {
                          service.addFrame(widget.projectId, widget.sceneId);
                        }
                      },
                      changesTiles: false,
                    );
                    Navigator.pop(ctx);
                  },
                  label: Text(l10n.commonOk),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showHoldDialog(
    BuildContext context,
    ProjectService service,
    int frameIndex,
    int currentHold,
  ) {
    final l10n = AppLocalizations.of(context)!;
    int hold = currentHold;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.frameStripHoldDialogTitle(frameIndex + 1)),
          scrollable: true,
          content: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: l10n.commonDecrease,
                onPressed: hold > 1 ? () => setS(() => hold--) : null,
              ),
              Expanded(
                child: Center(
                  heightFactor: 1,
                  child: Text('$hold', style: const TextStyle(fontSize: 24)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.commonIncrease,
                onPressed: hold < 99 ? () => setS(() => hold++) : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                service.setFrameHold(
                  widget.projectId,
                  widget.sceneId,
                  frameIndex,
                  hold,
                );
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();
    final total = service.frameCount(widget.projectId, widget.sceneId);
    final tiles = service.tileManagerOf(widget.projectId);
    final scheme = Theme.of(context).colorScheme;
    final project = service.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    return Container(
      height: 64,
      color: scheme.surface.withValues(alpha: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = ((constraints.maxWidth - _itemExtent) / 2).clamp(
            0.0,
            double.infinity,
          );
          return NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: Stack(
              children: [
                NotificationListener<ScrollMetricsNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0) _metricsChanged.value++;
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    itemExtent: _itemExtent,
                    itemCount: total,
                    itemBuilder: (context, index) {
                      final isChecked = widget.selectedFrames.contains(index);
                      final isSelected = widget.multiSelectMode && isChecked;
                      final hold = service.frameHold(
                        widget.projectId,
                        widget.sceneId,
                        index,
                      );
                      return GestureDetector(
                        key: ValueKey('frameStripCell$index'),
                        onTap: widget.multiSelectMode
                            ? () => widget.onFrameToggle?.call(index)
                            : () => widget.onFrameSelected(index),
                        onLongPress: widget.multiSelectMode
                            ? null
                            : () => _showHoldDialog(
                                context,
                                service,
                                index,
                                hold,
                              ),
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.surfaceContainerHighest
                                : scheme.surfaceContainerHigh,
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // The background behind the picture's
                                // own rectangle, as on the canvas.
                                FramePreviewBackground(
                                  backgroundColor:
                                      project?.backgroundColor ?? 0xFFFFFFFF,
                                  showTransparency: widget.showTransparency,
                                  aspectRatio: project == null
                                      ? null
                                      : project.exportWidth /
                                            project.exportHeight,
                                  child: _FrameThumbnail(
                                    key: ValueKey(
                                      '$index-${_refreshTick[index] ?? 0}',
                                    ),
                                    projectId: widget.projectId,
                                    sceneId: widget.sceneId,
                                    frameIndex: index,
                                    tileManager: tiles,
                                    layers: service.layersOf(
                                      widget.projectId,
                                      widget.sceneId,
                                      index,
                                    ),
                                    backgroundColor: widget.showTransparency
                                        ? null
                                        : project?.backgroundColor,
                                  ),
                                ),
                                if (hold > 1)
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context
                                            .watch<ThemeService>()
                                            .current
                                            .menuBgColor
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '$hold',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context
                                              .watch<ThemeService>()
                                              .current
                                              .updateMarkColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.multiSelectMode)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Icon(
                                      isChecked
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      size: 14,
                                      color: isChecked
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _scrollController,
                    _metricsChanged,
                  ]),
                  builder: (context, child) {
                    final offset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0;
                    final left = sidePadding + _itemExtent * total - offset;
                    if (left >= constraints.maxWidth) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: _itemExtent,
                      child: child!,
                    );
                  },
                  child: GestureDetector(
                    // 自動テストがコマを番号指定でタップできるよう
                    // にするためのKey（見た目・挙動には影響しない）。
                    key: const ValueKey('frameStripAddCell'),
                    onTap: () {
                      if (!_canAddFrames(context, service, 1)) return;
                      service.addFrame(widget.projectId, widget.sceneId);
                    },
                    onLongPress: () {
                      showIconActionDescription(
                        context,
                        AppLocalizations.of(context)!.frameStripBulkAddTitle,
                      );
                      _showBatchAddDialog(context, service);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Icon(Icons.add, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      key: const Key('canvasCurrentFrameOutline'),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: context
                              .watch<ThemeService>()
                              .current
                              .updateMarkColor,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FrameThumbnail extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final TileManager tileManager;
  final List<Layer> layers;

  /// The project's opaque background, when the strip shows it (not the
  /// transparency checkerboard): blend modes act on it.
  final int? backgroundColor;
  const _FrameThumbnail({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.tileManager,
    required this.layers,
    this.backgroundColor,
  });
  @override
  State<_FrameThumbnail> createState() => _FrameThumbnailState();
}

class _FrameThumbnailState extends State<_FrameThumbnail> {
  ui.Image? _image;
  int _renderRequest = 0;
  bool _refreshScheduled = false;
  @override
  void initState() {
    super.initState();
    widget.tileManager.addLayerContentListener(_layerChanged);
    widget.tileManager.addStrokeCommitListener(_layerChanged);
    _generate();
  }

  @override
  void didUpdateWidget(covariant _FrameThumbnail old) {
    super.didUpdateWidget(old);
    if (old.tileManager != widget.tileManager) {
      old.tileManager.removeLayerContentListener(_layerChanged);
      old.tileManager.removeStrokeCommitListener(_layerChanged);
      widget.tileManager.addLayerContentListener(_layerChanged);
      widget.tileManager.addStrokeCommitListener(_layerChanged);
    }
    if (old.tileManager != widget.tileManager ||
        old.projectId != widget.projectId ||
        old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex ||
        old.backgroundColor != widget.backgroundColor ||
        !listEquals(old.layers, widget.layers)) {
      _generate();
    }
  }

  void _layerChanged(String key) {
    if (_refreshScheduled) return;
    final frame = widget;
    final projects = context.read<ProjectService>();
    final usesLayer = frame.layers.any(
      (layer) =>
          projects.tileKeyFor(
            frame.projectId,
            frame.sceneId,
            frame.frameIndex,
            layer.id,
          ) ==
          key,
    );
    if (!usesLayer) return;
    _refreshScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _generate();
    });
    binding.ensureVisualUpdate();
  }

  Future<void> _generate() async {
    final request = ++_renderRequest;
    final frame = widget;
    final ps = context.read<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == frame.projectId)
        .firstOrNull;
    final tileManager = frame.tileManager;
    final drawW = tileManager.canvasWidth;
    final drawH = tileManager.canvasHeight;
    if (drawW <= 0 || drawH <= 0) return;
    final exportW = (project?.exportWidth ?? drawW).clamp(1, drawW).toInt();
    final exportH = (project?.exportHeight ?? drawH).clamp(1, drawH).toInt();
    final layers = frame.layers;
    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) =>
          ps.tileKeyFor(frame.projectId, frame.sceneId, frame.frameIndex, l.id),
      drawW,
      drawH,
      paperColor: LayerCompositor.paperForBlendModes(
        layers,
        frame.backgroundColor,
      ),
    );
    final offsetX = (drawW - exportW) / 2;
    final offsetY = (drawH - exportH) / 2;
    const thumbW = 96;
    final thumbH = (thumbW * exportH / exportW).round().clamp(1, 300).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTWH(
        offsetX,
        offsetY,
        exportW.toDouble(),
        exportH.toDouble(),
      ),
      ui.Rect.fromLTWH(0, 0, thumbW.toDouble(), thumbH.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    fullImage.dispose();
    final picture = recorder.endRecording();
    final thumb = await picture.toImage(thumbW, thumbH);
    picture.dispose();
    if (!mounted || request != _renderRequest) {
      thumb.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = thumb);
    old?.dispose();
  }

  @override
  void dispose() {
    widget.tileManager.removeLayerContentListener(_layerChanged);
    widget.tileManager.removeStrokeCommitListener(_layerChanged);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    // Keeps the canvas's proportions (FramePreviewBackground has already
    // given it the picture's own rectangle, so it fills that exactly).
    return RawImage(image: image, fit: BoxFit.contain);
  }
}
