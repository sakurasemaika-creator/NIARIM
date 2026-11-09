# AdMob 10コイン付与：アカウント承認前の検証結果

検証日：2026-11-09（JST）
対象：NIARIM `dev_branch`。本番AWSアカウントのユーザー残高には触れていない。

## 結果の要約

| 検証対象 | 状態 | 証拠 |
|---|---|---|
| 有効なECDSA署名付きSSVと10コイン加算のAPI処理 | PASS（暗号鍵はテスト用） | [Backend CI](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/42545545490) |
| 署名・広告ユニット・報酬数量・ユーザーセッションの改ざん拒否 | PASS | 同上 |
| GoogleのSSV URL接続確認（ユーザー未紐付け、付与0） | 以前AdMob管理画面で確認済み | Google側の確認表示をユーザーが確認 |
| DynamoDB Localへの原子的な+10コイン付与 | PASS | [DynamoDB Local integration](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/42545545430) |
| 同一GoogleトランザクションID再送・他ユーザーの受領記録 | PASS（重複支払いなし） | 同上 |
| 日次付与上限到達・取り消し後の残高不変 | PASS（テストのみ1件/日） | 同上 |
| 本番AdMobの実際の動画再生→Google本物のSSV→本番AWSの10コイン | **未検証** | アカウント・アプリ審査および実機テスト待ち |
| 本番サーバーへの今回のDynamoDB式修正デプロイ | **未実施** | 現在のCloudFormationは `UPDATE_ROLLBACK_COMPLETE` |

## 検証で発見・修正した不具合

`backend/src/api/routes/rewardedAd.ts` の日次付与カウンターを更新するDynamoDBトランザクションで、予約語 `ttl` と `consumed` を直接参照していた。
DynamoDB Localはそれぞれ `ValidationException` を返し、正規のコイン付与ができなかった。
両方を `ExpressionAttributeNames` で安全に参照するよう修正し、実際のトランザクションに成功したことを確認。

関連する保護を維持：
- SDKの `onUserEarnedReward` はローカルで残高を変更しない。
- 公開鍵によるECDSA署名・オファー・10 coins・本番広告ユニット照合を必須とする。
- サーバーが発行した未使用nonceのみをDynamoDBトランザクションで消費する。
- 全ユーザーで共有する `ADMOB_TX` 受領キーで二重付与を防ぐ。
- セッション消費・日次上限・履歴・残高加算は単一の `TransactWrite` にまとめる。
- テスト広告のデモユニットは本番コイン付与の有効化条件を満たさない。

## 現在の本番AWS設定（確認：2026-11-09）

- Lambda `niarim-api`: `Active`, `LastUpdateStatus=Successful`。
- 広告ユニットID `ca-app-pub-4380578821900659/6321761453`：再登録済み。
- `REWARDED_AD_SSV_ENABLED=false`。
- `REWARDED_AD_REVIEW_APPROVED=false`。
- `REWARDED_AD_DAILY_LIMIT`：空欄。
- 既存APIと無関係なCloudFormationリソースを一括デプロイすることは避けた。
- AWS本番のコイン残高やログイン情報、AdMob本番視聴をテストに流用していない。

## 本番解禁前に必要なこと

1. AdMobアカウント承認とストア連携・NIARIMアプリのAdMobレビュー完了を確認する。
2. Googleの本番広告ユニット・報酬 `10 coins`・SSVコールバック登録が保持されていることを再確認する。
3. 報酬経済の上限をユーザーと確定し、`REWARDED_AD_DAILY_LIMIT` に1〜500の範囲で設定する。テストの `1` や `10` は本番値を意味しない。
4. `dev_branch` の修正が実際にAWS Lambdaへ反映されるよう、CloudFormationの未整理差分を安全に解消する。現在のコードとデプロイ中コードを同一視しない。
5. 実機の **AdMobテストデバイス設定を使用した** エンドツーエンド検証を実施する。デモ広告の視聴だけでは、本番の署名付き通知を完全には検証できない。
6. 付与先アカウント・報酬履歴・二重通知・遅延・上限を検証した後、必要最小限の対象で本番付与フラグを有効化する。疑わしい場合は再度無効化する。

現在のガードは意図的に閉じたまま。承認待ちの間に本番の利用者へ誤って10コインを付与しない。
