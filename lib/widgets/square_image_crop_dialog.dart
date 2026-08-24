import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/theme_service.dart';

/// クロップ枠（プレビュー領域）の一辺の論理ピクセルサイズ。
const double _kCropViewSize = 260;

/// 出力する正方形サムネイルの実ピクセルサイズ。
const int _kOutputSize = 512;

/// デコード時に画像の長辺をこのサイズ以下へ縮小する。スマホのカメラ写真
/// （数千px四方）をそのままフル解像度でデコードすると、特にWeb版
/// （ブラウザのcanvas最大サイズ制限）で失敗することがあるため、
/// 出力サイズより十分大きい範囲で上限を設けておく。
const int _kDecodeMaxEdge = 2048;

/// 画像を1:1の正方形へトリミングするダイアログ（自動塗り
/// プリセットのサムネイル画像設定）。ドラッグで位置調整、ピンチで
/// 拡大縮小、2本指回転で角度調整ができる。戻り値はトリミング結果の
/// PNGバイト列（キャンセル時はnull）。
/// [imagePath]（デスクトップ/モバイル）と[imageBytes]（Web版：dart:ioの
/// Fileが使えないため、選択した画像のバイト列を直接渡す）のどちらか
/// 一方を指定する。
class SquareImageCropDialog extends StatefulWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  const SquareImageCropDialog({super.key, this.imagePath, this.imageBytes})
      : assert(imagePath != null || imageBytes != null);

  @override
  State<SquareImageCropDialog> createState() => _SquareImageCropDialogState();
}

class _SquareImageCropDialogState extends State<SquareImageCropDialog> {
  ui.Image? _image;
  double _scale = 1.0;
  double _rotation = 0.0;
  Offset _offset = Offset.zero;
  // 読み込みに失敗した場合、読み込み中のままぐるぐる止まって見えないよう
  // エラーとして明示する。
  bool _loadFailed = false;

  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  Offset _baseOffset = Offset.zero;
  Offset? _startFocalPoint;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Web版はdart:ioのFileが使えないため、bytesが渡されていればそちらを
      // 優先する（imagePathのみが渡されるのはデスクトップ/モバイルのみの
      // 想定）。
      final bytes = widget.imageBytes ?? await File(widget.imagePath!).readAsBytes();
      // 長辺が_kDecodeMaxEdgeを超える場合のみ縮小してデコードする
      // （allowUpscaling: falseにより、それより小さい画像は等倍のまま）。
      // targetWidth・targetHeightを両方指定すると、アスペクト比を保ったまま
      // その範囲に収まるサイズへデコードされる。
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _kDecodeMaxEdge,
        targetHeight: _kDecodeMaxEdge,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      final iw = frame.image.width.toDouble();
      final ih = frame.image.height.toDouble();
      // 初期状態：画像の短辺がクロップ枠を覆うように拡大率を決める
      final initialScale = _kCropViewSize / (iw < ih ? iw : ih);
      setState(() {
        _image = frame.image;
        _scale = initialScale;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _baseRotation = _rotation;
    _baseOffset = _offset;
    _startFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final start = _startFocalPoint;
    if (start == null) return;
    setState(() {
      _scale = (_baseScale * details.scale).clamp(0.05, 20.0);
      _rotation = _baseRotation + details.rotation;
      _offset = _baseOffset + (details.focalPoint - start);
    });
  }

  Future<Uint8List?> _renderCropped() async {
    final image = _image;
    if (image == null) return null;
    final outputScale = _kOutputSize / _kCropViewSize;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
        recorder, ui.Rect.fromLTWH(0, 0, _kOutputSize.toDouble(), _kOutputSize.toDouble()));
    canvas.save();
    canvas.translate(_kOutputSize / 2, _kOutputSize / 2);
    canvas.scale(outputScale);
    canvas.translate(_offset.dx, _offset.dy);
    canvas.rotate(_rotation);
    canvas.scale(_scale);
    canvas.translate(-image.width / 2, -image.height / 2);
    canvas.drawImage(image, Offset.zero, ui.Paint());
    canvas.restore();
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(_kOutputSize, _kOutputSize);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.autofillThumbnailCropDialogTitle),
      content: SizedBox(
        width: _kCropViewSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.autofillThumbnailCropDialogHint,
                style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            _loadFailed
                ? SizedBox(
                    width: _kCropViewSize,
                    height: _kCropViewSize,
                    child: Center(
                      child: Text(l10n.autofillThumbnailCropLoadFailed,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                    ),
                  )
                : _image == null
                ? const SizedBox(
                    width: _kCropViewSize,
                    height: _kCropViewSize,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ClipRect(
                    child: SizedBox(
                      width: _kCropViewSize,
                      height: _kCropViewSize,
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: ColoredBox(
                          // 画像が回転してクロップ枠の外側に空きができた部分の背景。
                          // 固定の黒ではなく、テーマのパネル背景色（暗めの面色）に
                          // 連動させる。
                          color: context.watch<ThemeService>().current.panelBgColor,
                          child: CustomPaint(
                            size: const Size(_kCropViewSize, _kCropViewSize),
                            painter: _CropPreviewPainter(
                              image: _image!,
                              scale: _scale,
                              rotation: _rotation,
                              offset: _offset,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: _image == null
              ? null
              : () async {
                  final bytes = await _renderCropped();
                  if (context.mounted) Navigator.pop(context, bytes);
                },
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

class _CropPreviewPainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final double rotation;
  final Offset offset;

  _CropPreviewPainter({
    required this.image,
    required this.scale,
    required this.rotation,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-image.width / 2, -image.height / 2);
    canvas.drawImage(image, Offset.zero, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropPreviewPainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.rotation != rotation ||
      oldDelegate.offset != offset ||
      oldDelegate.image != image;
}
