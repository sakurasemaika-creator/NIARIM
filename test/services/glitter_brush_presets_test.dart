import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh install includes glitter and lame presets with distinct behavior', () async {
    SharedPreferences.setMockInitialValues({});
    final service = BrushService();
    await service.init();

    final glitter = service.brushes.singleWhere((b) => b.id == 'Brush0016');
    final lame = service.brushes.singleWhere((b) => b.id == 'Brush0017');

    expect(glitter.name, 'グリッターペン');
    expect(lame.name, 'ラメペン');
    expect(glitter.scatter, greaterThan(lame.scatter));
    expect(glitter.size, greaterThan(lame.size));
    expect(lame.density, greaterThan(glitter.density));
    expect(lame.spacing, lessThan(glitter.spacing));
  });

  test('existing saved brush list is migrated with both new presets', () async {
    const oldBrush = Brush(
      id: 'Brush0001',
      name: 'ペン',
      size: 5,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 50,
      pixelMode: false,
      pressureMode: PressureMode.size,
      pressureStrength: 80,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
    );
    SharedPreferences.setMockInitialValues({
      'brushes': [jsonEncode(oldBrush.toJson())],
    });

    final service = BrushService();
    await service.init();

    expect(service.brushes.any((b) => b.id == 'Brush0016'), isTrue);
    expect(service.brushes.any((b) => b.id == 'Brush0017'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getStringList('brushes') ?? const <String>[];
    expect(persisted.any((s) => s.contains('Brush0016')), isTrue);
    expect(persisted.any((s) => s.contains('Brush0017')), isTrue);
  });
}
