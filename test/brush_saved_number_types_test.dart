import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 整数の項目が小数（80.0）で保存されていても、ブラシを読める。
/// 以前は`as int`で例外になり、その自作ブラシを捨てて一覧を保存し直した。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// JSONの中の整数をすべて同じ値の小数にする（80 → 80.0）。
  Object? asDoubles(Object? value) => switch (value) {
    final int number => number.toDouble(),
    final Map<dynamic, dynamic> map => {
      for (final entry in map.entries) entry.key: asDoubles(entry.value),
    },
    final List<dynamic> list => list.map(asDoubles).toList(),
    _ => value,
  };

  Future<Brush> customBrush() async {
    SharedPreferences.setMockInitialValues({});
    final service = BrushService();
    await service.init();
    final base = service.brushes.firstWhere((b) => b.id == 'Brush0002');
    service.dispose();
    return base.copyWith(
      id: 'custom_decimal',
      name: 'My pen',
      opacity: 80,
      spacing: 12,
      stabilizationStrength: 7,
      pixelColorLevels: 6,
      pixelExplicitColors: const [0xFF112233, 0xFF445566],
    );
  }

  test('a brush whose whole numbers were saved as decimals is read as it '
      'was', () async {
    final brush = await customBrush();
    final decimal = jsonEncode(asDoubles(brush.toJson()));
    expect(decimal, contains('"opacity":80.0'));
    final read = Brush.fromJson(jsonDecode(decimal) as Map<String, dynamic>);
    expect(jsonEncode(read.toJson()), jsonEncode(brush.toJson()));
  });

  test(
    'startup keeps a custom brush saved with decimal whole numbers',
    () async {
      final brush = await customBrush();
      final decimal = jsonEncode(asDoubles(brush.toJson()));
      SharedPreferences.setMockInitialValues({
        'brushes': [decimal],
      });
      AppErrorReporter.recentErrors.clear();
      final service = BrushService();
      await service.init();
      addTearDown(service.dispose);
      final kept = service.brushes.where((b) => b.id == 'custom_decimal');
      expect(kept, hasLength(1), reason: 'the custom brush is still listed');
      expect(kept.single.opacity, 80);
      expect(kept.single.spacing, 12);
      expect(kept.single.pixelExplicitColors, [0xFF112233, 0xFF445566]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs
            .getStringList('brushes')!
            .any((e) => e.contains('custom_decimal')),
        isTrue,
        reason: 'and it is still in the saved list',
      );
    },
  );

  test('a value that is not a whole number is not accepted as an integer '
      'field', () async {
    final brush = await customBrush();
    for (final bad in <Object?>[
      80.5,
      'eighty',
      double.nan,
      double.infinity,
      1e300,
      true,
      null,
    ]) {
      final json = brush.toJson()..['opacity'] = bad;
      expect(
        () => Brush.fromJson(json),
        throwsA(anything),
        reason: 'opacity: $bad',
      );
    }
    // 大きな整数（色）は、小数で保存されていても同じ値で読む。
    final colours = brush.toJson()
      ..['pixelExplicitColors'] = [4278190080.0, -0.0];
    expect(Brush.fromJson(colours).pixelExplicitColors, [0xFF000000, 0]);
  });
}
