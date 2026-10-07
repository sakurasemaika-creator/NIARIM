import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The settings added to the drawing filters (tone curve points per
/// channel, levels per channel and gamma, the fisheye's centre and radius,
/// chromatic aberration's X/Y/Z, the ink pool's width, the outline's reach,
/// sphere shading, the anime line width and the cathode-ray tube) survive
/// being saved and loaded: through FilterDef's JSON, and through
/// FilterService's storage as the panel changes them.
void main() {
  test('every new filter setting survives a JSON round trip', () {
    const def = FilterDef(
      id: 'custom-all',
      name: 'All settings',
      kind: FilterKind.toneCurve,
      inputBlack: 12,
      inputWhite: 230,
      inputGamma: 1.7,
      outputBlack: 5,
      outputWhite: 240,
      levelsRed: [10, 250, 0.8, 0, 255],
      levelsGreen: [0, 240, 1.3, 4, 250],
      levelsBlue: [20, 255, 2.2, 10, 245],
      toneCurvePreset: ToneCurvePreset.highContrast,
      toneCurvePoints: [0, 0, 0.3, 0.2, 0.7, 0.9, 1, 1],
      toneCurveRedPoints: [0, 0.1, 0.5, 0.6, 1, 1],
      toneCurveGreenPoints: [0, 0, 0.4, 0.3, 1, 0.9],
      toneCurveBluePoints: [0, 0.2, 1, 0.8],
      outlineColor: 0xFF123456,
      outlineWidth: 17,
      outlineErosion: 63,
      fisheyeRadius: 42,
      fisheyeCenterX: -18,
      fisheyeCenterY: 27,
      chromaticShiftX: -40,
      chromaticShiftY: 55,
      chromaticShiftZ: 80,
      inkPoolColor: 0xFF201010,
      inkPoolRange: 23,
      inkPoolCenterWidth: 9,
      animeLineWidth: 3,
      crtAberration: 61,
      crtBleed: 33,
      sphereShadowColor: 0x80102030,
      sphereLightColor: 0x70F0E0D0,
      sphereShadowBlend: LayerBlendMode.colorBurn,
      sphereLightBlend: LayerBlendMode.linearDodge,
      sphereCombined: true,
      sphereCombinedBlend: LayerBlendMode.softLight,
      sphereLightX: 31,
      sphereLightY: 64,
      sphereLightWidth: 47,
      sphereLightHeight: 22,
      sphereLightBlur: 71,
      sphereShadowBlur: 13,
    );
    final restored = FilterDef.fromJson(def.toJson());

    expect(restored.inputGamma, 1.7);
    expect(restored.levelsRed, orderedEquals(def.levelsRed));
    expect(restored.levelsGreen, orderedEquals(def.levelsGreen));
    expect(restored.levelsBlue, orderedEquals(def.levelsBlue));
    expect(restored.toneCurvePreset, ToneCurvePreset.highContrast);
    expect(restored.toneCurvePoints, orderedEquals(def.toneCurvePoints));
    expect(restored.toneCurveRedPoints, orderedEquals(def.toneCurveRedPoints));
    expect(
      restored.toneCurveGreenPoints,
      orderedEquals(def.toneCurveGreenPoints),
    );
    expect(
      restored.toneCurveBluePoints,
      orderedEquals(def.toneCurveBluePoints),
    );
    expect(restored.outlineColor, 0xFF123456);
    expect(restored.outlineWidth, 17);
    expect(restored.outlineErosion, 63);
    expect(restored.fisheyeRadius, 42);
    expect(restored.fisheyeCenterX, -18);
    expect(restored.fisheyeCenterY, 27);
    expect(restored.chromaticShiftX, -40);
    expect(restored.chromaticShiftY, 55);
    expect(restored.chromaticShiftZ, 80);
    expect(restored.inkPoolColor, 0xFF201010);
    expect(restored.inkPoolRange, 23);
    expect(restored.inkPoolCenterWidth, 9);
    expect(restored.animeLineWidth, 3);
    expect(restored.crtAberration, 61);
    expect(restored.crtBleed, 33);
    expect(restored.sphereShadowColor, 0x80102030);
    expect(restored.sphereLightColor, 0x70F0E0D0);
    expect(restored.sphereShadowBlend, LayerBlendMode.colorBurn);
    expect(restored.sphereLightBlend, LayerBlendMode.linearDodge);
    expect(restored.sphereCombined, isTrue);
    expect(restored.sphereCombinedBlend, LayerBlendMode.softLight);
    expect(restored.sphereLightX, 31);
    expect(restored.sphereLightY, 64);
    expect(restored.sphereLightWidth, 47);
    expect(restored.sphereLightHeight, 22);
    expect(restored.sphereLightBlur, 71);
    expect(restored.sphereShadowBlur, 13);
    // Nothing else is lost or changed either.
    expect(restored.toJson(), def.toJson());
  });

  test('settings changed in the panel are there after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final before = FilterService();
    await before.init();
    String idOf(FilterKind kind) =>
        before.filters.firstWhere((f) => f.kind == kind).id;

    final edits = <String, void Function(String id)>{
      idOf(FilterKind.toneCurve): (id) => before.updateFilterParams(
        id,
        toneCurvePoints: const [0, 0, 0.25, 0.4, 1, 1],
        toneCurveRedPoints: const [0, 0.1, 1, 0.9],
        toneCurveGreenPoints: const [0, 0, 0.6, 0.3, 1, 1],
        toneCurveBluePoints: const [0, 0.2, 1, 1],
      ),
      idOf(FilterKind.levels): (id) => before.updateFilterParams(
        id,
        inputGamma: 0.6,
        levelsRed: const [5, 250, 1.4, 0, 255],
        levelsGreen: const [0, 255, 0.7, 10, 245],
        levelsBlue: const [0, 200, 1, 0, 255],
      ),
      idOf(FilterKind.fisheye): (id) => before.updateFilterParams(
        id,
        fisheyeRadius: 37,
        fisheyeCenterX: 21,
        fisheyeCenterY: -33,
      ),
      idOf(FilterKind.chromaticAberration): (id) => before.updateFilterParams(
        id,
        chromaticShiftX: -25,
        chromaticShiftY: 60,
        chromaticShiftZ: -90,
      ),
      idOf(FilterKind.inkPool): (id) => before.updateFilterParams(
        id,
        inkPoolRange: 18,
        inkPoolCenterWidth: 7,
      ),
      idOf(FilterKind.outline): (id) =>
          before.updateFilterParams(id, outlineWidth: 11, outlineErosion: 45),
      FilterService.sphereShadingFilterId: (id) => before.updateFilterParams(
        id,
        sphereLightColor: 0x66FFEEDD,
        sphereLightBlend: LayerBlendMode.screen,
        sphereLightX: 70,
        sphereLightY: 25,
        sphereLightWidth: 30,
        sphereLightHeight: 55,
        sphereLightBlur: 40,
        sphereShadowBlur: 60,
      ),
    };
    final expected = <String, Map<String, dynamic>>{};
    for (final MapEntry(key: id, value: edit) in edits.entries) {
      final untouched = before.filters.firstWhere((f) => f.id == id).toJson();
      edit(id);
      final changed = before.filters.firstWhere((f) => f.id == id).toJson();
      expect(changed, isNot(untouched), reason: 'the edit changes $id');
      expected[id] = changed;
    }
    // The service saves in the background.
    await Future<void>.delayed(Duration.zero);

    final after = FilterService();
    await after.init();
    for (final MapEntry(key: id, value: json) in expected.entries) {
      expect(
        after.filters.firstWhere((f) => f.id == id).toJson(),
        json,
        reason: '$id after a restart',
      );
    }
  });
}
