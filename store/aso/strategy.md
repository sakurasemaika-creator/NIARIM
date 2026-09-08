# NIARIM Global ASO Strategy

This document is the operating brief for store discoverability and conversion. `store/aso/metadata.json` is the source of truth for localized store copy; this file defines how that copy and store creative should be evaluated after launch.

## Positioning

NIARIM should consistently own the intersection of **drawing + animation creation** rather than presenting itself as only a drawing app or only a video editor. Search wording may vary by locale, but claims must remain grounded in shipped product behavior.

Primary user intents:

1. Draw / illustration / painting
2. Frame-by-frame / hand-drawn animation
3. Animation creation workflow: layers, timeline, frames
4. Creator workflow and export

Avoid keyword stuffing, competitor names, ranking claims, pricing claims in discovery copy, and features that are not available in the shipped build.

## Localization coverage

Maintain native store copy for:

- Japanese (`ja-JP`)
- English / US (`en-US`)
- Simplified Chinese (`zh-CN`)
- Traditional Chinese (`zh-TW`)
- Korean (`ko-KR`)
- French (`fr-FR`)
- Spanish (`es-ES`)

Do not mechanically translate search terms between locales. Update keywords and short copy from locale-specific search/query data once the stores provide enough traffic.

## Screenshot conversion sequence

Use real in-app captures. Localize headline text, but keep the visual story consistent enough that experiments can be compared across markets.

1. **Core promise** — drawing that becomes animation
2. **Frame-by-frame creation** — show frames/timeline clearly
3. **Drawing workflow** — brushes, layers, selection and canvas
4. **Precision tools** — use a real example such as pixel-mode work when it helps the target audience
5. **Motion workflow** — show animation/timeline capability actually present in the current build
6. **Finish and share** — show the real export/output flow

The first two screenshots are acquisition assets, not documentation: one idea per image, large localized headline, minimal secondary text. Never composite UI states that cannot exist in the app.

## Experiment order

Change one major variable per experiment so the result is interpretable.

1. First screenshot promise
2. Second screenshot proof of animation workflow
3. Short description / subtitle value proposition
4. Screenshot order
5. Locale-specific keyword set

Keep a control. Record start/end date, locale, store surface, variant, impressions, product-page views, installs, and downstream retention before adopting a winner.

## KPI ladder

Discovery:
- Search impressions / store impressions
- Search terms or acquisition source where available
- Web organic landing sessions by locale

Conversion:
- Product page view rate
- Store listing conversion to install
- Screenshot / product-page experiment lift

Quality after acquisition:
- First project creation
- First drawing action
- First animation/timeline action
- Export completion
- D1 / D7 retention where available

A keyword that increases installs but produces materially worse activation or retention is not automatically a win.

## App Store specific

- Keep app name and subtitle concise and localized.
- Apple keyword content is byte-limited; CI validates UTF-8 bytes, not only character count.
- Keep the localized description current because it is also used by web search after release.
- Review App Tags in App Store Connect when available for the target storefront; keep only tags that accurately describe NIARIM.
- Use product-page optimization/custom pages only when there is enough traffic to measure a meaningful conversion difference.

## Google Play specific

- Keep title, short description and full description natural and feature-accurate; do not repeat keyword lists.
- Use localized store listing experiments once traffic is sufficient.
- Treat the short description and first screenshots as one conversion unit: they should communicate the same primary promise.

## Web → store loop

SEO pages and store pages must use the same product vocabulary. The website should capture broad informational intent (drawing animation, frame-by-frame workflow, features/help) and then lead qualified visitors to the relevant store page when store URLs are available. Store campaigns should link back to canonical localized web pages for support, feature education, privacy and trust.

## Release checklist

Before a public store release:

- Run `python tools/validate_aso_metadata.py`.
- Confirm every localized statement still matches the shipped build.
- Capture current production UI for screenshots; do not reuse obsolete UI.
- Confirm support/privacy/marketing URLs use the final branded production domain.
- Check App Store / Play Console previews for truncation in every locale.
- After release, establish a baseline before changing multiple acquisition assets at once.
