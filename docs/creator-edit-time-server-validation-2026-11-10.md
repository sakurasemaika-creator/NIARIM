# 制作時間ミッションのサーバー計測と限定的な検証（2026-11-10）

対象は `dev_branch`。通常の端末内プロジェクト制作時間（`totalWorkSeconds`）を
サーバー報酬に使用**しない**。

## 実装したもの

- `POST /me/missions/edit-session` start/checkpoint の認証済み
  ユーザー専用セッション。開始時間・前回チェックポイント時刻はサーバーが発行
- UUIDの開始nonceによる冪等開始、連番による二重付与防止、DynamoDB revision
  条件付き書込、最長20分の連絡途絶を失効扱い
- 認める秒数は **サーバー実経過秒、端末が申告した活動秒、
  コミット済み操作件数×180秒、900秒/回、1日8時間** の最小。
  端末の積算制作時間をそのまま信用しない
- `CREATOR_EDIT_TIME_VERIFICATION_ENABLED=true` と
  `CREATOR_EDIT_TIME_VERIFICATION_REVIEW_APPROVED=true` が
  `CREATOR_EDIT_SESSION_PILOT_ENABLED=true` と併用された場合に限り、
  **有効化後の新しいチェックポイント**の秒数を
  `verifiedEditSeconds` に加算。候補時間は遡って付与しない
- `GET /me/missions` の `editTimeVerificationReady`、
  `eligible`、`rewardEnabled` に反映。
  `POST /me/missions/claim` はこのサーバー保存秒数だけを使い、
  48時間保留の後、ウォレットとの原子的取引で報酬を付与する
- ミッション支給にはさらに
  `CREATOR_MISSION_CLAIMS_ENABLED=true` と
  `CREATOR_MISSION_CLAIMS_REVIEW_APPROVED=true` が必要
- CDK context:
  `creatorEditSessionPilotEnabled`,
  `creatorEditTimeVerificationEnabled`,
  `creatorEditTimeVerificationReviewApproved`。
  **どれもデフォルトはOFF**。端末ビルドは
  `--dart-define=NIARIM_EDIT_SESSION_PILOT=true` を指定する

## 残るセキュリティ上の限界（重要）

本機能は「デバイスが作った任意の累計秒数」を使わずサーバー時計で上限を検証するが、
端末が送る `activeSeconds` と `meaningfulMutations` 自体は偽造できる。
サーバーはローカルキャンバスの描画を実見していない。
したがって、**実際に人が絵を描いた証拠だとは断定できない**。
完全な不正対策には、例えば安全なデバイス証明や信頼済みのサーバー側
編集証跡が必要。これらを設計・検証して運営が承認するまでは
`creatorEditTimeVerificationReviewApproved` をOFFに保つこと。
この理由で「コード上の受取経路の完成」と「誰でも安全に本番支給可能」は別。

## 検証

`backend/test/creator-edit-session.test.ts` および
`backend/test/creator-mission-api.test.ts` で二重承認、
最長実経過秒、リプレイ時ゼロ加算、編集時間だけでの初回受取保留、
クライアントの勝手な累計制作時間が無視されることを検証。
