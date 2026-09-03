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
          blurRadius: 4,
          stabilization: true,
          stabilizationStrength: 41,
          pixelMode: false,
          pressureMode: PressureMode.sizeAndOpacity,
          pressureStrength: 66,
          fadeMode: FadeMode.custom,
          fadeCustom: const FadeCustomSettings(
            startValue: 1,
            endValue: 0.2,
            distancePx: 240,
          ),
          strokeDecay: true,
          mixingMode: BrushMixingMode.bleed,
          mixingRate: 60,
          customImagePath: brushImage,
          edgeJitter: true,
          edgeJitterStrength: 77,
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
      expect(brushJson['edgeJitter'], true);
      expect(brushJson['edgeJitterStrength'], 77);
      expect(
        (brushJson['fadeCustom'] as Map<String, dynamic>)['distancePx'],
        240,
      );

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
