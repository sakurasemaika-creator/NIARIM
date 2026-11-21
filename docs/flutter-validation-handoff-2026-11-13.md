# Flutter / external-service validation handoff (2026-11-13)

Target branch: **dev_branch only**. Do not modify `main` or other branches.

## Verified passes

- Whole-repository `dart format --output=none --set-exit-if-changed lib test tool` and `flutter analyze --no-pub --no-fatal-infos`, Flutter 3.47.2, passed: [Actions 43351599354](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43351599354) (see run conclusion).
- The preceding formatter/analyzer gate was definitely green: [Actions 43349476737](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43349476737).
- Full targeted desktop docking tests passed: [Actions 43350919412](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43350919412).
- Brush outline color picking contract passed without the obsolete source-rewriting script: [Actions 43350690872](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43350690872).
- Community five-icon tabs/visual matrix passed: [Actions 43348155725](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43348155725).
- Reward/advertisement Flutter contracts passed: [Actions 43345185742](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43345185742).
- FCM/API/Play-entitlement/coin/ad UI contracts passed (34 tests): [Actions 43345973494](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43345973494).
- Real Flutter/Dart read-only GET requests to deployed AWS Lambda passed: [Actions 43344271268](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43344271268).
- Android debug APK compiled: [Actions 43343113364](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43343113364) (whole workflow failed later at unrelated analyzer gate).

## Full Flutter suite still fails

The complete 4-shard run at commit `383de582` [Actions 43349873209](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/43349873209) counted **3,304 passed, 185 failed, 23 skipped**. This is a historical baseline, not a fresh count of the current HEAD, since several fixes landed later. Retrieve per-shard `flutter-shard.log` artifacts for detailed failures.

Failure categories include Home project/folder/trash/clipboard/thumbnail workflows, community search and card state, video/filters, canvas rendering, navigation smoke tests and visual capture harnesses. The first `desktop_dock_interactions_test.dart` and `desktop_dock_column_fit_test.dart` failures were reduced to zero in the targeted CI by updating obsolete legacy brush/tone/stamp test assertions to the canonical `penSubTool` panel and using production dock dimensions. Do **not** remove tests or weaken requirements merely to make a green CI badge.

## Real external-service gates NOT verified

- No Android handset is attached to this validation session; therefore interactive Google sign-in, phone auth, foreground/background FCM delivery and tap routing are not demonstrated.
- In the connected Tokyo AWS account, `niarim-api` Lambda is Active, last updated **2026-11-10**; `niarim-table` has seven ACTIVE GSIs. A read-only table Scan on 2026-11-13 found **zero items**.
- Live Lambda flags `REWARDED_AD_SSV_ENABLED=true` and `REWARDED_AD_REVIEW_APPROVED=true` are enabled. This **does not prove** Google-signed rewarded callbacks and production wallet crediting. Do not fabricate signed Google events or award spendable coins manually.
- `PLAY_PURCHASE_VERIFICATION_ENABLED=false` in the deployed Lambda. Live Play purchase, restore, subscription renewal and server verification require a configured Play Console test track, products, testers, server credentials and actual Play Billing flows. Do not enable the flag until validated.
- Current dev_branch backend changes may be newer than the deployed Lambda. Compare and deploy cautiously with explicit verification and rollback readiness; avoid unreviewed production mutations.

## Next regression priorities

1. Run the full 4-shard suite against a single *current* commit after more fixes and use the uploaded logs to group failures by their shared root cause.
2. Repair genuine app defects first. Update outdated assertions to modern UI behavior while retaining all behavior, security and persistence checks.
3. Keep whole-project analyzer/formatter green after every cluster of fixes, using Flutter **3.47.2** and locked dependencies.
4. On a connected Android phone, run Google login/FCM delivery and AdMob rewarded video → signed SSV → DynamoDB wallet readback. Then test Play Billing in a configured test track.
5. Report these real E2E checks as **unverified** until an observed receipt/token, callback, state change and account isolation prove them.
