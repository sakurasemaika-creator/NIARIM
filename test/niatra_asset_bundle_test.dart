import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:niarim/engine/archive_security.dart';
import 'package:niarim/engine/niatra_asset_bundle.dart';
import 'package:niarim/engine/niatra_serializer.dart';
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
  test('niatra embeds every image of a multi-image brush in order', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp(
      'niatra_multi_brush_test_',
    );
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final paths = <String>[];
    for (var i = 0; i < 5; i++) {
      final file = File('${temp.path}/bangs_$i.png');
      await file.writeAsBytes([i + 1, i + 2, i + 3, 255]);
      paths.add(file.path);
    }

    final brushService = BrushService();
    brushService.addBrush(
      Brush(
        id: 'multi-brush',
        name: 'multi',
        size: 32,
        opacity: 100,
        spacing: 1,
        stabilization: true,
        stabilizationStrength: 40,
        pixelMode: false,
        fadeMode: FadeMode.off,
        strokeDecay: false,
        customImagePaths: paths,
        customImageSelectionMode: BrushImageSelectionMode.random,
      ),
    );
    final baseData = utf8.encode(jsonEncode({'appVersion': '1.0.0'}));
    final baseArchive = Archive()
      ..addFile(ArchiveFile('data.json', baseData.length, baseData));

    final enriched = await NiatraAssetBundle.enrichExport(
      Uint8List.fromList(ZipEncoder().encode(baseArchive)!),
      selectedItems: const {'ブラシ': true},
      brush: brushService,
      tone: ToneService(),
      stamp: StampService(),
    );
    final archive = ArchiveSecurity.decodeZip(enriched);
    for (var i = 0; i < 5; i++) {
      final path =
          'CreativeAssets/Brushes/0/${i.toString().padLeft(3, '0')}.png';
      final entry = archive.findFile(path);
      expect(entry, isNotNull, reason: 'missing bundled variant $i');
      expect((entry!.content as List<int>).first, i + 1);
    }

    final dataFile = archive.findFile('data.json')!;
    final data =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    final brushJson =
        (data['brushes'] as List).single as Map<String, dynamic>;
    expect(brushJson['customImagePath'], isNull);
    expect(brushJson['customImagePaths'], isEmpty);
    expect(
      brushJson['embeddedImagePaths'],
      [
        'CreativeAssets/Brushes/0/000.png',
        'CreativeAssets/Brushes/0/001.png',
        'CreativeAssets/Brushes/0/002.png',
        'CreativeAssets/Brushes/0/003.png',
        'CreativeAssets/Brushes/0/004.png',
      ],
    );
  });

  test('niatra restores multi-image brush files in order', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp(
      'niatra_multi_restore_test_',
    );
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final embedded = <String>[];
    final archive = Archive();
    for (var i = 0; i < 5; i++) {
      final path =
          'CreativeAssets/Brushes/0/${i.toString().padLeft(3, '0')}.png';
      embedded.add(path);
      final bytes = <int>[i + 11, i + 21, i + 31, 255];
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
    final raw = <String, dynamic>{
      'creativeAssetsVersion': 1,
      'brushes': [
        {
          'id': 'source',
          'name': 'multi restore',
          'size': 32.0,
          'opacity': 100,
          'spacing': 1,
          'stabilization': true,
          'stabilizationStrength': 40,
          'pixelMode': false,
          'pressureOn': BrushPressureOnSettings.defaults.toJson(),
          'pressureOff': BrushPressureOffSettings.defaults.toJson(),
          'fadeMode': 'off',
          'fadeIn': FadeEndpointSettings.full.toJson(),
          'fadeOut': FadeEndpointSettings.full.toJson(),
          'strokeDecay': false,
          'customImagePath': null,
          'customImagePaths': <String>[],
          'customImageSelectionMode': 'random',
          'embeddedImagePaths': embedded,
        },
      ],
    };
    final brushService = BrushService();

    await NiatraAssetBundle.restoreEmbeddedAssets(
      NiatraData(raw, archive),
      brush: brushService,
      tone: ToneService(),
      stamp: StampService(),
      restoreBasePath: temp.path,
    );

    final restored = brushService.brushes.last;
    expect(restored.customImageSelectionMode, BrushImageSelectionMode.random);
    expect(restored.customImagePaths, hasLength(5));
    for (var i = 0; i < restored.customImagePaths.length; i++) {
      final file = File(restored.customImagePaths[i]);
      expect(await file.exists(), isTrue);
      expect((await file.readAsBytes()).first, i + 11);
    }
  });

}
