import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityPreviewService direct coverage', () {
    test('show close position and size clamping notify and retain state', () {
      final service = CommunityPreviewService();
      final work = CommunityService().works.first;
      var notifications = 0;
      service.addListener(() => notifications++);

      service.show(work);
      expect(service.work?.id, work.id);

      service.updatePosition(const Offset(31, 47));
      expect(service.position, const Offset(31, 47));

      // サイズは幅だけを持ち、高さは16:9＋コントロールバーから導出する
      // （YouTubeの埋め込みプレーヤーの最小200×200を構造的に守るため。
      // 詳細はCommunityPreviewServiceのコメント参照）。
      service.updateWidth(20);
      expect(service.width, CommunityPreviewService.minWidth);

      service.updateWidth(9999);
      expect(service.width, CommunityPreviewService.maxWidth);

      service.updateWidth(400);
      expect(service.width, 400);
      expect(
        service.size.height,
        closeTo(400 / CommunityPreviewService.playerAspect + 44, 0.001),
      );

      service.close();
      expect(service.work, isNull);
      expect(notifications, 6);
    });
  });

  group('ShortcutService direct coverage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults conflict add update remove and persistence work', () async {
      final service = ShortcutService();
      await service.init();
      expect(service.bindings.length, greaterThanOrEqualTo(7));

      final ctrlZ = ShortcutBinding(
        id: 'probe',
        label: 'Probe',
        keyId: LogicalKeyboardKey.keyZ.keyId,
        control: true,
        command: ShortcutCommand.playPause,
      );
      expect(service.findConflict(ctrlZ)?.id, 'default_undo');

      final custom = ShortcutBinding(
        id: 'custom_q',
        label: 'Custom Q',
        keyId: LogicalKeyboardKey.keyQ.keyId,
        shift: true,
        toolKey: 'pen',
        brushId: 'Brush0001',
        sizeOverride: 11,
      );
      service.addBinding(custom);
      await Future<void>.delayed(Duration.zero);
      expect(service.bindings.any((b) => b.id == custom.id), isTrue);
      expect(service.findConflict(custom, excludeId: custom.id), isNull);

      final updated = ShortcutBinding(
        id: custom.id,
        label: 'Custom W',
        keyId: LogicalKeyboardKey.keyW.keyId,
        alt: true,
        command: ShortcutCommand.nextFrame,
      );
      service.updateBinding(updated);
      await Future<void>.delayed(Duration.zero);
      expect(
        service.bindings.firstWhere((b) => b.id == custom.id).label,
        'Custom W',
      );

      final restored = ShortcutService();
      await restored.init();
      final restoredBinding = restored.bindings.firstWhere(
        (b) => b.id == custom.id,
      );
      expect(restoredBinding.keyId, LogicalKeyboardKey.keyW.keyId);
      expect(restoredBinding.alt, isTrue);
      expect(restoredBinding.command, ShortcutCommand.nextFrame);

      restored.removeBinding(custom.id);
      await Future<void>.delayed(Duration.zero);
      expect(restored.bindings.any((b) => b.id == custom.id), isFalse);
    });
  });

  group('FilterService direct coverage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'select params favorite search add duplicate reorder remove persist',
      () async {
        final service = FilterService();
        await service.init();
        expect(service.filters.length, 24);
        expect(service.currentFilter?.id, 'Filter0001');
        expect(service.isBuiltIn('Filter0001'), isTrue);
        expect(service.removeFilter('Filter0001'), isFalse);

        service.selectFilter('Filter0018');
        expect(service.currentFilter?.id, 'Filter0018');
        service.updateFilterParams(
          'Filter0018',
          strength: 13,
          colorLevels: 5,
          edgeStrength: 0.7,
        );
        await Future<void>.delayed(Duration.zero);
        expect(service.currentFilter?.strength, 13);
        expect(service.currentFilter?.colorLevels, 5);

        service.toggleFavorite('Filter0018');
        await Future<void>.delayed(Duration.zero);
        expect(service.currentFilter?.isFavorite, isTrue);
        service.setFavoritesOnly(true);
        expect(service.visibleFilters.every((f) => f.isFavorite), isTrue);
        expect(service.visibleFilters.map((f) => f.id), contains('Filter0018'));
        service.setFavoritesOnly(false);

        service.setSearchQuery('ガウス');
        expect(service.visibleFilters.map((f) => f.id), contains('Filter0001'));
        expect(
          service.visibleFilters.every((f) => f.name.contains('ガウス')),
          isTrue,
        );
        service.setSearchQuery('');

        const custom = FilterDef(
          id: 'custom_direct',
          name: 'Direct Custom',
          kind: FilterKind.colorAdjust,
          strength: 22,
        );
        service.addFilter(custom);
        await Future<void>.delayed(Duration.zero);
        expect(service.currentFilter?.id, custom.id);
        expect(service.isBuiltIn(custom.id), isFalse);

        service.duplicateFilter(custom.id);
        await Future<void>.delayed(Duration.zero);
        final copies = service.filters
            .where((f) => f.name == 'Direct Custom_copy')
            .toList();
        expect(copies, hasLength(1));
        final copyId = copies.single.id;
        expect(service.isBuiltIn(copyId), isFalse);

        service.reorderFilter(copyId, 0);
        await Future<void>.delayed(Duration.zero);
        expect(service.filters.first.id, copyId);

        service.toggleFavorite(custom.id);
        await Future<void>.delayed(Duration.zero);
        expect(
          service.removeFilter(custom.id),
          isFalse,
          reason: 'favorite custom filters are protected',
        );
        service.toggleFavorite(custom.id);
        await Future<void>.delayed(Duration.zero);
        expect(service.removeFilter(custom.id), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(service.filters.any((f) => f.id == custom.id), isFalse);

        expect(service.removeFilter(copyId), isTrue);
        await Future<void>.delayed(Duration.zero);

        final restored = FilterService();
        await restored.init();
        expect(restored.filters.any((f) => f.id == custom.id), isFalse);
        expect(
          restored.filters.firstWhere((f) => f.id == 'Filter0018').strength,
          13,
        );
        expect(
          restored.filters.firstWhere((f) => f.id == 'Filter0018').isFavorite,
          isTrue,
        );
      },
    );
  });
}
