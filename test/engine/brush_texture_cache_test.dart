import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';

void main() {
  test('preloadBrushTextures accepts multiple paths and ignores missing files', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-brush-textures-');
    addTearDown(() => dir.delete(recursive: true));

    // The contract deliberately includes missing paths: preset assets may be
    // unavailable while a brush is being migrated/imported, and preload must
    // keep the existing graceful fallback behavior.
    await expectLater(
      preloadBrushTextures([
        '${dir.path}/missing-a.png',
        '${dir.path}/missing-b.png',
      ]),
      completes,
    );
  });

  test('preloadBrushTextures tolerates duplicate paths', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-brush-textures-');
    addTearDown(() => dir.delete(recursive: true));
    final missing = '${dir.path}/missing.png';

    await expectLater(
      preloadBrushTextures([missing, missing, missing]),
      completes,
    );
  });
}
