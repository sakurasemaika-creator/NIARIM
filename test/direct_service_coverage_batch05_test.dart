import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('niarim_autofill_preset_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'default samples, find/add/update/remove and persistence work',
    () async {
      final service = AutofillPresetService();
      await service.init();
      expect(service.presets.map((p) => p.id), containsAll(['p1', 'p2']));
      expect(
        service.presets.firstWhere((p) => p.id == 'p1').parts.length,
        greaterThan(20),
      );
      final samplePart = service.presets.first.parts.first;
      expect(service.findPart(samplePart.id)?.id, samplePart.id);
      expect(service.findPart('missing-part'), isNull);

      const custom = AutofillPreset(
        id: 'direct_custom',
        name: 'Direct Custom',
        parts: [
          AutofillPart(id: 'direct_part', name: 'Part', color: 0xFF123456),
        ],
      );
      await service.addPreset(custom);
      expect(service.presets.any((p) => p.id == custom.id), isTrue);

      await service.updatePreset(
        custom.copyWith(name: 'Updated', isFavorite: true),
      );
      final updated = service.presets.firstWhere((p) => p.id == custom.id);
      expect(updated.name, 'Updated');
      expect(updated.isFavorite, isTrue);

      final restored = AutofillPresetService();
      await restored.init();
      expect(
        restored.presets.firstWhere((p) => p.id == custom.id).name,
        'Updated',
      );

      await restored.removePreset(custom.id);
      expect(restored.presets.any((p) => p.id == custom.id), isFalse);
      final afterRemove = AutofillPresetService();
      await afterRemove.init();
      expect(afterRemove.presets.any((p) => p.id == custom.id), isFalse);
    },
  );

  test(
    'thumbnail replacement deletes old file and clear removes current file',
    () async {
      final service = AutofillPresetService();
      await service.init();
      final presetId = service.presets.first.id;

      await service.setPresetThumbnailBytes(
        presetId,
        Uint8List.fromList([1, 2, 3, 4]),
      );
      final firstPath = service.presets
          .firstWhere((p) => p.id == presetId)
          .thumbnailPath;
      expect(firstPath, isNotNull);
      expect(File(firstPath!).existsSync(), isTrue);
      expect(await File(firstPath).readAsBytes(), [1, 2, 3, 4]);

      await service.setPresetThumbnailBytes(
        presetId,
        Uint8List.fromList([9, 8, 7]),
      );
      final secondPath = service.presets
          .firstWhere((p) => p.id == presetId)
          .thumbnailPath;
      expect(secondPath, isNot(firstPath));
      expect(File(firstPath).existsSync(), isFalse);
      expect(File(secondPath!).existsSync(), isTrue);
      expect(await File(secondPath).readAsBytes(), [9, 8, 7]);

      await service.clearPresetThumbnail(presetId);
      expect(
        service.presets.firstWhere((p) => p.id == presetId).thumbnailPath,
        isNull,
      );
      expect(File(secondPath).existsSync(), isFalse);

      await service.setPresetThumbnailBytes('missing-preset', Uint8List(0));
      await service.clearPresetThumbnail('missing-preset');
    },
  );

  test(
    'init repairs duplicate preset and part ids and upgrades untouched old samples',
    () async {
      const oldP1 = AutofillPreset(
        id: 'p1',
        name: '主人公',
        parts: [
          AutofillPart(id: 'dup_part', name: '髪', color: 0xFF111111),
          AutofillPart(id: 'dup_part', name: '肌', color: 0xFF222222),
        ],
      );
      const duplicateP1 = AutofillPreset(
        id: 'p1',
        name: 'duplicate',
        parts: [AutofillPart(id: 'x', name: 'X', color: 0xFF333333)],
      );
      SharedPreferences.setMockInitialValues({
        'autofill_presets': [
          jsonEncode(oldP1.toJson()),
          jsonEncode(duplicateP1.toJson()),
        ],
      });

      final service = AutofillPresetService();
      await service.init();
      final presetIds = service.presets.map((p) => p.id).toList();
      expect(
        presetIds.toSet().length,
        presetIds.length,
        reason: 'duplicate preset IDs must self-repair',
      );
      final upgraded = service.presets.firstWhere((p) => p.id == 'p1');
      expect(
        upgraded.parts.length,
        greaterThan(20),
        reason: 'untouched legacy p1 sample should be upgraded',
      );
      final partIds = upgraded.parts.map((p) => p.id).toList();
      expect(
        partIds.toSet().length,
        partIds.length,
        reason: 'parts must have unique IDs after initialization',
      );

      final persisted = SharedPreferences.getInstance();
      final prefs = await persisted;
      final raw = prefs.getStringList('autofill_presets')!;
      expect(
        raw,
        hasLength(3),
        reason: 'the built-in gray underpaint preset is persisted alongside repaired samples',
      );
      final decodedIds = raw
          .map(
            (s) => AutofillPreset.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ).id,
          )
          .toList();
      expect(decodedIds, contains('builtin_gray_underpaint'));
      expect(decodedIds.toSet().length, decodedIds.length);
    },
  );
}
