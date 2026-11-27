import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/models/stamp.dart';

/// Writes `assets/stamps/<id>.png` for every built-in stamp shape whose image
/// is missing or no longer matches the shape drawn at the base size. Images
/// that already match are left untouched.
///
/// Run with:
/// flutter test tool/build_builtin_stamp_images_test.dart
///
/// `test/stamp_filtered_sampling_test.dart` checks that image and shape agree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('build built-in stamp images', (tester) async {
    await tester.runAsync(() async {
      const size = baseStampTextureSize;
      final written = <String>[];
      for (final MapEntry(key: id, value: shape)
          in builtInStampShapes.entries) {
        final path = 'assets/stamps/$id.png';
        final drawn = await generateBuiltInStampTexture(
          Stamp(id: id, name: shape, imagePath: path),
        );
        final file = File(path);
        if (file.existsSync() &&
            await _matches(file.readAsBytesSync(), drawn)) {
          continue;
        }
        // The texture is premultiplied; PNG stores straight colour.
        final straight = Uint8List.fromList(drawn);
        for (var i = 0; i < straight.length; i += 4) {
          final a = straight[i + 3];
          if (a == 0 || a == 255) continue;
          for (var c = 0; c < 3; c++) {
            straight[i + c] = (straight[i + c] * 255 / a).round().clamp(0, 255);
          }
        }
        final image = img.Image.fromBytes(
          width: size,
          height: size,
          bytes: straight.buffer,
          numChannels: 4,
        );
        file.writeAsBytesSync(img.encodePng(image, level: 9));
        written.add('$id $shape');
      }
      // ignore: avoid_print
      print(written.isEmpty ? 'all images match' : written.join('\n'));
    });
  });
}

Future<bool> _matches(Uint8List png, Uint8List drawn) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  frame.image.dispose();
  final decoded = data!.buffer.asUint8List();
  if (decoded.length != drawn.length) return false;
  for (var i = 0; i < drawn.length; i++) {
    if ((decoded[i] - drawn[i]).abs() > 1) return false;
  }
  return true;
}
