import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:niarim/engine/archive_security.dart';
import 'package:niarim/engine/niatra_asset_bundle.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'niatra embeds custom brush tone and stamp images with full model json',
    () async {
      SharedPreferences.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp(
        'niatra_asset_bundle_test_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      Future<String> writeImage(String name, List<int> bytes) async {
        final file = File('${temp.path}/$name');
        await file.writeAsBytes(bytes);
        return file.path;
      }

      final brushImage = await writeImage('brush.png', [1, 2, 3, 4]);
      final toneImage = await writeImage('tone.png', [5, 6, 7, 8]);
      final stampImage = await writeImage('stamp.png', [9, 10, 11, 12]);

      final brushService = BrushService();
      brushService.addBrush(
        Brush(
          id: 'custom-brush',
          name: 'custom',
          size: 17,
          opacity: 73,
          spacing: 12,
          stabilization: true,
          stabilizationStrength: 41,
          pixelMode: false,
          pressureOn: const BrushPressureOnSettings(
            size: PressureRangeSetting(enabled: true, weak: 34, strong: 100),
            opacity: PressureRangeSetting(enabled: true, weak: 34, strong: 100),
            blur: PressureRangeSetting(enabled: true, weak: 4, strong: 4),
            edgeJitter: PressureRangeSetting(
              enabled: true,
              weak: 77,
              strong: 77,
            ),
            mixing: PressureMixingOnSetting(
              enabled: true,
              mode: BrushMixingMode.bleed,
              weakRate: 60,
              strongRate: 60,
            ),
          ),
          pressureOff: const BrushPressureOffSettings(
            blur: FixedBrushSetting(enabled: true, value: 4),
            edgeJitter: FixedBrushSetting(enabled: true, value: 77),
            mixing: PressureMixingOffSetting(
              enabled: true,
              mode: BrushMixingMode.bleed,
              rate: 60,
            ),
          ),
          fadeMode: FadeMode.custom,
          fadeIn: const FadeEndpointSettings(value: 1, rangePx: 120),
          fadeOut: const FadeEndpointSettings(value: 0.2, rangePx: 240),
          strokeDecay: true,
          customImagePath: brushImage,
        ),
      );

      final toneService = ToneService();
      toneService.addTone(
        Tone(id: 'custom-tone', name: 'tone', texturePath: toneImage),
      );

      final stampService = StampService();
      stampService.addStamp(
        Stamp(
          id: 'custom-stamp',
          name: 'stamp',
          imagePath: stampImage,
          rotation: true,
          density: 2.5,
          scatter: 18,
          opacity: 63,
          pixelMode: true,
        ),
      );

      final baseData = utf8.encode(
        jsonEncode({'appVersion': '1.0.0', 'keep': 42}),
      );
      final baseArchive = Archive()
        ..addFile(ArchiveFile('data.json', baseData.length, baseData));
      final original = ZipEncoder().encode(baseArchive)!;

      final enriched = await NiatraAssetBundle.enrichExport(
        Uint8List.fromList(original),
        selectedItems: const {'ブラシ': true, '素材': true},
        brush: brushService,
        tone: toneService,
        stamp: stampService,
      );

      final archive = ArchiveSecurity.decodeZip(enriched);
      expect(archive.findFile('CreativeAssets/Brushes/0.png'), isNotNull);
      expect(archive.findFile('CreativeAssets/Tones/0.png'), isNotNull);
      expect(archive.findFile('CreativeAssets/Stamps/0.png'), isNotNull);

      final dataFile = archive.findFile('data.json');
      expect(dataFile, isNotNull);
      final data =
          jsonDecode(utf8.decode(dataFile!.content as List<int>))
              as Map<String, dynamic>;
      expect(data['keep'], 42);
      expect(data['creativeAssetsVersion'], 1);

      final brushJson =
          (data['brushes'] as List).single as Map<String, dynamic>;
      expect(brushJson['customImagePath'], isNull);
      expect(brushJson['embeddedImagePath'], 'CreativeAssets/Brushes/0.png');
      final pressureOn = brushJson['pressureOn'] as Map<String, dynamic>;
      final pressureOff = brushJson['pressureOff'] as Map<String, dynamic>;
      expect(
        (pressureOn['edgeJitter'] as Map<String, dynamic>)['enabled'],
        true,
      );
      expect((pressureOn['edgeJitter'] as Map<String, dynamic>)['weak'], 77);
      expect((pressureOff['edgeJitter'] as Map<String, dynamic>)['value'], 77);
      expect((brushJson['fadeIn'] as Map<String, dynamic>)['rangePx'], 120);
      expect((brushJson['fadeOut'] as Map<String, dynamic>)['rangePx'], 240);

      final toneJson = (data['tones'] as List).single as Map<String, dynamic>;
      expect(toneJson['texturePath'], isNull);
      expect(toneJson['embeddedImagePath'], 'CreativeAssets/Tones/0.png');

      final stampJson = (data['stamps'] as List).single as Map<String, dynamic>;
      expect(stampJson['imagePath'], isNull);
      expect(stampJson['embeddedImagePath'], 'CreativeAssets/Stamps/0.png');
      expect(stampJson['rotation'], true);
      expect(stampJson['density'], 2.5);
      expect(stampJson['scatter'], 18);
      expect(stampJson['opacity'], 63);
      expect(stampJson['pixelMode'], true);
    },
  );
}
