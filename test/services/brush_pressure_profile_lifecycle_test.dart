import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Brush _profiledBrush(String id) => Brush(
  id: id,
  name: 'Pressure profile brush',
  size: 20,
  opacity: 80,
  spacing: 10,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 50,
  pixelMode: false,
  pressureMode: PressureMode.off,
  pressureStrength: 100,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: const PressureRangeSetting(enabled: true, weak: 31, strong: 97),
    opacity: const PressureRangeSetting(enabled: true, weak: 42, strong: 86),
    blur: const PressureRangeSetting(enabled: true, weak: 73, strong: 12),
    edgeJitter: const PressureRangeSetting(enabled: true, weak: 64, strong: 8),
    mixing: const PressureMixingOnSetting(
      enabled: true,
      mode: BrushMixingMode.bleed,
      weakRate: 79,
      strongRate: 17,
    ),
  ),
  pressureOff: BrushPressureOffSettings.defaults.copyWith(
    blur: const FixedBrushSetting(enabled: true, value: 23),
    edgeJitter: const FixedBrushSetting(enabled: true, value: 34),
    mixing: const PressureMixingOffSetting(
      enabled: true,
      mode: BrushMixingMode.simple,
      rate: 45,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);

void _expectProfilesPreserved(Brush actual, Brush expected) {
  expect(actual.pressureOn, expected.pressureOn);
  expect(actual.pressureOff, expected.pressureOff);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Brush pressure profile lifecycle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('duplicate preserves pressure ON and OFF profiles', () async {
      final service = BrushService();
      await service.init();
      final original = _profiledBrush('CustomPressureLifecycleDuplicate');
      service.addBrush(original);

      service.duplicateBrush(original.id);

      final duplicate = service.brushes.singleWhere(
        (brush) =>
            brush.id != original.id &&
            brush.name == '${original.name} (コピー)',
      );
      _expectProfilesPreserved(duplicate, original);
    });

    test('persistent reload preserves pressure ON and OFF profiles', () async {
      final service = BrushService();
      await service.init();
      final original = _profiledBrush('CustomPressureLifecyclePersist');
      service.addBrush(original);
      await Future<void>.delayed(Duration.zero);

      final reloaded = BrushService();
      await reloaded.init();

      final restored = reloaded.brushes.singleWhere(
        (brush) => brush.id == original.id,
      );
      _expectProfilesPreserved(restored, original);
    });

    test('export stores pressure ON and OFF profiles in niabrush data', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'niarim_pressure_export_',
      );
      const pathProviderChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          });
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, null);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = BrushService();
      await service.init();
      final original = _profiledBrush('CustomPressureLifecycleExport');
      service.addBrush(original);

      final exported = await service.exportBrush(original.id);
      final archive = ZipDecoder().decodeBytes(await exported.readAsBytes());
      final dataFile = archive.findFile('data.json');
      expect(dataFile, isNotNull);
      final json = jsonDecode(
        utf8.decode(dataFile!.content as List<int>),
      ) as Map<String, dynamic>;
      final restored = Brush.fromJson(json);

      _expectProfilesPreserved(restored, original);
    });

    test('import restores pressure ON and OFF profiles from niabrush data', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'niarim_pressure_import_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final original = _profiledBrush('CustomPressureLifecycleImport');
      final jsonBytes = utf8.encode(jsonEncode(original.toJson()));
      final archive = Archive()
        ..addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      final archiveBytes = ZipEncoder().encode(archive);
      expect(archiveBytes, isNotNull);
      final source = File('${tempDir.path}/source.niabrush');
      await source.writeAsBytes(archiveBytes!);

      final service = BrushService();
      await service.init();
      final imported = await service.importBrushFile(source.path);

      expect(imported.id, isNot(original.id));
      _expectProfilesPreserved(imported, original);
    });
  });
}
