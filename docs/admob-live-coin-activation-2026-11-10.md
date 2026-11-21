# NIARIM本番コイン獲得：2026-11-10 有効化記録

この記録は `dev_branch` とAWSアカウント `368601349794`・東京リージョンの
`niarim-api` を対象とする。**Google Play一般公開やAdMobのアプリ審査通過を意味しない。**

## 有効化した内容

- 1回の正規リワード広告視聴による付与：**10コイン**（従来仕様）。
- Google ECDSA署名＋本番リワード広告ユニット＋オファー10 coins＋
  サーバー発行のユーザー紐付けnonceの検証が**すべて成功した場合のみ**残高加算。
- 本番Lambdaの環境設定：
  - `ADMOB_REWARDED_AD_UNIT_ID=ca-app-pub-4380578821900659/6321761453`
  - `REWARDED_AD_SSV_ENABLED=true`
  - `REWARDED_AD_REVIEW_APPROVED=true`（NIARIM運営者の有効化判断を示す**内部フラグ**。
    Googleによるアプリ審査承認を示すものではない）
  - `REWARDED_AD_DAILY_LIMIT=1`（**暫定：ユーザーごとUTC日付で1回=10コイン**）。
- 同じ設定を `backend/cdk.json` に保存。CDKは別途デプロイしていない。
- Android `APPLICATION_ID` を公式デモ用からNIARIM本番AdMobアプリID
  `ca-app-pub-4380578821900659~1455226397` に変更。
- Androidバナーは開発中もGoogle公式デモ用ユニットのまま。報酬用ユニットは
  認証後の `POST /me/rewards/ad-session` でサーバーから渡される。

## 安全性と検証

- [バックエンド自動テスト](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/42545545490)
  と[DynamoDB Localの実取引テスト](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/42545545430)
  に成功。暗号的な偽造・二重付与・他人の通知転用・上限超過・取引失敗時の残高不変を検証。
- 今回のCDK設定変更もBackend CIで型チェック・テスト・synthを検証。
- ユーザーへ直接コインを付与したり、実ユーザーの既存残高を書き換えたりしていない。
- 付与は有効だが、**実際のGoogle配信広告→Google署名SSV→本番DynamoDB付与**
  はまだ実機未検証。GoogleからSSVが届かない場合は増えない。
- ストア未公開でAdMobアプリ審査が完了していないため、実際の広告配信は制限されうる。
- NIARIM運営者自身で広告を試す場合は、**先にGalaxyをAdMobでテストデバイス登録**し、
  ラベル「テスト広告」等を確認する。ライブ広告を自分でクリックしてはならない。
- 現在の端末テスト結果、SSV実通知、上限到達とUTC日付跨ぎは未確認。
- 本番コードはLambda設定変更によって再ビルドしていない。
  既存Lambdaの最終更新は2026-11-09。バックエンドの最新の修正が反映済みか
  は実機のSSVテストとデプロイ履歴で追加確認する。

## Galaxyでの検証手順

1. AdMobの [設定] → [テストデバイス] → [テストデバイスを追加] で
   Galaxyの広告IDを登録する。Googleの公式ヘルプ：
   https://support.google.com/admob/answer/9691433?hl=ja
2. `dev_branch` の固定デバッグ署名鍵・Googleログイン接続・NIARIM本番AdMobアプリIDを
   使用したデバッグAPKをビルドし、Galaxyにインストールする。
3. Googleログイン→NIARIMのコイン獲得画面→広告を視聴。
   テストデバイス登録が反映されていない場合は広告視聴を試さない。
4. 広告の完了後、コイン残高・履歴・`GET /me/rewards/ad-status` の成功を確認。
   署名付き通知が遅延・未着のとき、端末側だけでコインを加算しない。
5. 暫定上限1回/日への到達状態を確認。上限の本番変更は運営上の別判断。

## 有効化を停止する場合

緊急時は `niarim-api` の `REWARDED_AD_SSV_ENABLED=false` に戻すことで
新規の報酬セッションと実コイン付与を停止できる。ただし、CDK側の設定も
`backend/cdk.json` で停止して再デプロイ時に誤再有効化させないこと。

## 参照

- https://developers.google.com/admob/flutter/ssv
- https://developers.google.com/admob/flutter/test-ads?hl=ja
- https://support.google.com/admob/answer/10564477
