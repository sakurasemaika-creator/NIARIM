import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 画像ファイルを表示し、タップした位置のピクセル色を取得するダイアログ
/// （仕様書20：自動塗りプリセットのサムネイル画像から、謎のパレットではなく
/// スポイトで色を拾えるようにする機能）。戻り値は選択されたColor（未選択で
/// 閉じた場合はnull）。
/// [imagePath]（デスクトップ/モバイル）と[imageBytes]（Web版：dart:ioの
/// Fileが使えないため、選択した画像のバイト列を直接渡す）のどちらか一方を
/// 指定する。
class ImageEyedropperDialog extends StatefulWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  const ImageEyedropperDialog({super.key, this.imagePath, this.imageBytes})
      : assert(imagePath != null || imageBytes != null);

  @override
  State<ImageEyedropperDialog> createState() => _ImageEyedropperDialogState();
}

class _ImageEyedropperDialogState extends State<ImageEyedropperDialog> {
  ui.Image? _image;
  Uint8List? _pixels;
  Uint8List? _sourceBytes;
  Color? _previewColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = widget.imageBytes ?? await File(widget.imagePath!).readAsBytes();
    _sourceBytes = bytes;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _image = frame.image;
      _pixels = byteData?.buffer.asUint8List();
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// [localPos]（表示ウィジェット内の座標、サイズ[boxSize]）を、
  /// BoxFit.contain相当で表示された画像上のピクセル座標へ変換し、
  /// その位置の色を返す（範囲外タップはnull）。
  Color? _colorAt(Offset localPos, Size boxSize) {
    final image = _image;
    final pixels = _pixels;
    if (image == null || pixels == null) return null;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scale = (boxSize.width / imgW < boxSize.height / imgH)
        ? boxSize.width / imgW
        : boxSize.height / imgH;
    final dispW = imgW * scale;
    final dispH = imgH * scale;
    final offsetX = (boxSize.width - dispW) / 2;
    final offsetY = (boxSize.height - dispH) / 2;
    final x = ((localPos.dx - offsetX) / scale).floor();
    final y = ((localPos.dy - offsetY) / scale).floor();
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return null;
    final idx = (y * image.width + x) * 4;
    if (idx + 3 >= pixels.length) return null;
    return Color.fromARGB(pixels[idx + 3], pixels[idx], pixels[idx + 1], pixels[idx + 2]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.autofillEyedropperDialogTitle),
      content: SizedBox(
        width: 320,
        height: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.autofillEyedropperDialogHint,
                style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Expanded(
              child: _image == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(builder: (ctx, constraints) {
                      final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onTapUp: (details) {
                          final c = _colorAt(details.localPosition, boxSize);
                          if (c != null) setState(() => _previewColor = c);
                        },
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                          // dart:ioのFileはWeb版で使えないため、常にバイト列
                          // （_load()で読み込み済み）から表示する。
                          child: Image.memory(_sourceBytes!, fit: BoxFit.contain),
                        ),
                      );
                    }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _previewColor ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.autofillEyedropperPickedLabel, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: _previewColor == null ? null : () => Navigator.pop(context, _previewColor),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
