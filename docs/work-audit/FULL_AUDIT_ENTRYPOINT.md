# NIARIM 全面監査 — 開始入口

## 起動トリガー

ユーザーが「NIARIMの全面監査をしてください」「NIARIMを全面監査して」「前回のNIARIM全面監査を再開してください」等、製品全体を対象とする依頼を明示した場合、追加質問なしで全面監査モードへ入る。

## 開始時に必ず読む正本

1. 最新 `dev_branch` のApp/Web HEADと開始SHA
2. `AGENTS.md`
3. `docs/work-audit/README.md`
4. `docs/work-audit/policy/ASTRA_WORK.md`
5. `docs/work-audit/state/AUDIT_ROUTE.md`
6. `docs/work-audit/state/AUDIT_DELTA_ROUTE.md`
7. `docs/work-audit/state/FULL_AUDIT_EXECUTION_STANDARD.md`
8. `docs/product-audit/QUALITY_STANDARD.md`
9. `docs/product-audit/ENGINEERING_QUALITY_STANDARD.md`
10. `docs/product-audit/HANDS_ON_UI_STANDARD.md`
11. `docs/product-audit/LEGAL_IP_STANDARD.md`
12. State / inventory / verifier群

`docs/AI設計書/**` や日付付きverificationは、現在実装の意図・仕様・過去証拠を確認する補助資料として必要な箇所だけ参照する。

## 実行順

1. 最新HEADを取得し、実装inventoryと開始SHAを記録する。
2. baseline verifier / delta verifier / full-audit state preflightを実行し、State整合性を確認する。
3. Baseline current_idから固定順序で監査する。
4. 実行中に新規画面・状態・操作・分岐・品質リスクを発見したらDiscoveryへ登録する。
5. Baseline完了後、Discoveryを番号順に消化し、その後Deltaを番号順に消化する。
6. Deltaでは最新HEADから、全フィルター、質感変更/質感偏光、Brush Custom、縁取りペン、Hair Fold、髪/前髪preset、Community/API、Help/Tips、保存/export、native/backend連携等を再inventoryし、漏れなく追跡する。
7. 問題は列挙だけで終わらせず、可能ならroot cause→fix→targeted test→production UI再操作→Visual確認→regressionまで行う。
8. 全画面・全visible control・全固有操作を実際に操作する。機能結果、意図挙動、見た目、継続性、製品品質を別々に判定する。
9. PC/SP、対応7言語、指定responsive widths、theme/appearance、入力方式、権限/free/Premium等の条件差を、該当する全機能で確認する。
10. 最終Visual closureは最新HEADから再生成し、BEFORE/SETTINGS/AFTER、機能名、preset/mode、主要設定を識別可能にし、全ページrender＋実画像目視を行う。
11. 最終coverage、quality、evidence、advisor-pending、unregistered Discoveryを確認する。

## 「全通り」の扱い

数学的な無限直積を意味しない。ユーザーが実際に取り得る固有の操作、状態遷移、分岐、離散preset/選択肢、境界値を全件実操作し、viewport/language/theme/device等はmatrixと条件差ケースで漏れを防ぐ。

数値はminimum / maximum / boundary / representative middle / invalid / empty / largeを、相互作用がある場合は組合せを確認する。

## 外部サービス連携を「あと接続するだけ」にする最終確認

全面監査では、YouTube API、Google AdMobを含む、**人間による外部コンソール操作・認証情報登録・審査/承認等が必要な外部サービス連携について、アプリ側・Web側の実装を「人間が最後に接続操作を行えば本番接続できる」状態まで完成させる**。人間が必要だからという理由で、コード側のTODO、仮実装、未接続の本番経路、未定義の設定、未処理のerror/retry、未検証のconsent/privacy、未実装のcallback等を残してはならない。

監査中は、実際の資格情報を扱えない場合でも、production相当の接続経路を検証できるsandbox/test credential/mock boundary等を使って、設定→認証→callback→API/SDK呼出し→成功→失敗→retry→quota/rate→権限/consent→ログ/secret保護まで確認する。最終的に人間に残す作業は、**外部サービス側でしか実行できない登録・秘密情報投入・承認・契約同意・公開操作等に限定**する。

代表例としてYouTube APIでは、API有効化、credential/OAuth、scope、redirect/callback、アップロード/取得等の必要経路、quota/error/retry、secret管理まで実装・検証済みとする。Google AdMobでは、SDK/adapter、app/ad unit等の設定注入、広告表示経路、test/production切替、consent/privacy連携、fail-safe、配置・レイアウト、production設定の受け渡しまで実装・検証済みとする。実際の接続値や外部コンソール操作そのものは人間作業として残してよいが、そこから先に**コード修正が必要になる状態を完成扱いにしない**。

監査終了時には「人間が残り何をすれば公開・接続できるか」を、作業名、対象サービス、App/Web、実施場所、必要なcredential/設定、事前条件、完了確認方法、証跡、実施できない理由まで具体的にまとめる。人間作業が0件である必要はないが、**human-action-pending以外のimplementation-pendingを残さない**ことを完成条件とする。

## 完了条件

- Baseline incomplete = 0
- Discovery incomplete = 0
- Delta incomplete = 0
- unregistered Discovery = 0
- advisor-pending = 0
- 必要Visual evidence未完了 = 0
- 必要regression未完了 = 0
- 重大な機能・安定性・データ損失・セキュリティ・法務/IPリスクが未処理で残っていない
- 商用品質として明確な改善候補を放置していない、または放置理由をEvidenceへ記録している
- 外部連携のimplementation-pending = 0、human-action-pendingは外部サービス側でしかできない作業に限定され、最終報告へ集約されている

過去会話、旧PDF、旧CI、旧checkpoint、古いHEADだけで現在の完了を判定しない。現在のdev_branchが一次事実である。


## 初心者向け導線・チュートリアル・隠れ操作の確認

全面監査では、キャンバスモードのツール切替を含む「初見では発見しにくい操作」を独立した品質対象として確認する。シングルタップによるツール切替の制作効率を維持しつつ、長押し・上スワイプ等で開くサブツール/カスタム画面が初見ユーザーにも発見可能か、操作体系自体を変更すべきかまで評価する。

チュートリアル/オンボーディングは文章だけでなく、現行UIの図・キャプチャ・操作位置の強調・番号・短い手順等を使って視覚的に理解できることを確認する。必要な導入チュートリアルは横スワイプ/カード形式等も含めて再設計を検討し、重要な全ページを理解しないまま終了できる設計になっていないか、未読状態、スキップ/解除、再表示、制作阻害とのバランスまで監査する。現行UIと一致しない古いキャプチャ/説明は不合格とする。

現在のUI・gesture・チュートリアル構造を維持することを正解とせず、初心者の発見性と経験者の制作効率を両立できる案へ必要なら大胆に再設計し、改修後は初見→学習→実操作→再訪を実画面で再検証する。
