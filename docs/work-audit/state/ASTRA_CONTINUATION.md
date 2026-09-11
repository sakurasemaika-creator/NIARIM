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

current_substep: A001/S4 implement minimal recovery for corrupt JSON settings and re-run targeted startup contract tests on current dev_branch
remaining_substeps:
- A001/S4 SettingsService/ThemeServiceの破損JSONを項目単位で隔離して既定値へfallbackし、保存値自体は上書きしない修正。targeted testをcurrent HEADでgreen化。
- A001/S5 fresh/warm startup・initialization failure propagation/retry・二重初期化/side-effect review（premium/ads/auth/project/license/error reporter含む）。必要なら追加targeted tests。
- A001/S6 A001のsource review + targeted tests/log evidenceをまとめ、未確認がなければRoute/Evidenceをdone同期してA002へ。

blockers:
- 現時点でadvisor blockerなし。A001/S4は通常の局所root-cause修正としてSolで実行可能。

next_action: 現行dev_branchへ破損JSON回復の最小修正を入れ、startup-contract-auditをcurrent HEADで再実行して結果をEvidenceへcheckpointする。
