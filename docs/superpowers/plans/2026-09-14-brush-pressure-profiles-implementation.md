# Brush Pressure Profiles Implementation Plan

> Execute with test-driven development: each production change must be preceded by a failing test and verified green before moving on.

**Goal:** Replace the current single pressure mode/strength brush behavior with persisted common settings plus independent pressure-ON and pressure-OFF brush profiles, while keeping active-tool size/opacity/stabilization outside brush common customization.

**Architecture:** `Brush` owns common pressure-independent fields plus immutable `BrushPressureOnSettings` and `BrushPressureOffSettings`. The ON profile stores independent enabled flags and weak/strong ranges; the OFF profile stores independent enabled flags and fixed values. Rendering resolves raw pressure through the user's global pressure curve, then derives effective brush values from the appropriate profile. Brush settings UI presents Common / Pressure ON / Pressure OFF accordion sections; both pressure profiles are always editable.

**Tech Stack:** Flutter/Dart, existing `Brush` JSON persistence, `BrushService`, canvas brush panel, existing pressure-curve service/settings, Flutter widget/unit tests.

---

## Task 1: Lock model defaults and JSON shape

**Files:**
- Modify: `lib/models/brush.dart`
- Create/Modify: focused brush model tests under `test/`

1. Write failing tests for explicit construction defaults: ON size 50→100, opacity 50→100, blur 50→0, edge bleed 50→0, mixing 50→0; OFF blur/edge/mixing fixed values and enabled flags are concrete stored values, not null fallbacks.
2. Write failing JSON round-trip tests proving common + ON + OFF settings survive serialization.
3. Run focused tests and verify RED because profile objects do not yet exist.
4. Implement immutable numeric range, ON profile, OFF profile, `copyWith`, equality, and JSON serialization. Replace active `PressureMode`/`pressureStrength` representation. No legacy migration code.
5. Run focused tests and verify GREEN.

## Task 2: Preserve profiles through brush lifecycle

**Files:**
- Modify: `lib/services/brush_service.dart` as required
- Modify/Create: brush service persistence/export/import/duplicate tests

1. Write failing tests proving duplicate, persistent reload, export, and import preserve both profile enabled states, modes, and values.
2. Verify RED.
3. Make the minimum service changes needed for the new model shape and `.niabrush` payload.
4. Verify GREEN.

## Task 3: Add pressure-profile resolution helpers

**Files:**
- Create/Modify: pressure/brush resolution helper in the existing drawing/model utility location
- Create: focused unit tests

1. Write failing tests for interpolation at curve output 0, 0.5, 1.
2. Write failing tests that ON size/opacity percentages use active-tool size/opacity as 100% bases.
3. Write failing tests that ON blur, edge strength, and mixing rate use direct weak/strong values.
4. Write failing tests that OFF blur/edge/mixing ignore pressure and use one constant value.
5. Write failing tests that disabled profile items contribute no effect/override.
6. Implement the minimal pure resolution helpers and verify GREEN.

## Task 4: Wire rendering to the global pressure curve and profiles

**Files:**
- Modify: actual stroke/drawing pipeline files discovered from the current canvas implementation
- Modify/Create: drawing regression tests

1. Trace the existing raw stylus pressure → global pressure curve → brush calculation path and identify the exact production entry points.
2. Add failing integration/regression tests demonstrating the new ON/OFF profile behavior through the real calculation path.
3. Verify RED.
4. Replace old `PressureMode`/`pressureStrength` branching with profile resolution after global pressure-curve evaluation.
5. Ensure common spacing/rotation/density/scatter/pixel/fade/stroke-decay behavior remains unchanged.
6. Verify GREEN and run adjacent drawing tests.

## Task 5: Restructure brush customization UI

**Files:**
- Modify: `lib/screens/canvas/widgets/brush_panel.dart`
- Modify: localization ARB files and generated localization output as required by repository workflow
- Modify/Create: brush settings widget tests

1. Write failing widget tests for three accordion sections: Common, Pressure ON, Pressure OFF.
2. Test initial expansion follows current app pressure preference only; both pressure accordions remain independently openable/closable.
3. Test Common contains spacing, rotation, density, scatter, pixel settings, fade settings, and stroke decay; size, opacity, and stabilization are absent from brush common customization.
4. Test OFF profile independently enables blur, edge bleed, and mixing; only checked items show one fixed-value editor (plus mode where applicable).
5. Test ON profile independently enables size, opacity, blur, edge bleed, and mixing; only checked items show weak/strong editors.
6. Test numeric controls clamp 0–100 and expose slider + fine ±1 + direct numeric input using the repository's existing numeric-control pattern or a small reusable component if needed.
7. Verify RED.
8. Implement the accordion UI and profile editing with the minimum production changes.
9. Add/update localization strings in every supported locale; do not introduce Japanese fallback text into non-Japanese locales.
10. Regenerate localizations and verify GREEN.

## Task 6: Remove obsolete pressure-hardness implementation

**Files:**
- Modify/Delete: old pressure-hardness helpers/tests/localization entries where no longer used
- Modify: any remaining callers found by repository search

1. Add/adjust tests so no production UI or rendering behavior depends on `PressureMode`, `pressureStrength`, or the 1–10 pressure-hardness control.
2. Search the repository for all obsolete symbols and classify each occurrence before removal.
3. Remove dead helpers/UI/localization only after replacement tests are green.
4. Run focused tests and static analysis.

## Task 7: Verification and integration

1. Run `dart format --set-exit-if-changed` on touched Dart files.
2. Run `flutter gen-l10n` if localization changed.
3. Run `flutter analyze`.
4. Run focused model/service/profile/UI/drawing tests.
5. Run the relevant broader brush/canvas regression suite required by `AGENTS.md` and current CI.
6. Inspect the final diff for accidental audit-route/state changes; this remains a bounded normal task.
7. Commit implementation on a feature branch, open a PR to `dev_branch`, inspect CI and changed-file diff, and merge only after required checks for this change are green or any unrelated pre-existing failure is explicitly isolated with evidence.
8. After merge, verify the `dev_branch` HEAD contains the implementation and no temporary verification workflow/scripts/artifacts remain.
