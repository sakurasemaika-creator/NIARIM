# DISC145 — Long unbroken Latin folder names

Date: 2026-11-21
Branch: `dev_branch`
Implementation/test checkpoint: `c045b40abc5767866be90632fa9e3353a4f6f5f1`

## Finding

The folder detail-row title uses `KoreanWordsText`. Its non-Hangul path previously delegated directly to `Text`, which can break ordinary words at spaces but does not provide break opportunities inside a long Latin token. The second-round reproduction was French, 320px viewport, 200% text, with folder name `Storyboards (2)`, rendered as `Storybo / ards (2)`.

## Change

- Added opt-in `breakLongLatinWords` behavior to `KoreanWordsText`; enabled it only for folder detail-row titles.
- A shared helper measures tokens using the active text style, locale, direction, and text scaler. OS bold-text accessibility preference is included in the measurement.
- Token matching covers Unicode Latin script, combining marks, and numbers; splitting uses Unicode grapheme-cluster boundaries via `characters`.
- A zero-width break opportunity is inserted only inside a token wider than the available width.
- The helper is used by both the ordinary non-Hangul path and the segmented path that preserves duplicate-name marks (`copyMarks`). The duplicate mark itself remains managed by `copyMarkLineText`.
- The original name remains the semantics label. Short names and ordinary spaced text remain unchanged.
- Existing Japanese line-start restrictions and Korean word grouping remain in place.

## Regression coverage

`test/korean_words_text_long_latin_test.dart` covers:
- Seven locales: ja, en, es, fr, ko, zh-Hans, zh-Hant.
- Widths 96, 180, and 320 logical pixels.
- Text scales 1.0, 1.3, and 2.0.
- Long Unicode Latin names, grapheme-safe break opportunities, line count, text width, selection boxes, and original semantics label.
- The exact DISC145 example `Storyboards (2)` at French locale, 160 logical pixels, 200% text scale, and bold accessibility text.
- A long Latin prefix with a preserved duplicate mark, `Storyboards (copy 2)`, under the same French/160px/200%/bold condition.
- A short ordinary Latin name remains unchanged.

## Relevant commits

- Initial opt-in wrapping: `404401d3e3d2f1cd43842813ec363cf246068d19`
- Folder detail-row opt-in: `bc6d3d6d6b14e4008834c7a317da108cd0cfaaeb`
- Constructor option: `c14be3f35396713a5e7eb3e260bd3a702cbe28d3`
- Bold accessibility measurement: `5fe1fbbbf3574b57114d3cd580980c19807868fe`
- Unicode Latin/combining mark support: `e442c48f2c6b2af6ade007076f294c7864b51188`
- Seven-locale/width/scale matrix: `4f3683fac01be0759f719ae8a4c5beda8c480205`
- Exact DISC145 reproduction test: `ef46d778a750a8d29818dc6d1792402a4f474d10`
- Grapheme/duplicate-mark follow-up: `3befc76f5217d1eb099e151b6ab32b60368d78ad`, `0bb0c02270475e4e2b5536740d3ac302153e9d36`, `8f44656940f61feaf4d1ce8a2266d759d32717d7`, `c045b40abc5767866be90632fa9e3353a4f6f5f1`

## Status

Implementation and source re-fetch are confirmed on `dev_branch`. Flutter regression suite run `44881246086` targets checkpoint `3a1e6ca6` and was pending with no jobs reported at the time of recording. Run `44881226017` for the preceding checkpoint was also pending. The workflow now queues full regression runs rather than cancelling pending runs. Do not mark DISC145 complete until current CI and targeted tests pass, the relevant SP/PC layouts and screen-reader output are visually/operationally checked, and the remaining discovery scope is reconciled.
