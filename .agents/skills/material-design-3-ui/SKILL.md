---
name: material-design-3-ui
description: Design, implement, review, or audit UI/UX using Material Design 3 semantics, Material You, optional restrained M3 Expressive, semantic tokens, responsive/adaptive layouts, and accessibility. Use for app and website UI tasks, component selection, theming, state design, accessibility, and design reviews.
---

# Material Design 3 UI / UX

Use M3 as a **design system and quality framework**, not as a mandate to copy Google's visual style.

## Workflow
1. Understand platform, user task, hierarchy, existing product identity, input methods, content density, relevant window sizes, states, and constraints.
2. Define information architecture before styling. Separate navigation from actions; avoid redundant controls and decorative filler.
3. Choose adaptive structure (compact/medium/expanded) based on available space and tasks; wider windows should improve context or productivity rather than stretch a phone layout.
4. Use semantic design tokens for color, typography, shape, spacing, and elevation. Avoid arbitrary scattered values.
5. Select components by semantics and behavior, not visual similarity. Choose the right button emphasis, navigation, form control, selection, dialog, sheet, feedback, and state patterns.
6. Include empty, loading, error/recovery, disabled, selected, pressed, focus, hover, and busy states as relevant.
7. Review accessibility: contrast, target size, logical/visible focus, keyboard operation, accessible labels, screen-reader semantics, text scaling, localization, reduced motion, and non-color state cues.
8. Add purposeful motion only when it communicates state, hierarchy, response, or spatial relationships.
9. Use M3 Expressive selectively only when it improves hierarchy, recognition, usability, or emotional clarity; routine/dense workflows stay calm.
10. Review anti-patterns and report concrete issues instead of inflating approval.

## Semantic tokens and components
Prefer semantic roles (primary/onPrimary, surface/onSurface, surfaceContainer, outlineVariant, error/errorContainer) rather than literal values scattered through screens. Preserve theme behavior, including dark theme where the product supports it. Shape, elevation, and spacing should form a consistent hierarchy, not decorative effects.

## Adaptive layout guidance
Use the M3 window-size categories as a starting point: compact <600dp, medium 600–839dp, expanded 840–1199dp, large 1200–1599dp, extra-large ≥1600dp. Treat these as guides, verify actual content and platform behavior. Consider adaptive navigation, list-detail/supporting panes, safe areas, resizable windows, foldables/tablets/desktop and input modes.

## Review gate (score 0/1/2)
- Task clarity
- Information hierarchy
- Component semantics
- Semantic token consistency
- Adaptive behavior
- States and recovery
- Accessibility
- Expressive restraint

Do not approve if component semantics, states/recovery, or accessibility scores 0. Record specific gaps and fixes.

## Upstream reference
This bundled adaptation is project-tailored. For deeper topic references or updates, read upstream:
https://github.com/skydashnet/material-design-3-ui-skill
MIT license. When local project constraints conflict with general guidance, follow project-specific adoption rules below.

## NIARIM app constraints
M3 applies to conventional UI and UX/accessibility quality; do not wholesale convert the canvas, timeline, frame strip, layers, brush controls, or animation creation gestures to generic Material components. Preserve specialist density, precision, behavior, 7-language localization, existing product identity, and approved decisions. M3 touch/accessibility advice must not break precision input; verify practical reach, gesture conflicts, keyboard/DeX and screen-reader semantics. No runtime dependency is required for this skill. Adapt tablet/DeX layouts structurally. See `docs/ui/MATERIAL_DESIGN_3_ADOPTION.md` for project contract.
