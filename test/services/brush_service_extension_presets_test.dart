import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('first launch includes Net and Hair as built-in presets', () async {
    final service = BrushService();
    await service.init();

    final byId = {for (final brush in service.brushes) brush.id: brush};
    expect(byId.containsKey('Brush0022'), isTrue);
    expect(byId.containsKey('Brush0023'), isTrue);
    expect(byId['Brush0022']!.name, 'ネット');
    expect(byId['Brush0023']!.name, '髪の毛');
    expect(service.isBuiltIn('Brush0022'), isTrue);
    expect(service.isBuiltIn('Brush0023'), isTrue);
    expect(byId.containsKey('Brush0024'), isTrue);
    expect(byId['Brush0024']!.name, '前髪');
    expect(service.isBuiltIn('Brush0024'), isTrue);
  });

  test('existing saved brush list receives missing extension presets', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'brushes': <String>[],
    });
    final service = BrushService();
    await service.init();

    final ids = service.brushes.map((brush) => brush.id).toSet();
    expect(ids, containsAll(<String>{'Brush0022', 'Brush0023', 'Brush0024'}));
  });

  test('duplicate and persistence preserve multiple texture settings', () async {
    final service = BrushService();
    await service.init();
    final base = service.brushes.firstWhere((brush) => brush.id == 'Brush0024');
    final original = base.copyWith(
      id: 'MultiTextureLifecycle',
      name: 'Multi texture lifecycle',
      customImagePaths: const ['a.png', 'b.png', 'c.png'],
      customImageSelectionMode: BrushImageSelectionMode.sequential,
    );
    service.addBrush(original);

    service.duplicateBrush(original.id);
    final duplicate = service.brushes.singleWhere(
      (brush) =>
          brush.id != original.id && brush.name == '${original.name} (コピー)',
    );
    expect(duplicate.customImagePaths, original.customImagePaths);
    expect(
      duplicate.customImageSelectionMode,
      BrushImageSelectionMode.sequential,
    );

    await Future<void>.delayed(Duration.zero);
    final reloaded = BrushService();
    await reloaded.init();
    final restored = reloaded.brushes.singleWhere(
      (brush) => brush.id == original.id,
    );
    expect(restored.customImagePaths, original.customImagePaths);
    expect(
      restored.customImageSelectionMode,
      BrushImageSelectionMode.sequential,
    );
  });

  test('niabrush round trip preserves multiple texture variants', () async {
    final service = BrushService();
    await service.init();

    final sourceDir = await Directory.systemTemp.createTemp('niarim-brush-textures-');
    addTearDown(() => sourceDir.delete(recursive: true));
    final paths = <String>[];
    for (var i = 0; i < 3; i++) {
      final file = File('${sourceDir.path}/variant_$i.png');
      await file.writeAsBytes(<int>[i + 1, i + 2, i + 3]);
      paths.add(file.path);
    }

    final base = service.brushes.firstWhere((brush) => brush.id == 'Brush0024');
    final custom = base.copyWith(
      id: 'RoundTripMultiTexture',
      customImagePath: null,
      customImagePaths: paths,
      customImageSelectionMode: BrushImageSelectionMode.sequential,
    );
    service.addBrush(custom);

    final bundle = await service.exportBrush(custom.id);
    final archive = ZipDecoder().decodeBytes(await bundle.readAsBytes());
    expect(
      archive.files.where((file) => file.name.startsWith('images/')).length,
      paths.length,
    );

    final imported = await service.importBrushFile(bundle.path);
    expect(imported.customImagePaths.length, paths.length);
    expect(
      imported.customImageSelectionMode,
      BrushImageSelectionMode.sequential,
    );
    for (final path in imported.customImagePaths) {
      expect(File(path).existsSync(), isTrue);
    }
  });
}
