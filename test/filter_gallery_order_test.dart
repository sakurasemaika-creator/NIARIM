// フィルターの見本の一覧は、NIARIMならではの組み込みのフィルター（自動線画・
// 墨溜まり・背景馴染ませ・水彩境界・球体陰影・プリズム・眼鏡断層・質感変更）を
// 先に並べ、ほかのフィルターは今までの順のまま続ける。どのフィルターも1回ずつ
// 並び、利用者の複製は元のすぐ後ろ（今までどおり）、お気に入りの印もそのまま。
// FilterService.filters（保存・自動操作の順）は変えない。
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('signature filters lead the gallery; every filter stays once', () async {
    final service = FilterService();
    addTearDown(service.dispose);
    await service.init();
    final stored = service.filters.map((f) => f.id).toList();
    final gallery = service.galleryFilters.map((f) => f.id).toList();

    expect(gallery.toSet(), stored.toSet());
    expect(gallery, hasLength(stored.length));
    expect(
      gallery.take(FilterService.signatureFilterIds.length),
      FilterService.signatureFilterIds,
    );
    expect(
      [
        for (final id in FilterService.signatureFilterIds)
          service.filters.firstWhere((f) => f.id == id).kind,
      ],
      [
        FilterKind.autoLineart,
        FilterKind.inkPool,
        FilterKind.backgroundBlend,
        FilterKind.watercolorBorder,
        FilterKind.sphereShading,
        FilterKind.prism,
        FilterKind.lensDistortion,
        FilterKind.auroraHologram,
      ],
    );
    // The rest keep the order they had.
    expect(gallery.skip(FilterService.signatureFilterIds.length), [
      for (final id in stored)
        if (!FilterService.signatureFilterIds.contains(id)) id,
    ]);
    // The stored order (saving, automations) is unchanged.
    expect(stored.first, 'Filter0001');
  });

  test('a duplicate and a favourite keep their place', () async {
    final service = FilterService();
    addTearDown(service.dispose);
    await service.init();
    service.duplicateFilter('Filter0001');
    service.duplicateFilter('Filter0021');
    service.toggleFavorite('Filter0002');
    final gallery = service.galleryFilters;
    final ids = gallery.map((f) => f.id).toList();
    final gaussian = ids.indexOf('Filter0001');
    final gaussianCopy = gallery[gaussian + 1];
    expect(service.isBuiltIn(gaussianCopy.id), isFalse);
    expect(gaussianCopy.kind, FilterKind.gaussianBlur);
    // A copy of a signature filter is the user's own: it stays with the
    // others, right after where the original is stored.
    final inkCopy = gallery.singleWhere(
      (f) => f.kind == FilterKind.inkPool && !service.isBuiltIn(f.id),
    );
    expect(
      ids.indexOf(inkCopy.id),
      greaterThan(FilterService.signatureFilterIds.length - 1),
    );
    expect(gallery.singleWhere((f) => f.id == 'Filter0002').isFavorite, isTrue);
    expect(ids.toSet(), hasLength(ids.length));
  });
}
