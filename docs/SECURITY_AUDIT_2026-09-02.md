# 脆弱性診断・セキュリティ改善報告（2026-09-02）

## 対象と手法

Flutter/Dartアプリ、Androidネイティブ層、`.niashare`/`.niatra`取込、
AWS Lambda/DynamoDBバックエンド、CDK、GitHub Actions、依存パッケージ、
リポジトリ内の秘密情報を対象に、コードレビューと自動検査を行った。

- `npm audit`：既知脆弱性 0件
- `pubspec.lock`のPub依存129件をOSV APIで照合：既知脆弱性 0件
- 秘密情報パターン検索：ソース管理対象内へのAPIキー・秘密鍵の混入なし
- バックエンド型検査・テスト、Flutter静的解析・全テスト、Androidの
  Manifest処理/Kotlinコンパイルを実施

## 修正した問題

### 高：共有ZIPからのパストラバーサル／リソース枯渇

`Materials/../../...`のようなエントリ名を持つ細工済み`.niashare`を読むと、
同梱素材の復元時にプロジェクトディレクトリ外へ書き出せる余地があった。
また、圧縮後サイズだけが小さいZIP爆弾、過剰なエントリ数、巨大JSONを
展開前に制限していなかった。

`ArchiveSecurity`を追加し、ZIP中央ディレクトリを展開前に検査するよう修正。
親相対/絶対パス、重複名、シンボリックリンク、暗号化・分割ZIPを拒否し、
入力ZIP 128 MiB、展開後256 MiB、単一エントリ128 MiB、メタデータ16 MiB、
20,000エントリの上限を設定した。申告サイズを偽装したDeflateも、展開結果を
保持しないストリーム検査で実サイズを照合して拒否する。Androidの
ContentResolver読込も128 MiBで打ち切り、UIスレッド外で処理する。

### 中：公開APIの入力検証不足

Lambdaルーターが本文サイズ、不正Base64、不正なURLエンコード、長大な
パスパラメータを早期拒否せず、一部PATCH APIが文字列等を真偽値へ暗黙変換
していた。64 KiBの本文上限とパス上限を追加し、JSON本文をオブジェクトに
限定。YouTube ID、アクセストークン長、タイトル、タグ数/長、ユーザーID、
通報理由、公開設定の型と長さを検証するよう統一した。エラー応答には
413/400と安定したエラーコードを返し、CSP、Referrer-Policy、HSTSも追加した。

### 中：公開Lambda URLの濫用耐性

Function URLは匿名閲覧を提供する設計上`AuthType: NONE`だが、同時実行上限が
なく、急増アクセスがLambda/DynamoDBの費用と同時実行枠を消費し得た。
API Lambdaへ予約済み同時実行数10（Function URL換算で最大約100 RPS）を
設定した。書込APIは従来どおりGoogle ID token認証を必須とする。

### 中：Android端末上のデータ・通信設定

OSバックアップ除外が明示されておらず、`.niashare`受信ActivityのVIEW
フィルターには不要な`BROWSABLE`が付いていた。バックアップを無効化し、
Android 11以前/12以降の両ルールで全アプリデータを除外した。Network
Security ConfigとManifestの双方で平文通信を禁止し、`BROWSABLE`を削除した。

### 中：GitHub Actionsのサプライチェーン耐性

Actionsが可変のメジャータグ参照で、checkoutが書込可能な資格情報を後続
ステップへ残していた。全Actionを検証時点の完全なcommit SHAへ固定し、
`persist-credentials: false`を設定。静的解析の`continue-on-error`を廃止し、
warning/error時はAPK配布前に失敗するよう変更した。

## 検証結果

- Flutter変更ファイル静的解析：No issues found
- Flutter全スイート（リモート先行更新の統合後）：334 tests passed、今回の
  変更範囲外にあるWeb比較撮影テスト5件が失敗。ZIP防御・Niatra取込の
  セキュリティ関連8 testsはすべて成功
- Android：`:app:processDebugMainManifest :app:compileDebugKotlin`成功
- バックエンド：`npm run build`成功、29 tests passed
- バックエンド：`npm audit` 0 vulnerabilities
- 追加回帰テスト：危険なZIP相対パス、巨大ZIP宣言、API本文上限、
  不正Base64/URLエンコード、JSONオブジェクト型を検証

## 残存リスクと公開前の必須対応

1. **リリース署名（高）**：現在のrelease buildは既存設定どおりデバッグ鍵で
   署名される。公開前に専用keystoreを安全な保管場所で生成し、CI secretsから
   注入すること。秘密鍵をリポジトリへ保存してはならない。
2. **APIの精密なレート制御（中）**：予約済み同時実行数は全体上限であり、
   IP/ユーザー単位ではない。利用増加時はAPI Gateway/WAF、CloudFront、
   原子的なユーザー別レートカウンターを追加する。
3. **CDK設定値（中）**：`googleClientId`と`youtubeApiKey`は未設定時に
   `REPLACE_ME`でデプロイ可能な既存仕様。実環境ではCDK context/CI secretsを
   必須化し、CloudWatch Logsや出力へ値を表示しないこと。
4. **可用性（低〜中）**：DynamoDBのPITRは費用方針により無効。運用開始前に
   復旧要件と費用を再評価する。

参考：Androidの[バックアップ推奨事項](https://developer.android.com/privacy-and-security/risks/backup-best-practices)、
[Network Security Configuration](https://developer.android.com/privacy-and-security/security-config)、
GitHubの[Actionsセキュリティ強化](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)、
AWSの[Function URLスロットリング](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html#urls-throttling)。
