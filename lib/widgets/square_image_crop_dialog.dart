import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// クロップ枠（プレビュー領域）の一辺の論理ピクセルサイズ。
const double _kCropViewSize = 260;

/// 出力する正方形サムネイルの実ピクセルサイズ。
const int _kOutputSize = 512;

/// 画像を1:1の正方形へトリミングするダイアログ（仕様書20：自動塗り
/// プリセットのサムネイル画像設定）。ドラッグで位置調整、ピンチで
/// 拡大縮小、2本指回転で角度調整ができる。戻り値はトリミング結果の
/// PNGバイト列（キャンセル時はnull）。
class SquareImageCropDialog extends StatefulWidget {
  final String imagePath;
  const SquareImageCropDialog({super.key, required this.imagePath});

  @override
  State<SquareImageCropDialog> createState() => _SquareImageCropDialogState();
}

class _SquareImageCropDialogState extends State<SquareImageCropDialog> {
  ui.Image? _image;
  double _scale = 1.0;
  double _rotation = 0.0;
  Offset _offset = Offset.zero;

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
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
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
            _image == null
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
                          color: Colors.black,
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
