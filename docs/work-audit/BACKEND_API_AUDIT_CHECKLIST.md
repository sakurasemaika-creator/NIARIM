# NIARIM 現行Backend/API監査対象チェックリスト（2026-11-10登録）

> **これは監査項目の登録であり、監査実行・PASS・本番接続・法令適合を意味しない。**
> 作業対象: NIARIM App `dev_branch`、NIARIM-web `dev_branch`、Backend（AWS Lambda / DynamoDB / CDK / CI）、Appの各SDK連携。
> 正式Route: `docs/work-audit/state/AUDIT_DELTA_ROUTE.md` の **D001.61 および D021**。BaselineのA/W ID・lock・State・実績を変えない。
> 登録時ソース: `backend/src/api/handler.ts` の **49 HTTPルート** と `backend/src/api/routes/` の **32 route-moduleファイル**。両者は異なる集計単位。これは2026-11-10時点のコード棚卸しであり、全面監査開始時に再inventoryが必須。

## 監査実行時の進め方

- 最新 **App/Web両リポジトリのdev_branch HEAD SHA** を記録し、`backend/src/api/handler.ts` と `backend/src/api/routes/**`、`backend/src/lib/**`、`backend/lib/niarim-backend-stack.ts` の実体からルート・権限・副作用・データストア・呼出元（App/Web/SDK）を再列挙する。下記リストにない新規ルートはD001.61へ子項目として追加。
- 下表の **各ルート個別**に、HTTP method/path/入力型・境界・必須/任意Bearer、本人/他人/匿名、権限欠如、期待response/error code、可視データ、追加・変更・削除の副作用、ページング・cursor、競合・重複・再送、失敗復旧、App/Web表示への反映を検証する。1件でも未確認なら該当ルート未完了。
- 正常・異常のリクエスト/レスポンスを個人情報・Token/Secretを除去した証拠で記録する。unit/mock・DynamoDB Local・stage/隔離アカウント・実機を区別し、**本番データの変更や実課金・実広告報酬の発行は勝手に実施しない**。
- CIが成功しても **UI実操作・Google/YouTube/AdMob/FCM/Play Console/AWSの実環境境界は別証拠**とする。human-action-pending と implementation-pending を分離する。

## 49 HTTPルートの棚卸し（確認前。未実施）

### 公開・ランキング・動画情報

| ルートID | HTTP | パス | 監査実施 |
|---|---|---|---|
| API-001 | `GET` | `/ranking/visibility` | 未実施 |
| API-002 | `GET` | `/ranking/{period}` | 未実施 |
| API-003 | `GET` | `/works/latest` | 未実施 |
| API-004 | `GET` | `/works/{id}/playback-status` | 未実施 |
| API-005 | `GET` | `/works/{id}/metadata` | 未実施 |
| API-006 | `PATCH` | `/works/{id}/metadata` | 未実施 |
| API-007 | `GET` | `/works/{id}/youtube-comments` | 未実施 |

### 作者・フォロー・作品リスト

| ルートID | HTTP | パス | 監査実施 |
|---|---|---|---|
| API-008 | `GET` | `/users/{id}/works` | 未実施 |
| API-009 | `GET` | `/works/{id}/bookmarkers` | 未実施 |
| API-010 | `GET` | `/users/{id}/bookmarks` | 未実施 |
| API-011 | `GET` | `/users/{id}/social-counts` | 未実施 |
| API-012 | `GET` | `/users/{id}/following` | 未実施 |
| API-013 | `GET` | `/users/{id}/reposts` | 未実施 |

### 本人作品・YouTubeチャンネル

| ルートID | HTTP | パス | 監査実施 |
|---|---|---|---|
| API-014 | `GET` | `/me/works` | 未実施 |
| API-015 | `GET` | `/me/works/{id}` | 未実施 |
| API-016 | `POST` | `/me/youtube-channel/refresh` | 未実施 |

### 報酬・Google Play・AdMob

| ルートID | HTTP | パス | 監査実施 |
|---|---|---|---|
| API-017 | `GET` | `/me/rewards` | 未実施 |
| API-018 | `POST` | `/me/premium/play/verify` | 未実施 |
| API-019 | `GET` | `/me/premium/play/availability` | 未実施 |
| API-020 | `GET` | `/me/rewards/history` | 未実施 |
| API-021 | `POST` | `/me/rewards/ad-session` | 未実施 |
| API-022 | `GET` | `/me/rewards/ad-status` | 未実施 |
| API-023 | `GET` | `/me/rewards/quote` | 未実施 |
| API-024 | `POST` | `/me/rewards/redeem` | 未実施 |
| API-025 | `GET` | `/admob/ssv` | 未実施 |

### ログイン特典・制作ミッション

| ルートID | HTTP | パス | 監査実施 |
|---|---|---|---|
| API-026 | `POST` | `/me/login-bonus/visit` | 未実施 |
| API-027 | `GET` | `/me/login-bonus` | 未実施 |
| API-028 | `POST` | `/me/login-bonus/claim` | 未実施 |
| API-029 | `GET` | `/me/missions` | 未実施 |
| API-030 | `GET` | `/me/missions/grid` | 未実施 |
| API-031 | `GET` | `/me/missions/attention` | 未実施 |
| API-032 | `GET` | `/me/missions/activity` | 未実施 |
| API-033 | `POST` | `/me/missions/activity/sync` | 未実施 |
| API-034 | `GET` | `/me/missions/work-achievements` | 未実施 |
| API-035 | `POST` | `/me/missions/claim` | 未実施 |
| API-036 | `POST` | `/me/missions/qualified-works/scan` | 未実施 |
| API-037 | `POST` | `/me/missions/edit-session` | 未実施 |

### 投稿更新・モデレーション・ソーシャル操作・通知

| ルートID | HTTP | パス | 監査実施 |
|---|---|---|---|
| API-038 | `POST` | `/works` | 未実施 |
| API-039 | `PATCH` | `/works/{id}` | 未実施 |
| API-040 | `DELETE` | `/works/{id}` | 未実施 |
| API-041 | `PATCH` | `/works/{id}/tags` | 未実施 |
| API-042 | `POST` | `/reports` | 未実施 |
| API-043 | `POST` | `/blocks` | 未実施 |
| API-044 | `POST` | `/works/{id}/bookmark` | 未実施 |
| API-045 | `POST` | `/works/{id}/repost` | 未実施 |
| API-046 | `POST` | `/users/{id}/follow` | 未実施 |
| API-047 | `GET` | `/users/{id}/notifications` | 未実施 |
| API-048 | `POST` | `/users/{id}/notifications/mark-read` | 未実施 |
| API-049 | `PUT` | `/users/{id}/push-token` | 未実施 |

## 各系統の固有監査観点

### BE-01 — OAuth・認証と本人/他人の認可境界（未実施）

- Google ID tokenの `aud` / issuer / sub / expiry / replay扱い、複数Googleアカウント切替とNIARIM User ID対応、Bearer欠落・偽造・期限切れ・他端末、匿名閲覧とmutating APIの差。
- `/me/**`、`/users/{id}/following`、個人のbookmark/notifications/push-token、`/works/**` 投稿編集・削除・タグ・報告等の「本人・他人・匿名」マトリクス。HTTP URLのID改ざんやhidden/private metadata漏えいの有無。
- フォロー中のユーザーID一覧は**本人だけ**取得可。公開画面のフォロー中数/フォロワー数は件数だけ、フォロワー氏名/ID・他人のFF一覧を公開しない。ブックマーク公開設定のdefault・owner許可も別途確認。通知に個別フォロワー身元を漏らさない。

### BE-02 — 作品広場・作者ページ・本人の一覧データの一貫性（未実施）

- 最新・ranking各期間（再生/ブックマーク）・Top50・並び順・cursor(25)・検索・作者・フォロー投稿/repost・本人投稿/管理・bookmark・Web read-only proxyについて、App/Web/Backend間の条件一致と古い応答の無効化を検証。
- **取得時点ですでにprivate/deletedな作品は順位の母集団から除外**、集計済みランキング掲載後にprivate/deletedとなった作品は位置を維持した伏字slotでtitle/thumbnail/作者等を漏らさず詳細・再生不可。YouTubeの限定公開/公開判定は現行契約を確認して差異を修正候補として登録。
- 開いたままの画面、cache、deep link、検索結果、戻る操作、直前の作品detail/playback-status preflightについて再チェック。YouTube Data APIのunknown/quota/errorは「公開できる」と誤認せず、誤ってdeleted確定ともしない。
- 最上部のpull-to-refreshで**表示中の一覧だけ**取得し、ヘッダー・他tab・検索入力・スクロールを不必要に再生成せず、非先頭のdragやjump/多重pointerで再取得しない。

### BE-03 — 自分専用フォロー一覧とFF数の現在仕様（未実施）

- 自分の作者ページの「フォロー中人数」タップだけでprivate一覧を開ける。他人の作者ページでは人数は非操作。作品広場に旧専用入口が残らないか確認。
- 一覧から作者の作品ページへ移動し、フォロー・解除・直後の再フォロー（最近解除の一時表示）・最上部の更新を行う。本人の人数が即時更新され、author pageへ戻っても整合する。
- 同時操作・server toggleとのずれ・通信失敗時rollback・account切替/ログアウト中の遅延レスポンス、旧アカウント名/IDの残留をチェック。フォロー中一覧GETは本人IDと認証主体一致が必須、非公開関係が他人のApp/Web/API/ログへ漏れない。

### BE-04 — 投稿・YouTube・公開予約・コメント・作品所有権（未実施）

- Google/YouTube OAuth scope/refreshと本人チャンネルの紐付け、NIARIMとYouTubeの独立タイトル・説明、動画ID/URL/サムネ、Shorts、投稿の冪等化、予約公開の時刻/再試行/GSI cleanup、削除tombstone、プライバシー変更、公開前の再生可否照会。
- YouTube Data API quota/403/404/429/5xx、timeout、ネットワーク中断・callbackキャンセル・SDK未設定・token失効時のUIとbackend状態。実YouTube動画として再生できる経路をmockだけでPASSにしない。
- コメント参照のcache・期限・権限・別作品漏えい、作者のみ編集できる境界、下書き/投稿完了/予約/取消/削除の整合性。

### BE-05 — コイン・広告・購入・ミッションの不可逆更新（未実施）

- AdMob rewarded session→動画視聴→**Google署名付きSSV callback**→nonce/transaction冪等性→DynamoDB残高確定を追跡。署名不正・replay・二重callback・日次上限/JST/UTC境界・取消/未完了・offline・重複送信・複数端末・アカウント切替を検証。テスト用と本番用の付与経路・env gateの区別。
- Google Play purchase verification/restore、購入保留/解約/返金/期限/署名不正・商品ID/ユーザーID照合・Premium特典の付与/剥奪。審査待ち設定やPlay Console未登録はコード側完了として扱わない。
- coin残高/履歴/交換quoteとredemption、Creator mission/作品数/活動時間/ログインボーナス等の達成・claimと不正重複・条件逸脱・quota、DynamoDB transaction部分失敗/再試行/冪等性を確認。
- App全画面・route/modal/広告表示除外面のAdMob規約・同意・SDK・サイズ・誤タップ・多重表示。実配信/審査済みとモック配置を厳密に分離。

### BE-06 — FCM・通知・アカウント分離（未実施）

- permission、token登録/更新/失効/削除、foreground/background/terminatedの配信と通知tap→本人が開ける画面への遷移、作品非公開/削除時deep link、無効payload、重複通知、リトライ、他アカウントの通知混線。
- Googleログイン/電話番号認証導線との適用範囲は実装で確定し、Firebase Analyticsの同意・送信先・保持とFirestoreを利用しない設計の相違が生じないことを確認。FCMとAnalyticsを「設定があるだけ」でPASSにしない。

### BE-07 — AWS・CDK・HTTP境界・運用安全性（未実施）

- API handlerのmethod/path/URI decode/body size/base64/JSON/schema/CORS、公開endpointのrate/quota/入力制限、エラーでの認証情報/PII漏れ、log redaction、環境変数、Google/AdMob署名鍵、IAM最小権限、GitHub Actions OIDC branch subject、CDK差分、デプロイ先・rollback、alarm/retention/costを確認。
- DynamoDBのPK/SK/GSI/TTL/ページング、GSI eventual consistencyと強整合read、ランキング旧結果・bookmark解除tombstone・重複書き込み/同時実行、timeout/partial failure、APIのread-after-write/再試行による二重請求を確認。
- 本番機能有効化のflag（rewarded grant/mission/coin/Play verification/FCM等）を、App画面・backend deployment・運用手順・審査/承認の4者で照合。false/未設定時に誤付与・未対応UI・無制限挙動が起きないこと。
- Web公開ページ経由のAPI proxy/read-onlyランキング、CORS/cache/no-store、Linkクリック直前の可視性再照会、公開情報/credential境界とApp側契約の一致。

### BE-08 — Evidence/closure/既存項目との重複整理（未実施）

- 個別証拠は `D001.8–14` / `D001.35–43` / `D001.46–51` / `D001.55–60` / `D020–D021` / `D028–D031` と相互参照。**監査TODOの重複は証拠の重複実行を強制しない**が、各対象に実証拠が紐づくことを要求。
- 各APIについて `request/response + side-effect + auth/owner + public/hidden + failure/retry + relevant UI navigation` の最低6軸を記録。mock/Local/Stage/本番資格情報を使った実検証の可否・結果を混同せず記録。
- 完了の判定は実行する全面監査セッションが正本State/Evidenceへ行う。**この文書追加の時点で全件未実施**であり、過去CI greenをPASSへ繰り上げない。
