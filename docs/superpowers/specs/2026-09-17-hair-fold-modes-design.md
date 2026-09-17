# Hair fold modes and fringe preset design

## Scope

This approved design extends the existing brush repetition/outline/fold task. It does not restart or modify the audit route. Work remains on `dev_branch` only. Existing Task 5 ruler snap persistence and Task 6 visual/performance/delivery requirements remain mandatory.

## Fold detection versus fold shape

Keep `ScreenSpaceFoldDetector` responsible only for deciding that a meaningful fold exists. It continues to use logical screen/local movement, smoothed cumulative turn, minimum travel, bounded samples, jitter rejection and distance-based cooldown/hysteresis. Document/canvas coordinates remain responsible for generated geometry.

Replace the old configurable Y-ray shape with an inward hair-fold shape derived from the actual stroke. Left and right bends must both use the computed inward side. The generated fold follows the local inner edge/tangent/curvature instead of a user-selected branch angle.

## Straight mode

Straight is the default fold mode. Its user-facing geometry controls are ratios, not fixed canvas pixels:

- `foldCurveStartRatio`: curve-start position as a percentage of effective brush width. This controls where the fold line begins transitioning from its initial extension into the terminal curve.
- `foldDepthRatio`: inward depth as a percentage of effective brush width. This moves the target depth across the hair bundle as illustrated by the approved purple guide.
- `foldLengthRatio`: total fold-line length as a percentage of effective brush width, corresponding to the approved green traced segment.
- `foldEndTaperRatio`: terminal taper range as a percentage of generated fold length.

The old user-facing Y branch angle and Y branch width controls are removed from the fold settings. Fold line thickness is not independently configurable; it uses the brush outline width so the mark reads as a continuation of the outline rather than a third stroke style.

Geometry should be a smooth curve (prefer a cubic Bezier or equivalent sampled spline) whose initial tangent is continuous with the local inward edge. The terminal section bends using the source stroke's local signed curvature. Do not construct a straight ray followed by a discontinuous circular arc. Clamp ratios to practical ranges and use the pressure/fade-resolved effective width at the fold event.

## Wave mode

Wave mode is an optional terminal treatment layered on the same inward fold path. The fold remains Straight by default.

- `foldWaveEndRatio`: percentage measured from the fold endpoint backward that is rendered as wave. `0%` means fully Straight; intermediate values produce a Straight-to-Wave mix; `100%` makes the whole eligible fold section Wave.
- `foldWaveTriggerAngle`: smoothed cumulative stroke turn required before crescent/wave lobes are emitted. This is not an adjacent-event angle test.

The wave section consists of alternating crescent-like curved lobes attached along the inward path. Their orientation follows local tangent/normal and alternates sides along the path. Sampling is distance/arc-length based so event density does not alter the result. The transition at the Straight/Wave boundary must be tangent-continuous and visually smooth.

## Model and compatibility

Introduce a fold mode enum with Straight as the default and persist the new ratios in Brush JSON, copyWith, duplication, project persistence and `.niabrush` import/export. Existing development data without these fields uses safe Straight defaults. Existing legacy Y fields may be accepted on read while current writes use the new fold fields; no large migration framework is required because NIARIM is pre-release.

Do not store the fill/current color in Brush. Outline color remains brush-local and defaults to black.

## Hair preset

Update the built-in Hair preset to use outline + fold + pressure/taper with Straight mode by default. Tune curve-start, depth, length and taper from production captures. Validate thin/medium/thick widths, weak/strong pressure, left/right/S bends, near-threshold and sharp bends, repeated bends, Straight, Wave and mixed Straight/Wave.

## Fringe preset

Add a separate built-in `前髪` (Fringe/Bangs) preset. This is a preset request, not permission for an unrelated global subsystem. Prefer existing brush/tip/texture capabilities. Its terminal edge should read as almost flat with small, soft, irregular low-frequency notches rather than regular saw teeth. Any deterministic procedural variation must be bounded and stable enough for repeatable tests/captures. Allocate a non-colliding built-in brush ID and cover it in preset/IO tests.

## UI and localization

Within the existing Fold section, show Straight as the default mode. Replace Y-angle/Y-width controls with curve start %, depth %, length % and endpoint taper %. Add Wave controls for endpoint wave ratio % and wave trigger angle. Preserve dependency rules: Fold only when Outline is enabled; fold details only when Fold is enabled. Keep narrow-phone layouts overflow-safe and use AppLocalizations for all supported locales.

## Ruler Task 5 remains required

Complete independent project-level `rulerSnapEnabled` persistence, archive round-trip, panel Switch, all seven ruler types, OFF-visible/editable ruler behavior, OFF free drawing, re-ON reuse, ruler-kind changes preserving OFF, and real pointer-path integration.

## Delivery Task 6 remains required

Production UI capture tests and runtime evidence must cover Net, outline picker/eyedropper, updated Hair Straight/Wave/mixed folds, Fringe, and ruler snap ON/OFF. Measure feature-OFF baseline and bounded long-stroke memory. Update Help/Tips/brush/ruler specifications and all supported locales. Run affected regressions, format and analyze. Android/emulator checks must be performed when the environment provides one; otherwise report them explicitly as unverified rather than successful.
