# NIARIM Audit Progress

route_version: 2026-09-09-initial-v1
route_state: locked
current_id: A001
current_status: in_progress
last_completed_id: none
next_id: A001
app_baseline: 46949156156850f8e49dcd9919ca6a7eeaf3bfac
web_baseline: 2a44dd9007e4a764e489a42a70f96ac5da6b3b8a

今回の新規Routeから開始。旧進捗の転記なし。

completed_substeps:
- A001/S1 route-policy-current-head restore: App dev_branch 97e5618fcdd4d248e5e2d85629fb800789f41798 / Web dev_branch 9491a890db7fd76ed9267e05de0665970f69b7e6、両AGENTS、locked Route、current_id=A001を確認。
- A001/S2 startup source-order review: main()→AppErrorReporter.install→font license registration→orientation→buildAppProviders→runApp、buildAppProviders内のsettings/performance/premium/ads/projectほかの逐次初期化を現行HEADで追跡。
- A001/S3 corrupt persisted-settings reproduction: existing isolated test run 34533483148 の生ログを再確認し、SettingsService.initのcustom_size_presets破損JSONとThemeService.initのtheme_current_json破損JSONがFormatExceptionで起動初期化を中断することを現行コード位置と照合してroot cause確定。正常設定を保持し、壊れた値を勝手に上書きしないというA001期待を満たさない。
- A001/S5a source-side double-init root cause: AdvertisingService.initは再呼出しでprovider再生成＋Premium listener再登録、AppErrorReporter.installはglobal handlerを再ラップすることを確認。GoogleAuthServiceには既存_initialized guardあり。Premium/Advertisingはmonetization gateにより2027-01-01前はstore/AdMob SDKへ進まないことも確認。
- A001/S5b minimal idempotence code: AppErrorReporter.installへidempotent guard（commit 5d71d158c0aae465dfa9122232ff01b52f6e18bd）、AdvertisingService.init/disposeへidempotent lifecycle guard（commit 9ea1c72c54f9d5ac73825c661c851083e484408d）を投入。まだtargeted test未完了のためA001全体はdoneにしない。

current_substep: A001/S4 + S5 verification runners queued; parallel S5c startup failure/retry lifecycle review

in_progress_substeps:
- A001/S4 persisted JSON recovery: first one-shot run 34575062904 failed safely before source commit because exact ThemeService anchor no longer matched current source shape; no product code was written by that failed run. v2 run 34575385855 is queued against latest dev_branch and will patch item/key-isolated Settings/Theme recovery, preserve raw prefs, add neighboring-theme regression, then test/analyze before commit.
- A001/S5c failure visibility/idempotence verification: run 34575561261 is queued. It adds targeted tests for AdvertisingService/AppErrorReporter double-init and changes ProjectService startup recovery catches to record errors via AppErrorReporter while preserving empty-state/corrupt-file recovery.

remaining_substeps:
- A001/S4 obtain green current-HEAD startup_settings_recovery_test + analyze; verify resulting startup-contract-audit on committed repair.
- A001/S5c obtain green idempotence/failure-visibility targeted test + analyze and verify ProjectService recovery remains non-fatal.
- A001/S5d finish fresh/warm startup and partial-bootstrap failure/retry lifecycle review, including cleanup requirements for services initialized before a later init failure; do not add retry UI without cleanup safety.
- A001/S5e verify license registration and remaining auth/project/premium startup side effects for duplicate/leak/failure reporting behavior; add only necessary targeted tests.
- A001/S6 consolidate source review + targeted tests/log evidence; only when all A001 expected conditions are verified, mark Route/Evidence done and advance A002.

blockers:
- advisor blocker: none at this checkpoint. Generic partial-bootstrap retry/cleanup is still being analyzed by Sol; no Astra packet created because a normal implementation decision has not yet exceeded Sol confidence.
- execution: GitHub hosted runners for A001/S4 v2 and S5c are currently queued. This is not treated as pass or completion.

next_action: continue S5d lifecycle/root-cause review while queued targeted runs execute; when each run starts/completes, inspect raw job logs, fix only actual failures, and checkpoint green evidence before any A001 done transition.
