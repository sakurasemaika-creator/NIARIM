// フィルターの「キャンセル」で、動かした値を元に戻す（所有者の判断、
// 2026-11-27、全部入りの作品づくりの判断カードJ9「キャンセル：元の値に戻す」）。
//
// 以前は、スライダーを動かしてからキャンセルしても、次にそのフィルターを
// 開くと動かした値のままだった。値を覚えるのは適用したときだけ。
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FilterService> service() async {
    SharedPreferences.setMockInitialValues({});
    final filters = FilterService();
    await filters.init();
    addTearDown(filters.dispose);
    return filters;
  }

  FilterDef mosaic(FilterService filters) =>
      filters.filters.singleWhere((f) => f.id == FilterService.mosaicFilterId);

  test('cancelling puts the moved values back', () async {
    final filters = await service();
    final before = mosaic(filters);
    filters.selectFilter(FilterService.mosaicFilterId);
    filters.updateFilterParams(
      FilterService.mosaicFilterId,
      strength: before.strength + 7,
    );
    expect(mosaic(filters).strength, before.strength + 7);
    filters.clearCurrentFilter();
    expect(mosaic(filters).strength, before.strength);
    expect(filters.currentFilter, isNull);
  });

  test('choosing another filter puts the values back too', () async {
    final filters = await service();
    final before = mosaic(filters);
    filters.selectFilter(FilterService.mosaicFilterId);
    filters.updateFilterParams(
      FilterService.mosaicFilterId,
      strength: before.strength + 3,
    );
    filters.selectFilter(FilterService.filmGrainFilterId);
    expect(mosaic(filters).strength, before.strength);
  });

  test('applying keeps the values', () async {
    final filters = await service();
    final before = mosaic(filters);
    filters.selectFilter(FilterService.mosaicFilterId);
    filters.updateFilterParams(
      FilterService.mosaicFilterId,
      strength: before.strength + 5,
    );
    filters
      ..keepFilterEdits()
      ..clearCurrentFilter();
    expect(mosaic(filters).strength, before.strength + 5);
  });

  test('a name or favourite changed meanwhile stays', () async {
    final filters = await service();
    final before = mosaic(filters);
    filters.selectFilter(FilterService.mosaicFilterId);
    filters.updateFilterParams(
      FilterService.mosaicFilterId,
      strength: before.strength + 4,
    );
    filters.toggleFavorite(FilterService.mosaicFilterId);
    filters.clearCurrentFilter();
    final now = mosaic(filters);
    expect(now.strength, before.strength);
    expect(now.isFavorite, !before.isFavorite);
  });
}
