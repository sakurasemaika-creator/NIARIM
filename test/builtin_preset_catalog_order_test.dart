import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new installs offer related built-in presets together', () async {
    SharedPreferences.setMockInitialValues({});
    final brushes = BrushService();
    final tones = ToneService();
    final stamps = StampService();
    addTearDown(brushes.dispose);
    addTearDown(tones.dispose);
    addTearDown(stamps.dispose);
    await brushes.init();
    await tones.init();
    await stamps.init();

    final brushIds = brushes.brushes.map((brush) => brush.id).toList();
    // The painting brushes with bristle marks follow the other paint.
    expect(brushIds.sublist(13, 18), [
      'Brush0027',
      'Brush0004',
      'Brush0042',
      'Brush0043',
      'Brush0044',
    ]);
    expect(brushIds.sublist(26), [
      'Brush0021',
      'Brush0022',
      'Brush0025',
      'Brush0023',
      'Brush0031',
      'Brush0032',
      'Brush0034',
      'Brush0035',
      'Brush0024',
      'Brush0036',
      'Brush0037',
      'Brush0038',
      'Brush0039',
      'Brush0040',
      'Brush0030',
      'Brush0041',
    ]);
    final firstPixel = tones.tones.indexWhere((tone) => tone.pixelMode);
    expect(firstPixel, greaterThan(0));
    expect(
      tones.tones.skip(firstPixel).every((tone) => tone.pixelMode),
      isTrue,
    );
    final ditherNames = tones.tones
        .map((tone) => tone.name)
        .where((name) => name.startsWith('ピクセルディザ'));
    expect(ditherNames, hasLength(18));
    expect(
      ditherNames.every(
        (name) =>
            RegExp(r'^ピクセルディザ（(粗目|標準|細目)・[248]×[248]・\d+%）$').hasMatch(name),
      ),
      isTrue,
    );
    expect(stamps.stamps, hasLength(29));
    expect(stamps.stamps.take(4).map((stamp) => stamp.id), [
      'Stamp0001',
      'Stamp0009',
      'Stamp0010',
      'Stamp0011',
    ]);
  });

  test(
    'upgrade removes retired stamps once and keeps hand sorting thereafter',
    () async {
      const removed = Stamp(id: 'Stamp0016', name: '六芒星', isFavorite: true);
      const custom = Stamp(
        id: 'StampCustom001',
        name: '自作のマーク',
        imagePath: 'assets/stamps/Stamp0001.png',
      );
      const moved = Stamp(
        id: 'Stamp0008',
        name: '円',
        folderId: 'shapes',
        imagePath: 'assets/stamps/Stamp0008.png',
      );
      SharedPreferences.setMockInitialValues({
        'stamps': [
          for (final stamp in [removed, custom, moved])
            jsonEncode(stamp.toJson()),
        ],
      });
      final stamps = StampService();
      addTearDown(stamps.dispose);
      await stamps.init();
      final ids = stamps.stamps.map((stamp) => stamp.id).toList();
      expect(ids, isNot(contains(removed.id)));
      expect(stamps.stamps.first.id, custom.id);
      expect(
        stamps.stamps.firstWhere((stamp) => stamp.id == moved.id).folderId,
        'shapes',
      );

      stamps.reorderStamp(0, stamps.stamps.length);
      await Future<void>.delayed(Duration.zero);
      final restarted = StampService();
      addTearDown(restarted.dispose);
      await restarted.init();
      expect(restarted.stamps.last.id, custom.id);
      expect(
        restarted.stamps.map((stamp) => stamp.id),
        isNot(contains(removed.id)),
      );
    },
  );
}
