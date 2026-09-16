# Brush extension current verification

This ordinary-task note records only the implementation checkpoint for the approved brush extension work. It is not audit state.

- Model extension fields are present on `Brush`, including repeat, outline, fold, Y ratios and `BrushTipShape`.
- Approved defaults that still need source correction before Task 1 can be considered green: `outlineWidth=1.5` and `yBranchWidthRatio=.08` (the current model source still has 1.0 and .12).
- Pure geometry now has centered lateral offsets, local-normal centers, bounded screen-space sampling, minimum travel, cooldown, inward fold events, effective-width Y ratios and smooth endpoint taper.
- Focused tests have been added for geometry and approved model defaults.
- These tests have NOT been executed in the current environment; no green claim is made.
- Next implementation work: correct model defaults, add Net/Hair presets and lifecycle coverage, then integrate geometry into the production raster/input path before UI work.
