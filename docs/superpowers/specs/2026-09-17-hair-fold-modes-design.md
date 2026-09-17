# Hair fold modes and fringe preset design

## Scope

This approved design extends the existing brush repetition/outline/fold task. It does not restart or modify the audit route. Work remains on `dev_branch` only. Existing Task 5 ruler snap persistence and Task 6 visual/performance/delivery requirements remain mandatory.

## Fold detection versus fold shape

Keep `ScreenSpaceFoldDetector` responsible only for deciding that a meaningful fold exists. It continues to use logical screen/local movement, smoothed cumulative turn, minimum travel, bounded samples, jitter rejection and distance-based cooldown/hysteresis. Document/canvas coordinates remain responsible for generated geometry.

Replace the old configurable Y-ray shape with an inward hair-fold shape derived from the actual stroke. Left and right bends must both use the computed inward side. The generated fold follows the local inner edge/tangent/curvature instead of a user-selected branch angle.

## Straight geometry

The fold shape has these user-facing ratios, never fixed canvas pixels:

- `foldCurveStartRatio`: curve-start position as a percentage of effective brush width. This controls where the fold line begins transitioning from its initial extension into the terminal curve.
- `foldDepthRatio`: inward depth as a percentage of effective brush width. This moves the target depth across the hair bundle as illustrated by the approved purple guide.
- `foldLengthRatio`: total fold-line length as a percentage of effective brush width, corresponding to the approved green traced segment.
- `foldEndTaperRatio`: terminal taper range as a percentage of generated fold length.

The old user-facing Y branch angle and Y branch width controls are removed. Fold line thickness is not independently configurable; it uses the brush outline width so the mark reads as a continuation of the outline rather than a third stroke style.

Geometry should be a smooth curve (prefer a cubic Bezier or equivalent sampled spline) whose initial tangent is continuous with the local inward edge. The terminal section bends using the source stroke's local signed curvature. Do not construct a straight ray followed by a discontinuous circular arc. Clamp ratios to practical ranges and use the pressure/fade-resolved effective width at the fold event.

## Wave amount

There is no separate Straight/Mixed/Wave mode selector. Fold has one continuous `foldWaveEndRatio` slider from 0% to 100%:

- `0%`: fully Straight. This is the default whenever a user enables Fold on an ordinary/custom brush.
- intermediate values: the initial section stays Straight and the endpoint-side percentage becomes Wave.
- `100%`: the whole eligible fold section is Wave.

`foldWaveTriggerAngle` controls the smoothed cumulative stroke turn required before crescent/wave lobes are emitted. It is not an adjacent-event angle test.

The wave section consists of alternating crescent-like curved lobes attached along the inward path. Their orientation follows local tangent/normal and alternates sides along the path. Sampling is distance/arc-length based so event density does not alter the result. The transition at the Straight/Wave boundary must be tangent-continuous and visually smooth.

## Model and compatibility

Persist `foldCurveStartRatio`, `foldDepthRatio`, `foldLengthRatio`, `foldEndTaperRatio`, `foldWaveEndRatio`, and `foldWaveTriggerAngle` through Brush JSON, copyWith, duplication, project persistence and `.niabrush` import/export. A separate fold-mode enum is intentionally unnecessary: the wave percentage fully expresses Straight, mixed, and Wave states. Existing development data without these fields uses safe defaults with `foldWaveEndRatio = 0.0`. Existing legacy Y fields may be accepted on read while current writes use the new fold fields; no large migration framework is required because NIARIM is pre-release.

Do not store the fill/current color in Brush. Outline color remains brush-local and defaults to black.

## Hair preset

Update the built-in Hair preset to use outline + fold + pressure/taper. Its default wave amount is 30%, producing the approved 7:3 Straight:Wave balance. Tune curve-start, depth, length, taper and wave trigger from production captures. Validate thin/medium/thick widths, weak/strong pressure, left/right/S bends, near-threshold and sharp bends, repeated bends, 0% Straight, 30% preset default, intermediate values and 100% Wave.

## Fringe preset

Add a separate built-in `前髪` (Fringe/Bangs) preset. Its default fold wave amount is 0% (fully Straight). This is a preset request, not permission for an unrelated global subsystem. Prefer existing brush/tip/texture capabilities. Its terminal edge should read as almost flat with small, soft, irregular low-frequency notches rather than regular saw teeth. Any deterministic procedural variation must be bounded and stable enough for repeatable tests/captures. Allocate a non-colliding built-in brush ID and cover it in preset/IO tests.

## UI and localization

Within the existing Fold section, do not show a mode selector. Replace Y-angle/Y-width controls with curve start %, depth %, length % and endpoint taper %. Add a single Wave amount slider (`foldWaveEndRatio`) plus wave trigger angle. New/custom brushes default to Wave 0%; moving the slider alone continuously produces any Straight/Wave mix. Preserve dependency rules: Fold only when Outline is enabled; fold details only when Fold is enabled. Keep narrow-phone layouts overflow-safe and use AppLocalizations for all supported locales.

## Ruler Task 5 remains required

Complete independent project-level `rulerSnapEnabled` persistence, archive round-trip, panel Switch, all seven ruler types, OFF-visible/editable ruler behavior, OFF free drawing, re-ON reuse, ruler-kind changes preserving OFF, and real pointer-path integration.

## Delivery Task 6 remains required

Production UI capture tests and runtime evidence must cover Net, outline picker/eyedropper, updated Hair at 0/30/intermediate/100% wave, Fringe at 0%, and ruler snap ON/OFF. Measure feature-OFF baseline and bounded long-stroke memory. Update Help/Tips/brush/ruler specifications and all supported locales. Run affected regressions, format and analyze. Android/emulator checks must be performed when the environment provides one; otherwise report them explicitly as unverified rather than successful.
