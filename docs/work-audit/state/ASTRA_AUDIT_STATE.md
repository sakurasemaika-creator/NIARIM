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

next_action: implement minimal item/key-level recovery for these corrupt JSON settings, preserve raw persisted values, rerun targeted startup contract tests on current `dev_branch`, then continue S5 side-effect/failure/retry/double-init review.
