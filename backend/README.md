# NIARIM作品広場バックエンド

`docs/AI設計書/29_動画投稿・ランキング機能仕様.md`（特に16章）に基づく、
NIARIM作品広場のバックエンド実装。

**このコードはまだAWSへデプロイされていません。** このセッションには
AWSのデプロイ認証情報が接続されていないため、コード（Lambdaハンドラ・
DynamoDBスキーマ・CDKによるIaC）を用意するところまでを行いました。
実際のデプロイはあなた自身の環境・AWSアカウントで行ってください。

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

## デプロイ手順（あなたの環境で実行してください）

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

# 初回のみ：CDKのブートストラップ（アカウント・リージョンごとに1回）
npx cdk bootstrap

# OAuthクライアントID・YouTube APIキーをコンテキストで渡してデプロイ
npx cdk deploy \
  -c googleClientId=<あなたのOAuthクライアントID> \
  -c youtubeApiKey=<あなたのYouTube APIキー>
```

デプロイが完了すると、`ApiFunctionUrl`（アプリから叩くLambda Function
URL）と`TableName`が出力されます。

`bin/app.ts`の`env`をコメントアウトしたままだと、CLIのデフォルト
認証情報（`aws configure`で設定したアカウント・リージョン）が使われ
ます。特定のアカウント・リージョンへ固定したい場合はコメントを外して
指定してください。

### デプロイ後の確認

```bash
# 動作確認（作品0件の状態で200が返れば疎通OK）
curl "$(npx cdk deploy --outputs-file /tmp/out.json > /dev/null 2>&1; jq -r '.NiarimBackendStack.ApiFunctionUrl' /tmp/out.json)works/latest"
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

| メソッド | パス | 対応する仕様書の節 | 認証 |
|---|---|---|---|
| GET | `/ranking/{period}` | 8.2節（`period=all`／`yearly`／`monthly`／`weekly`／`daily`）／`period=bookmarks`は8.5節 | 不要 |
| GET | `/works/latest` | 8.3節・8.6節（`q`で検索） | 不要 |
| GET | `/users/{id}/works` | 8.4節 | 任意（本人なら非公開作品も含む） |
| GET | `/works/{id}/bookmarkers` | 21.1節（被ブックマーク一覧） | 任意（非公開設定のユーザーは除外） |
| POST | `/works` | 6章・12章・17章 | 必須 |
| PATCH | `/works/{id}` | 13章 | 必須（投稿者本人） |
| DELETE | `/works/{id}` | 13章 | 必須（投稿者本人） |
| PATCH | `/works/{id}/tags` | 8.7節 | 必須（追加/削除は誰でも、ロックは投稿者本人） |
| POST | `/reports` | 9章 | 必須 |
| POST | `/blocks` | 9章 | 必須 |
| POST | `/works/{id}/bookmark` | 8.5節 | 必須 |
| GET | `/users/{id}/bookmarks` | 8.5節・21.2節 | 任意（非公開なら本人のみ） |
| PATCH | `/users/{id}/bookmarks-visibility` | 8.5節 | 必須（本人のみ） |
| POST | `/works/{id}/repost` | 8.5bis節 | 必須 |
| POST | `/users/{id}/follow` | 22.5節 | 必須 |
| GET | `/users/{id}/followers` | 22.5節・22.7節 | 任意（非公開なら本人のみ、22.7節のフィルタ適用） |
| GET | `/users/{id}/following` | 22.5節 | 任意（非公開なら本人のみ） |
| PATCH | `/users/{id}/follow-visibility` | 22.5節 | 必須（本人のみ） |
| GET | `/users/{id}/notifications` | 22.6節 | 必須（本人のみ） |
| POST | `/users/{id}/notifications/mark-read` | 22.6節 | 必須（本人のみ） |
| PUT | `/users/{id}/push-token` | 22.7節（FCM端末トークン登録／解除） | 必須（本人のみ） |

## 未実装・既知の制約（デプロイ前に把握しておくべきこと）

1. **未デプロイ**：この`backend/`はコードのみで、実際のAWSへのデプロイと
   動作確認はまだ行っていない（開発環境にAWSの認証情報が無いため）。
   下記はすべて「コードとしては書けている」段階であり、実環境での挙動は
   未検証である点に注意すること。
2. **全文検索基盤は無し**：8.6節の検索は現状Lambda側での部分一致
   フィルタのみ（小〜中規模向け）。大規模化した場合はOpenSearch等への
   移行が必要（20章）。
3. **期間別ランキングはバッチ実行時点の順位**：`yearly`/`monthly`/
   `weekly`/`daily`は、統計更新バッチが全作品を走査したついでに集計して
   `RANKINGSNAPSHOT#{PERIOD}`へ書き出したものを返す（GetItem 1回で読める）。
   期間別のGSIを4本足すとAlways Free枠を明確に超えるための設計。
   したがって順位が更新されるのはバッチ実行時（既定1日2回）で、リアル
   タイムではない。またバッチを一度も完走していない状態では空配列を返す
   （クライアント側で「まだ集計されていません」の表示にすること）。
   期間の境目（日付が変わる等）では各作品のスナップショットが順次
   取り直されるため、切り替わり直後の数時間は順位が安定しない。
4. **プッシュ通知はFCMの鍵が未設定だと送信されない**：`src/lib/push.ts`は
   `FCM_SERVICE_ACCOUNT_JSON`が未設定（既定の`REPLACE_ME`）のとき、
   ログだけ残して何も送らない。アプリ内通知一覧（22.6節）は鍵の有無に
   関係なく動く。送信はbest-effortで、FCMが落ちてもフォロー操作自体は
   成功させる方針にしてある。実機での到達確認は当然ながら未実施。
5. **購入レシートのサーバー検証は無し**：`membershipTier`は現状すべて
   `free`固定で、課金基盤との連携が未実装（11章の会員種別による投稿上限は
   コード上は効くが、premiumになる経路がまだ無い）。
6. **通報レート制限の窓は固定境界**：`src/lib/reportQuota.ts`は10分窓と
   1日窓の2段構えで、いずれも固定境界（スライディングウィンドウではない）。
   窓の境目では短時間に最大2倍まで通り得るが、1回のUpdateItemで判定できる
   ぶん安価という割り切り。
7. **CI/CDのdeployジョブは未設定のままでは動かない**：
   `.github/workflows/backend-ci.yml`の`ci`ジョブ（型チェック・テスト・
   `cdk synth`）は認証情報不要でそのまま動くが、`deploy`ジョブは
   OIDCのIAMロールとSecretsの登録が前提。手順は同ファイル冒頭のコメントに
   書いてある。

## Google/YouTube側で別途必要な準備

15章（YouTube OAuth審査）に記載のとおり、次はこのリポジトリの外側の
作業です。

1. Google Cloudプロジェクト作成・YouTube Data API有効化
2. OAuth同意画面の設定・OAuthクライアントの作成
3. `youtube.upload`スコープの申請理由整理・Googleのアプリ確認審査

審査完了前でも、テストユーザーとして自分のGoogleアカウントを登録すれば
動作確認は可能です。

## $0運用の内訳（実測ではなく設計上の見積もり）

| リソース | Always Free枠 | このスタックでの使用量 |
|---|---|---|
| DynamoDB | 25 GB・25 RCU・25 WCU | テーブル15+GSI6本合計10 = 25 RCU/WCU、ストレージは5章の見積もりで50万作品時約1GB |
| Lambda | 月100万リクエスト＋40万GB秒 | APIリクエスト数・バッチ実行頻度に依存。想定ユーザー数の初期段階では十分収まる |
| EventBridge Scheduler | 低頻度実行はごく低コスト | 1日2回の定期実行のみ |
| Lambda Function URL | 追加費用なし | - |

将来的にAlways Free枠を超えた場合の対応は`29_動画投稿・ランキング機能
仕様.md` 11.2節の段階的引き上げ方針を参照してください。
