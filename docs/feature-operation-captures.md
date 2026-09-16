# NIARIM operation captures

This is the reproducible feature-capture task requested for filters, automation,
auto-fill, and missing Help/Tips. It is a normal development task.

## Executed coverage

Production `NiarimApp`, providers, router, Canvas menus and dialogs run in the
Flutter 3.47.3 Linux test renderer. Storage plugin boundaries and source artwork
are fixtures; effect selection, application, automation execution and auto-fill
part assignment use UI taps. Screenshots are 960 × 1920 (480 × 960 logical,
DPR 2); artwork comparisons are 256 × 256. This is not Android/iOS device testing.

| Area | Coverage | Cases |
| --- | --- | ---: |
| Drawing filters | All 25 cards; all 6 tone curves, 8 texture presets, 4 pixel color modes | 40 |
| Official automation | Digital lineart, analog lineart extraction, color trace, aurora hologram | 4 |
| Shipped auto-fill | Gray underpaint, protagonist, heroine; every shipped part | 55 |
| Additional operations | Record/save/replay; repaint; color update; all 3 gradient types; outline and same-as-fill line color | 7 |
| Help/Tips | Automation Help, filter Help, official automation Tips, texture/prism/VHS Tips | 4 screens |

All 106 operation cases passed in the complete UI run. Each case records input,
output, settings and full UI PNGs in `build/feature-captures/<group>/`. Separate
generated layers are also captured after toggling input-layer visibility in the
real layer panel. The normal composite remains in the `after` image.

Checks include changed pixels for non-neutral filters, unchanged pixels for
linear tone curve and default levels, actual auto-fill interior RGBA matching
each part's assigned color, generated layer existence, and exact RGBA equality
between recorded and replayed blur. Continuous slider combinations are not
exhaustively enumerated. Raw changed-pixel counts include RGB under transparency.
The palette choice intentionally copies selected colors into explicit mode.

## Improvements made while exercising the UI

- Fresh installs receive the four existing semantic official presets. A one-time
  migration replaces untouched legacy starters, preserves edited/user entries,
  transfers favorites, and respects deliberately empty or deleted libraries.
- Canvas playback uses the semantic executor for complete official recipes and
  recorded filter aliases. Generated layers become the input for following steps.
- Frame scopes resolve the original selected layer by type; playback honors
  auto-fill, lineart, common and text layers. Explicit frame navigation updates
  the executor's frame before later operations.
- Generated filter output is placed immediately below its source, consistent
  with applying the same filter directly through the panel.
- Playback shows a non-dismissible progress dialog, prevents duplicate runs,
  and reports execution failure through a localized message.
- Structural Undo actions are grouped per automation. Color-trace's merged-away
  intermediate duplicates do not cause empty Undo presses or reappear on Redo;
  a partially failed execution retains its available inverse actions.
- The negative/invert filter has its own localized title. Filter preview and
  controls scroll together to prevent the auto-lineart panel overflowing.
- Help lists all 25 filters and explains operation recording. Tips explain the
  official recipes and texture/prism/VHS use. All additions are present in
  Japanese, English, Spanish, French, Korean, Simplified and Traditional Chinese.

## Reproduce

Use the repository's compatible Flutter SDK and install locked dependencies.
Set `CI=true` in noninteractive environments.

```sh
flutter gen-l10n
flutter test test/custom_automation_executor_test.dart \
  test/services/custom_automation_builtin_migration_test.dart \
  test/custom_automation_service_test.dart \
  test/custom_automation_frame_scope_test.dart \
  test/custom_automation_discrete_step_test.dart \
  test/generated_filter_redo_test.dart
flutter test test/visual/feature_operation_capture_test.dart --reporter expanded
python3 tool/feature_capture_gallery.py --output /absolute/output/path \
  --revision <verified-git-commit>
```

`CAPTURE_GROUP=filters|automation|autofill|extras` and `CAPTURE_MATCH=<case-id>`
can be passed as `--dart-define` for diagnosis. A filtered rerun replaces that
group's manifest; rerun the entire group before packaging. The packaging script
requires all 40 + 4 + 55 + 7 cases, verifies required files, and produces a
comparison PDF plus a ZIP with original PNGs, settings and an offline HTML gallery.
It requires Pillow and ReportLab. Generated capture binaries stay outside Git.

Regression coverage also checks color-trace Undo/Redo over repeated cycles,
exact restored layer order and pixels, prior history, standalone duplication,
partial failure, and stale removed-layer cache entries from another project.
