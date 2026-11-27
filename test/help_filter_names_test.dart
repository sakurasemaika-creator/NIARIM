import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/utils/filter_display_name.dart';

/// The help on drawing filters names each filter as the filter list shows
/// it, in every language, so a filter read about in the help can be found
/// in the list (and by its name in the list's search).
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('${locale.toLanguageTag()}: every drawing filter is named in the '
        'help as in the list', () {
      final l10n = lookupAppLocalizations(locale);
      final names = {
        for (final filter in FilterService.builtInFilters)
          filterDisplayName(l10n, filter),
      };
      expect(names, hasLength(FilterService.builtInFilters.length));
      for (final name in names) {
        expect(l10n.helpDrawingFilterDesc, contains(name), reason: name);
      }
    });
  }

  test('the list\'s search finds a name regardless of case, and anywhere '
      'in it', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(filterNameMatches(l10n.filterNameGaussianBlur, 'blur'), isTrue);
    expect(filterNameMatches(l10n.filterNameGaussianBlur, 'GAUSS'), isTrue);
    expect(filterNameMatches(l10n.filterNameGaussianBlur, ' Blur '), isTrue);
    expect(filterNameMatches(l10n.filterNameGaussianBlur, 'prism'), isFalse);
    expect(filterNameMatches(l10n.filterNameGaussianBlur, ''), isTrue);
  });

  test('the Noise tile is found by the names of its kinds', () {
    // 実際に使ってみたとき（2026-11-27）、「フィルムグレイン」「VHSノイズ」で
    // 探すと「フィルターがありません」だった（どちらもノイズの種類）。
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final noise = FilterService.builtInFilters.singleWhere(
        (f) => f.id == FilterService.genericNoiseFilterId,
      );
      for (final kind in [
        l10n.filterNameNoise,
        l10n.filterNoiseColor,
        l10n.filterNameVhsNoise,
      ]) {
        expect(filterSearchMatches(l10n, noise, kind), isTrue, reason: kind);
      }
      final blur = FilterService.builtInFilters.firstWhere(
        (f) => filterDisplayName(l10n, f) == l10n.filterNameGaussianBlur,
      );
      expect(filterSearchMatches(l10n, blur, l10n.filterNameVhsNoise), isFalse);
    }
  });
}
