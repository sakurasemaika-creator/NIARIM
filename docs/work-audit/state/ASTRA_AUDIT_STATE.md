# NIARIM Audit Evidence

今回の新規Routeの実検証だけを記録する。旧監査からの完了引継ぎなし。

## Bootstrap

- 両AGENTS・ASTRA_WORK・全品質基準を確認。
- 現行App/Webのrouter、直接遷移、screen/widget、state/input、全default資産、filter/effect/command、API、native/runtime/sourceを棚卸し。
- 全要件とsourceの割当はAUDIT_INVENTORY.json、固定順序と定義hashはAUDIT_ROUTE_LOCK.json。
- coverage検査結果はAUDIT_COVERAGE_CHECK.jsonへ保存する。構造coverageであり実機能の合格ではない。
- 実監査は全件todoから開始。

## A001 — 起動サービス・初期化契約（非UI）

status: in_progress

### A001/S1 restore + current-head precondition

- App dev_branch observed HEAD: `97e5618fcdd4d248e5e2d85629fb800789f41798` before this checkpoint; Web dev_branch observed HEAD: `9491a890db7fd76ed9267e05de0665970f69b7e6`.
- locked Route version `2026-09-09-initial-v1`; continuation current_id was A001/todo. No previous Route item was promoted to done.
- baseline→current App compare is ahead by 144 commits. Scope-bounded A001-relevant additions include `.github/workflows/startup-contract-audit.yml` and `test/startup_settings_recovery_test.dart`; unrelated Canvas/Prism/etc changes were not used to reorder Route.

### A001/S2 current startup source review

- `main()` order at observed HEAD: `WidgetsFlutterBinding.ensureInitialized()` → `AppErrorReporter.install()` → bundled font license registration → orientation preference → `await buildAppProviders()` → `runApp(MultiProvider(...))`.
- `buildAppProviders()` initializes services sequentially beginning with SettingsService, PerformanceService, PremiumService, AdvertisingService, ProjectService; later brush/tone/stamp/filter/theme/autosave/preset/material/automation/shortcut/workspace/watermark/font/tooltip/palette/work-folder/home-widget/auth/community/share/undo wiring.
- monetization gate is local-time `DateTime(2027, 1, 1)`; A001 later substep must verify startup side effects stay consistent with campaign-disabled ads/IAP before this date.

### A001/S3 corrupt persisted-settings reproduction + root cause

- Existing dedicated workflow run `34533483148` at commit `93a289c0acadc1b86fbcaf81c1200b24bc02c3d5` was inspected as raw run/job logs rather than accepted as audit completion.
- Job `startup-contracts` / step `Reproduce pre-fix corrupt settings failure` failed while `flutter pub get --enforce-lockfile` succeeded.
- Test `a damaged size preset must not prevent loading valid settings` failed with `FormatException` from `jsonDecode` in `SettingsService.init` (`settings_service.dart:557`, then init line 559) when one entry in `custom_size_presets` was `{broken`.
- Test `damaged current theme falls back without overwriting saved JSON` failed with `FormatException` from `jsonDecode` in `ThemeService.init` (`theme_service.dart:336`) when `theme_current_json` was `{broken`.
- Current source review confirms SettingsService maps every persisted size preset through unguarded `jsonDecode`/`CanvasSizePreset.fromJson`, so one corrupt item aborts all settings initialization. ThemeService likewise has an unguarded current-theme JSON decode on this path.
- Expected contract from Route A001 is not met: corrupted persisted setting must not make startup unrecoverable, valid neighboring settings/assets must remain available, and recovery must not silently overwrite the damaged persisted value.

root_cause: persisted structured settings are decoded as an all-or-nothing startup operation instead of item/key-isolated recovery. A single malformed JSON value escapes `init()`, aborts `buildAppProviders()`, and prevents `runApp`.

### A001/S4 repair execution state

- First repair workflow run `34575062904` checked out current `dev_branch`, completed dependency setup, then stopped at the source-shape guard `theme preset list anchor changed`. The guard fired before formatting/tests/commit, so the failed run made no product-code commit. This is execution evidence only, not a product test failure.
- Current ThemeService was re-read after the stop and still had the same unguarded saved-preset/current-theme decode semantics; the failure was whitespace/source-shape anchoring rather than an already-fixed product path.
- v2 repair commit `9bf9ffe69521e0c13350f58e5e9a31379f357067` contains a safer current-shape one-shot. Run `34575385855` is queued and is not counted as pass. Intended verified change remains item/key isolation, preserved raw SharedPreferences values, and a valid-neighbor saved-theme regression case.

### A001/S5 startup side-effects / duplicate initialization findings

- `PremiumService.init()` reads persisted purchase state first. Before monetization is enabled or on unsupported runtime it returns without obtaining `InAppPurchase.instance`, so current campaign startup does not initiate Billing. When store startup is enabled it owns a purchase-stream subscription and therefore must not be duplicated by a retry path.
- `AdvertisingService.init()` created a new provider every call and registered `_onPremiumChanged` every call. Repeated init on the same instance therefore duplicated a long-lived listener even while monetization was gated off. `dispose()` removed only one registration. This violates A001's no-double-initialization condition.
- `AppErrorReporter.install()` had no idempotence guard. Calling it again captured its own already-installed Flutter handler as `previousOnError`, nesting wrappers and duplicating error recording on later Flutter errors. This also violates no-double-initialization.
- `GoogleAuthService.init()` already has an `_initialized` guard, so this specific double-init failure is not present there.
- `ProjectService.init()` intentionally recovers from a corrupt individual `.niapro` by skipping it and from outer storage access failure by continuing empty, but both startup catch paths used `catch (_)`, making these recoverable failures invisible to the application reporter. That conflicts with A001's failure-not-silently-swallowed condition.

### A001/S5 minimal fixes currently awaiting targeted verification

- Commit `5d71d158c0aae465dfa9122232ff01b52f6e18bd`: `AppErrorReporter.install()` now returns after the first install, preventing global Flutter/Platform handlers from being wrapped repeatedly.
- Commit `9ea1c72c54f9d5ac73825c661c851083e484408d`: `AdvertisingService` now guards successful initialization and only removes/hides initialized resources on dispose, preventing repeated Premium listener registration/provider setup on the same service instance while leaving a failed init retryable.
- One-shot run `34575561261` is queued to add deterministic duplicate-init tests for AdvertisingService and AppErrorReporter, record ProjectService startup failures through `AppErrorReporter.record` while keeping the existing recovery behavior, format, run targeted tests, and analyze the touched files. It is not counted as pass until raw job evidence is reviewed.

### A001/S5d partial-bootstrap retry risk

- Current `main()` awaits the full `buildAppProviders()` before `runApp`. An exception from a later initializer can therefore leave no product UI/retry surface.
- Adding a Retry UI alone would be unsafe: `buildAppProviders()` constructs and initializes services sequentially, and a failure after an earlier service has attached a stream/listener can leave that partial service graph alive. A second build attempt could then duplicate side effects (notably purchase subscriptions or other global/listener ownership) unless partial initialization is rolled back/disposed.
- Therefore A001/S5d is explicitly reviewing failure UI together with partial-bootstrap cleanup/ownership. No retry UI is accepted until that lifecycle is deterministic.

next_action: inspect queued S4/S5 raw job evidence when runners execute; continue the partial-bootstrap cleanup design and remaining license/auth/premium/project side-effect checks in parallel. A001 remains in_progress and no advisor request is pending at this checkpoint.
