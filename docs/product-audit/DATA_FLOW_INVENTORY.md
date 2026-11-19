# NIARIMのデータフロー

2026-11-19の実装照合。App `cd1d8d6c` とWeb `426dae0e` を基準とする。公開環境の設定、外部事業者での保管、法令上の要否は確認欄に記載した。

| 機能 | 取得する情報と送信先 | コードで確認した保存と制御 | 根拠 |
| --- | --- | --- | --- |
| 作品の編集・保存・共有 | 作品の絵、シーン、履歴は端末内で扱う。作品共有と端末引き継ぎは、利用者が作成したファイルをOSの共有先へ渡す。 | 作品共有は選択した画像・動画・音声と使用フォント名を含める。端末引き継ぎのファイルは選択に応じて実データを含む。初回のファイル作成時点では共有先にネットワーク送信しない。 | [作品保存と共有](../../lib/engine/niapro_serializer.dart)、[共有操作](../../lib/widgets/share_project_file_action.dart)、[引き継ぎ画面](../../lib/screens/settings/transfer_screen.dart) |
| Googleログイン | GoogleのIDトークンをNIARIM APIに渡し、サーバーで検証してGoogleアカウントの識別子 `sub` とNIARIM内のIDを対応付ける。YouTube向けの認可は読み取り・アップロードの用途ごとに扱う。 | AWSのデータベースにアカウントの対応を保存する。作品の削除とアカウントの削除は別の処理で、アカウント削除の経路は確認できていない。 | [Google認証](../../lib/services/google_auth_service.dart)、[NIARIM API認証](../../backend/src/lib/auth.ts)、[APIルート](../../backend/src/api/handler.ts) |
| 作品広場と動画投稿 | 動画ファイルは端末からYouTubeへ送る。タイトル、説明、タグ、公開状態・公開予定時刻、子ども向けと改変・合成に関する申告をアップロード時に渡す。作品広場の作品情報・反応はNIARIM APIが扱う。 | AWSに作品広場の投稿情報、ブックマーク等を保存する。YouTube上の動画とNIARIM上の投稿情報の操作はそれぞれのサービスで行う。 | [YouTubeアップロード](../../lib/services/youtube_upload_service.dart)、[作品広場API](../../backend/src/api/handler.ts) |
| Google Playの購入確認 | 商品IDと購入トークンを端末からNIARIM APIへ送り、NIARIM APIがGoogle Playに照会する。 | AWSのデータベースにトークンのSHA-256ハッシュ、アカウントと商品の対応、期限・検証時刻を記録する。購入照会には環境設定の有効化が必要。 | [端末の購入処理](../../lib/services/premium_service.dart)、[購入確認API](../../backend/src/api/routes/playPremium.ts) |
| オパール・広告報酬 | NIARIM APIで残高、付与・消費、ログインボーナス、ミッションを処理する。広告報酬はリワード広告の検証情報をAdMobから受け取り、セッションと照合する。 | AWSのデータベースに残高と履歴、検証用のセッション・受領記録等を保存する。一部の検証記録と集計には個別のTTLがある。 | [報酬API](../../backend/src/api/handler.ts)、[広告報酬検証](../../backend/src/api/routes/rewardedAd.ts)、[広告SDK呼び出し](../../lib/services/advertising_service.dart) |
| 制作時間の計測 | 試験機能が有効な場合、計測セッションのIDと有効秒数・操作数等を端末からNIARIM APIへ送る。 | アカウントごとにAWSのデータベース側の計測状態を管理する。実行の有無はAppとバックエンドの有効化設定に依存する。 | [端末の計測処理](../../lib/services/creator_edit_session_reporter.dart)、[制作時間API](../../backend/src/api/routes/creatorEditSession.ts) |
| プッシュ通知 | 通知が有効なとき、端末はFirebase Cloud Messagingのトークンを取得し、NIARIM APIに登録する。 | 設定をオフにした場合はトークン取得の自動初期化を止め、既存トークンの解除・無効化を試みる。 | [通知サービス](../../lib/services/push_notification_service.dart)、[通知API](../../backend/src/api/routes/notifications.ts) |
| Webのお問い合わせ | 種別、名前、返信先アドレス、本文、任意の添付と元ファイル名をCloudflare Workerが受け取る。WorkerはResendに渡し、設定済みの窓口に送信する。 | 送信制限は接続元IPをキーにDurable Objectで管理する。オブジェクトのSQLiteに送信予約の時刻を保持し、24時間を超えた記録を削除する。 | [送信処理](https://github.com/sakurasemaika-creator/NIARIM-web/blob/426dae0e449fe5b1835b3963054b4c54524aca80/src/contact.js)・[送信制限](https://github.com/sakurasemaika-creator/NIARIM-web/blob/426dae0e449fe5b1835b3963054b4c54524aca80/src/contact-rate-limiter.js) |
| Webの作品広場 | Webの作品情報と再生可否をWorkerの同一オリジンAPIから取得する。ブラウザはYouTube提供のサムネイルを表示し、再生時にはYouTubeを開く。 | Worker側で作品情報を取得し、公開可否を確認する。非公開作品の内容は公開ページへ出さない。 | [作品情報の変換](https://github.com/sakurasemaika-creator/NIARIM-web/blob/426dae0e449fe5b1835b3963054b4c54524aca80/src/community-feed.js)・[ブラウザ側の表示](https://github.com/sakurasemaika-creator/NIARIM-web/blob/426dae0e449fe5b1835b3963054b4c54524aca80/public/js/community.js) |

## 公開前に照合する項目

- 本番で有効な環境設定と配信SDK、ログとバックアップの保持、AWS・Cloudflare・Resend・Googleで実際に設定している保管先と削除手順。
- 問い合わせメールの保管と削除、各処理の運用主体と委託先、利用者からの開示・訂正・削除の窓口。
- アカウント削除経路と、作品広場の投稿・端末トークン・各種サーバー記録を削除または保持する範囲。
- この一覧と公開用プライバシーポリシー、Google Play Data safetyの申告内容との照合。
