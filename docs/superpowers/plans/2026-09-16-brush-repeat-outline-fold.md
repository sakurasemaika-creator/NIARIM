# Brush repetition, outline, folds and ruler snap implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. The user explicitly approved autonomous execution of the attached specification.

**Goal:** Implement real drawing, storage, UI, presets, ruler snapping, tests, captures and documentation for the approved brush extension specification.

**Architecture:** Keep the existing tile rasterizer fast path when disabled. Isolate repeat/fold geometry and outline coverage composition. Carry logical screen input separately from document coordinates. Persist ruler geometry and its independent snap preference on Project through the existing archive serializer.

**Tech Stack:** Dart / Flutter 3.47.3, TileManager, SharedPreferences, existing NIARIM archive serializers.

**Spec:** `docs/superpowers/specs/2026-09-16-brush-repeat-outline-fold.md`.

## Constraints and contracts

- Normal task; dev_branch only; no audit reads/edits; preserve concurrent source changes.
- New data defaults disabled; repeat count1..10; no stored fill color; outline black.
- Screen-distance fold detection, bounded sample window, inward-only Y geometry, pressure-resolved width ratios and endpoint taper; no whole-canvas event scan.
- Field API: `lateralRepeatEnabled=false`, `lateralRepeatCount=1` [1..10], `lateralRepeatSpacing=1` [.1..3], `outlineEnabled=false`, `outlineWidth=1.5` [.1..100 nominal px], `outlineColor=0xff000000`, `foldEnabled=false`, `foldTriggerAngle=90` [30..170], `yBranchAngle=45` [10..120], `yBranchLengthRatio=.6` [.1..1], `yBranchWidthRatio=.08` [.01...3], `yBranchEndTaperRatio=.4` [0..1], `tipShape=BrushTipShape.round` (also hollowSquare).
- Outline width scales with pressure/fade. Ratios display %. Net longitudinal spacing is brush-size percent; new Net default100.
- Net=`Brush0022`, size20, spacing100, rotation, repeat4/spacing1, pressure-size/opacity disabled, hollowSquare. Hair=`Brush0023`, size28, spacing1, outline1.5 black, fold90/45/.6/.08/.4, pressure-size20..100, fade enabled. Tune Hair endpoint appearance from actual captures.
- Geometry API: `lateralOffsets({int count,double spacing})`, `lateralCenters({Offset center,Offset tangent,int count,double spacing})`; `BrushStrokeSample(screenPosition,documentPosition,effectiveWidth)`; `ScreenSpaceFoldDetector(triggerAngleDegrees:90,sampleSpacing:2,minimumTravel:12,windowLength:48,cooldownDistance:24)` with `add`, `reset`, `bufferedSampleCount`; `FoldEvent(sample,tangent,inwardNormal,signedTurnRadians,screenDistance)`; `buildFoldY(event,{branchAngleDegrees,lengthRatio,widthRatio,taperRatio})` returns3 `FoldBranch(start,end,width,taperRatio)` with `widthAt(t)`.
- Input API: optional `StrokePoint.screenPosition` (`Offset?`), preserved through stabilization/constraint/Canvas transforms. No logical coordinates means generated shape paths don't trigger gesture folds.
- Ruler API: Project `activeRuler`, `rulerSnapEnabled=true`; service `updateProjectRuler(id,Ruler?,{persist=true})`, `updateRulerSnapEnabled(id,bool)`; engine `setSnapEnabled(bool)`; panel optional `snapEnabled`/`onSnapChanged`. Root wires CanvasArea `rulerSnapEnabled` and `onRulerEditCommitted`. Live handle move does not save ZIP; drag-end and Undo/Redo save once.

## Task 1: model, preset and IO lifecycle

Files: `lib/models/brush.dart`, `lib/services/brush_service.dart`; new model/lifecycle tests.
- [ ] Add RED tests: count0→1,99→10, missing fields disabled, JSON/copyWith all values, outline color and no stored fill. Example: `expect(Brush.fromJson(configured.toJson()).outlineColor, 0xff1267ab)`.
- [ ] Implement const-safe clamps, safe finite JSON defaults, shape enum, Net/Hair definitions. Retain existing pressure profiles.
- [ ] Test duplication, SharedPreferences and `.niabrush`/`.niatra` retention plus old-field absence and unique preset IDs. Update only Net-specific spacing expectation in old preset test.
- [ ] Run model/lifecycle/pressure/preset/import regressions; checkpoint verified files.

## Task 2: pure geometry

Files: new `lib/engine/brush_stroke_geometry.dart`, `test/engine/brush_stroke_geometry_test.dart`.
- [ ] RED: `expect(lateralOffsets(count:4,spacing:10),[-15,-5,5,15])`; tangent rotation/spacing/count clamps.
- [ ] RED: identical logical paths at multiple event densities/document zooms produce equivalent folds; jitter/gentle turns none, both bend signs inward, cooldown bounds count, ratio/taper endpoint checks.
- [ ] Implement distance resampling, smoothed cumulative-turn window, cooldown and3 tapered rays with bounded buffered points. Keep independent of Brush/UI.
- [ ] Run focused geometry tests; checkpoint.

## Task 3: tile rendering and input integration

Files: `drawing_engine.dart`, new `outlined_stroke_compositor.dart`, texture cache if needed, `input_handler.dart`, CanvasArea transforms; new raster tests.
- [ ] RED raster tests: independent fill/outline colors, no internal seams at curves/intersections, OFF matches old pixels, repeat normal symmetry, hollow-square holes/corners, pressure/size and clipping.
- [ ] Add repeat centers after pressure/spacing/scatter resolution and analytic hollow-square tip. Preserve texture/rotation/pixel/blur/mixing paths.
- [ ] Compose per-tile max fill/outer/fold coverage over original stroke pixels. Fill union wins over outline union; fold marks remain on top and clip to interior. Custom-tip dilation uses a cached small tip mask/distance field, never canvas-wide work.
- [ ] Carry logical screen position and feed detector; render branches using effective pressure/fade width. Replace unbounded input-point storage with running length/count and bounded geometry state.
- [ ] Draw/tune actual Hair start/end taper and all curve/pressure cases. Run existing drawing/pressure/rotation/density/scatter/custom texture and new raster regressions.

## Task 4: details UI and targeted eyedropper

Files: `brush_panel.dart`, focused extension controls, `canvas_screen.dart`, ARBs/generated l10n; UI tests.
- [ ] RED UI visibility/count/range tests and narrow layout; independent picker color and cancel tests.
- [ ] Add expandable repeat/outline/fold sections with existing editable sliders and percent labels.
- [ ] Expose `showBrushSettingsSheet(context,brush,{onOutlineEyedropperRequested})` and `BrushPanel.onOutlineEyedropperRequested`. Details closes with retained draft, root arms an outline target, existing composite eyedropper samples canvas, root restores tool and opens draft with only outlineColor changed. Cancel restores unchanged draft/current color.
- [ ] Add all seven locales and updated Help/Tips descriptions without hardcoded UI text. Run details/normal+outline eyedropper tests.

## Task 5: ruler snap persistence

Files: ruler/project models, project_service ruler methods, niapro_serializer, ruler_engine/panel, focused tests and ordinary ruler spec. Canvas integration owned by root.
- [ ] RED for all7 engine types: OFF input unchanged, geometry retained, re-ON constraint, kind change keeps OFF; model/manifest missing-field defaults and archive round-trip.
- [ ] Implement JSON and independent Project preference. Add panel Switch with `rulerSnapLabel`, `rulerSnapOffHint`; do not add unrelated picker types.
- [ ] Root passes project ruler/snap state to CanvasArea/Panel and saves only on committed geometry edits. Test visible/editable ruler while OFF with real pointer input.
- [ ] Run ruler and project/archive regression tests; checkpoint.

## Task 6: visual, performance and delivery

- [ ] New `test/visual/brush_extension_operation_capture_test.dart` exercises production UI and actual pointer strokes, all Net/outline/Hair/Y/ruler cases from spec. Seed only input; save original output/screenshots.
- [ ] Check available Android/emulator/desktop runtime. Clearly distinguish actual-device checks from production-widget renderer evidence; unavailable checks remain unverified.
- [ ] Measure stroke update cost on small/large canvases, event densities, feature-off baseline and bounded long-stroke memory; don't assert phone frame rates from Linux tests.
- [ ] Update ordinary brush/ruler specs, Help/Tips and7 locales; verify compile, all affected tests, format and analyze. Persist tested source to dev_branch and save capture deliverables.
- [ ] Report exact defaults/APIs/geometry/rendering/IO/UI/persistence, commands/results, actual visual/performance evidence, SHA and remaining unverified checks.

## Persisted continuation

Previous filter/automation capture task completed at `12d38c39`:106 UI cases,41 regressions,30-page PDF,551 PNGs; delivered files were saved successfully. New brush feature work was not committed before an environment restart, so no implementation is counted complete. Current recovered source is `8ec30cecca1cae06c258ebaef87aed436af099a2`; restart directly with Tasks1/2/5 in independent files and root Task3. Flutter SDK exists; exact locked pub archives are being restored after the cache was lost.
