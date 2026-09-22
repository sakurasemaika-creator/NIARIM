# Hair Fold five modes implementation plan

Goal: Complete the user-approved folding brush on dev_branch, preserving the drawn curve and rendering actual occlusion.

Spec: User handoff dated 2026-09-21 and four attached reference drawings. Top view puts upper portions in front, low angle lower portions; right curl puts NW–SE portions in front, left curl the inverse. Crescent pieces follow each actual bend without synthetic waves. Fold OFF is ordinary drawing. Exactly five modes; no Straight option.

Constraints: dev_branch only; no new branches, no force pushes, no audit state access. Preserve other sessions' changes. Seven languages and real brush export/import. Visual captures are required; passing tests alone do not establish visual quality.

## Task 1: Production ribbon drawing
- [ ] Reproduce mode occlusion failures through DrawingEngine pixels.
- [ ] Add a separate ribbon geometry/raster component using actual center samples, pressure/fade widths, outline color, selected fill color and active texture. Resolve overlapping faces before compositing once over the original pixels.
- [ ] Integrate stroke lifecycle, live drawing, final replay and Undo, avoiding centerline dot overlays. Cover screen trigger threshold, reverse drawing, transparent backgrounds, short/hairpin/multiple bends and texture selection.
- [ ] Remove superseded bool Wave controls and obsolete synthesized fold builders/contracts.
- [ ] Run renderer tests and regenerate labeled same-curve captures for all five modes; inspect PNGs.

## Task 2: UI and localization
- [ ] Five-mode dropdown, localized labels, no obsolete wave toggles/ranges.
- [ ] Update seven-language Help/Tips and verify real widget selection/state.

## Task 3: Persistence
- [ ] Reproduce the platform directory failure; fake only the platform directory boundary.
- [ ] Verify all modes across model JSON, custom save/restart, duplication, niabrush and niatra round trips.

## Task 4: Integration
- [ ] Targeted tests and analyze, relevant existing regression tests and visual inspection.
- [ ] Fresh code review, address functional findings, commit and push dev_branch without replacing newer work.

Review focus: reversed/rotated strokes; density-dependent seams; semitransparent fill over existing content; cross-tile Undo/fade replay; imported texture variants and all mode values.

## Execution record
- Baseline cd16eb423dcb903094266e3ba2750dea7d0f6199. Hair Fold Production Green fails at obsolete waveEnabled test API. Captures at 8b756328 show essentially indistinguishable filled bands; overlay circles cannot occlude existing outline.
- Design decision: explicit filled ribbon surfaces and per-face occlusion replace additive centerline dots. Input centers are immutable. Retain ordinary brush rendering when no fold triggers.
