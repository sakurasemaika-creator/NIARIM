import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_asset_bundle.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Brush _foldBrush(HairFoldMode mode, {String? imagePath}) => Brush(
  id: 'CustomFold_${mode.name}',
  name: 'Custom fold ${mode.name}',
  size: 28,
  opacity: 83,
  spacing: 9,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  folderId: 'source-folder',
  customImagePath: imagePath,
  outlineEnabled: true,
  outlineWidth: 2.25,
  outlineColor: 0xFF375577,
  foldEnabled: true,
  foldMode: mode,
  foldTriggerAngle: 64,
  foldCurveStartRatio: 0.32,
  foldCurveStrength: 8,
  foldLengthRatio: 0.74,
  foldEndTaperRatio: 0.46,
);

void _expectFoldSettings(Brush actual, Brush expected) {
  expect(actual.foldMode, expected.foldMode);
  expect(actual.foldEnabled, expected.foldEnabled);
  expect(actual.outlineEnabled, expected.outlineEnabled);
  expect(actual.outlineWidth, expected.outlineWidth);
  expect(actual.outlineColor, expected.outlineColor);
  expect(actual.foldTriggerAngle, expected.foldTriggerAngle);
  expect(actual.foldCurveStartRatio, expected.foldCurveStartRatio);
  expect(actual.foldCurveStrength, expected.foldCurveStrength);
  expect(actual.foldLengthRatio, expected.foldLengthRatio);
  expect(actual.foldEndTaperRatio, expected.foldEndTaperRatio);
}

Future<BrushService> _loadBrushService() async {
  final service = BrushService();
  addTearDown(service.dispose);
  await service.init();
  return service;
}

Future<Map<String, dynamic>> _savedBrush(String id) async {
  // BrushService persists asynchronously. Reading the platform-backed values
  // after its pending writes also checks that the in-memory model was saved.
  await Future<void>.delayed(Duration.zero);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs
      .getStringList('brushes')!
      .map((json) => jsonDecode(json) as Map<String, dynamic>)
      .singleWhere((json) => json['id'] == id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory testDirectory;
  late Directory documentsDirectory;
  final imageBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    testDirectory = await Directory.systemTemp.createTemp('niarim-fold-mode-');
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (await testDirectory.exists()) {
        await testDirectory.delete(recursive: true);
      }
    });
    documentsDirectory = await Directory(
      '${testDirectory.path}/source-device',
    ).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDirectory.path;
          }
          throw MissingPluginException('Unexpected path lookup: ${call.method}');
        });
  });

  Future<File> writeImage(String name) async {
    return File('${testDirectory.path}/$name.png').writeAsBytes(imageBytes);
  }

  Future<void> useDestinationDevice() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    documentsDirectory = await Directory(
      '${testDirectory.path}/destination-device',
    ).create();
  }

  for (final mode in HairFoldMode.values) {
    test('${mode.name} custom edit survives saved JSON and restart', () async {
      final service = await _loadBrushService();
      final original = _foldBrush(mode);
      service.addBrush(
        original.copyWith(
          foldMode: mode == HairFoldMode.waveTopView
              ? HairFoldMode.curlRight
              : HairFoldMode.waveTopView,
        ),
      );
      service.selectBrush(original.id);
      service.updateBrush(original);

      expect(service.isBuiltIn(original.id), isFalse);
      _expectFoldSettings(service.currentBrush!, original);
      expect((await _savedBrush(original.id))['foldMode'], mode.name);

      final restarted = await _loadBrushService();
      final restored = restarted.brushes.singleWhere(
        (brush) => brush.id == original.id,
      );
      _expectFoldSettings(restored, original);
      expect(restarted.currentBrush!.id, original.id);
      _expectFoldSettings(restarted.currentBrush!, original);
    });

    test('${mode.name} duplicate survives restart independently', () async {
      final service = await _loadBrushService();
      final original = _foldBrush(mode);
      service.addBrush(original);
      service.duplicateBrush(original.id);
      final duplicate = service.brushes.singleWhere(
        (brush) => brush.name == '${original.name} (コピー)',
      );

      expect(duplicate.id, isNot(original.id));
      expect(service.isBuiltIn(duplicate.id), isFalse);
      _expectFoldSettings(duplicate, original);
      expect((await _savedBrush(duplicate.id))['foldMode'], mode.name);

      final restarted = await _loadBrushService();
      _expectFoldSettings(
        restarted.brushes.singleWhere((brush) => brush.id == duplicate.id),
        original,
      );
      restarted.updateBrush(duplicate.copyWith(foldEnabled: false));
      expect(
        restarted.brushes.singleWhere((brush) => brush.id == original.id)
            .foldEnabled,
        isTrue,
      );
      final savedDuplicate = Brush.fromJson(await _savedBrush(duplicate.id));
      expect(savedDuplicate.foldEnabled, isFalse);
      expect(savedDuplicate.foldMode, mode);
    });

    test('${mode.name} niabrush export and import survives restart', () async {
      final service = await _loadBrushService();
      final sourceImage = await writeImage(mode.name);
      final original = _foldBrush(mode, imagePath: sourceImage.path);
      service.addBrush(original);

      final exported = await service.exportBrush(original.id);
      expect(exported.path, endsWith('.niabrush'));
      final archive = ZipDecoder().decodeBytes(await exported.readAsBytes());
      final json = jsonDecode(
        utf8.decode(archive.findFile('data.json')!.content as List<int>),
      ) as Map<String, dynamic>;
      expect(json['foldMode'], mode.name);
      _expectFoldSettings(Brush.fromJson(json), original);
      expect(archive.findFile('images/000.png')!.content, imageBytes);

      await sourceImage.delete();
      await useDestinationDevice();
      final destination = await _loadBrushService();
      final imported = await destination.importBrushFile(exported.path);
      expect(imported.id, isNot(original.id));
      expect(imported.folderId, isNull);
      expect(imported.customImagePath, isNot(sourceImage.path));
      expect(imported.customImagePath, startsWith(documentsDirectory.path));
      expect(await File(imported.customImagePath!).readAsBytes(), imageBytes);
      _expectFoldSettings(imported, original);
      expect((await _savedBrush(imported.id))['foldMode'], mode.name);

      final restarted = await _loadBrushService();
      _expectFoldSettings(
        restarted.brushes.singleWhere((brush) => brush.id == imported.id),
        original,
      );
    });
  }

  test('niatra transfer preserves all five fold modes through restart', () async {
    final source = await _loadBrushService();
    final originals = <Brush>[];
    for (final mode in HairFoldMode.values) {
      final image = await writeImage(mode.name);
      final brush = _foldBrush(mode, imagePath: image.path);
      source.addBrush(brush);
      originals.add(brush);
    }

    // These are real services; only the brush category is selected for transfer.
    final settings = SettingsService();
    final tone = ToneService();
    final stamp = StampService();
    final autofillPresets = AutofillPresetService();
    final theme = ThemeService();
    final palette = PaletteService();
    final pixelArtPalette = PixelArtPaletteService();
    addTearDown(settings.dispose);
    addTearDown(tone.dispose);
    addTearDown(stamp.dispose);
    addTearDown(autofillPresets.dispose);
    addTearDown(theme.dispose);
    addTearDown(palette.dispose);
    addTearDown(pixelArtPalette.dispose);

    const selectedItems = {'ブラシ': true};
    final rawBytes = await NiatraSerializer.export(
      selectedItems: selectedItems,
      settings: settings,
      brush: source,
      tone: tone,
      stamp: stamp,
      autofillPresets: autofillPresets,
      theme: theme,
      palette: palette,
      pixelArtPalette: pixelArtPalette,
    );
    final bytes = await NiatraAssetBundle.enrichExport(
      rawBytes,
      selectedItems: selectedItems,
      brush: source,
      tone: tone,
      stamp: stamp,
    );
    final transferFile = await File(
      '${testDirectory.path}/fold-modes.niatra',
    ).writeAsBytes(bytes);
    final data = await NiatraSerializer.load(transferFile.path);
    final brushJson = (data.raw['brushes'] as List).cast<Map<String, dynamic>>();
    for (final original in originals) {
      final saved = brushJson.singleWhere((json) => json['id'] == original.id);
      expect(saved['foldMode'], original.foldMode.name);
      expect(saved['customImagePath'], isNull);
      expect(saved['embeddedImagePath'], isA<String>());
      await File(original.customImagePath!).delete();
    }

    await useDestinationDevice();
    final destination = await _loadBrushService();
    await NiatraAssetBundle.restoreEmbeddedAssets(
      data,
      brush: destination,
      tone: tone,
      stamp: stamp,
    );
    final restoredCount = destination.brushes.length;
    expect(data.raw.containsKey('brushes'), isFalse);
    NiatraSerializer.applyTo(
      data,
      settings: settings,
      brush: destination,
      tone: tone,
      stamp: stamp,
      autofillPresets: autofillPresets,
      theme: theme,
      palette: palette,
      pixelArtPalette: pixelArtPalette,
    );
    expect(destination.brushes, hasLength(restoredCount));

    for (final original in originals) {
      final imported = destination.brushes.singleWhere(
        (brush) => brush.name == original.name,
      );
      expect(imported.id, isNot(original.id));
      expect(imported.folderId, isNull);
      expect(imported.customImagePath, isNot(original.customImagePath));
      expect(imported.customImagePath, startsWith(documentsDirectory.path));
      expect(await File(imported.customImagePath!).readAsBytes(), imageBytes);
      _expectFoldSettings(imported, original);
      expect((await _savedBrush(imported.id))['foldMode'], original.foldMode.name);
    }

    final restarted = await _loadBrushService();
    for (final original in originals) {
      _expectFoldSettings(
        restarted.brushes.singleWhere((brush) => brush.name == original.name),
        original,
      );
    }
  });
}
