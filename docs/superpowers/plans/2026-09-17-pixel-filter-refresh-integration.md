# Pixel / Filter Refresh Semantic Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the verified Pixel Art, Mosaic, generic Noise, Film Grain, Retro Anime, CRT, and VHS work while semantically integrating it onto the latest `dev_branch`, then continue the remaining Sunset Gold, Aurora Hologram, Prism, blend-mode, Help/Tips, capture, and regression work.

**Architecture:** Treat latest `dev_branch` as the source of truth. Port only intentional behavioral changes from `feature/pixel-filter-blend-refresh`; do not wholesale replace files or formatting. Lock each behavioral slice with focused tests, then validate affected production surfaces before advancing.

**Tech Stack:** Flutter/Dart, repository filter engines/models/services/UI, flutter_test, GitHub Actions.

**Spec:** User-approved pixel/filter/blend refresh requirements in the active NIARIM task.

## Global Constraints

- Latest `dev_branch` is authoritative; preserve unrelated concurrent changes.
- No force-push/reset/destructive replacement of other-session work.
- Pixel Art and Mosaic remain separate effects.
- Pixel Art uses the shared pixel-art contract across every NIARIM pixelization route.
- Film Grain, generic Noise, Retro Anime, CRT, and VHS remain semantically distinct.
- Temporary verification workflows/scripts must be removed after verified use.
- Do not mark a slice complete without fresh tests and targeted `flutter analyze`.

---

### Task 1: Establish semantic integration branch

**Files:**
- Base: latest `dev_branch`
- Reference: `feature/pixel-filter-blend-refresh`

- [ ] Create a fresh integration branch from latest `dev_branch`.
- [ ] Confirm the 16 PR #10 changed paths and inspect current `dev_branch` counterparts.
- [ ] Classify each diff as intentional behavior, test-only contract, formatting-only noise, or obsolete/conflicting change.

### Task 2: Port Pixel Art and Mosaic contracts

**Files:**
- Modify: `lib/models/filter_def.dart`
- Modify: `lib/services/filter_service.dart`
- Modify: `lib/engine/filter_engine.dart`
- Modify as needed: `lib/engine/filter_engine_legacy.dart`
- Modify: `lib/engine/pixel_art_engine.dart`
- Modify: `lib/screens/canvas/widgets/filter_panel.dart`
- Tests: `test/engine/*pixel_art*`, `test/engine/mosaic_filter_contract_test.dart`, `test/models/mosaic_filter_def_contract_test.dart`, `test/mosaic_filter_test.dart`

- [ ] Port `FilterKind.mosaic` without unrelated formatting churn.
- [ ] Port the shared PixelArtEngine behavior and all pixelization routes.
- [ ] Port classic block-average Mosaic dispatch/UI independently from Pixel Art palette logic.
- [ ] Run focused Pixel Art/Mosaic tests and targeted analyze; fix only root causes.

### Task 3: Port Noise / Film Grain / Retro Anime / CRT / VHS distinctions

**Files:**
- Modify: `lib/services/filter_service.dart`
- Modify: `lib/engine/filter_engine_legacy.dart`
- Modify: `lib/screens/canvas/widgets/filter_panel.dart`
- Tests: `test/engine/noise_filter_distinction_test.dart`, `test/engine/analog_filter_distinction_test.dart`

- [ ] Preserve Film Grain as neutral grain and add generic per-channel Noise as a distinct built-in.
- [ ] Keep Retro Anime focused on cell-animation color/aging texture rather than CRT/VHS artifacts.
- [ ] Preserve CRT static scanline/vignette behavior and VHS temporal tracking/jitter/channel-bleed behavior.
- [ ] Run distinction tests and targeted analyze.

### Task 4: Resume remaining requested visual filter work

**Files:**
- Inspect/modify relevant filter engines, presets, and `filter_panel.dart`.
- Tests: add focused contracts before production changes.

- [ ] Rebuild Sunset Gold palette from the approved reference, excluding grayscale swatches.
- [ ] Improve Aurora Hologram with explicit white-mixed, high-saturation, and white reflective bands/highlights.
- [ ] Correct Prism compositing semantics so Linear Dodge behavior is represented correctly against layer/background content.
- [ ] Verify each effect through production UI capture.

### Task 5: Blend-mode coverage

**Files:**
- Inspect blend-mode model, compositor/renderer, layer UI, serialization, Help/Tips.

- [ ] Compare implemented modes against the previously approved ibisPaint / Clip Studio Paint / MediBang references.
- [ ] Add only materially useful missing modes with tests for equations, alpha, black/white edge cases, persistence, and UI labels.
- [ ] Execute every existing and newly added blend mode through production UI and capture representative results.

### Task 6: Help/Tips, visual evidence, and final regression

**Files:**
- Update Help/Tips/localizations only where production behavior changed or coverage is missing.

- [ ] Reconcile Help/Tips against final production names and behavior.
- [ ] Capture all affected filters and all blend modes through the production Flutter UI path.
- [ ] Run affected regression suites and targeted/full relevant `flutter analyze`.
- [ ] Confirm no temporary workflow, script, diagnostic, or generated repair artifact remains.
- [ ] Review final `dev_branch` diff and only then mark the task complete.
