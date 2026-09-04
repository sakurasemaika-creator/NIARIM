import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../engine/layer_compositor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/project_service.dart';
import '../../../services/theme_service.dart';
import '../../../config/font_fallback.dart';

/// キャンバスプレビュー（ナビゲーター）：拡大表示中でも作品全体を縮小した
/// 状態で常に確認できる、プロ向けペイントソフトのナビゲーターパネルに
/// 相当する機能（PC/DeXモードのドッキング領域専用）。フル解像度で毎フレーム
/// 再合成すると重いため、小さい出力サイズで軽量に合成し、一定間隔で
/// 更新する（ライブのストロークそのものではなく「今どのあたりを描いて
/// いるか」を把握するための概観表示）。
class CanvasPreviewNavigator extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final VoidCallback onClose;

  const CanvasPreviewNavigator({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.onClose,
  });

  @override
  State<CanvasPreviewNavigator> createState() => _CanvasPreviewNavigatorState();
}

class _CanvasPreviewNavigatorState extends State<CanvasPreviewNavigator> {
  ui.Image? _image;
  bool _building = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _rebuild();
    // ストローク中も一定間隔で最新の状態へ更新する（毎フレーム合成は
    // 重いため、フル解像度ではなく縮小サイズでの合成に留めている）。
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
    try {
      final ps = context.read<ProjectService>();
      final tm = ps.tileManagerOf(widget.projectId);
      final layers = ps.layersOf(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
      );
      // 概観確認用のため、縦横比を保ったまま長辺を200pxまで縮小して合成する
      // （フル解像度は不要かつ重い）。
      const maxSide = 200.0;
      final scale =
          maxSide /
          (tm.canvasWidth > tm.canvasHeight ? tm.canvasWidth : tm.canvasHeight);
      final outW = (tm.canvasWidth * scale).round().clamp(1, 4096);
      final outH = (tm.canvasHeight * scale).round().clamp(1, 4096);
      final img = await LayerCompositor.composite(
        tm,
        layers,
        (l) => ps.tileKeyFor(
          widget.projectId,
          widget.sceneId,
          widget.frameIndex,
          l.id,
        ),
        outW,
        outH,
      );
      if (!mounted) {
        img.dispose();
        return;
      }
      final old = _image;
      setState(() => _image = img);
      old?.dispose();
    } catch (_) {
      // 合成に失敗しても（レイヤーが空、破棄済みタイル等）ナビゲーター自体は
      // 表示を維持し、次回の定期更新で回復を試みる。
    } finally {
      _building = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.watch<ThemeService>().current;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: theme.panelBgColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: theme.menuBgColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 14, color: theme.textColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.canvasPreviewNavigatorTitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textColor,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: widget.onClose,
                  child: Icon(Icons.close, size: 16, color: theme.textColor),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: _image != null ? _image!.width / _image!.height : 1,
            child: Container(
              color: scheme.surfaceContainerHighest,
              child: _image == null
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : RawImage(image: _image, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}
