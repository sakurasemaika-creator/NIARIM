import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/screens/canvas/filter_immersive_policy.dart';
import 'package:niarim/services/filter_service.dart';

void main() {
  test('Every built-in filter opens the same desktop immersive edit canvas', () {
    final filters = FilterService.builtInFilters;
    expect(filters.length, greaterThan(15));
    for (final filter in filters) {
      expect(
        shouldUseImmersiveFilterUi(
          panelOpen: true,
          desktop: true,
          selectedFilter: filter,
        ),
        isTrue,
        reason: '${filter.id}: ${filter.name} must hide canvas chrome',
      );
    }
  });

  test('Custom filters and instant inversion use the same immersive rule', () {
    final custom = FilterDef(
      id: 'custom-focus',
      name: 'User filter',
      kind: FilterKind.gaussianBlur,
    );
    for (final filter in [custom, FilterService.builtInFilters.firstWhere(
      (f) => f.id == 'Filter0025',
    )]) {
      expect(
        shouldUseImmersiveFilterUi(
          panelOpen: true,
          desktop: true,
          selectedFilter: filter,
        ),
        isTrue,
      );
    }
  });

  test('Closing adjustment restores chrome and desktop catalogue is normal', () {
    final filter = FilterService.builtInFilters.first;
    expect(
      shouldUseImmersiveFilterUi(
        panelOpen: false,
        desktop: true,
        selectedFilter: filter,
      ),
      isFalse,
    );
    expect(
      shouldUseImmersiveFilterUi(
        panelOpen: true,
        desktop: true,
        selectedFilter: null,
      ),
      isFalse,
    );
    expect(
      shouldUseImmersiveFilterUi(
        panelOpen: true,
        desktop: false,
        selectedFilter: null,
      ),
      isTrue,
    );
  });
}
