import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush_presets_extension.dart';
import 'package:niarim/engine/brush_texture_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('all shipped bangs texture assets preload into the production cache', () async {
    final bangs = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
    expect(bangs.customImagePaths.length, 5);
    await preloadBrushTextures(bangs.customImagePaths);
    for (final path in bangs.customImagePaths) {
      final texture = getCachedBrushTexture(path);
      expect(texture, isNotNull, reason: 'missing built-in bangs texture: $path');
      final alpha = <int>[
        for (var i = 3; i < texture!.length; i += 4) texture[i],
      ];
      final inkPixels = alpha.where((value) => value > 0).length;
      expect(
        inkPixels,
        greaterThan(alpha.length * .18),
        reason: 'bangs texture must stay dense through the tip: $path',
      );
    }
  });
}
