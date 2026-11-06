# Brush Pressure Profiles Design

## Goal

Redesign brush pressure configuration so every distributed brush carries both a pressure-ON profile and a pressure-OFF profile, while keeping pressure-independent brush behavior in a shared section. Users can edit both profiles regardless of their current device pressure setting.

## Scope

This design replaces the current `PressureMode` + single `pressureStrength` model with explicit pressure profiles. NIARIM is pre-release, so no legacy migration path is required for old saved brush data.

## UI Structure

The brush customization sheet is divided into three accordion sections:

1. **Common settings**
2. **Pressure ON settings**
3. **Pressure OFF settings**

At sheet open, the accordion matching the user's current app pressure setting opens by default. The other pressure accordion is collapsed by default. This is only an initial presentation rule: users can freely open or close either section at any time, and both profiles are always editable.

Each configurable pressure-dependent feature is individually enabled with a checkbox. Only enabled items expose their numeric controls.

Numeric controls use the existing fine-adjustment pattern: slider, ±1 controls where the existing component supports them, and direct numeric input. Defaults are real stored values represented by the initial slider position; they are not null fallbacks injected later.

## Common Settings

The following remain identical regardless of pressure state and are stored once per brush:

- spacing
- rotation
- density
- scatter
- pixel mode and pixel color settings
- fade mode and fade custom settings
- stroke decay

Brush size, opacity, and stabilization are not stored as common brush-customization values in this redesign because users adjust them from the active tool UI while drawing.

## Pressure OFF Profile

The OFF profile stores fixed brush behavior used when pressure is disabled. Each feature is independently enabled.

### Blur

- enabled: boolean
- value: 0–100
- one constant value applies across the whole stroke

### Edge bleed / edge jitter

- enabled: boolean
- strength: 0–100
- one constant strength applies across the whole stroke

### Mixing

- enabled: boolean
- mode: existing `BrushMixingMode` semantics (`simple` / `bleed`)
- rate: 0–100 continuous numeric value
- one constant rate applies across the whole stroke

There is no weak/strong pressure range in the OFF profile.

## Pressure ON Profile

The ON profile stores pressure-reactive behavior. Every item is independently enabled and only enabled items show their weak/strong controls.

All weak/strong values are initialized as real stored values when a new brush is created.

### Size

- enabled: boolean
- weak pressure: 50%
- strong pressure: 100%
- range: 0–100%
- percentage is applied to the current active tool size, which is treated as 100%

### Opacity

- enabled: boolean
- weak pressure: 50%
- strong pressure: 100%
- range: 0–100%
- percentage is applied to the current active tool opacity, which is treated as 100%

### Blur

- enabled: boolean
- weak pressure: 50
- strong pressure: 0
- range: 0–100
- values are direct blur strengths for the pressure-ON profile, not multipliers of the OFF profile

### Edge bleed / edge jitter

- enabled: boolean
- weak pressure strength: 50
- strong pressure strength: 0
- range: 0–100
- the existing edge-jitter effect semantics are preserved; pressure changes only the strength

### Mixing

- enabled: boolean
- mode: existing `BrushMixingMode` semantics (`simple` / `bleed`)
- weak pressure rate: 50
- strong pressure rate: 0
- range: 0–100
- the selected mixing mode is fixed for the pressure-ON profile; pressure changes the rate only

## Pressure Curve Evaluation

The user's global pressure curve is applied first to raw stylus pressure, producing a normalized pressure value `t` in the range 0–1.

For every enabled pressure-ON parameter, the effective value is linearly interpolated between the stored weak and strong values using `t`:

`effective = weak + (strong - weak) * t`

Size and opacity then apply that interpolated percentage to the current active-tool value. Blur, edge-jitter strength, and mixing rate use the interpolated value directly.

The ON profile never uses the OFF profile as a numeric base. The two profiles are intentionally independent so distributed brushes behave predictably on both pressure-enabled and pressure-disabled environments.

## Brush Distribution and Persistence

A brush always serializes:

- common settings
- pressure ON profile
- pressure OFF profile

Both profiles are present regardless of the current device or user pressure preference. Copy, duplicate, export/import (`.niabrush`), and persistence flows must preserve all profile values and enabled states.

Because the application is pre-release, implementation may replace the current pressure serialization format directly rather than adding compatibility code for previous pressure fields.

## Existing Model Changes

The current `PressureMode` and single `pressureStrength` representation is removed from the active brush model. Replace it with explicit immutable profile objects, for example:

- `BrushPressureOnSettings`
- `BrushPressureOffSettings`
- a reusable weak/strong numeric range value object where useful

The exact names may follow existing repository naming conventions, but ON and OFF settings must remain distinct serialized objects with explicit defaults.

Existing common fields move only when required by this design:

- `blurRadius`, `edgeJitter`, `edgeJitterStrength`, `mixingMode`, `mixingRate` become profile-specific values rather than single brush-wide values.
- spacing, rotation, density, scatter, pixel settings, fade settings, and stroke decay remain brush-wide common values.

## Rendering Rules

When pressure is disabled:

- use the OFF profile for enabled blur, edge-jitter, and mixing behavior
- disabled OFF items contribute no effect

When pressure is enabled:

- use the ON profile only for enabled pressure-reactive items
- current tool size and opacity are the 100% bases for their respective ranges
- disabled ON items contribute no pressure-specific override/effect
- common settings still apply normally

## Testing Requirements

Tests must cover:

- default ON/OFF profile values at brush construction
- serialization/deserialization round trips for both profiles
- duplicate/export/import persistence of both profiles
- each enabled/disabled flag independently
- pressure-curve interpolation at 0, 0.5, and 1.0
- size and opacity applying percentages to active-tool values
- blur, edge-jitter strength, and mixing rate using direct interpolated values
- OFF profile applying one constant value across pressure values
- accordion default expansion following the current app pressure preference without preventing editing of the other section
- disabled items hiding their numeric controls
- numeric control clamping to 0–100 and ±1/direct-input behavior
- existing common settings remaining pressure-independent

## Non-goals

- Fade does not react to pressure.
- Spacing, rotation, density, scatter, pixel settings, stroke decay, and stabilization do not receive new pressure interpolation behavior in this change.
- No historical-data migration layer is added for pre-release pressure data.
