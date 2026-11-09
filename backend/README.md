# NIARIM作品広場バックエンド

`docs/AI設計書/29_動画投稿・ランキング機能仕様.md`（特に16章）に基づく、
NIARIM作品広場のバックエンド実装。

**2026-11-06に東京リージョンへ初回デプロイ済みです。** NIARIM開発用AWSアカウント
（`368601349794`）の`NiarimBackendStack`は`CREATE_COMPLETE`、
Lambda `niarim-api`は`Active`、DynamoDB `niarim-table`と6つのGSIは
`ACTIVE`を確認済みです。GitHub Actionsの初回デプロイと
`GET /works/latest` のスモークテスト（HTTP 200）が成功しました。
[GitHub Actions実行結果](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/42163616025)。

現行のFunction URL:
`https://ibjfhyoqvfanle62ltokgz6sry0fjqfh.lambda-url.ap-northeast-1.on.aws/`

**アプリ側は別途接続設定が必要です。** Flutterの
`lib/services/api/niarim_api_config.dart` は
`--dart-define=NIARIM_API_BASE_URL=<Function URL>` を渡したビルドに限り、
作品広場の実APIを使用します。未指定のAPKはダミーデータのままです。
機能の一般公開・認証済みE2E・全APIの実環境検証は未完了です。

## 技術スタック・採用理由

- **AWS Lambda Function URL + DynamoDB**（API Gatewayは使わない、16章）
- **AWS CDK（TypeScript）**でIaC化
- **DynamoDBはProvisioned（25 RCU / 25 WCU）でAlways Free枠に収める**
  設計（PAY_PER_REQUESTは最初のリクエストから課金されるため不採用。
  詳細は`lib/niarim-backend-stack.ts`のコメント参照）
- Node.js 22.xランタイム

Cloudflare Workers（公式サイト`NIARIM-web`で既に採用）ではなくAWSを
選んだ理由は、8.1節の統計更新バッチ（DynamoDBの自己再帰ページング処理）
がCPU時間に余裕のあるLambda（最大15分）に向いており、Cloudflare
Workers無料プランのCPU時間上限（1リクエストあたり10ms）とは相性が
悪いため。詳細はセッションのやり取り、および仕様書側の議論を参照。

## デプロイ手順（以後の更新用。初回デプロイは完了）

### 前提条件

1. **AWSアカウント**（新規登録でも既存でも可。DynamoDB Always Free枠は
   アカウント単位で永続的に無料）
2. **AWS CLIの認証情報設定**（`aws configure`または環境変数）
3. **Node.js 20以上**
4. **Google Cloud プロジェクト＋OAuthクライアントID**（15章のOAuth審査
   はアプリを一般公開する前に必要。開発中はテストユーザー登録のみでも
   動作確認できる）
5. **YouTube Data APIキー**（`videos.batchGetStats`用。Google Cloud
   Consoleで「認証情報」→「APIキー」から発行し、YouTube Data API v3
   に制限しておくことを推奨）

### 手順

```bash
cd backend
npm install

# 初回bootstrapは既に東京リージョンで完了済み。再実行不要。
# 通常はGitHub Actions > Backend CI を dev_branch で手動実行し、
# 「AWSへデプロイする」を有効にする。GitHub OIDCとSecretsを使う。
# APIキーをコマンドライン・シェル履歴・Git履歴に直接書かないこと。
# FCM秘密鍵JSONはCDKコンテキストに渡さず、安全な実行時取得方式が
# 実装されるまでプッシュ通知を無効に保つ。
```

デプロイが完了すると、`ApiFunctionUrl`（アプリから叩くLambda Function
URL）と`TableName`が出力されます。

`bin/app.ts`の`env`をコメントアウトしたままだと、CLIのデフォルト
認証情報（`aws configure`で設定したアカウント・リージョン）が使われ
ます。特定のアカウント・リージョンへ固定したい場合はコメントを外して
指定してください。

### デプロイ後の確認

```bash
# 読み取りのみの疎通確認（デプロイやDB変更は行わない）
curl --fail-with-body --show-error \
  "https://ibjfhyoqvfanle62ltokgz6sry0fjqfh.lambda-url.ap-northeast-1.on.aws/works/latest"
```

## ディレクトリ構成

```
backend/
├── bin/app.ts                    CDKアプリのエントリポイント
├── lib/niarim-backend-stack.ts   DynamoDBテーブル+GSI・Lambda・EventBridgeのIaC
├── src/
│   ├── api/
│   │   ├── handler.ts            Lambda Function URLのルーター（16章）
│   │   └── routes/                各エンドポイントの実装
│   ├── batch/statsUpdate.ts      統計更新バッチ（8.1節：自己再帰ページング）
│   └── lib/                       DynamoDB・認証・YouTube APIラッパー・共通処理
└── test/                          vitestによる単体テスト（純粋関数のみ、AWS接続不要）
```

## 実装したAPIエンドポイント

| メソッド | パス                                  | 対応する仕様書の節                                                                       | 認証                                             |
| -------- | ------------------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------ |
| GET      | `/ranking/{period}`                   | 8.2節（`period=all`／`yearly`／`monthly`／`weekly`／`daily`）／`period=bookmarks`は8.5節 | 不要                                             |
| GET      | `/works/latest`                       | 8.3節・8.6節（`q`で検索）                                                                | 不要                                             |
| GET      | `/users/{id}/works`                   | 8.4節                                                                                    | 任意（本人なら非公開作品も含む）                 |
| GET      | `/works/{id}/bookmarkers`             | 21.1節（被ブックマーク一覧）                                                             | 任意（非公開設定のユーザーは除外）               |
| POST     | `/works`                              | 6章・12章・17章                                                                          | 必須                                             |
| PATCH    | `/works/{id}`                         | 13章                                                                                     | 必須（投稿者本人）                               |
| DELETE   | `/works/{id}`                         | 13章                                                                                     | 必須（投稿者本人）                               |
| PATCH    | `/works/{id}/tags`                    | 8.7節                                                                                    | 必須（追加/削除は誰でも、ロックは投稿者本人）    |
| POST     | `/reports`                            | 9章                                                                                      | 必須                                             |
| POST     | `/blocks`                             | 9章                                                                                      | 必須                                             |
| POST     | `/works/{id}/bookmark`                | 8.5節                                                                                    | 必須                                             |
| GET      | `/users/{id}/bookmarks`               | 8.5節・21.2節                                                                            | 任意（非公開なら本人のみ）                       |
| PATCH    | `/users/{id}/bookmarks-visibility`    | 8.5節                                                                                    | 必須（本人のみ）                                 |
| POST     | `/works/{id}/repost`                  | 8.5bis節                                                                                 | 必須                                             |
| POST     | `/users/{id}/follow`                  | 22.5節                                                                                   | 必須                                             |
| GET      | `/users/{id}/followers`               | 22.5節・22.7節                                                                           | 任意（非公開なら本人のみ、22.7節のフィルタ適用） |
| GET      | `/users/{id}/following`               | 22.5節                                                                                   | 任意（非公開なら本人のみ）                       |
| GET      | `/users/{id}/reposts`                 | 8.5bis節（リポスト一覧。フォロー中タブで使う）                                           | 不要（リポストは公開。非公開化された作品は除外） |
| PATCH    | `/users/{id}/follow-visibility`       | 22.5節                                                                                   | 必須（本人のみ）                                 |
| GET      | `/users/{id}/notifications`           | 22.6節                                                                                   | 必須（本人のみ）                                 |
| POST     | `/users/{id}/notifications/mark-read` | 22.6節                                                                                   | 必須（本人のみ）                                 |
| PUT      | `/users/{id}/push-token`              | 22.7節（FCM端末トークン登録／解除）                                                      | 必須（本人のみ）                                 |

## 未実装・既知の制約（デプロイ前に把握しておくべきこと）

1. **初回デプロイ済み・総合検証は未完了**：東京リージョンへの
   CloudFormation作成、Lambda/DynamoDBの稼働、公開作品一覧のHTTP 200を
   確認済み。ただしGoogleログインを伴う書き込み、動画投稿、各種通知、
   有料機能の実機E2Eは別途検証が必要。
2. **全文検索基盤は無し**：8.6節の検索は現状Lambda側での部分一致
   フィルタのみ（小〜中規模向け）。大規模化した場合はOpenSearch等への
   移行が必要（20章）。
3. **ブックマークランキングは操作時更新**：累計および
   `yearly`/`monthly`/`weekly`/`daily`はブックマーク登録・解除と
   同じDynamoDBトランザクションでスコアを更新する。期間別は日本時間の
   暦期間内に記録されたブックマークを数える。閲覧時に既存GSI2から
   上位50件を読み、実際のWORKの公開状態を強整合性で確認して
   非公開・削除済みを除外する。順位は詰めて表示する。
   定期統計バッチによる集計ではないが、GSIの結果整合性による
   短時間の反映遅延はあり得る。
4. **FCMはWorkload Identity Federationで実装済み・統合検証は別途必要**：
   `src/lib/push.ts`はAWSの短期認証情報からGoogle WIFで
   `niarim-fcm-sender`を権限借用する。秘密鍵JSONは不要。
   `FCM_PROJECT_ID`/`FCM_WIF_AUDIENCE`/
   `FCM_SENDER_SERVICE_ACCOUNT`とGoogle側の権限が未設定なら
   送信しない。通知履歴は独立して保存される。
5. **Google Play購入検証APIは実装済み・本番接続未確認**：
   `/me/premium/play/verify`でPlayの購入状態をサーバー確認するが、
   `PLAY_PURCHASE_VERIFICATION_ENABLED`とパッケージ名が
   正しく設定されるまでは購入を許可しない。Play Consoleの実商品・
   認証資格情報・テスト購入とのE2E確認は別途必要。
6. **通報レート制限の窓は固定境界**：`src/lib/reportQuota.ts`は10分窓と
   1日窓の2段構えで、いずれも固定境界（スライディングウィンドウではない）。
   窓の境目では短時間に最大2倍まで通り得るが、1回のUpdateItemで判定できる
   ぶん安価という割り切り。
7. **CI/CDはGitHub OIDCで稼働中**：
   `.github/workflows/backend-ci.yml`の`ci`ジョブ（型チェック・テスト・
   `cdk synth`）と手動`deploy`ジョブが成功済み。通常のpushでAWSへの
   デプロイは行わない。再デプロイは`dev_branch`から明示的に手動実行する。

## Google/YouTube側で別途必要な準備

15章（YouTube OAuth審査）に記載のとおり、次はこのリポジトリの外側の
作業です。

1. Google Cloudプロジェクト作成・YouTube Data API有効化
2. OAuth同意画面の設定・OAuthクライアントの作成
3. `youtube.upload`スコープの申請理由整理・Googleのアプリ確認審査

審査完了前でも、テストユーザーとして自分のGoogleアカウントを登録すれば
動作確認は可能です。

## $0運用の内訳（実測ではなく設計上の見積もり）

| リソース              | Always Free枠               | このスタックでの使用量                                                           |
| --------------------- | --------------------------- | -------------------------------------------------------------------------------- |
| DynamoDB              | 25 GB・25 RCU・25 WCU       | テーブル15+GSI6本合計8 = 23 RCU/WCU、ストレージは5章の見積もりで50万作品時約1GB |
| Lambda                | 月100万リクエスト＋40万GB秒 | APIリクエスト数・バッチ実行頻度に依存。想定ユーザー数の初期段階では十分収まる    |
| EventBridge Scheduler | 低頻度実行はごく低コスト    | 1日1回の定期実行のみ                                                             |
| Lambda Function URL   | 追加費用なし                | -                                                                                |

将来的にAlways Free枠を超えた場合の対応は`29_動画投稿・ランキング機能
仕様.md` 11.2節の段階的引き上げ方針を参照してください。


## クリエイターミッションとコイン（追加API・安全な初期設定）

- `GET /me/missions`（認証必須）: 53段階（アカウント共通39、作品ごと14）のカタログとサーバーの本人状態を返す。任意の `?workId=動画ID` を付けると本人の指定作品の達成履歴も確認できる。ブックマーク・作品公開状態などNIARIM独自データで集計し、YouTube再生数・高評価・コメント数の定期取得は行わない。
- `POST /me/missions/claim`（認証必須）: `{"missionId":"followers_10"}`、作品別ミッションは `{"missionId":"work_bookmarks_10","workId":"YouTube動画ID"}`／`{"missionId":"bookmark_rank_1","workId":"YouTube動画ID"}`。アカウント共通は各階段生涯1回、作品別は同じ段階を**作品ごとに1回**。48時間保留の報酬見積もりを固定し、ウォレットへ重複なく付与。
- **絶対に重要**: `CREATOR_MISSION_CLAIMS_ENABLED` は既定で未設定＝**false**。インフラや課金の実準備が整うまで真にしない。**制作時間ミッションは別途サーバー検証セッションが実装されるまで、仮に環境フラグを真にしても払い出せない**。
- ブックマーク・ランキングの達成報酬にはNIARIM独自のブックマーク数だけを使い、YouTubeのいいね・再生回数・チャンネル登録・YouTube由来スコアは使用禁止。
- 既存 `USER#{id}/COIN_WALLET` にコインを保存。アカウント共通履歴は `USER#{id}/MISSION_STATE_V1` のビットマスク1件、作品別は**報酬を得た作品だけ** `USER#{id}/MISSION_WORK#{workId}` を1件ずつ保存。新しいDynamoDBテーブル・GSIは不要。アカウント引き継ぎで保持。
- 新しいクライアント `/creator-missions` 画面は7ロケール対応。制作時間は既存のローカルカウンターを表示するが、無検証の値を報酬に使用しない。実際のコイン獲得ボタンは安全確認まで非表示。
- アカウント共通39段階の上限は **1,178,030コイン**、作品別14段階は各作品で達成可能なためアカウント全体では上限なし。制作50時間の報酬は**55,000コイン**（サブスク月額550円の参考単位に相当）。報酬用制作時間検証APIは未実装。1万作品達成ミッションの全件検証は未実装（現状500作品までの有界Query）。詳しくは `docs/AI設計書/13B_クリエイターミッション・コイン報酬仕様.md`。

このコードは開発用AWSへデプロイ済みですが、コイン払い出しの機能フラグは初期状態で無効です。一般公開向けの報酬運用やアプリからの認証済みE2Eが完了した状態ではありません。


## Firebase Cloud Messaging（AWSからの鍵なし送信）

FCMはFirestoreとは無関係です。Flutter端末がFCMトークンを取得し、認証済み
`PUT /users/{id}/push-token` でDynamoDBに保存します。ミッション達成時の
永続通知が記録された場合のみ、`sendPushToUser` がFCM HTTP v1へ送信します。
個別フォロー・ブックマーク操作すべてが即時通知を送る仕様ではありません。

AWS Lambdaでは長期秘密鍵を発行しません。Google Cloud
`niarim-513201` の WIF `niarim-aws-fcm/niarim-aws-lambda` を使用し、
`niarim-fcm-sender` を権限借用します。CDKの環境変数
`FCM_PROJECT_ID` / `FCM_WIF_AUDIENCE` / `FCM_SENDER_SERVICE_ACCOUNT`
には公開可能な識別子だけを設定します。GCPのWorkload Identity User権限と
`roles/firebasecloudmessaging.admin` はGoogle Cloud管理画面で設定が必要です。
AWSロール名が変更されると、WIFプロバイダの属性条件も更新が必要です。

これはAWSのLambda実行環境での認証と、Android端末のバックグラウンド受信を
含めた統合テストが必要な実装です。プッシュが送れなくてもDynamoDBの
通知履歴は保存されます。サービスアカウントのJSON秘密鍵をGitHub Secretsや
CDK contextへ登録しないでください。
