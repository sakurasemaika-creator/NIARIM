# NIARIM Pixel, Filter, and Blend Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all NIARIM pixel-art entry points share hard-alpha pixel-art semantics, separate mosaic/noise/look filters cleanly, refresh metallic/holographic effects, correct Prism compositing, and add/verify the missing production blend modes.

**Architecture:** Introduce one reusable pixel-art conversion contract used by the filter and every stamp/brush pixel mode, while keeping mosaic as a deliberately alpha-averaging block effect. Keep filter algorithms independently testable in the engine; blend modes remain backward-compatible additions and are verified both mathematically and through production UI captures.

**Tech Stack:** Flutter/Dart, existing NIARIM filter/render engines, flutter_test, production Flutter UI capture tests.

**Spec:** User-approved conversation specification from 2026-09-16.

## Global Constraints

- Work on `dev_branch`; do not touch audit Route/State.
- Preserve existing serialized enum values and saved-project compatibility.
- Pixel-art outer alpha boundary is always hard: never invent translucent anti-alias pixels against transparency.
- Horizontal/vertical internal color boundaries remain hard.
- Only diagonal boundaries between opaque colors may use a middle color when shape is preserved.
- Unrestricted color mode may synthesize a middle color; color-count mode must remain within its total color limit; explicit palette mode may only choose an existing palette color and otherwise leaves the edge hard.
- Mosaic remains a separate block-average effect and may average alpha.
- Every production pixel-art/pixel-mode entry point must use the same conversion contract.
- Final verification includes production UI captures, affected tests, relevant `flutter analyze`, save/restore checks, and removal of task-only CI/trigger files.

---

### Task 1: Shared pixel-art semantics

**Files:**
- Modify: `lib/engine/filter_engine.dart`
- Modify/create focused pixel-art helper if repository structure warrants it.
- Modify: all production stamp/brush/filter pixel-mode callers found by repository search.
- Test: `test/engine/pixel_art_filter_engine_test.dart`

**Interfaces:**
- Consumes: RGBA bytes, canvas dimensions, pixel-cell size, `PixelColorMode`, color-count/palette constraints.
- Produces: deterministic RGBA bytes with source alpha preserved and selective opaque-diagonal color smoothing.

- [ ] Add failing fixtures for transparent diagonal outer edges, opaque diagonal two-color edges, horizontal/vertical boundaries, count-limited colors, and explicit palettes.
- [ ] Run focused tests and confirm each new contract fails for the expected reason.
- [ ] Extract/implement the shared conversion path and route `applyPixelate` plus every production stamp/brush pixel mode through it.
- [ ] Run focused tests and existing pixel/stamp/brush regressions until green.
- [ ] Commit the independently working pixel-art change.

### Task 2: Mosaic and general noise separation

**Files:**
- Modify: filter definitions/model used by the production filter panel.
- Modify: `lib/engine/filter_engine.dart`
- Modify: production filter UI/localization/help files discovered from current filter definitions.
- Test: relevant filter engine/UI tests.

- [ ] Add failing tests proving Mosaic is exposed separately and retains block/alpha averaging.
- [ ] Add failing tests for a neutral general Noise filter distinct from Film Grain.
- [ ] Expose Mosaic and Noise without changing existing serialized filter identities.
- [ ] Verify production UI application, parameter changes, save/restore, and no-op boundaries.
- [ ] Commit.

### Task 3: Blur and analog-look differentiation

**Files:**
- Modify: `lib/engine/filter_engine.dart`
- Modify: filter definitions/help/localization as needed.
- Test: engine and production UI filter tests.

- [ ] Add fixtures that distinguish Gaussian convolution from circular-aperture Lens/Bokeh blur.
- [ ] Add fixtures distinguishing fine luminance-oriented Film Grain from Retro Anime color/quantization/cel-print treatment.
- [ ] Add fixtures distinguishing CRT scanline/phosphor behavior from VHS horizontal tracking/chroma/time-noise behavior.
- [ ] Implement minimal algorithms satisfying those contracts.
- [ ] Capture and visually inspect all affected filters; fix no-op/look-alike regressions.
- [ ] Commit.

### Task 4: Sunset Gold and Aurora/Hologram material refresh

**Files:**
- Modify: material/filter palette implementation in `lib/engine/filter_engine.dart` or its current focused owner.
- Test: palette/effect tests and production UI captures.

- [ ] Add tests rejecting grayscale stops in Sunset Gold and requiring copper/gold/cream/rose-highlight coverage.
- [ ] Add tests requiring Aurora/Hologram to contain a white/specular band, at least one white-mixed chromatic band, and at least one high-saturation chromatic band.
- [ ] Implement the revised palettes and localized high-contrast reflection structure rather than uniform blur/tint.
- [ ] Capture on light, mid-gray, and colored artwork and visually inspect reflection readability.
- [ ] Commit.

### Task 5: Prism and Linear Dodge correctness

**Files:**
- Modify: blend-mode model/renderer discovered from current layer implementation.
- Modify: Prism generation/application path.
- Test: blend math, Prism layer semantics, production UI capture.

- [ ] Add failing black/white/gray/chromatic fixtures for Linear Dodge, including black-neutral behavior.
- [ ] Add failing Prism test that checks the final composited canvas rather than the generated effect layer alone.
- [ ] Implement/route Prism through the production Linear Dodge layer mode with backward-compatible serialization.
- [ ] Capture both generated Prism layer and final composite over white, gray, and colored backgrounds.
- [ ] Commit.

### Task 6: Missing production blend modes

**Files:**
- Modify: current blend-mode enum/model, serializer, renderer, layer UI, localization/help.
- Test: blend math/serialization/UI tests.

**Modes:** Linear Burn, Linear Dodge, Vivid Light, Linear Light, Pin Light, Hard Mix, Exclusion, Divide.

- [ ] Add failing canonical channel-math fixtures for all eight modes, including black/white boundary cases and 50% opacity behavior where applicable.
- [ ] Append serialized identities without renumbering/reinterpreting existing modes.
- [ ] Implement renderer math and production layer-picker entries.
- [ ] Add save/restore round-trip coverage for old and new values.
- [ ] Run all blend regressions and commit.

### Task 7: Help/Tips/localization sync

**Files:**
- Modify: existing Help/Tips and seven-language localization resources discovered from current production implementation.

- [ ] Document true Pixel Art versus Mosaic and the selective internal diagonal smoothing rule.
- [ ] Document Noise, Film Grain, Retro Anime, CRT/VHS, refreshed materials, Prism/Linear Dodge, and new blend modes using actual production names/behavior.
- [ ] Run localization/static checks and commit.

### Task 8: Production UI visual verification and closure

**Files:**
- Modify/create only the existing production UI capture test infrastructure needed for permanent regression coverage.
- Do not retain one-shot workflow/trigger artifacts.

- [ ] Run every existing and newly added blend mode from production UI using common black, white, 50%-gray, chromatic, and semi-transparent fixtures; capture outputs.
- [ ] Run Pixel Art from every production entry point and compare transparent outer diagonal, internal diagonal, horizontal/vertical, count-limited, and explicit-palette fixtures.
- [ ] Run all changed filters and capture parameterized outputs.
- [ ] Inspect captures for no-op, clipping, unexpected darkening, alpha halos, and visually duplicate effects; repair and rerun where found.
- [ ] Run affected tests plus relevant `flutter analyze`.
- [ ] Verify save/restore and backward compatibility.
- [ ] Remove task-only workflows, trigger files, scripts, and diagnostics; confirm final `dev_branch` diff contains production/permanent-test/docs changes only.
- [ ] Record final commit and successful verification evidence in the normal-task handoff only; do not update audit State/Route.
