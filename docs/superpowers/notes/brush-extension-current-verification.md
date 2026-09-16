# Brush extension current verification

This ordinary-task note records only the implementation checkpoint for the approved brush extension work. It is not audit state.

## Implemented source pieces

- `Brush` already contains repeat, outline, fold, Y-ratio and tip-shape persistence fields.
- Pure geometry contains centered lateral offsets, local-normal centers, bounded screen-space sampling, minimum travel, cooldown, inward fold events, effective-width Y ratios and smooth endpoint taper.
- Canonical approved constants live in `brush_extension_defaults.dart`.
- Net (`Brush0022`) and Hair (`Brush0023`) definitions live in `brush_presets_extension.dart`, ready to be appended to BrushService built-ins once the production renderer consumes their fields.
- Coverage-only outline composition is isolated in `outlined_stroke_compositor.dart`: fill union removes internal outline seams and fold marks are clipped to fill.
- Focused tests exist for model contracts, canonical defaults, geometry, presets and outline coverage composition.

## Known RED / integration work

- The main `Brush` constructor still has stale defaults `outlineWidth=1.0` and `yBranchWidthRatio=.12`; approved values are 1.5 and .08. `brush_extension_defaults_test.dart` intentionally catches this until the model source is corrected.
- BrushService does not yet append `brushExtensionPresets()` to `_defaultBrushes()`.
- DrawingEngine/InputHandler do not yet consume lateral repeat, outline coverage, screen-space fold detector or hollow-square tip.
- Details UI/targeted outline eyedropper and ruler snap persistence are not implemented yet.
- Flutter tests/analyze/format have NOT been executed in the current environment. No green claim is made.

## Next

Correct the model defaults and wire presets into BrushService, then integrate the pure geometry/compositor into the production raster/input path before exposing UI. Do not mark Task 1 or Task 3 complete until focused tests can actually run.
