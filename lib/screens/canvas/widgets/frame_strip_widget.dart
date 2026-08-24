import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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
  // そこに来るよう一覧側をスクロールさせる。タップ・
  // スワイプでフレームが変わっても赤枠自体は動かない。
  final ScrollController _scrollController = ScrollController();
  static const double _itemExtent = 48; // 幅48、左右マージンなし（フレーム同士を隙間なく詰める）

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
    }
    if (old.currentFrame != widget.currentFrame ||
        old.sceneId != widget.sceneId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToCurrent(animate: true),
      );
    }
  }

  // リストの左右にビューポート半分弱の余白（_sidePaddingで算出）を付けて
  // あるため、先頭・末尾のフレームであっても赤枠（画面中央）まで
  // スクロールしきれる（「index*_itemExtent」がそのまま中央揃えの
  // スクロール位置になり、境界のclampが実質的に無害になる）。
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

  /// スワイプ・ドラッグを手放した位置が中途半端でも、赤枠に一番近い
  /// フレームへ自動的にスナップさせる。dragDetailsが
  /// nullの場合はこちらの_scrollToCurrent等によるプログラム操作由来の
  /// スクロールなので無視する（無限ループ防止）。
  bool _handleScrollEnd(ScrollEndNotification notification, int total) {
    if (notification.dragDetails == null) return false;
    if (widget.multiSelectMode || total <= 0) return false;
    if (!_scrollController.hasClients) return false;
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

  /// フレーム追加の前に、無料会員の長さ上限（90秒）を超えないかチェックする
  /// （タイムラインモードのフレーム追加・複製と同じ制限を
  /// キャンバスモードのフレーム一覧の追加ボタンにも適用する）。
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

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 左右に((ビューポート幅-アイテム幅)/2)の余白を入れることで、
                // 先頭・末尾のフレームも中央の現在フレーム枠まできっちり
                // スクロールできるようにする。
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
                        itemCount: total + 1, // +1 は追加ボタン
                        itemBuilder: (context, index) {
                          if (index == total) {
                            return GestureDetector(
                              onTap: () {
                                if (!_canAddFrames(context, service, 1)) return;
                                service.addFrame(
                                  widget.projectId,
                                  widget.sceneId,
                                );
                              },
                              child: Container(
                                width: 48,
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[600]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Icon(Icons.add, color: Colors.grey),
                                ),
                              ),
                            );
                          }
                          final isChecked = widget.selectedFrames.contains(
                            index,
                          );
                          // 現在フレームの強調表示は画面中央固定の赤枠が担うため、通常
                          // モードでは枠色を変えない（多重に強調表示すると煩雑になるため）。
                          // 複数選択モードのチェック状態のみここで色分けする。
                          final isSelected =
                              widget.multiSelectMode && isChecked;
                          final hold = service.frameHold(
                            widget.projectId,
                            widget.sceneId,
                            index,
                          );
                          return GestureDetector(
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
                                color: Colors.grey[isSelected ? 700 : 850],
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[700]!,
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
                                            // サムネイルはどんな絵柄・色にもなり得るため、バッジの背景は
                                            // テーマのメニュー背景色（半透明）、文字は更新マーク色と同じ
                                            // 目立つ差し色（テーマの警告・注目色）を使う。
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
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Colors.grey[400],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // 画面中央に固定表示する枠。フレーム一覧側が
                      // スクロールして現在位置のフレームをここへ合わせる。色は
                      // 赤固定ではなく、テーマの更新マーク色（レイヤーパネルの
                      // 自動塗り更新マーク❗と同じ、警告・注目を引く差し色）と
                      // 連動させる。
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
          // フレーム一覧・タイムラインの切替。「フレーム一覧」は現在表示中の
          // この一覧自体を指すため常に選択状態で表示し、「タイムライン」を
          // 選ぶとonTimelineTapを呼んでタイムライン画面へ遷移する。
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
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    if (image == null) {
      // 生成中は背景色のみ（従来の見た目のまま）
      return const SizedBox.shrink();
    }
    return RawImage(image: image, fit: BoxFit.contain);
  }
}
