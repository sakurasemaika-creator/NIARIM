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

| メソッド | パス                     | 対応する仕様書の節                                                                       | 認証                                             |
| -------- | ------------------------ | ---------------------------------------------------------------------------------------- | ------------------------------------------------ |
| GET      | `/ranking/{period}`      | 8.2節（`period=all`／`yearly`／`monthly`／`weekly`／`daily`）／`period=bookmarks`は8.5節 | 不要                                             |
| GET      | `/works/latest`          | 8.3節・8.6節（`q`で検索）                                                                | 不要                                             |
| GET      | `/users/{id}/works`      | 8.4節                                                                                    | 任意（本人なら非公開作品も含む）                 |
| POST     | `/works`                 | 6章・12章・17章                                                                          | 必須                                             |
| PATCH    | `/works/{id}`            | 13章                                                                                     | 必須（投稿者本人）                               |
| DELETE   | `/works/{id}`            | 13章                                                                                     | 必須（投稿者本人）                               |
| PATCH    | `/works/{id}/tags`       | 8.7節                                                                                    | 必須（追加/削除は誰でも、ロックは投稿者本人）    |
| POST     | `/reports`               | 9章                                                                                      | 必須                                             |
| POST     | `/blocks`                | 9章                                                                                      | 必須                                             |
| POST     | `/works/{id}/bookmark`   | 8.5節                                                                                    | 必須                                             |
| GET      | `/users/{id}/bookmarks`  | 8.5節・21.2節                                                                            | 必須（本人のみ）                                 |
| POST     | `/works/{id}/repost`     | 8.5bis節                                                                                 | 必須                                             |
| POST     | `/users/{id}/follow`     | 22.5節                                                                                   | 必須                                             |
| GET      | `/users/{id}/following`  | 22.5節                                                                                   | 必須（本人のみ）                                 |
| GET      | `/users/{id}/followers`  | フォロワー一覧を25件ずつ取得（次のページは `cursor`）                                    | 必須（本人のみ）                                 |
| GET      | `/users/{id}/reposts`    | 8.5bis節（リポスト一覧。フォロー中タブで使う）                                           | 不要（リポストは公開。非公開化された作品は除外） |
| PUT      | `/users/{id}/push-token` | 22.7節（FCM端末トークン登録／解除）                                                      | 必須（本人のみ）                                 |
| GET/POST | `/admin/...`             | 通報の管理API（下の「作品広場の通報対応」）                                              | 必須（GoogleのIDトークン＋SSMの管理者リスト）    |
| GET/POST | `/triage-bot/...`        | 通報の判定ボット（下の「Claudeのサブスクリプションでの判定」）                           | 必須（管理ページで作る判定用のトークン）         |

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
   `deploy`ジョブは`cdk deploy`の前に本番のLambdaの環境変数を読み、
   オパール・報酬の設定を`cdk.json`で上書きしないか確かめる
   （`scripts/assert-live-coin-config.mjs`）。読むのはデプロイ用のロール
   （`AWS_DEPLOY_ROLE_ARN`）自身なので、そのロールに次の権限が要る
   （CDKのlookup roleは`kms:Decrypt`を禁じているので環境変数を読めない）：

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "ReadLiveLambdaConfigForDeployGuard",
         "Effect": "Allow",
         "Action": "lambda:GetFunctionConfiguration",
         "Resource": [
           "arn:aws:lambda:ap-northeast-1:368601349794:function:niarim-api",
           "arn:aws:lambda:ap-northeast-1:368601349794:function:niarim-reward-ad-revenue"
         ]
       }
     ]
   }
   ```

   読めなければデプロイの前に止まり、ログに足りない権限を出す。

   CloudFormationが実際にAWSを操作するCDKの実行ロール
   （`cdk-hnb659fds-cfn-exec-role-368601349794-ap-northeast-1`）は、NIARIMのLambda
   ごとに許す絞った権限で動いている。**新しい名前のLambda（`functionName`）を足したら、
   その関数のARNを実行ロールのLambdaの許可（イベントソースマッピングの
   `lambda:FunctionArn`の条件があればそこも）に足してからデプロイすること**。足さないと
   `cfn-exec-role … is not authorized to perform: lambda:GetFunction`で作成に失敗し、
   スタックは元に戻る（2026-11-25の`niarim-moderation-worker`で実際に起きた）。

## Google/YouTube側で別途必要な準備

15章（YouTube OAuth審査）に記載のとおり、次はこのリポジトリの外側の
作業です。

1. Google Cloudプロジェクト作成・YouTube Data API有効化
2. OAuth同意画面の設定・OAuthクライアントの作成
3. OAuth 同意画面に `youtube.upload`（動画・サムネイルの投稿）と `youtube.readonly`（本人のチャンネル情報と投稿動画の所有・公開状態の確認）を登録し、それぞれの利用理由を添えて Google のアプリ確認審査を申請する。チャンネル情報の手動更新では読み取り権限のみを要求する。

審査完了前でも、テストユーザーとして自分のGoogleアカウントを登録すれば
動作確認は可能です。

## $0運用の内訳（実測ではなく設計上の見積もり）

| リソース              | Always Free枠               | このスタックでの使用量                                                          |
| --------------------- | --------------------------- | ------------------------------------------------------------------------------- |
| DynamoDB              | 25 GB・25 RCU・25 WCU       | テーブル15+GSI6本合計8 = 23 RCU/WCU、ストレージは5章の見積もりで50万作品時約1GB |
| Lambda                | 月100万リクエスト＋40万GB秒 | APIリクエスト数・バッチ実行頻度に依存。想定ユーザー数の初期段階では十分収まる   |
| EventBridge Scheduler | 低頻度実行はごく低コスト    | 1日1回の定期実行のみ                                                            |
| Lambda Function URL   | 追加費用なし                | -                                                                               |

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
永続通知と、投稿・公開（予約公開を含む）の通知をFCM HTTP v1で本人に送ります。
投稿・公開とミッションの通知はDynamoDB Streamsで処理します。通知条件と実機確認は [FCM運用手順](../docs/FCM_プッシュ通知_導入・実機確認.md) を参照してください。

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

### ストリーム処理の失敗を確認・再処理する

API・予約公開・広告収益集計のLambdaは、既存のCloudWatchロググループに30日の保持期間を適用します。

通知ストリームで最大4回の再試行または15分の最大経過時間に達したレコードは、
CloudFormation出力 `NotificationStreamFailureBucket` に示すS3バケットへ保存されます。
`aws/lambda/` 配下のJSONには失敗理由と元のDynamoDBイベントが含まれます。
バケットは非公開で、保存から7日を過ぎたオブジェクトはS3のライフサイクルで削除されます。
レコードには利用者の情報が含まれるため、確認時はアクセス権限のある運用環境で扱います。

1. JSONの `requestContext` と `payload` を確認し、CloudWatchの関数ログと照合します。
2. 原因を解消した後、対象レコードを再処理できる場合は `payload` のJSON文字列を展開し、元の `Records` を持つイベントとして対象のLambdaを同期呼び出しします。関数エラーがなく、レスポンスの `batchItemFailures` が空であることを確認します。
3. FCM送信が既に試行された通知は、重複防止のため同じレコードを再処理しても再送されません。通知履歴と送信状況を確認し、再処理の結果を記録します。

### 作品広場の通報対応

通報は作品またはアカウントを対象とし、ログインした利用者から `POST /reports` で受け付ける。
通報の内容は公開APIからは取り出せない。運営はブラウザーの管理ページ（Webサイトのリポジトリで作る
`https://niarim.miranima-studio.com/admin/`）から、下の管理APIで確認・対応する。
仕組みはすべて既存のテーブルとキー（通報は `WORK#{id}` / `USER#{id}` の下、状態の一覧はGSI7）の上にあり、
GSI・テーブルは増やしていない（`CAPACITY_PLAN` は変わらない）。

#### 自動の一時非掲載・投稿の停止

- **一時非掲載**：1つの作品に、未対応（pending・reviewing）の通報をした**別々のアカウントが3人**に達すると、
  確認が終わるまで作品を非掲載にする（`moderationHidden: true` と `moderationAutoHidden: true`）。
  AIの判定が「重大（critical）」のときも同じく一時非掲載にする（`moderationAutoHiddenReason: "ai"`）。
  非掲載は既存の `moderationHidden` なので、公開の一覧・検索・ランキング・詳細・通報の対象からは今までどおり外れる。
- **「対応不要（dismiss）」**にすると、その作品の未対応の通報をすべて完了にし、自動で隠した作品は掲載に戻す
  （運営が自分で非掲載にした作品は戻さない）。
- **「非掲載（hide）」**にすると、作品を非掲載のままにし、投稿者に**違反1回（strike）**を数える
  （同じ作品で2回は数えない）。違反が**3回**になると、その投稿者の作品広場への投稿を自動で停止する
  （ユーザーの `postingSuspended: true`、`postingSuspendedBy: "auto"`）。
- 停止中のアカウントは `POST /works`（新しい投稿）と `PATCH /works/{id}` で非公開→公開に戻す操作が
  **403・`code: "POSTING_SUSPENDED"`** になる（アプリは7言語で、異議はお問い合わせフォームかメールで、と出す）。
  非公開にする・メタデータを直すことはできる。
- 異議（お問い合わせフォーム・メール）を認めたときは、管理APIの `unhide`（作品を戻し、その作品の違反を取り消す。
  自動の停止は違反が3回未満に戻れば一緒に解除）や `unsuspend`（手動で解除、`resetStrikes` で違反の回数も0に）を使う。

数値は `cdk.json` の `context`（または `cdk deploy -c 名前=値`）で変え、デプロイし直すと反映される。0にするとその仕組みを止める。

| context名                          | 既定      | 意味                                                                |
| ---------------------------------- | --------- | ------------------------------------------------------------------- |
| `moderationReportHideThreshold`    | `3`       | 一時非掲載にする、未対応の通報をした別々のアカウントの数            |
| `moderationStrikeSuspendThreshold` | `3`       | 投稿を自動で停止する違反の回数                                      |
| `moderationAiMode`                 | `backlog` | AIの判定：`off`／`always`（毎回）／`backlog`（溜まったときだけ）    |
| `moderationAiBacklogThreshold`     | `20`      | `backlog` で、未対応（pending）の通報がこの件数以上の間だけAIで判定 |
| `moderationAiDailyCap`             | `50`      | AIの判定の1日（日本時間）の上限                                     |
| `moderationMailDailyCap`           | `30`      | 通報のお知らせメールの1日（日本時間）の上限                         |

#### お知らせメールとAIの判定（通報の後で動く）

通報が保存されると、テーブルのDynamoDB Streamsの2つ目の読み手 `niarim-moderation-worker`
（`src/batch/moderationWorker.ts`、通報の追加だけを受け取る）が、通報者の数の確認・AIの判定・メールを行う。
`POST /reports` はこれを待たず、メール・AIが失敗しても通報は失敗しない。Streamsは1つずつ順に処理されるので、
通報が集中してもアカウントの小さな同時実行枠（10）をAPIから奪わない。

- **メール**：`support@miranima-studio.com` へ、件名の先頭が **`[NIARIM通報]`** のメールを送る
  （Resendを使い、差出人は `NIARIM <support@miranima-studio.com>`）。メールソフトでこの件名で振り分けられる。
  本文は日本語で、理由・作品名・YouTubeのリンク・通報した人数・状態・AIの判定・管理ページのURL。
  通報者のIDは書かない。**同じ作品（アカウント）について1時間に1通**、**1日30通まで**。上限を越えたら
  その日に1度だけ「`[NIARIM通報]多数の通報があります`」を送り、以降はメールせずに通報だけ保存する。
- **AIの判定**：Claude（`claude-opus-5-5`、思考は自動・effort `low`、決まった形のJSONで返す）が、
  通報の理由と作品の公開情報（題・概要・タグ・YouTubeのサムネイル）から
  重大度（`critical`〜`none`）・分類・推奨（`hide`／`keep`／`review`）・短い理由（日本語）を返し、通報に保存する。
  通報者・投稿者のIDは送らない。判定はあくまで参考で、決めるのは運営。安全のための判定の拒否
  （`stop_reason: "refusal"`）は、まずAnthropicのおすすめのモデルで自動でやり直し（`fallbacks: "default"`）、
  それでも断られたら「人の確認が必要」として残す。1件の通報につき1回、1日50件まで。
  既定の `backlog` では、未対応の通報が20件以上たまっている間だけ判定する。
- **費用の目安**：1件あたり入力約1,500トークン（画像を含む）・出力300〜800トークン（思考を含む）で、
  Claude Opus 5.5（入力$4・出力$20／100万トークン）では1件$0.01〜0.02（約2〜3円）。上限の50件／日に達しても
  1日$1前後（約150円）まで。既定の `backlog` では通報が20件以上たまらない限り呼ばないので、通常は0円。
  Claude Consoleでワークスペースの使用量の上限も設定しておくと安全。Resendは既存のWebサイトのアカウントを使う。
  APIキーを置かず、所有者のClaudeのサブスクリプションで判定することもできる（次の節）。

#### Claudeのサブスクリプションでの判定（APIキーなし）

Claude APIのキーが無くても、所有者のClaudeのサブスクリプションで通報を判定できる。どちらも
APIの判定と同じ決まり（`src/lib/moderationAi.ts` の `TRIAGE_GUIDELINES`）・同じ形の `aiTriage` を通報に保存し、
`source` で出どころを見分ける（`api`＝APIキーの判定、`subscription`＝判定ボット、`chat`＝チャットから貼り付け。
この項目の無い古い判定はAPIのもの）。

- **自動の下見（判定ボット）**：決まった時刻に動くClaude Codeのセッション（クラウド）が、判定用のトークンで
  `GET /triage-bot/reports` から未判定の通報を読み、1件ずつ `POST /triage-bot/reports/{reportId}/triage` で
  判定を書く。トークンは管理ページで作る（`nrtb_` で始まる。**作ったときに1度だけ表示**され、保存されるのは
  SHA-256のハッシュだけ）。作り直すと前のトークンは使えなくなり、取り消しもできる（ほかのLambdaの
  コンテナは最長30秒前の設定を覚えている）。最後に使った時刻（10分ごと）は管理ページに出る。
- **チャットで判定（ボタン）**：管理ページの `GET /admin/triage/prompt` が、決まり・通報・答えの形を1つにまとめた
  文を作る。Claudeのチャットに貼り、返ってきた ` ```json ` のコードブロックを `POST /admin/triage/results` で
  貼り戻す（1件ずつ反映し、失敗した通報だけ理由のコードを返す）。

判定ボットができるのは、**未対応（pending・reviewing）で、まだ判定の無い（または判定に失敗・拒否された）通報を
読むことと、参考の判定を書くことだけ**。通報者・投稿者のNIARIMのIDは渡さない（渡すのは理由・作品の公開情報・
チャンネル名・通報した人数）。判定は参考で、決めるのは運営。ただし作品への判定が **重大（critical）** のときは、
APIの判定と同じく確認が終わるまで一時非掲載にする（`moderationAutoHiddenReason: "ai"`。すでに非掲載の作品は
そのまま）。対応済みの通報・判定済みの通報には書けない（`REPORT_RESOLVED`・`ALREADY_TRIAGED`。同時に2つ書いても
1つ目だけが残る）。お知らせメールは送らない（判定は管理ページの通報に出る）。

| メソッド | パス                                    | 認証                                       | 本文（JSON）                                                                           | 返すもの                                                                                                                                                                                                                         |
| -------- | --------------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GET      | `/triage-bot/reports?limit=`            | `Authorization: Bearer <判定用のトークン>` | -                                                                                      | `{guidelines, outputFormat, reports: [TriageReport]}`。未判定の通報を古い順に、`limit`は1〜50（既定20）。`guidelines`は判定の決まり、`outputFormat`は1件の判定のJSON Schema                                                      |
| POST     | `/triage-bot/reports/{reportId}/triage` | `Authorization: Bearer <判定用のトークン>` | `{severity, category, recommendedAction, rationale}`                                   | `{ok: true, autoHidden}`（`autoHidden`＝この判定で一時非掲載にしたか）。保存する判定の`model`は`claude-subscription`、`source`は`subscription`                                                                                   |
| POST     | `/admin/triage/token`                   | 管理API                                    | -                                                                                      | `{token, createdAt, settings}`（トークンを作る・作り直す。トークンが返るのはここだけ）                                                                                                                                           |
| POST     | `/admin/triage/token/revoke`            | 管理API                                    | -                                                                                      | `{ok: true, settings}`                                                                                                                                                                                                           |
| GET      | `/admin/triage/prompt?limit=`           | 管理API                                    | -                                                                                      | `{prompt, reportCount, reportIds}`（チャットに貼る文。通報が無ければ`prompt`は空の文字列）                                                                                                                                       |
| POST     | `/admin/triage/results`                 | 管理API                                    | `{results: [{reportId, severity, category, recommendedAction, rationale}]}`（1〜50件） | `{results: [{reportId, ok: true, autoHidden} \| {reportId, ok: false, code}]}`（いつも200。`code`は`INVALID_TRIAGE`・`NOT_FOUND`・`REPORT_RESOLVED`・`ALREADY_TRIAGED`）。保存する判定の`model`は`claude-chat`、`source`は`chat` |

- `TriageReport`：`reportId`・`targetType`（`work`/`account`）・`reason`・`createdAt`・`reporterCount`（未対応の通報を
  した別々のアカウントの数）・`work`（`{available, title, description, tags, thumbnailUrl, youtubeUrl}`、
  アカウントへの通報はnull）・`authorName`（チャンネル名かnull）。
- 判定の値：`severity`は`critical`・`high`・`medium`・`low`・`none`、`category`は`child_safety`・`sexual`・
  `violence`・`hate_harassment`・`self_harm`・`illegal`・`privacy`・`copyright`・`spam_scam`・`other`・`none`、
  `recommendedAction`は`hide`・`keep`・`review`、`rationale`は日本語で1〜300文字（前後の空白は除く）。
  違えば400 `INVALID_TRIAGE`。
- 判定ボットの認証：トークンを作っていない → 403 `TRIAGE_BOT_DISABLED`、トークンが無い・違う → 401 `UNAUTHORIZED`。
  CORSは付けない（サーバーからの呼び出し）。GoogleのIDトークンでは呼べない。

#### 所有者が作るSSMのパラメーター（値はリポジトリ・CloudFormationに置かない）

AWSコンソール → **Systems Manager** → **パラメータストア** → **パラメータの作成**で、リージョンは
**アジアパシフィック（東京）ap-northeast-1**、利用枠は「標準」、タイプは **SecureString**、
KMSのキーは既定の **`alias/aws/ssm`**（自分のKMSキーにする場合はLambdaのロールに `kms:Decrypt` を足す）。
作った・変えた値は、Lambdaが最長5分覚えているので、遅くとも5分ほどで効く。デプロイし直す必要はない。

| 名前                                   | 入れる値                                                               | 無いとき                     |
| -------------------------------------- | ---------------------------------------------------------------------- | ---------------------------- |
| `/niarim/moderation/admin-emails`      | 管理ページを使うGoogleアカウントのメールアドレス（複数はカンマ区切り） | 管理APIはすべて403           |
| `/niarim/moderation/resend-api-key`    | ResendのAPIキー（`re_`で始まる。送信だけの権限のキーを作る）           | メールを送らない（ログだけ） |
| `/niarim/moderation/anthropic-api-key` | Claude APIのキー（Claude Consoleで作る。使用量の上限も設定しておく）   | AIの判定をしない             |

あわせて、Google Cloud ConsoleでアプリのOAuthクライアント（`GOOGLE_CLIENT_ID`と同じWebクライアント）の
「承認済みのJavaScript生成元」に `https://niarim.miranima-studio.com` を足す（管理ページのGoogleログインのため）。

#### 管理API（`/admin/...`）

- **認証**：`Authorization: Bearer <GoogleのIDトークン>`。IDトークンの対象（aud）はほかのAPIと同じ
  `GOOGLE_CLIENT_ID`、メールアドレスが確認済み（`email_verified`）で、`/niarim/moderation/admin-emails` に
  載っていること。管理者のNIARIMアカウントは作らない。
  - パラメーターが無い・空 → 403 `ADMIN_DISABLED`（トークンも見ない）
  - トークンが無い・無効 → 401 `UNAUTHORIZED`
  - 載っていない・確認されていないメール → 403 `ADMIN_FORBIDDEN`
- **CORS**：`/admin/` のパスだけ、Origin が `https://niarim.miranima-studio.com` のときに
  `access-control-allow-origin` を返す（`OPTIONS` の事前確認は204）。ほかのAPIはこれまでどおりCORSなし。
- エラーはどれも `{"error": "日本語の文", "code": "機械向けの識別子"}`。

| メソッド | パス                                           | 本文（JSON）                                     | 返すもの                                                                                                                                                                                                                               |
| -------- | ---------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GET      | `/admin/me`                                    | -                                                | `{email, settings:{reportHideThreshold, strikeSuspendThreshold, aiMode, aiModeSource, aiBacklogThreshold, aiDailyCap, mailDailyCap, triageBot:{configured, createdAt, createdBy, lastUsedAt}}}`（`triageBot`は判定用のトークンの状態） |
| POST     | `/admin/settings`                              | `{aiMode: "off" \| "always" \| "backlog"}`       | `{ok, settings}`（管理画面からAIの判定を切り替える。デプロイの既定の`MODERATION_AI_MODE`より優先し、`aiModeSource`は`admin`になる。APIキーが無ければどのモードでもAIは動かない）                                                       |
| GET      | `/admin/reports?status=&order=&limit=&cursor=` | -                                                | `{status, order, reports:[Report], nextCursor}`。`status`は`pending`（既定）・`reviewing`・`resolved`、`order`は`oldest`（既定、resolvedは`newest`）、`limit`は1〜50（既定20）                                                         |
| GET      | `/admin/reports/{reportId}`                    | -                                                | `{report: Report, relatedReports: [ReportSummary]}`（同じ作品・アカウントへの通報すべて、新しい順）                                                                                                                                    |
| POST     | `/admin/reports/{reportId}/review`             | -                                                | `{ok, report}`（確認中にする）                                                                                                                                                                                                         |
| POST     | `/admin/reports/{reportId}/dismiss`            | `{note?}`                                        | `{ok, resolved, unhidden, report}`                                                                                                                                                                                                     |
| POST     | `/admin/reports/{reportId}/hide`               | `{workId?（アカウントへの通報では必須）, note?}` | `{ok, workId, resolved, strikeAdded, strikeCount, postingSuspended, suspendedNow, report}`                                                                                                                                             |
| POST     | `/admin/works/{workId}/unhide`                 | `{keepStrike?: boolean, note?}`                  | `{ok, unhidden, strikeRemoved, strikeCount?, suspensionLifted, resolved, work: Work}`                                                                                                                                                  |
| GET      | `/admin/users/{userId}`                        | -                                                | `{user: User}`                                                                                                                                                                                                                         |
| POST     | `/admin/users/{userId}/suspend`                | `{reason}`（1〜500文字）                         | `{ok, user}`                                                                                                                                                                                                                           |
| POST     | `/admin/users/{userId}/unsuspend`              | `{resetStrikes?: boolean}`                       | `{ok, user}`                                                                                                                                                                                                                           |

- `ReportSummary`：`reportId`（URLにそのまま使える不透明なID）・`status`・`createdAt`・`reason`・`reporterId`・
  `decision`（`dismiss`/`hide`/`unhide`/null）・`reviewedAt`・`reviewedBy`・`reviewNote`・`aiTriage`
  （`{status: "ok"|"refused"|"failed", severity?, category?, recommendedAction?, rationale?, model?, refusalCategory?, source?: "api"|"subscription"|"chat", triagedAt}` か null）。
- `Report`：`ReportSummary` に加えて `targetType`（`work`/`account`）・`workId`・`targetUserId`・
  `reporterCount`（未対応の通報をした別々のアカウントの数）・`openReportCount`・`totalReportCount`・`work`・`author`。
- `Work`：`workId`・`available`（false＝消えた作品、`deleted`も）・`title`・`description`・`tags`・`youtubeVideoId`・
  `youtubeUrl`・`thumbnailUrl`・`authorId`・`channelName`・`postedAt`・`isNiarimPublished`・`youtubePrivacyStatus`・
  `moderationHidden`・`autoHidden`・`autoHiddenReason`・`autoHiddenAt`・`hiddenAt`・`hiddenBy`・`strikeRecorded`。
- `User`：`userId`・`available`・`displayName`（YouTubeのチャンネル名）・`avatarUrl`・`youtubeChannelId`・
  `strikeCount`・`lastStrikeAt`・`postingSuspended`・`postingSuspendedAt`・`postingSuspendedReason`・
  `postingSuspendedBy`（`auto` か管理者のメール）。
- 主なエラーの `code`：`REPORT_RESOLVED`（対応済み）・`REPORT_CHANGED`・`WORK_ID_REQUIRED`・
  `WORK_AUTHOR_MISMATCH`・`MODERATION_CHANGED`（同時に変わった。読み直してやり直す）・`INVALID_STATUS`・
  `INVALID_PAGE_SIZE`・`INVALID_PAGE_CURSOR`・`INVALID_NOTE`・`INVALID_REASON`・`NOT_FOUND`、
  判定の貼り戻しでは `INVALID_RESULTS`・`INVALID_TRIAGE`・`ALREADY_TRIAGED`。
- 「対応不要」「非掲載」「戻す」は、その作品（アカウントへの通報はそのアカウント）の未対応の通報をまとめて完了にする。

#### コマンドラインからの対応（管理ページが無いとき）

運営担当者のAWSプロファイルと対象テーブルを明示して、backend ディレクトリで実行する。管理APIと同じ処理を使う。

```sh
AWS_PROFILE=<運営用プロファイル> TABLE_NAME=<対象テーブル> npx ts-node scripts/review-reports.ts pending
```

最後の引数を `reviewing` にすると確認中の通報を一覧表示する。通報行に記載された
`pk` と `sk` を引用符で囲み、`review 'pk' 'sk'` で確認中、`dismiss 'pk' 'sk'` で対応不要、
`hide 'pk' 'sk'` で非掲載（違反を1回数える）にする。アカウントへの通報では、確認した対象作品の動画IDを最後に指定する。
`unhide <動画ID>` で非掲載を取り消す。動画本体はYouTubeに残る。
運営用プロファイルには対象テーブルの取得・該当インデックスの検索・通報処理の更新に必要な権限を付与する。
通報の一覧には個人情報が含まれるため、運営担当者の閲覧に限る。

#### デプロイ

ここに書いた変更は、GitHub Actions の **Backend CI** を `dev_branch` で手動実行し「AWSへデプロイする」を
選んだときだけ本番に入る（pushでは入らない）。デプロイしてもSSMのパラメーターを作るまでは、管理APIは403、
メールとAIは動かない（通報の保存・自動の一時非掲載・違反の回数と投稿の停止は動く）。
判定ボットは、管理ページで判定用のトークンを作るまで403（`TRIAGE_BOT_DISABLED`）。
