import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation_presets.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('installs the three requested Canvas presets once', () async {
    final service = CustomAutomationService();
    await service.init();

    expect(
      service.items.map((item) => item.name),
      containsAll(<String>['オーロラホログラム', '線画抽出', '線画作成']),
    );
    expect(
      service.items.where((item) => item.id.startsWith('preset_')),
      hasLength(3),
    );
    for (final item in service.items) {
      if (!item.id.startsWith('preset_')) continue;
      expect(item.steps, hasLength(1));
      expect(item.steps.single.command, 'canvas.filterApply');
      expect(item.supportsFrameScopeChoice, isTrue);
    }
  });

  test('starter snapshots map to the intended production filters', () {
    final presets = {
      for (final item in builtInCanvasAutomationPresets()) item.name: item,
    };

    FilterDef filterOf(String name) {
      final raw = presets[name]!.steps.single.args['filter'] as Map;
      return FilterDef.fromJson(raw.cast<String, dynamic>());
    }

    expect(filterOf('オーロラホログラム').kind, FilterKind.auroraHologram);
    expect(filterOf('オーロラホログラム').id, 'Filter0019');
    expect(filterOf('線画抽出').kind, FilterKind.autoLineart);
    expect(filterOf('線画抽出').id, 'Filter0023');
    expect(filterOf('線画作成').kind, FilterKind.outline);
    expect(filterOf('線画作成').id, 'Filter0006');
  });

  test('deleting a starter preset does not recreate it after restart', () async {
    final first = CustomAutomationService();
    await first.init();
    await first.delete(auroraHologramAutomationPresetId);

    final second = CustomAutomationService();
    await second.init();
    expect(
      second.items.any((item) => item.id == auroraHologramAutomationPresetId),
      isFalse,
    );
  });
}
