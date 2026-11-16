import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;

/// Reads the original tip image from either the app bundle or a user file.
Future<Uint8List?> readBrushImageSource(String path) async {
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
