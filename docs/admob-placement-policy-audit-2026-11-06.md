# NIARIM Android: AdMob placement policy audit (2026-11-06)

## Scope and evidence

- Audited `dev_branch` GoRouter's 39 explicit routes, the global banner,
  `ProgressDialog`, `AdMediumRectangleMockWidget`, Google Mobile Ads
  lifecycle, premium gating, UMP consent and modal dialog overlay behavior.
- **This is a source/layout-level policy risk audit, not an AdMob review or
  a legal guarantee.** The live Galaxy layout, screen accessibility, content
  loading/empty states, every ad refresh and real Google policy enforcement
  must still be inspected before publishing production IDs.
- Official references:
  - [Google Publisher Policies: ads on screens without publisher content](https://support.google.com/publisherpolicies/answer/11112688)
  - [Ads interfering with content or user interactions](https://support.google.com/publisherpolicies/answer/11035030)
  - [AdMob: discouraged banner implementations](https://support.google.com/admob/answer/6275345)
  - [AdMob: recommended banner implementations](https://support.google.com/admob/answer/6275335)
  - [AdMob: 300x250 banner guidance](https://support.google.com/admob/answer/6293636)
  - [Google Mobile Ads Flutter banner lifecycle](https://developers.google.com/admob/flutter/banner)

## Policy decisions implemented

1. A single 320×50 top banner is placed **outside** the root Navigator, in its
   own reserved, non-overlapping layout region (SafeArea, 8dp above, 16dp
   below, a non-clickable border). Navigation among eligible routes retains
   that same BannerAd instead of mounting duplicates.
2. The route policy **fails closed**: only content-centric routes are eligible.
   Obvious menu-only, splash/navigation, forms, account, legal, configuration,
   billing, rewards, error, and action-only routes don't request a top banner.
3. Local project/share/trash lists require non-empty local content. Remote
   community feeds can still be empty/loading/error; this is **not fully
   solved by static path eligibility** and requires runtime gating/inspection.
4. A modal overlay observer suppresses production banners whenever a root
   PopupRoute (dialogs, modal bottom sheets, menus) covers publisher content.
   This includes progress alerts. The popup's 300×250 **live** ad is likewise
   disabled in release builds. This guards against ads on alert/behavior-only
   screens and background ads near/behind overlay interactions.
5. For debugging **only**, a long-running ProgressDialog can show Google
   official **test** ads simultaneously in the persistent upper banner and
   a separate 300×250 test placement. The two use distinct BannerAd objects
   and remain in disjoint layouts; tests verify both exist. This does **not**
   authorize shipping the same 2-ad popup configuration with live IDs.
6. Premium members have no routine display banners. Ads are requested only
   after UMP says requests are permitted; small screens fail closed.
   User-initiated rewarded ads remain a separate flow. Production rewarded
   coin granting is not enabled by this work.

## Route-by-route review (39 GoRouter routes)

| Route | Static assessment | Active top banner policy | Remaining concerns |
|---|---|---|---|
| `/` | Navigation-only launch (logo, two navigation actions) | **Off** | Publisher-content rule; use app-open format separately only if policy-compliant |
| `/home` | User project/work index | On when local content | Empty-state checks, export-only lists |
| `/shared` | User shared projects list | On when non-empty | Verify visible content |
| `/trash` | User trash list | On when non-empty | Avoid action-only/empty dialog overlays |
| `/community` | User-submitted works feed | Conditional on route | **Outstanding:** hide on loading, empty, login errors; check video playback |
| `/community/work/:id` | Individual work/media | Conditional on route | Check player controls and scrolling over ad; empty/removed works |
| `/new-project` | Form/action screen | **Off** | Focus/keyboard, navigation-only |
| `/project/:id` | Project detail/preview | On | Ensure preview loads and content remains visible |
| `/canvas/:id` | Animation drawing editor | On | High-frequency stylus input: verify ad separated from toolbar/canvas, orientation and DeX |
| `/timeline/:id` | Animation timeline editor | On | Same high-frequency input risks, landscape |
| `/export/:id` | Export configuration/action | **Off** | Avoid ads on action/processing-only screens |
| `/settings` | Settings navigation | **Off** | Menu-only |
| `/settings/gestures` | Settings controls | **Off** | Configuration-only |
| `/settings/shortcuts` | Settings controls | **Off** | Configuration-only |
| `/settings/performance` | Settings controls | **Off** | Configuration-only |
| `/settings/pen` | Settings controls | **Off** | Configuration-only |
| `/settings/bucket` | Settings controls | **Off** | Configuration-only |
| `/settings/workspace` | Settings controls | **Off** | Configuration-only |
| `/settings/transfer` | Transfer/actions | **Off** | Data operation controls |
| `/settings/widget` | Widget settings | **Off** | Configuration-only |
| `/settings/widget/artwork` | Widget art selection | **Off** | Selection-focused controls |
| `/settings/widget/artwork/:id` | Frame selection | **Off** | Repeated tap targets |
| `/settings/theme` | Theme settings | **Off** | Configuration-only |
| `/settings/watermark` | Watermark settings | **Off** | Configuration-only |
| `/help` | Instructions/tutorial content | Eligible | Check selected topic has substantial guidance, not just empty navigation |
| `/tips` | Tips/tutorial content | Eligible | Search-empty results; dynamic popup/dismiss actions |
| `/premium` | Purchase/paywall | **Off** | Avoid conflating ad with purchase CTA |
| `/rewards` | Rewards/action view | **Off** | Rewarded ads must be voluntary and independently verified |
| `/earn-coins` | Rewards/action view | **Off** | Ditto |
| `/membership` | Membership/action view | **Off** | CTA-only |
| `/creator-missions` | Missions/claims | **Off** | Claim controls and reward mechanisms |
| `/autofill-presets` | Preset configuration | **Off** | Configuration-only |
| `/save-tree/:id` | Saves and project data | Eligible | Empty-state, destructive actions |
| `/materials/:id` | Material browser/content | Eligible | Gallery thumbnails are interactive |
| `/settings/fonts` | Font settings | **Off** | Configuration-only |
| `/settings/error-log` | Error/diagnostic | **Off** | Error-only |
| `/settings/license` | Terms/legal | **Off** | Legal disclosure |
| `/settings/privacy-policy` | Policy/consent | **Off** | Legal disclosure |
| `/storage` | Storage/cleanup actions | **Off** | Storage controls |

## Overlay and secondary navigation review

| Surface | Debug layout | Release/live policy | Rationale |
|---|---|---|---|
| `ProgressDialog` (export, filter, GIF, WebM) | Upper test banner + test 300×250 may coexist | **Neither ad while dialog covers content** | Short-lived progress/alert-only screen; interactive cancel, scroll and tips |
| Generic `showDialog` / popup routes in root navigator | Top test ad remains mounted | Top ad suppressed while popup open | Avoid ads when underlying content is not usable |
| `MaterialPageRoute` outside GoRouter | Shares underlying top-slot policy | Further per-screen audit needed | Non-GoRouter pages may have different content/empty state |
| Fullscreen native rewarded ad | Not a banner placement | Only user-initiated with SSV; no overlay ad | Maintain Google fullscreen isolation |
| OS-level Android native launch splash | No Flutter banner yet | No banner | No usable publisher content |

## Open issues before enabling production AdMob IDs

- **Manual Galaxy/DeX QA:** portrait, landscape, narrow/short screens,
  small font/large font, Android gestures, high-frequency drawing,
  dialogs/bottom sheets, keyboard, AppBar and playback controls.
- **Dynamic feed and empty-state gating:** suppress on network error, no works,
  a removed work, no project selection, or a fullscreen viewer obscuring content.
- **Root-navigator observer coverage:** confirm nested navigators and custom
  overlays cannot leave a live banner underneath an alert/overlay.
- **Ad unit size, reload and refresh QA:** no overlap, no ad-sized layout jumps;
  test on actual hardware with Google test IDs; never force ad click.
- **Separate premium and UMP checks:** block requests while consent is required
  but not granted, and ensure Premium removes all standard ad placements.
- **App review:** Google can classify content and actual placement differently;
  passing unit tests is not an official compliance approval.

## Final status

- Debug layout for **simultaneous top + processing-popup placements**: implemented and regression-tested.
- Release/live simultaneous ads on progress alerts: **intentionally blocked**
  because official low-value/alert and interaction policies make that placement
  unsafe. A content-rich, separately designed waiting experience would require
  a new design and policy review before enabling live ads.
- All 39 routes: statically reviewed; **not all are suitable advertising
  placements**, and remote empty/overlay states need more live testing.

## Follow-up: SP / DeX responsive viewport validation (2026-11-06)

- [Successful CI run](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/42216835683):
  Flutter static analysis and targeted widget tests completed successfully.
- Tested width/height combinations in logical pixels:
  `280×640`, `319×700`, `320×568`, `360×780`, `393×852`,
  `430×932`, `640×360`, `800×440`, `480×720`, `600×800`,
  `800×600`, `1024×768`, `1280×720`, `1440×900`,
  `1920×1080`.
- Fixed banner sizes (never stretched): phone `320×50`; intermediate
  tablet/DeX `468×60`; desktop-like/DeX `728×90`. When available
  width/height is insufficient, no banner slot is mounted.
- Popup medium rectangle is not requested below its safe viewport minimum.
  Fixed a Flutter `AlertDialog` intrinsic-sizing incompatibility introduced
  by a nested `LayoutBuilder`; all targeted tests now pass.
- Hide top banners while the system keyboard is open. Root modal routes
  suppress live/release banners and the 300×250 processing ad is debug-only.
- **More conservative production policy:** `/community` and individual
  works, `/tips`, `/help`, creative canvas/timeline and materials/save
  controls are disabled until visible-content/interactive-surface-specific
  tests exist. At this stage, only nonempty local list surfaces and project
  detail have static route eligibility.
- These are **automated Flutter geometry/widget tests**, not screenshot-based
  review of each real device. Physical Galaxy, Samsung DeX and real Google
  test-ad rendering remain unverified. Publisher policy compliance cannot be
  guaranteed without reviewing actual production content, overlays and
  AdMob's final policy assessment.
