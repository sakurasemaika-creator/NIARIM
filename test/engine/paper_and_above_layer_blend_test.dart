import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';

/// Blend modes act on the paper and on everything drawn below a layer, on
/// the canvas as in the export: a Linear Dodge layer (Prism's glow)
/// brightens a grey paper instead of showing its own dark colours, and a
/// Multiply or Screen layer above the layer being drawn on blends onto it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const size = 8;

  Uint8List solid(int r, int g, int b, [int a = 255]) {
    final out = Uint8List(size * size * 4);
    for (var i = 0; i < out.length; i += 4) {
      out.setAll(i, [r * a ~/ 255, g * a ~/ 255, b * a ~/ 255, a]);
    }
    return out;
  }

  Future<List<int>> pixel(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List().sublist(0, 4);
  }

  Layer layer(String id, LayerBlendMode mode) =>
      Layer(id: id, name: id, type: LayerType.normal, blendMode: mode);

  test('Linear Dodge brightens the paper it is composited onto', () async {
    final tm = TileManager(canvasWidth: size, canvasHeight: size);
    tm.replaceLayerPixels('glow', solid(60, 40, 20));
    final layers = [layer('glow', LayerBlendMode.linearDodge)];
    final onPaper = await LayerCompositor.composite(
      tm,
      layers,
      (l) => l.id,
      size,
      size,
      paperColor: 0xFF808080,
    );
    final px = await pixel(onPaper);
    expect(px[0], closeTo(128 + 60, 1));
    expect(px[1], closeTo(128 + 40, 1));
    expect(px[2], closeTo(128 + 20, 1));
    // Without a paper (a transparent background) it is its own colour.
    final alone = await LayerCompositor.composite(
      tm,
      layers,
      (l) => l.id,
      size,
      size,
    );
    expect(await pixel(alone), [60, 40, 20, 255]);
    // A see-through paper is not composited into the layers.
    final seeThrough = await LayerCompositor.composite(
      tm,
      layers,
      (l) => l.id,
      size,
      size,
      paperColor: 0x80808080,
    );
    expect(await pixel(seeThrough), [60, 40, 20, 255]);
  });

  test('previews bake the paper only when a layer blends with it', () {
    const grey = 0xFF808080;
    final normal = layer('a', LayerBlendMode.normal);
    final dodge = layer('b', LayerBlendMode.linearDodge);
    // Normal layers alone: the background behind the picture is the same.
    expect(LayerCompositor.paperForBlendModes([normal], grey), isNull);
    expect(LayerCompositor.paperForBlendModes([normal, dodge], grey), grey);
    // A hidden blending layer does not count, nor does a see-through or
    // missing background.
    expect(
      LayerCompositor.paperForBlendModes([
        normal,
        dodge.copyWith(isVisible: false),
      ], grey),
      isNull,
    );
    expect(LayerCompositor.paperForBlendModes([dodge], 0x80808080), isNull);
    expect(LayerCompositor.paperForBlendModes([dodge], null), isNull);
  });

  test('layers above blend onto what is drawn below them', () async {
    final tm = TileManager(canvasWidth: size, canvasHeight: size);
    tm.replaceLayerPixels('shade', solid(128, 128, 255));
    tm.replaceLayerPixels('light', solid(64, 64, 64));
    Future<List<int>> playedOnto(Layer above) async {
      final picture = await LayerCompositor.compositeToPicture(
        tm,
        [above],
        (l) => l.id,
        size,
        size,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // What the canvas has drawn below: an orange current layer.
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, size + 0.0, size + 0.0),
        ui.Paint()..color = const ui.Color(0xFFC86432),
      );
      canvas.drawPicture(picture);
      picture.dispose();
      final out = recorder.endRecording();
      final image = await out.toImage(size, size);
      out.dispose();
      final px = await pixel(image);
      image.dispose();
      return px;
    }

    final multiplied = await playedOnto(
      layer('shade', LayerBlendMode.multiply),
    );
    expect(multiplied[0], closeTo(0xC8 * 128 / 255, 1));
    expect(multiplied[1], closeTo(0x64 * 128 / 255, 1));
    expect(multiplied[2], closeTo(0x32, 1));
    final screened = await playedOnto(layer('light', LayerBlendMode.screen));
    expect(screened[0], closeTo(255 - (255 - 0xC8) * (255 - 64) / 255, 1));
    // Linear Dodge (CPU-only) shows as its nearest GPU mode, Plus.
    final dodged = await playedOnto(layer('light', LayerBlendMode.linearDodge));
    expect(dodged[0], 255);
    expect(dodged[1], closeTo(0x64 + 64, 1));
  });

  test(
    'blendOnto gives the exact CPU-only blend for the current layer',
    () async {
      Future<ui.Image> image(Uint8List pixels) async {
        final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
        final codec = await ui.ImageDescriptor.raw(
          buffer,
          width: size,
          height: size,
          pixelFormat: ui.PixelFormat.rgba8888,
        ).instantiateCodec();
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      }

      final backdrop = await image(solid(200, 200, 200));
      final source = await image(solid(100, 30, 0));
      final dodged = await LayerCompositor.blendOnto(
        backdrop,
        source,
        LayerBlendMode.linearDodge,
      );
      // Clipped at white, unlike Plus at less than full opacity.
      expect((await pixel(dodged)).sublist(0, 3), [255, 230, 200]);
      final half = await LayerCompositor.blendOnto(
        backdrop,
        source,
        LayerBlendMode.linearDodge,
        opacityPercent: 50,
      );
      // Linear Dodge at 50 %: halfway between the backdrop and the clipped sum.
      expect((await pixel(half))[0], closeTo((200 + 255) / 2, 1));
      final burned = await LayerCompositor.blendOnto(
        backdrop,
        source,
        LayerBlendMode.linearBurn,
      );
      expect((await pixel(burned)).sublist(0, 3), [45, 0, 0]);
    },
  );
}
