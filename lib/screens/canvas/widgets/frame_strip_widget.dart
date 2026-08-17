import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../engine/layer_compositor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/premium_service.dart';
import '../../../services/project_service.dart';

class FrameStripWidget extends StatefulWidget {
  final int currentFrame;
  final String projectId;
  final String sceneId;
  final ValueChanged<int> onFrameSelected;
  final VoidCallback onTimelineTap;
  // フレーム複数選択モード（仕様書18：大量処理実行時のフレーム一括選択）
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
  // フレームごとのサムネイル再生成カウンター。表示中フレームを切り替えた
  // 直後、直前まで表示していたフレームは描画内容が更新された可能性が
  // 高いため、そのフレームのサムネイルだけを再生成させる。
  final Map<int, int> _refreshTick = {};

  // フレーム一覧は常に画面中央に固定で赤枠を表示し、現在位置のフレームが
  // そこに来るよう一覧側をスクロールさせる（ユーザー指示）。タップ・
  // スワイプでフレームが変わっても赤枠自体は動かない。
  final ScrollController _scrollController = ScrollController();
  static const double _itemExtent = 56; // 幅48＋左右マージン4ずつ

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(animate: false));
  }

  @override
  void didUpdateWidget(covariant FrameStripWidget old) {
    super.didUpdateWidget(old);
    if (old.currentFrame != widget.currentFrame ||
        old.sceneId != widget.sceneId) {
      final left = old.currentFrame;
      _refreshTick[left] = (_refreshTick[left] ?? 0) + 1;
    }
    if (old.currentFrame != widget.currentFrame || old.sceneId != widget.sceneId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(animate: true));
    }
  }

  void _scrollToCurrent({required bool animate}) {
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final target = (widget.currentFrame * _itemExtent + _itemExtent / 2) - viewport / 2;
    final clamped = target.clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(clamped, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// フレーム追加の前に、無料会員の長さ上限（90秒）を超えないかチェックする
  /// （ユーザー指示：タイムラインモードのフレーム追加・複製と同じ制限を
  /// キャンバスモードのフレーム一覧の追加ボタンにも適用する）。
  bool _canAddFrames(BuildContext context, ProjectService service, int count) {
    final isPremium = context.read<PremiumService>().isPremium;
    final maxSeconds = isPremium ? 7200 : 90;
    final projected = service.projectedDurationSeconds(widget.projectId, frameDelta: count);
    if (projected <= maxSeconds) return true;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineDurationLimitTitle),
        content: Text(isPremium
            ? l10n.timelineDurationLimitBodyPremium
            : l10n.timelineDurationLimitBodyFree),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
        ],
      ),
    );
    return false;
  }

  void _showHoldDialog(BuildContext context, ProjectService service, int frameIndex, int currentHold) {
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
                onPressed: hold > 1 ? () => setS(() => hold--) : null,
              ),
              Expanded(child: Center(child: Text('$hold', style: const TextStyle(fontSize: 24)))),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: hold < 99 ? () => setS(() => hold++) : null,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                service.setFrameHold(widget.projectId, widget.sceneId, frameIndex, hold);
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

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: total + 1, // +1 は追加ボタン
              itemBuilder: (context, index) {
                if (index == total) {
                  return GestureDetector(
                    onTap: () {
                      if (!_canAddFrames(context, service, 1)) return;
                      service.addFrame(widget.projectId, widget.sceneId);
                    },
                    child: Container(
                      width: 48,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[600]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: Icon(Icons.add, color: Colors.grey)),
                    ),
                  );
                }
                final isChecked = widget.selectedFrames.contains(index);
                // 現在フレームの強調表示は画面中央固定の赤枠が担うため、通常
                // モードでは枠色を変えない（多重に強調表示すると煩雑になるため）。
                // 複数選択モードのチェック状態のみここで色分けする。
                final isSelected = widget.multiSelectMode && isChecked;
                final hold = service.frameHold(widget.projectId, widget.sceneId, index);
                return GestureDetector(
                  onTap: widget.multiSelectMode
                      ? () => widget.onFrameToggle?.call(index)
                      : () => widget.onFrameSelected(index),
                  onLongPress: widget.multiSelectMode
                      ? null
                      : () => _showHoldDialog(context, service, index, hold),
                  child: Container(
                    width: 48,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[isSelected ? 700 : 850],
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // フレームのサムネイル（仕様書26：赤枠＝書き出し範囲の
                          // 内側のみを表示する。描画領域を拡張していても
                          // 赤枠外の描画内容はここには映らない）。
                          _FrameThumbnail(
                            key: ValueKey('$index-${_refreshTick[index] ?? 0}'),
                            projectId: widget.projectId,
                            sceneId: widget.sceneId,
                            frameIndex: index,
                          ),
                          if (hold > 1)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text('$hold',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (widget.multiSelectMode)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Icon(
                                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 14,
                                color: isChecked ? Theme.of(context).colorScheme.primary : Colors.grey[400],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
                ),
                // 画面中央に固定表示する赤枠（ユーザー指示）。フレーム一覧側が
                // スクロールして現在位置のフレームをここへ合わせる。
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            // タイムラインモードへの切替ボタン（ユーザー指示により絵文字ではなく
            // タイムライン画面内で既に使われているIcons.movieへ変更）。
            icon: const Icon(Icons.movie, size: 20),
            onPressed: widget.onTimelineTap,
            tooltip: l10n.frameStripTimelineModeTooltip,
          ),
        ],
      ),
    );
  }
}

/// フレーム一覧の1コマ分のサムネイル（仕様書26：赤枠固定表示）。
///
/// 描画領域全体（描画領域倍率を反映した拡張範囲）を合成した上で、
/// 中央に配置された書き出し範囲（赤枠）分だけを切り出して縮小表示する。
/// これは動画書き出し時に実際にレンダリングされる範囲と同じであり、
/// export_engine.dartの中央配置ロジックと同じ計算式を用いている。
///
/// 生成コストを抑えるため、初回表示時に一度だけ生成しキャッシュする
/// （フレーム切り替え時に親[FrameStripWidget]が直前のフレームのみ
/// 再生成させる。詳細は[_FrameStripWidgetState.didUpdateWidget]を参照）。
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
    final project = ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
    final tileManager = ps.tileManagerOf(widget.projectId);
    final drawW = tileManager.canvasWidth;
    final drawH = tileManager.canvasHeight;
    if (drawW <= 0 || drawH <= 0) return;
    final exportW = (project?.exportWidth ?? drawW).clamp(1, drawW).toInt();
    final exportH = (project?.exportHeight ?? drawH).clamp(1, drawH).toInt();

    final layers = ps.layersOf(widget.projectId, widget.sceneId, widget.frameIndex);

    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => ps.tileKeyFor(widget.projectId, widget.sceneId, widget.frameIndex, l.id),
      drawW,
      drawH,
    );

    // 描画領域の中央から書き出しサイズ分だけ切り出す（赤枠＝書き出し範囲。
    // export_engine.dart renderFrame()と同じ中央配置計算式）。
    final offsetX = (drawW - exportW) / 2;
    final offsetY = (drawH - exportH) / 2;
    const thumbW = 96;
    final thumbH = (thumbW * exportH / exportW).round().clamp(1, 300).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTWH(offsetX, offsetY, exportW.toDouble(), exportH.toDouble()),
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
    if (image == null) {
      // 生成中は背景色のみ（従来の見た目のまま）
      return const SizedBox.shrink();
    }
    return RawImage(image: image, fit: BoxFit.contain);
  }
}
