import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../engine/layer_compositor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/premium_service.dart';
import '../../../services/project_service.dart';
import '../../../services/theme_service.dart';

class FrameStripWidget extends StatefulWidget {
  final int currentFrame;
  final String projectId;
  final String sceneId;
  final ValueChanged<int> onFrameSelected;
  final VoidCallback onTimelineTap;
  final bool multiSelectMode;
  final Set<int> selectedFrames;
  final ValueChanged<int>? onFrameToggle;
  const FrameStripWidget({
    super.key,
    required this.currentFrame,
    required this.projectId,
    required this.sceneId,
    required this.onFrameSelected,
    required this.onTimelineTap,
    this.multiSelectMode = false,
    this.selectedFrames = const {},
    this.onFrameToggle,
  });
  @override
  State<FrameStripWidget> createState() => _FrameStripWidgetState();
}

class _FrameStripWidgetState extends State<FrameStripWidget> {
  final Map<int, int> _refreshTick = {};
  final ScrollController _scrollController = ScrollController();
  static const double _itemExtent = 48;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrent(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant FrameStripWidget old) {
    super.didUpdateWidget(old);
    if (old.currentFrame != widget.currentFrame ||
        old.sceneId != widget.sceneId) {
      final left = old.currentFrame;
      _refreshTick[left] = (_refreshTick[left] ?? 0) + 1;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToCurrent(animate: true),
      );
    }
  }

  void _scrollToCurrent({required bool animate}) {
    if (!_scrollController.hasClients) return;
    final target = (widget.currentFrame * _itemExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  bool _handleScrollEnd(ScrollEndNotification notification, int total) {
    if (notification.dragDetails == null ||
        widget.multiSelectMode ||
        total <= 0 ||
        !_scrollController.hasClients) {
      return false;
    }
    final nearest = (_scrollController.offset / _itemExtent).round().clamp(
      0,
      total - 1,
    );
    if (nearest != widget.currentFrame) {
      widget.onFrameSelected(nearest);
    } else {
      _scrollToCurrent(animate: true);
    }
    return false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _canAddFrames(BuildContext context, ProjectService service, int count) {
    final isPremium = context.read<PremiumService>().isPremium;
    final maxSeconds = isPremium ? 7200 : 90;
    final projected = service.projectedDurationSeconds(
      widget.projectId,
      frameDelta: count,
    );
    if (projected <= maxSeconds) return true;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineDurationLimitTitle),
        content: Text(
          isPremium
              ? l10n.timelineDurationLimitBodyPremium
              : l10n.timelineDurationLimitBodyFree,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void setCount(int value) {
            setS(() {
              count = value.clamp(1, 100);
              syncController();
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.library_add_rounded,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('フレームを一括追加')),
              ],
            ),
            content: Column(
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
                      onPressed: count > 1 ? () => setCount(count - 1) : null,
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          suffixText: '枚',
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
                      onPressed: count < 100 ? () => setCount(count + 1) : null,
                    ),
                  ],
                ),
              ],
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
                  for (var i = 0; i < addCount; i++) {
                    service.addFrame(widget.projectId, widget.sceneId);
                  }
                  Navigator.pop(ctx);
                },
                label: Text(l10n.commonOk),
              ),
            ],
          );
        },
      ),
    ).whenComplete(controller.dispose);
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
          content: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: l10n.commonDecrease,
                onPressed: hold > 1 ? () => setS(() => hold--) : null,
              ),
              Expanded(
                child: Center(
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
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<ProjectService>();
    final total = service.frameCount(widget.projectId, widget.sceneId);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      color: scheme.surface.withValues(alpha: 0),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePadding = ((constraints.maxWidth - _itemExtent) / 2)
                    .clamp(0.0, double.infinity);
                return NotificationListener<ScrollEndNotification>(
                  onNotification: (n) => _handleScrollEnd(n, total),
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: sidePadding),
                        itemCount: total + 1,
                        itemBuilder: (context, index) {
                          if (index == total) {
                            return GestureDetector(
                              // 自動テストがコマを番号指定でタップできるよう
                              // にするためのKey（見た目・挙動には影響しない）。
                              key: const ValueKey('frameStripAddCell'),
                              onTap: () {
                                if (!_canAddFrames(context, service, 1)) return;
                                service.addFrame(
                                  widget.projectId,
                                  widget.sceneId,
                                );
                              },
                              onLongPress: () =>
                                  _showBatchAddDialog(context, service),
                              child: Container(
                                width: 48,
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: scheme.outline),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.add,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }
                          final isChecked = widget.selectedFrames.contains(
                            index,
                          );
                          final isSelected =
                              widget.multiSelectMode && isChecked;
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
                              width: 48,
                              margin: const EdgeInsets.symmetric(vertical: 4),
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
                                    _FrameThumbnail(
                                      key: ValueKey(
                                        '$index-${_refreshTick[index] ?? 0}',
                                      ),
                                      projectId: widget.projectId,
                                      sceneId: widget.sceneId,
                                      frameIndex: index,
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
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
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
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 56,
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'frames',
                  label: Text(
                    l10n.frameStripFrameListModeLabel,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                ButtonSegment(
                  value: 'timeline',
                  label: Text(
                    l10n.frameStripTimelineModeLabel,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
              selected: const {'frames'},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: WidgetStatePropertyAll(
                  scheme.surface.withValues(alpha: 0),
                ),
              ),
              onSelectionChanged: (selected) {
                if (selected.contains('timeline')) widget.onTimelineTap();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameThumbnail extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  const _FrameThumbnail({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
  });
  @override
  State<_FrameThumbnail> createState() => _FrameThumbnailState();
}

class _FrameThumbnailState extends State<_FrameThumbnail> {
  ui.Image? _image;
  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final ps = context.read<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final tileManager = ps.tileManagerOf(widget.projectId);
    final drawW = tileManager.canvasWidth;
    final drawH = tileManager.canvasHeight;
    if (drawW <= 0 || drawH <= 0) return;
    final exportW = (project?.exportWidth ?? drawW).clamp(1, drawW).toInt();
    final exportH = (project?.exportHeight ?? drawH).clamp(1, drawH).toInt();
    final layers = ps.layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => ps.tileKeyFor(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
        l.id,
      ),
      drawW,
      drawH,
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
      ui.Paint(),
    );
    fullImage.dispose();
    final picture = recorder.endRecording();
    final thumb = await picture.toImage(thumbW, thumbH);
    picture.dispose();
    if (!mounted) {
      thumb.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = thumb);
    old?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return RawImage(image: image, fit: BoxFit.contain);
  }
}
