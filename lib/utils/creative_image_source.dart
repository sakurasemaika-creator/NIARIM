import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

/// Reads the original creative asset image from either the app bundle or a user file.
Future<Uint8List?> readCreativeImageSource(String path) async {
  if (path.startsWith('assets/')) {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on FlutterError {
      return null;
    }
  }
  final file = File(path);
  return await file.exists() ? file.readAsBytes() : null;
}

/// Stores imported artwork as RGBA PNG, preserving its original colors and alpha.
Future<void> copyCreativeImageAsPng(String source, String destination) async {
  final bytes = await readCreativeImageSource(source);
  if (bytes == null) throw const FormatException('Image file not found');
  await File(destination).writeAsBytes(await encodeCreativePng(bytes));
}

/// Already-normalized PNGs can be kept byte for byte.
Future<Uint8List> encodeCreativePng(Uint8List bytes) async {
  if (bytes.length > 26 &&
      img.PngDecoder().isValidFile(bytes) &&
      (bytes[25] == 6 || bytes[25] == 4)) {
    return bytes;
  }
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (rgba == null) {
        throw const FormatException('Image could not be decoded');
      }
      return creativePngFromRgba(
        rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        frame.image.width,
        frame.image.height,
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Uint8List creativePngFromRgba(Uint8List rgba, int width, int height) =>
    img.encodePng(
      img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        bytesOffset: rgba.offsetInBytes,
        numChannels: 4,
      ),
    );

/// Reads old exports without dropping the asset if its image cannot be decoded.
Future<String> restoreCreativeImage(
  List<int> original,
  String destinationWithoutExtension,
  String originalExtension,
) async {
  final (bytes, extension) = await normalizeRestoredCreativeImage(
    original,
    originalExtension,
  );
  final file = File('$destinationWithoutExtension.$extension');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<(List<int>, String)> normalizeRestoredCreativeImage(
  List<int> original,
  String originalExtension,
) async {
  try {
    return (await encodeCreativePng(Uint8List.fromList(original)), 'png');
  } on Exception {
    return (original, originalExtension);
  }
}

/// Normalizes legacy user files when they are readable. A failed conversion
/// leaves both the original reference and original file intact.
Future<String> migrateCreativeImage(String path) async {
  if (path.startsWith('assets/') || path.endsWith('.rgba.png')) return path;
  try {
    final original = await readCreativeImageSource(path);
    if (original == null) return path;
    final png = await encodeCreativePng(original);
    if (identical(original, png) && path.toLowerCase().endsWith('.png')) {
      return path;
    }
    final destination = File('$path.rgba.png');
    await destination.writeAsBytes(png, flush: true);
    return destination.path;
  } on Exception {
    return path;
  }
}
