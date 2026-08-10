import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/procedural_texture.dart';
import '../models/tone.dart';

/// トーンを指定色で着色したプレビューを表示するウィジェット（仕様書04・20：
/// 自動塗りプリセットのパーツ一覧で「トーンを使用」しているパーツの
/// プレビューに、実際のトーンパターンを反映させるために使う。タスク#91）。
class TonePreviewThumb extends StatefulWidget {
  final Tone? tone;
  final Color color;
  final double size;
  final BoxShape shape;

  const TonePreviewThumb({
    super.key,
    required this.tone,
    required this.color,
    this.size = 32,
    this.shape = BoxShape.circle,
  });

  @override
  State<TonePreviewThumb> createState() => _TonePreviewThumbState();
}

class _TonePreviewThumbState extends State<TonePreviewThumb> {
  static const int _textureSize = 32;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TonePreviewThumb old) {
    super.didUpdateWidget(old);
    if (old.tone?.id != widget.tone?.id ||
        old.tone?.texturePath != widget.tone?.texturePath ||
        old.color != widget.color) {
      _load();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tone = widget.tone;
    if (tone == null) return;
    await ensureToneTextureLoaded(tone, size: _textureSize);
    if (!mounted) return;
    final mask = generateBuiltInToneTexture(tone, size: _textureSize);
    final rgba = Uint8List(mask.length);
    final r = (widget.color.r * 255).round();
    final g = (widget.color.g * 255).round();
    final b = (widget.color.b * 255).round();
    for (int i = 0; i < mask.length; i += 4) {
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = mask[i + 3];
    }
    ui.decodeImageFromPixels(rgba, _textureSize, _textureSize, ui.PixelFormat.rgba8888, (img) {
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = img;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.rectangle ? BorderRadius.circular(6) : null,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: _image == null ? null : RawImage(image: _image, fit: BoxFit.cover),
    );
  }
}
