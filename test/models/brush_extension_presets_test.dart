import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

Brush _baseBrush({
  String? customImagePath,
  List<String> customImagePaths = const [],
  BrushImageSelectionMode customImageSelectionMode =
      BrushImageSelectionMode.random,
}) => Brush(
  id: 'test',
  name: 'test',
  size: 20,
  opacity: 100,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  customImagePath: customImagePath,
  customImagePaths: customImagePaths,
  customImageSelectionMode: customImageSelectionMode,
);

void main() {
  test('net preset uses lateral repetition and hollow square tip', () {
    final net = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0022');
    expect(net.name, 'ネット');
    expect(net.tipSpacingFactor, .94);
    expect(net.lateralRepeatEnabled, isTrue);
    expect(net.lateralRepeatCount, 4);
    expect(net.tipShape, BrushTipShape.hollowSquare);
  });

  test(
    'wave hair uses the tuned fold defaults and the current palette fill',
    () {
      final hair = brushExtensionPresets().singleWhere(
        (b) => b.id == 'Brush0023',
      );
      expect(hair.name, 'ウェーブヘア（俯瞰）');
      expect(hair.outlineEnabled, isTrue);
      expect(hair.outlineColor, 0xff000000);
      expect(hair.outlineWidth, 1);
      expect(hair.foldEnabled, isTrue);
      expect(hair.foldTriggerAngle, 60);
      expect(hair.foldCurveStartRatio, .25);
      expect(hair.foldAngleRatio, .80);
      expect(hair.foldLengthRatio, .60);
      expect(hair.foldEndTaperRatio, .35);
      expect(hair.fadeIn, FadeEndpointSettings.full);
      expect(hair.fadeOut.rangePx, 165);
      expect(hair.toJson().containsKey('fillColor'), isFalse);
    },
  );

  test('bangs has asymmetric tips without taper or automatic folds', () {
    final bangs = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0024',
    );
    expect(bangs.name, '前髪');
    expect(bangs.customImagePaths.length, greaterThanOrEqualTo(4));
    expect(bangs.customImageSelectionMode, BrushImageSelectionMode.random);
    expect(bangs.outlineEnabled, isTrue);
    expect(bangs.foldEnabled, isFalse);
    expect(bangs.fadeMode, FadeMode.off);
    expect(bangs.pressureOn.size.enabled, isTrue);
    expect(bangs.toJson().containsKey('fillColor'), isFalse);
  });

  test('the five dedicated hair presets keep their fold mode when saved', () {
    final variants = brushExtensionPresets().where(
      (brush) => const {
        'Brush0031',
        'Brush0032',
        'Brush0023',
        'Brush0034',
        'Brush0035',
      }.contains(brush.id),
    );
    expect(variants, hasLength(5));
    expect(
      variants.map((brush) => brush.foldMode).toSet(),
      HairFoldMode.values.toSet(),
    );
    for (final brush in variants) {
      final restored = Brush.fromJson(brush.toJson());
      expect(restored.foldEnabled, isTrue);
      expect(restored.outlineEnabled, isTrue);
      expect(restored.foldMode, brush.foldMode);
    }
  });

  test(
    'ribbons offer every fold mode with flat pressure and red as their start color',
    () {
      final ribbons = brushExtensionPresets().where(
        (brush) => brush.name.startsWith('リボン'),
      );
      expect(ribbons, hasLength(5));
      expect(
        ribbons.map((brush) => brush.foldMode).toSet(),
        HairFoldMode.values.toSet(),
      );
      for (final ribbon in ribbons) {
        final restored = Brush.fromJson(ribbon.toJson());
        expect(restored.foldEnabled, isTrue);
        expect(restored.foldFlatEnds, isTrue);
        expect(restored.fadeMode, FadeMode.off);
        expect(restored.pressureOn.size.enabled, isFalse);
        expect(restored.pressureOn.opacity.enabled, isFalse);
        expect(restored.presetColor, 0xffdb424b);
        expect(restored.outlineWidth, 1);
        expect(restored.foldLengthRatio, .65);
        expect(restored.foldAngleRatio, .70);
        expect(restored.foldCurveStartRatio, .62);
      }
    },
  );

  test('cloud changes tip within the stroke after save and reload', () {
    final cloud = brushExtensionPresets().singleWhere(
      (brush) => brush.id == 'Brush0030',
    );
    expect(cloud.resolvedCustomImagePaths, hasLength(8));
    final flat = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0041',
    );
    expect(cloud.name, '雲');
    expect(flat.name, '雲（ベタ塗り）');
    expect(flat.resolvedCustomImagePaths, cloud.resolvedCustomImagePaths);
    expect(flat.outlineEnabled, isTrue);
    expect(flat.outlineWidth, 1);
    expect(flat.presetColor, isNull);
    expect(
      Brush.fromJson(flat.toJson()).imageInkMode,
      BrushImageInkMode.silhouette,
    );
    expect(
      Brush.fromJson(cloud.toJson()).customImageSelectionMode,
      BrushImageSelectionMode.randomPerStamp,
    );
  });

  test('multiple texture selection survives brush json round trip', () {
    final brush = _baseBrush(
      customImagePaths: const ['a.png', 'b.png', 'c.png'],
      customImageSelectionMode: BrushImageSelectionMode.sequential,
    );
    final restored = Brush.fromJson(brush.toJson());
    expect(restored.customImagePaths, const ['a.png', 'b.png', 'c.png']);
    expect(
      restored.customImageSelectionMode,
      BrushImageSelectionMode.sequential,
    );
  });

  test('legacy single custom image remains available as one texture', () {
    final restored = Brush.fromJson(
      _baseBrush(customImagePath: 'legacy.png').toJson(),
    );
    expect(restored.customImagePath, 'legacy.png');
    expect(restored.resolvedCustomImagePaths, const ['legacy.png']);
  });

  test('extension preset ids are unique', () {
    final ids = brushExtensionPresets().map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
