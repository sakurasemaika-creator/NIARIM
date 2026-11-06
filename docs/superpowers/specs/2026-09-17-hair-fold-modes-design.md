# Hair fold modes and fringe preset design

## Scope

This approved design extends the existing brush repetition/outline/fold task. It does not restart or modify the audit route. Work remains on `dev_branch` only. Existing ruler snap persistence and visual/performance/delivery requirements remain mandatory.

## Fold detection versus fold shape

Keep `ScreenSpaceFoldDetector` responsible only for deciding that a meaningful fold exists. It continues to use logical screen/local movement, smoothed cumulative turn, minimum travel, bounded samples, jitter rejection and distance-based cooldown/hysteresis. Document/canvas coordinates remain responsible for generated geometry.

Replace the old configurable Y-ray shape with an inward hair-fold shape derived from the actual stroke. Left and right bends must both use the computed inward side. The generated fold follows the local inner edge/tangent/curvature instead of a user-selected branch angle.

## Straight geometry

The fold shape has these user-facing ratios, never fixed canvas pixels:

- `foldCurveStartRatio`: curve-start position as a percentage of effective brush width.
- `foldDepthRatio`: inward depth as a percentage of effective brush width.
- `foldLengthRatio`: total fold-line length as a percentage of effective brush width.
- `foldEndTaperRatio`: terminal taper range as a percentage of generated fold length.

The old user-facing Y branch angle and Y branch width controls are removed. Fold line thickness is not independently configurable; it uses the brush outline width. Geometry is a smooth curve whose initial tangent is continuous with the local inward edge and whose terminal bend follows the source stroke's signed local curvature. Use the pressure/fade-resolved effective width at the fold event.

## Wave toggle and endpoint range

Wave is an explicit dependent option under Fold:

- `foldWaveEnabled`: OFF by default for ordinary/custom brushes. When OFF, wave-specific controls are hidden/disabled and rendering remains Straight even if stored wave values are non-zero.
- `foldWaveEndRatio`: user-facing label means **"終点からウェーブにする範囲 %"**. It selects what percentage of the eligible fold region, measured backward from the stroke endpoint, becomes Wave.
- `foldWaveTriggerAngle`: smoothed cumulative stroke turn required before a curve is eligible to form a crescent. It is not an adjacent-event angle test.

Turning Wave OFF does not erase its stored percentage/angle, so turning it back ON restores the user's settings.

## Crescent wave geometry

Wave is not a thin sinusoidal line or a sequence of stamped symbols. It is a continuous outlined hair-bundle silhouette made from connected crescent sections derived from successive stroke curves.

For each eligible curve apex, resolve the pressure/fade-adjusted effective brush width at that apex. That effective brush width is the **maximum thickness of the crescent at its widest part**. Therefore normal brush pressure/taper behavior directly narrows later crescents toward a tapered stroke endpoint.

For two consecutive eligible curve apexes, find the halfway point by **arc length along the source stroke**, not by coordinate midpoint. This arc-length midpoint is the seam where the two neighboring crescent sections meet/close. Crescent sides must meet continuously at that seam without holes or double-thick overlap.

The first eligible curve is special: do **not** create a standalone crescent for it. Keep the incoming segment as the ordinary pen/hair bundle, and use the first curve only to form the closing transition that connects that ordinary segment into the crescent associated with the second eligible curve. Thus a stable crescent sequence requires at least two eligible curve apexes.

As successive curve signs alternate, crescent bulges alternate with the stroke's local curvature. All placement is arc-length/tangent/normal based so event density and canvas zoom do not determine the shape. The Straight-to-Wave boundary must be tangent-continuous.

## Model and compatibility

Persist `foldCurveStartRatio`, `foldDepthRatio`, `foldLengthRatio`, `foldEndTaperRatio`, `foldWaveEnabled`, `foldWaveEndRatio`, and `foldWaveTriggerAngle` through Brush JSON, copyWith, duplication, project persistence and `.niabrush` import/export. Existing development data without these fields uses safe defaults: Wave OFF and endpoint range 0.0. Existing legacy Y fields may be accepted on read while current writes use the new fold fields; no large migration framework is required because NIARIM is pre-release.

Do not store the fill/current color in Brush. Outline color remains brush-local and defaults to black.

## Hair preset

Update built-in Hair to use outline + fold + pressure/taper with Wave ON and `foldWaveEndRatio = 0.30`, producing the approved 7:3 Straight:Wave balance. Tune curve-start, depth, length, taper and wave trigger from production captures. Validate thin/medium/thick widths, weak/strong pressure, left/right/S bends, repeated bends and crescent seam continuity.

## Fringe preset

Add a separate built-in `前髪` (Fringe/Bangs) preset with Wave OFF. Prefer existing brush/tip/texture capabilities. Its terminal edge should read as almost flat with small, soft, irregular low-frequency notches rather than regular saw teeth. Any deterministic procedural variation must be bounded and stable enough for repeatable tests/captures. Allocate a non-colliding built-in brush ID and cover it in preset/IO tests.

## UI and localization

Within Fold, replace Y-angle/Y-width controls with curve start %, depth %, length % and endpoint taper %. Add a Wave ON/OFF toggle. Only while Wave is ON show `終点からウェーブにする範囲 %` and wave trigger angle. Ordinary/custom brushes default Wave OFF; Hair defaults ON/30%; Fringe defaults OFF. Preserve dependency rules: Fold only when Outline is enabled; fold details only when Fold is enabled. Keep narrow-phone layouts overflow-safe and use AppLocalizations for all supported locales.

## Ruler Task remains required

Complete independent project-level `rulerSnapEnabled` persistence, archive round-trip, panel Switch, all seven ruler types, OFF-visible/editable ruler behavior, OFF free drawing, re-ON reuse, ruler-kind changes preserving OFF, and real pointer-path integration.

## Delivery remains required

Production UI capture tests and runtime evidence must cover Net, outline picker/eyedropper, Hair Straight plus Wave ON at 30% and other endpoint ranges, crescent maximum-width/taper behavior, first-curve transition, arc-length seams, Fringe Wave OFF, and ruler snap ON/OFF. Measure feature-OFF baseline and bounded long-stroke memory. Update Help/Tips/brush/ruler specifications and all supported locales. Run affected regressions, format and analyze. Android/emulator checks must be performed when the environment provides one; otherwise report them explicitly as unverified rather than successful.
