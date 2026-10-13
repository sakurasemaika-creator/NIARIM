# NIARIM Audit Progress

route_version: 2026-09-09-initial-v1
route_state: locked
current_id: A003
current_status: todo
last_completed_id: A002
next_id: A003
discovery_current_id: DISC001
delta_current_id: not_started
app_baseline: 46949156156850f8e49dcd9919ca6a7eeaf3bfac
web_baseline: 2a44dd9007e4a764e489a42a70f96ac5da6b3b8a

今回の新規Routeから開始。旧進捗の転記なし。

## 2026-10-10 session progress (Baseline)

- 開始SHA: App `bbcb4293c37df925c15c98eaee90fafe0c58fd15`（dev_branch先端は監査stateのみの `f97451054c6b0284944f4f96154682c58646a0f1`）/ Web `ed8e5ceda0833c69d3838c3ca6bbbd8f456658a8`（同 `31042310306f7aaa15c5f85f68daa7ae74687027`）。
- 作業branch: 両repoとも `ccr-f56ee68e-77ag7y`（このセッションのgit指示による）。dev_branchへの取り込みは人間のmerge/PR判断に委ねる。
- 実行環境: Flutter 3.47.7 stable、Linux desktop debug build＋Xvfb＋openbox＋xdotool（実操作・実画面キャプチャ）。Android実機/エミュレータ無し（NATIVEはblocked扱い）。タッチ・マルチタッチ・筆圧の実入力は不可。
- A001 done（製品修正 App `35d229e`）。A002 done（同 `35d229e`）。詳細はASTRA_AUDIT_STATE.md。
- Discovery登録: DISC001（初回起動の表示言語）、DISC002（エラー記録の閲覧手段）。Baseline完了後にDISC001から消化する。
- 証跡画像: 監査証跡Artifact（ASTRA_AUDIT_STATE.mdにURL）。Google Driveへのバイナリ保存は、接続ツールがbase64本文の手入力しか受け付けず実用にならないため `backup-pending`。テキストの索引のみDriveへ置く。

completed_substeps:
- A001/S1–S5c: 前セッションまでに検証済み（Evidence参照）。
- A001/S5d partial-bootstrap cleanup + failure surface/retry: verified（全28段階の失敗注入テスト、実画面で失敗→再試行）。
- A001/S5e remaining startup side effects: verified（Google SDK初期化の1回化、共有チャンネルのハンドラー所有、型の違う設定で起動不能になる不具合の修正）。
- A001/S6 fresh/warm/corrupt real startup: verified。
- A002 全操作・336表示マトリクス・修正・再検証: done。

current_substep: none（A003未着手）

remaining_substeps:
- A003 ホーム /home・初回案内・ドロワー（申し送り：初回案内「手描きアニメーションを制作できます」は「はじめる」を押すまで再起動のたびに出る。仕様どおりか判定する）。

blockers:
- advisor blocker: none。
- NATIVE（Android実機・低性能端末）: 実行環境なし。該当IDでblockedとして記録する。

next_action: A003をRoute定義どおり実操作で監査する（初回/既訪、一覧の空/大量、PC/SP、3タブ、ドロワー全リンク、検索、起動画面へ戻る、336表示マトリクス）。

## 前セッションまでのA001 substep記録（履歴）

- A001/S1 route-policy-current-head restore: 両AGENTS、locked Route、current_id=A001を確認。Route再構築・並べ替えなし。
- A001/S2 startup source-order review: main()→AppErrorReporter.install→font license registration→orientation→buildAppProviders→runApp、buildAppProviders内の逐次初期化を追跡。
- A001/S3 corrupt persisted-settings reproduction: run 34533483148 の生ログと現行sourceを照合し、SettingsService/ThemeServiceの壊れたJSONがFormatExceptionでstartupを中断するroot causeを確定。
- A001/S4 persisted JSON recovery verified: run 34575385855 success。startup_settings_recovery_test 3/3 PASS。修正commit `770e2c57d0a77c11c1a174b5a07243a71383f369`。
- A001/S5a–S5c: AdvertisingService再init・AppErrorReporter再wrapのguard（commit `5d71d158…`, `9ea1c72c…`）、run 34575561261 success、startup_service_contract_test 2/2 PASS。

## 2026-10-06 product-delta synchronization note

この監査stateは、全面監査そのもののcurrent_idを勝手に進めるためのものではない。現時点の全面監査順序は引き続き `A001` から開始する固定Routeを維持する。一方、Route lock後に通常開発で追加・変更された機能は、次回の該当TODO／lock後差分回帰で必ず監査対象へ取り込む。

### 最新dev_branch基準

- 最新確認された製品HEAD（追補前）: `ac5ec59e6f96fa87a0d84f59e09db238ed61a5e5`
- 監査state追補後HEAD: `0205cf5823676ff6111968f3409f1edd95bc0ab2`
- 直近の通常開発では、Filter系、選択系、Auto Lineart、Blend/Prism、Pixel Art、Community等に仕様追加・実装変更が入っている。
- したがって旧bootstrap snapshotのSHAを「現在の製品状態」として扱わない。
- 既存Routeの番号・順序・完了状態は変更せず、追加機能は末尾のlock後差分回帰または対応する既存TODOへ割り当てる。

### 今回同期する追加監査対象

1. 範囲選択時の対象レイヤー切替（作業レイヤーのみ／表示レイヤーすべて）。既存production UI・widget testあり。最終回帰のみ。
2. 投げ縄「線に吸着」。近傍線の単純最近傍ではなく、ユーザー軌跡・連続性・進行方向・交差角を考慮し、横切る別線へ誤吸着しないこと。複数領域ケースと大雑把な外周囲いケースをVisual fixture化。
3. 新規「球体陰影フィルター」。影色／光色、透明色、個別blend mode、楕円光領域、X/Yサイズ、位置、blur、slider±1、数値入力、Canvas drag、影の逆領域塗り、保存復元、Undo/Redo、Visual。
4. Gaussian / Lens / Prismの描画領域外へのblur展開。元alpha境界で再clipしない。
5. Anime Styleの線幅変化がある場合の線幅調整slider。
6. Tone Curve。任意control point列、graph、histogram、RGB/R/G/B、追加・移動・削除、preset fallback、保存復元、実描画反映。
7. Levels。Input Black/Gamma/White、Output Black/White、RGB/R/G/B、保存復元、実描画反映。
8. Filter編集画面の省スペース化、選択後の検索／カード領域非表示、透過UI、テーマカラー文字＋outline、Canvas最大化。
9. Filter編集Undo/Redo。
10. Outline。線幅＋内側侵食threshold、作業レイヤー直描画禁止、1つ下へ新規レイヤー自動追加。
11. 「縁取り＋塗り色と同じ線画色」の隙間thresholdをUI→engineまで接続。
12. Vignette／周辺減光。四隅をぼんやり暗くし、strength default 50。
13. Retro Anime。指定記事の手順を自動適用し、彩度のみ-2%ではなく+5%。Film Grainとの差をVisual確認。
14. CRT。色収差強度＋にじみblur強度。VHSと視覚的意味差を成立させる。
15. Monochrome削除。UIから隠すだけでなく旧FilterKind/engine routeを整理。
16. Fisheye。radius、distortion、center X/Y、Canvas上＋drag。
17. Chromatic Aberration。strengthに加えX/Y/Z方向調整。
18. 眼鏡断層。diopter／「眼鏡の度数」と表記しない。Filter内maskをpen/eraser/bucketで編集可能にする。
19. Pixel Art。描画範囲外と重なるblockを切断せず正方形のまま保持。6色（黒・白・赤・黄・青・緑）、block size／resolution-fit切替、Mosaicとの差をVisual確認。
20. 背景なじませ。対象の縁だけでなく対象描画内容全体へ色を適用。Hard Light等の一括陰影方式を必要に応じて利用。
21. 墨溜まり。rangeに加えて最大太さ。外周端は1pxへ滑らかに減衰。
22. Auto Lineart。Apply隣の制御点追加／削除mode、tap追加・tap削除、既存drag編集、Undo/Redo、Visual。
23. 線画色トレス。実結果を確認して異常原因を特定・修正。
24. Blend picker preview。各blend modeの実プレビュー。25 mode、特にAddition/Linear Dodgeの差を確認。
25. Prism。Linear Dodgeの実明るさと外側blurをVisual確認。
26. Automationから「オーロラホログラム」を削除。Gradient Map側の同名質感変更とは混同しない。
27. Auto Fill。プリセットごとに全パーツが一度に塗られた完成状態をVisual capture。
28. 作品広場。「AI画像・AI動画使用」フラグを投稿時・投稿後に投稿者本人がON/OFFできること。AI非表示設定を新着・ランキング・フォロー中・リポスト・Shorts等へ一貫適用。
29. 作品広場のミュートタイトル、ミュートタグ。SharedPreferences復元時のtrim/lowercase/空項目除外を含め、全表示経路で一貫適用。作者本人の管理表示を不必要にfilterしない。
30. Community backend/API。投稿後AI使用フラグ変更がlocal modelだけで終わらず、service/API/backend→再取得→全閲覧面まで一貫することを確認。
31. 7言語Help/Tips、保存復元、targeted regression、analyze、Visual PDFを最新HEADで再確認。

### Visual closure規則

旧 `NIARIM-functional-visual-closure-2026-09-29-labeled.pdf` は履歴証拠として保持するが、今回の追加仕様を含む最終closureの代替にはしない。最新HEADで再captureし、機能名・BEFORE/SETTINGS/AFTER・preset/mode・主要設定値を画像へ焼き込む。最新PDFの全ページレンダリング確認と実画像目視が終わるまで、追加されたVisual機能を完了扱いにしない。

### 監査順序への反映方法

通常の全面監査current_idはこの同期で変更しない。Routeの既存IDを並べ替えず、上記追加対象は対応する既存TODOへ紐付け、対応IDがない新規機能はlock後差分回帰の末尾へ追加する。次回監査実行時はこのdelta noteを無視して旧snapshotへ戻るのではなく、最新HEADとの差分として必ず取り込む。


### 2026-10-06 全面監査追加同期
- 最新HEADの**全フィルター**を実装実体から再inventoryし、質感変更系を含めて監査対象へ明示追加する。**質感偏光フィルター**も対象に含める。
- ブラシカスタム全体を監査し、**縁取りペン**を独立確認する。
- **折りたたみモード（Hair Fold）**を縁取りペンの拡張として、ウェーブ俯瞰／ウェーブ煽り／右カール／左カール／三日月カールの5モードを個別監査する。
- **プリセットの髪の毛ブラシ／前髪ブラシ**を各プリセット単位で実描画・設定・保存復元・Visual確認する。
- 追加対象は監査対象への登録であり完了宣言ではない。既存Route順序/current_idを変更せず、対応既存IDまたはlock後差分回帰末尾へ取り込む。
- 最新Visual PDFには上記追加対象を含め、機能名・BEFORE/SETTINGS/AFTER・preset/mode・主要設定値を画像へ焼き込む。



## 2026-10-06 delta-route execution sync

lock後の追加監査対象は A105 等のBaseline IDではなく、docs/work-audit/state/AUDIT_DELTA_ROUTE.md の D001 以降で正式追跡する。既存A001–A104のRoute順序/current_idは不変。

- D001: 最新HEAD差分・全追加対象inventory
- D002: 全フィルター（質感変更系・質感偏光を含む）→ 1対象=1子TODO
- D023: Brush Custom
- D024: 縁取りペン
- D025: Hair Fold 5モード
- D026: 髪の毛ブラシpreset
- D027: 前髪ブラシpreset
- D028: Help/Tips/7言語
- D029: 最新Visual closure
- D030: 全品質cross-matrix
- D031: 最終coverage/completion gate
- D032: hands-on full-product review and polish

他のD-IDもD001→D031の順序で実行する。登録だけではdoneにせず、実操作・実描画・保存復元・回帰・必要なVisual evidenceを揃える。D-ID中の新発見は末尾へ子TODO化する。



## 2026-10-06 state freshness rule

このProgressは監査開始時に必ず両repoの最新dev_branch HEADを再取得して比較する。ここに記録されたlast_observed_*は再開位置の補助情報であり、現在HEADの代用ではない。製品変更があった場合は、current_idを勝手にdoneへ進めず、現在IDの前提をscope-boundedに再確認し、変更が監査対象ならD-seriesまたはDiscoveryへ登録する。
## 2026-10-06 全面監査実行契約同期
- 「全面監査」依頼時は docs/work-audit/state/FULL_AUDIT_EXECUTION_STANDARD.md を既定実行標準として適用する。
- 全画面・全visible control・全実在操作方式・全プリセットをproduction UIで実操作し、機能結果／意図挙動／見た目／継続性／UX・導線／性能を別判定する。
- theme・quality・save schema/version・export format等を意図的にmutationして再監査し、source hygieneとperformance optimizationも監査対象に含める。
- 明確な品質改善は監査中に修正し、同一操作・Visual・関連regressionを再実行する。
- D032〜D037をこの契約の実行担当として扱い、Baseline/Discovery/Deltaの未確認を隠さない。

## 2026-10-10 全面監査セッション開始（明示依頼）

- 開始SHA: App `bbcb4293c37df925c15c98eaee90fafe0c58fd15` / Web `ed8e5ceda0833c69d3838c3ca6bbbd8f456658a8`（両repoとも `dev_branch` 最新をfetchして一致を確認）。
- 読了した正本: AGENTS.md、docs/work-audit/README.md、FULL_AUDIT_ENTRYPOINT.md、policy/ASTRA_WORK.md、state/AUDIT_ROUTE.md、state/AUDIT_DELTA_ROUTE.md、state/FULL_AUDIT_EXECUTION_STANDARD.md、product-audit 4 standard、state/verifier群。policy文書はApp側が上位版（Web側は旧版）であり、App側を正本として適用。policy自体は変更していない。
- preflight結果（修正前）: `verify_full_audit_state.py` = delta tracker範囲不一致（verifierがD001–D032固定、trackerはD001–D037）＋mirror差分（ASTRA_CONTINUATION.md / AUDIT_DELTA_ROUTE.md がWebへ未反映）、`verify_audit_route.py` = mirror差分、`verify_audit_delta.py` = `状態: \`active\`` のバックスラッシュ混入で active 判定失敗。
- state構造修正: verifierのdelta範囲をD001–D037へ、AUDIT_DELTA_ROUTE.mdのエスケープ混入を除去、App側stateをWebへmirror。修正後に3 verifierとも ok を確認してから製品監査を再開。
- 実行環境: Flutter 3.47.7 stable（CIのstable channelと同版）、Linux desktop debug buildをXvfb上で起動し実操作する。Android実機/エミュレータ（KVMなし）は本環境に無いため `NATIVE` 条件はblockedとして別記する。

