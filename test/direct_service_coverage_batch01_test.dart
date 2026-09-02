import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/quick_tool_entry.dart';
import 'package:niarim/services/first_use_tooltip_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickToolService direct coverage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('default entries cycle, add/remove/reorder and persistence work', () async {
      final service = QuickToolService();
      await service.init();
      expect(service.entries, hasLength(5));
      expect(service.next()?.id, 'qt1');
      expect(service.next()?.id, 'qt2');

      const custom = QuickToolEntry(
        id: 'custom',
        label: 'Custom',
        toolKey: 'pen',
        brushId: 'Brush0001',
        sizeOverride: 12,
      );
      service.addEntry(custom);
      await Future<void>.delayed(Duration.zero);
      expect(service.entries.last.id, 'custom');

      service.reorder(service.entries.length - 1, 0);
      await Future<void>.delayed(Duration.zero);
      expect(service.entries.first.id, 'custom');

      service.removeEntry('qt2');
      await Future<void>.delayed(Duration.zero);
      expect(service.entries.any((e) => e.id == 'qt2'), isFalse);

      final restored = QuickToolService();
      await restored.init();
      expect(restored.entries.first.id, 'custom');
      expect(restored.entries.any((e) => e.id == 'qt2'), isFalse);
    });

    test('replaceAll resets cycle and persists exact replacement', () async {
      final service = QuickToolService();
      await service.init();
      service.next();
      service.replaceAll(const [
        QuickToolEntry(id: 'a', label: 'A', toolKey: 'eraser'),
        QuickToolEntry(id: 'b', label: 'B', toolKey: 'eyedropper'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(service.entries.map((e) => e.id), orderedEquals(['a', 'b']));
      expect(service.next()?.id, 'a');

      final restored = QuickToolService();
      await restored.init();
      expect(restored.entries.map((e) => e.id), orderedEquals(['a', 'b']));
    });
  });

  group('FirstUseTooltipService direct coverage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('markSeen persists, duplicate mark is idempotent, reset clears', () async {
      final service = FirstUseTooltipService();
      await service.init();
      expect(service.hasSeen('mesh'), isFalse);

      var notifications = 0;
      service.addListener(() => notifications++);
      await service.markSeen('mesh');
      expect(service.hasSeen('mesh'), isTrue);
      expect(notifications, 1);

      await service.markSeen('mesh');
      expect(notifications, 1, reason: 'duplicate mark must not notify again');

      final restored = FirstUseTooltipService();
      await restored.init();
      expect(restored.hasSeen('mesh'), isTrue);

      await restored.resetAll();
      expect(restored.hasSeen('mesh'), isFalse);
      final afterReset = FirstUseTooltipService();
      await afterReset.init();
      expect(afterReset.hasSeen('mesh'), isFalse);
    });
  });
}
