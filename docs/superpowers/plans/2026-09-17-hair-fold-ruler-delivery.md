# Hair Fold Modes, Ruler Persistence and Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace configurable Y-ray folds with stroke-derived Straight/Wave hair folds, add the Fringe preset, and finish ruler snap persistence plus visual/performance/delivery requirements.

**Architecture:** Preserve the existing screen-space fold detector and tile renderer fast path, but separate fold detection from a new document-space fold-path builder. Persist Straight/Wave brush configuration through the existing Brush lifecycle and keep ruler snap as an independent Project preference. Validate through focused geometry/model/UI/archive tests before production-widget captures and runtime checks.

**Tech Stack:** Dart / Flutter 3.47.3, existing NIARIM DrawingEngine/TileManager, AppLocalizations, existing project and `.niabrush` serializers.

**Spec:** `docs/superpowers/specs/2026-09-17-hair-fold-modes-design.md`

## Global Constraints

- Work on `dev_branch` only; do not modify main, audit Route/State/Policy, or create extra branches.
- Preserve feature-OFF drawing fast paths; no whole-canvas scan per PointerEvent and no unbounded stroke history.
- Fold detection remains logical screen/local-space and distance-based; generated geometry remains document/canvas-space.
- Fold line color is outline color and fold line thickness uses outline width; no third global color and no independent fold-width control.
- Existing development data without new fields must load with safe Straight defaults; no large migration framework.
- Task 5 and Task 6 from the original approved plan remain completion requirements.

---

### Task 1: Replace legacy Y configuration with Straight/Wave Brush lifecycle

**Files:**
- Modify: `lib/models/brush.dart`
- Modify: `lib/services/brush_service.dart`
- Modify: existing `.niabrush` import/export lifecycle files discovered from BrushService
- Test: existing Brush model/lifecycle/import-export tests

**Interfaces:**
- Produces: `FoldMode.straight`, `FoldMode.wave`; Brush fields `foldCurveStartRatio`, `foldDepthRatio`, `foldLengthRatio`, `foldEndTaperRatio`, `foldWaveEndRatio`, `foldWaveTriggerAngle`.
- Compatibility: missing fields load Straight safe defaults; legacy Y fields may be read but are no longer current UI controls.

- [ ] **Step 1: Add RED lifecycle tests** for defaults, clamp/finite handling, `copyWith`, JSON round-trip, duplication, persistence and `.niabrush` round-trip. Assert old-field absence does not enable fold and current writes preserve all six new values.
- [ ] **Step 2: Run the focused lifecycle tests** with `flutter test <affected-test-files> --reporter expanded`; verify failures identify missing new fields/mode.
- [ ] **Step 3: Implement the model and serializer fields** with Straight default, bounded ratios, finite-value guards and compatibility reads. Do not add a stored fill color.
- [ ] **Step 4: Update built-in Hair** to use the new Straight configuration while retaining outline black, current-color fill, pressure sizing and taper.
- [ ] **Step 5: Run lifecycle/preset/import regressions** and `dart format` on touched files; require GREEN before commit.
- [ ] **Step 6: Commit** `feat: add straight and wave hair fold settings`.

### Task 2: Build stroke-derived Straight fold geometry

**Files:**
- Modify: `lib/engine/brush_stroke_geometry.dart`
- Modify/Create: focused geometry helper only if the existing file becomes unwieldy
- Test: `test/engine/brush_stroke_geometry_test.dart` or its current equivalent

**Interfaces:**
- Consumes: existing `FoldEvent(sample,tangent,inwardNormal,signedTurnRadians,screenDistance)` and effective width.
- Produces: a sampled/Bezier fold path with per-sample tangent and taper; curve start/depth/length are effective-width ratios.

- [ ] **Step 1: Add RED geometry tests** for left/right bends, tangent continuity at the branch, curve-start ratio moving the bend onset, depth ratio moving the inward target, length ratio scaling with effective width, pressure-resolved width, taper 0/mid/100, and no outward fold.
- [ ] **Step 2: Run focused geometry tests** and verify RED against the current Y-ray builder.
- [ ] **Step 3: Implement Straight path generation** from the local inward edge using a cubic Bezier or equivalently smooth sampled spline. Keep the initial tangent continuous, derive terminal bending from signed local curvature, and arc-length sample the result.
- [ ] **Step 4: Remove renderer dependence on user Y branch angle/width**; fold stroke thickness resolves from outline width and fold color from outline color.
- [ ] **Step 5: Run geometry plus DrawingEngine raster tests**, then format/analyze touched engine files.
- [ ] **Step 6: Commit** `feat: render stroke-derived straight hair folds`.

### Task 3: Add Wave and mixed Straight/Wave geometry

**Files:**
- Modify: fold geometry helper(s)
- Modify: `lib/engine/drawing_engine.dart`
- Test: geometry and raster tests

**Interfaces:**
- Consumes: Straight base path and `foldWaveEndRatio`, `foldWaveTriggerAngle`.
- Produces: alternating crescent-like lobes along the eligible terminal arc-length range.

- [ ] **Step 1: Add RED tests**: 0% wave equals Straight; 100% covers the eligible fold; 40–60% preserves a Straight prefix and Wave suffix; below trigger angle emits no lobes; above trigger emits alternating inward-path lobes; event-density changes produce equivalent lobe placement.
- [ ] **Step 2: Run focused tests** and verify current implementation fails these Wave cases.
- [ ] **Step 3: Implement arc-length-based Wave sampling** with alternating local normal sign and smooth crescent curves. Blend the first lobe tangent continuously from the Straight prefix.
- [ ] **Step 4: Integrate Wave into DrawingEngine** without adding work when Fold is disabled and without unbounded history.
- [ ] **Step 5: Run geometry/raster/input regressions**, format and analyze.
- [ ] **Step 6: Commit** `feat: add wave and mixed hair fold rendering`.

### Task 4: Update fold UI and all locales

**Files:**
- Modify: `lib/screens/canvas/widgets/brush_extension_settings.dart`
- Modify: `lib/screens/canvas/widgets/brush_panel.dart`
- Modify: all supported `lib/l10n/app_*.arb`
- Test: existing brush extension UI tests plus narrow-layout test

**Interfaces:**
- Shows: mode, curve start %, depth %, length %, endpoint taper %, wave endpoint ratio %, wave trigger angle.
- Removes from current UI: Y branch angle and Y branch width.

- [ ] **Step 1: Add RED UI tests** for dependency visibility, Straight default, Wave-only controls, percent labels, slider bounds and narrow-phone overflow.
- [ ] **Step 2: Run UI tests** and verify RED.
- [ ] **Step 3: Replace legacy Y controls** with the approved controls, reusing existing editable sliders/sections and preserving Outline→Fold dependency behavior.
- [ ] **Step 4: Add translations to every supported ARB** and regenerate localization output through the project-standard Flutter generation path.
- [ ] **Step 5: Run UI/localization tests and analyze**, then format.
- [ ] **Step 6: Commit** `feat: expose straight and wave fold controls`.

### Task 5: Add the Fringe/Bangs built-in preset

**Files:**
- Modify: `lib/services/brush_service.dart`
- Modify only existing tip/texture definitions if required to express the approved soft irregular terminal edge
- Test: preset/model/IO tests

**Interfaces:**
- Produces: one non-colliding built-in Fringe/Bangs brush ID.

- [ ] **Step 1: Add RED preset tests** for unique ID, built-in registration, persistence/import retention and deterministic bounded irregularity where applicable.
- [ ] **Step 2: Run preset tests** and verify missing preset failure.
- [ ] **Step 3: Implement Fringe using existing brush/tip/texture mechanisms where possible**: nearly flat terminal edge plus low-frequency small soft irregular notches, avoiding regular saw teeth.
- [ ] **Step 4: Run preset/IO plus existing built-in brush regressions**.
- [ ] **Step 5: Commit** `feat: add fringe hair brush preset`.

### Task 6: Finish independent ruler snap Project persistence

**Files:**
- Modify: `lib/models/project.dart`
- Modify: `lib/services/project_service.dart`
- Modify: `lib/engine/niapro_serializer.dart`
- Modify: `lib/engine/ruler_engine.dart`
- Modify: `lib/screens/canvas/widgets/ruler_panel.dart`
- Modify: `lib/screens/canvas/canvas_screen.dart`
- Modify: `lib/screens/canvas/widgets/canvas_area.dart` as needed
- Test: ruler engine/panel/project/archive tests

**Interfaces:**
- Project: `rulerSnapEnabled=true` independent from ruler geometry/type.
- Service: project ruler/snap update methods following existing persistence conventions.
- Panel: explicit Switch; Canvas: same ruler visible/editable while OFF.

- [ ] **Step 1: Add RED tests** for missing-field default true, archive round-trip, all seven ruler types OFF→unchanged input, ruler retained/displayed/editable while OFF, re-ON reuse, and kind changes preserving OFF.
- [ ] **Step 2: Run focused ruler/project/archive tests** and verify RED gaps.
- [ ] **Step 3: Implement Project and archive persistence** for independent snap state, preserving existing geometry persistence and avoiding ZIP writes during live handle movement.
- [ ] **Step 4: Wire panel Switch and root/CanvasArea** so OFF bypasses constraint but does not delete/hide ruler; re-ON restores constraint to the same ruler.
- [ ] **Step 5: Add real PointerEvent integration coverage** for ON/OFF/re-ON and kind change.
- [ ] **Step 6: Run all ruler/project/archive regressions**, format and analyze.
- [ ] **Step 7: Commit** `feat: persist ruler snap independently`.

### Task 7: Production visual captures and tuning

**Files:**
- Create/Modify: `test/visual/brush_extension_operation_capture_test.dart`
- Modify: Hair/Fringe defaults only when capture evidence requires tuning
- Save: project-standard capture artifacts

**Interfaces:**
- Uses production UI and actual pointer strokes, not a synthetic geometry-only preview.

- [ ] **Step 1: Add production capture cases** for Net horizontal/vertical/diagonal/gentle/sharp curves and 1/multiple/10 columns; outline picker/eyedropper; Hair thin/medium/thick, weak/strong pressure, left/right/S/near-threshold/sharp/repeated bends, Straight, Wave, mixed; Fringe; ruler ON/OFF/re-ON and visible ruler while OFF.
- [ ] **Step 2: Run capture tests** and inspect the produced images; do not declare visual success from test exit code alone.
- [ ] **Step 3: Tune Hair Straight/Wave defaults and Fringe edge softness** only from observed production output, then rerun captures.
- [ ] **Step 4: Commit** `test: capture hair folds fringe and ruler snap`.

### Task 8: Performance, Help/Tips/specs, full regression and delivery

**Files:**
- Modify: existing Help/Tips content for brush/ruler features
- Modify: ordinary brush/ruler specifications only in relevant sections
- Modify: all supported locales for user-visible additions
- Test: affected suite and project-required validation

**Interfaces:**
- Completion evidence includes commands, results, captures, performance measurements, SHA and explicit unverified runtime checks.

- [ ] **Step 1: Measure feature-OFF baseline and enabled paths** on small/large canvases and varied event densities; verify bounded detector/history memory on a long stroke. Record measurements without claiming phone FPS from Linux.
- [ ] **Step 2: Update Help/Tips/specs** for lateral repeat, Net, outline color/current fill, outline picker/eyedropper, Straight/Wave fold controls, Hair, Fringe and ruler snap OFF-visible behavior.
- [ ] **Step 3: Check available Android emulator/device/runtime** and perform actual app drawing checks when available. If unavailable, record `未検証` explicitly.
- [ ] **Step 4: Run affected and existing regressions**, localization generation, `dart format --output=none --set-exit-if-changed` on touched Dart, and AGENTS-required `flutter analyze`/tests.
- [ ] **Step 5: Verify branch hygiene**: only `main` and `dev_branch` are part of the intended workflow; do not create or merge branches in this task.
- [ ] **Step 6: Produce final report** with implemented features, files, model fields, repeat/outline/fold geometry, eyedropper, screen-space detector, jitter/cooldown, Straight/Wave algorithms/defaults, Fringe preset, ruler persistence, `.niabrush`, locales/docs, exact test commands/results, captures, performance, final SHA and every remaining unverified item.
- [ ] **Step 7: Commit** `docs: complete brush fold ruler delivery evidence` if documentation/evidence changed.
