# DISC145 — Long unbroken Latin folder names

Date: 2026-11-21
Branch: `dev_branch`
Implementation checkpoint: `e77d7bbc0bdbedb60e926f628fce46383a4281e6`

## Finding

The folder detail-row title uses `KoreanWordsText`. Its non-Hangul path previously delegated directly to `Text`, which preserves ordinary word wrapping but cannot wrap a long ASCII/Latin alphanumeric token with no spaces. Such a folder name could exceed the available title width on narrow layouts and enlarged text settings.

## Change

- Added the opt-in `breakLongLatinWords` behavior to `KoreanWordsText`.
- The widget measures each ASCII alphanumeric token using the active text style, locale, direction, and text scaler.
- A zero-width break opportunity is inserted between characters only when that token exceeds the available width. Short tokens and normal words remain unchanged.
- The original unmodified name remains the semantics label.
- Enabled the behavior for folder detail-row titles only. Other callers retain existing behavior.

## Regression coverage added

`test/korean_words_text_long_latin_test.dart` covers:
- A long unbroken folder name at 96 logical pixels and text scales 1.0 and 2.0.
- Multi-line layout and semantics label preservation.
- A short ordinary Latin name remaining unchanged.

## Commits

- Widget behavior: `404401d3e3d2f1cd43842813ec363cf246068d19`
- Folder detail-row opt-in: `bc6d3d6d6b14e4008834c7a317da108cd0cfaaeb`
- Constructor option: `c14be3f35396713a5e7eb3e260bd3a702cbe28d3`
- Regression test: `e77d7bbc0bdbedb60e926f628fce46383a4281e6`

## Status

Implementation and source re-fetch are confirmed on `dev_branch`. Flutter regression suite run `44880366441` was pending with no jobs reported at the time of this checkpoint. Do not mark DISC145 complete until the targeted test and relevant CI pass, the relevant layout is visually checked, and the remaining discovery scope is reconciled.
