# NIARIM App＋Web 製品監査・再開記録

状態：進行中。全体監査完了ではない。開始：2026-09-07。

## 安全条件と再開手順

- App `C:/Users/user/Downloads/MIRANIMA`、Web `C:/Users/user/Downloads/NIARIM_web/NIARIM-web`。両方 `dev_branch` のみ。force push / hard reset / 本番データ操作は禁止。
- 毎再開・重要領域変更・checkpoint・push直前に両repoの status / HEAD / fetch origin / ahead-behind / incoming diff を確認。差分がある領域の旧監査結果は無効化して読み直す。競合は双方の意図を統合する。
- 開始前のユーザー変更：`macos/Flutter/GeneratedPluginRegistrant.swift`、`pubspec.lock`。今回のcommitには含めない。無関係な上書き・破棄禁止。
- ローカル原本＋patch＋SHA256保護：`.git/niarim-product-audit/initial-user-changes/`。既存stash `f7f8bec9cbae01261bc37ef8dd4727029c61c295` を維持。
- Swift SHA256 `c21cf31544420c9a679ce095b05c9761720bfaa5b583e8fd10f93a25b1940d2b`、lock SHA256 `f901642a163cc1d1cd57dc6c38926f3633d7048982486a0af6d99fe452561475`。
- 本体を変更する前に回帰テストRED→修正→GREEN。formatは対象差分中心、pub操作は上記保護を前提とする。検証済み論理単位だけcommit/pushし、独立レビューを通す。

## 調査基準

開始HEAD：App `dfa64ab981a5eaea159fa284ec6e436cc9bd9844`、Web `3f397d05d624f4f3866ee85e535f15b848aaf030`（Webの先行8commitを内容確認してfast-forward済み）。
追跡ファイル：App 799、Web 152。全体一覧・hash・サイズ・TODO候補はローカル `C:/Users/user/AppData/Local/Temp/niarim-audit/{app,web}-{inventory,flags}.json`。一覧化は精査完了を意味しない。

設計：Android向け低価格端末対応の手描きラスター制作。生成AI/クラウド同期/ベクター/3Dは対象外。Webは公式紹介＋ヘルプ＋法務＋問い合わせWorkerであり、別の制作クラウドではない。既存ロゴ・HakkouMincho/Kuramubon・コーラルアクセントを維持する。

## 全体監査マップ

| 領域 | 状態 / 次の確認 |
| --- | --- |
| 構造・仕様・履歴 | entry/依存/CI一覧化、00/01/31/30・CLAUDE・Web guide/DESIGNを確認中。古い「認証未実装」記載は現コードと要照合 |
| 永続化・復元・共有・autosave・削除 | 調査中。`findings/persistence.md` に根拠を分離 |
| 認証・API・公開/投稿・YouTube・セキュリティ | App/backend/Web横断調査中。`findings/contracts-security.md` |
| workspace・旧設定・スマホ/DeX | 調査中。`findings/workspace.md` |
| 描画・レイヤー・Undo・timeline・export・音声・素材 | 未精査。既存testを入口に実操作/異常系へ追跡 |
| Web全ページ・問い合わせ・多言語・a11y | 環境確立/既存監査baseline取得から開始 |
| ブランド・法務・サポート・用語・URL | 上記横断担当と統合、未完了 |
| 性能・メモリ・重複・dead code・依存 | 一覧化のみ。明確な根拠と計測後に局所改善 |
| 実画面・モーダル・keyboard/mouse/touch | 未実施。テストの成功だけで正常扱いしない |

## 環境・検証

- Windows / bash。Flutter 3.44.7、Dart 3.12.2。資料のLinux/Flutter3.47.2をそのまま採用しない。
- `python` はWindowsAppsスタブ。実行可能なのは `C:/Users/user/AppData/Local/hermes/hermes-agent/venv/Scripts/python.exe`。
- `node` はwinpty aliasで非TTY時失敗するため `node.exe`。Node 20.11.1、npm 10.2.4。依存engine要件を確認。
- baseline `flutter analyze --no-pub`、backend `npm run build && npm test` 実行中。結果未判定。
- テスト/画像ログはGit管理対象へ大量投入せず、コマンド・結果・必要な証拠パスを記録する。

## 問題・修正・checkpoint

本監査によるproduction変更：まだ無し。新規checkpoint：まだ無し。push：まだ無し。
発見問題は証拠・優先度・再現・修正ファイル・検証を各findingsへ追記し、この欄に採択結果を要約する。

## 現在地点 / 次の具体作業

1. baselineログを回収し、Web依存とローカル配信/Chromiumを用意する。
2. 並列の保存/契約/workspace調査結果を統合し、データ損失/認証から再現テスト付きで修正する。
3. 初回の安全記録checkpoint、以後修正単位で検証・独立レビュー・commit・fetch・push。
4. 未精査領域を明示したまま範囲を広げる。実機・外部認証・運用設定など不可検証項目を完了扱いしない。
