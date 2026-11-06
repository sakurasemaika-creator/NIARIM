# NIARIM FCM プッシュ通知: 運用・実機確認

2026-11-07 / dev_branch

## 統合した構成

- Firebase Cloud Messaging（Android）は無料で利用。Firestore / Firebase Storage / Firebase Authには依存しない。
- `android/app/google-services.json` はプロジェクト `niarim-513201`、Android `com.niarim.niarim`。
- `lib/main.dart` がFirebase初期化。Firebase未設定のローカル編集やFlutterテストを塞がない。
- `lib/services/push_notification_service.dart` がGoogleログイン後にFCMトークンを取得し、
  既存の認証済み `PUT /users/{id}/push-token` へ登録する。別アカウント移行では既存トークンを失効。
- FCMプッシュの配信はAWS Lambda `niarim-api` が担当、トークン/通知履歴はDynamoDB。
- 認証はGoogle Cloud Workload Identity Federation（AWS provider `niarim-aws-lambda`）と
  `niarim-fcm-sender` サービスアカウントの短期トークンを利用し、JSON秘密鍵を使わない。
- ミッション達成の **新規** 永続通知記録を作成した場合のみFCMを送る。フォロー操作ごと、
  ブックマーク操作ごとの個別通知は現在のバックエンド仕様では送らない。
- 既存の投稿完了通知は端末ローカル通知で、FCMとは独立する。
- プッシュ通知タップの遷移先は `/creator-missions` と
  `/community/work/<正しいYouTube動画ID>` のみ許可。画面起動中はスナックバーに表示。

## 反映されたファイルと検証

- `backend/src/lib/push.ts`、`backend/src/lib/missionNotifications.ts`、
  `backend/lib/niarim-backend-stack.ts`
- `lib/services/push_notification_service.dart`、`lib/main.dart`、`lib/app.dart`
- `pubspec.yaml`、`pubspec.lock`、Android Gradle設定、`android/app/google-services.json`
- `test/push_notification_service_test.dart` で遷移先の許可範囲を検証。
- AWSのFCM対応は既存Lambdaを単独更新し、DynamoDB/CloudFormationの変更を避けた。
  GitHub Actionsの一時的なLambda更新権限は反映後に削除した。

## 人間が行う実機検証

1. GitHub Actionsの **FCM Android smoke APK (dev_branch only)** の成功した実行から
   `niarim-fcm-dev-android-apk` を取得する。成果物の保持期間は1日。
   必要なら標準 `Build APK` で `debug`、`connect_backend=true`、
   `connect_google_auth=true` として再ビルドする。
2. GalaxyでAPKをインストール（既存の同じアプリIDのAPKは署名鍵が同じなら上書き）。
3. Googleログインし、通知の許可ダイアログで「許可」を選択する。
4. DynamoDBで生成される **新規ミッション達成通知** でFCM実配送を確認する。
   通知が見えない場合は、まず `niarim-api` CloudWatch logsで
   `FCMアクセストークンの取得に失敗しました` または送信失敗を探す。
   ログは利用者のGoogle IDトークン、FCMトークン、APIキー、個人情報を転載しない。
5. アプリ終了時・バックグラウンド時の通知表示と、通知タップから
   `/creator-missions` への遷移を確認する。

注記：Google Cloud側のWIFユーザー権限とFCM API Adminロールについて、
実際のIAM設定をプログラムから取得して照合したわけではない。
Lambdaの稼働確認はFCM送信の実配送成功を意味しない。
