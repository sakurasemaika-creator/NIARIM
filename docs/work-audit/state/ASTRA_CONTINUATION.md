# NIARIM Audit Progress

route_version: 2026-09-09-initial-v1
route_state: locked
current_id: A001
current_status: in_progress
last_completed_id: none
next_id: A001
app_baseline: 46949156156850f8e49dcd9919ca6a7eeaf3bfac
web_baseline: 2a44dd9007e4a764e489a42a70f96ac5da6b3b8a

今回の新規Routeから開始。旧進捗の転記なし。

completed_substeps:
- A001/S1 route-policy-current-head restore: 両AGENTS、locked Route、current_id=A001を確認。Route再構築・並べ替えなし。
- A001/S2 startup source-order review: main()→AppErrorReporter.install→font license registration→orientation→buildAppProviders→runApp、buildAppProviders内の逐次初期化を追跡。
- A001/S3 corrupt persisted-settings reproduction: run 34533483148 の生ログと現行sourceを照合し、SettingsService/ThemeServiceの壊れたJSONがFormatExceptionでstartupを中断するroot causeを確定。
- A001/S4 persisted JSON recovery verified: run 34575385855 success。startup_settings_recovery_test 3/3 PASS（壊れたsize preset隔離、壊れたcurrent theme fallback+raw保持、壊れたsaved theme隣接valid保持）、touched analyze 0 issues。修正commit `770e2c57d0a77c11c1a174b5a07243a71383f369` がdev_branchへpush済み。
- A001/S5a source-side double-init root cause: AdvertisingService再initのlistener/provider重複、AppErrorReporter.install再wrapを確認。GoogleAuthServiceは既存guardあり。
- A001/S5b minimal idempotence code: AppErrorReporter install guard commit `5d71d158c0aae465dfa9122232ff01b52f6e18bd`、AdvertisingService lifecycle guard commit `9ea1c72c54f9d5ac73825c661c851083e484408d`。
- A001/S5c idempotence/failure visibility verified: run 34575561261 success。startup_service_contract_test 2/2 PASS（AdvertisingService init idempotence、AppErrorReporter handler single-wrap）。ProjectServiceの破損file/storage recoveryはAppErrorReporter.recordへ記録しつつ非fatal recoveryを維持。analyzeは不要import info 1件のみでfatalなし。結果はrebase後commit `a7e8ed68c1db4af7bdf9fabc3c5caff06d910a1f` 系列としてdev_branchへ入り、その後S4修正がHEAD `770e2c57...` に積まれた。

current_substep: A001/S5d partial-bootstrap failure/retry lifecycle + fresh/warm startup verification

remaining_substeps:
- A001/S5d finish fresh/warm startup and partial-bootstrap failure/retry lifecycle review。後段initializer failure時に先行serviceのlistener/subscriptionを残したまま再buildしないことを保証し、必要ならfailure surface/cleanupを実装してtargeted testする。
- A001/S5e verify bundled font license registration and remaining auth/project/premium startup side effects for duplicate/leak/failure reporting behavior; add only necessary targeted tests.
- A001/S6 consolidate source review + targeted tests/log evidence; only when all A001 expected conditions are verified, mark Route/Evidence done and advance A002.

blockers:
- advisor blocker: none。S5dはSolで継続可能な通常のlifecycle設計/検証論点。
- execution: none。S4/S5 queued runnersは双方successを生ログ確認済み。

next_action: current HEAD `770e2c57d0a77c11c1a174b5a07243a71383f369` からS5dを継続し、partial bootstrap failureを注入できる最小test seamとcleanup ownershipを確定する。retry UIを追加する場合はcleanup safetyのtargeted testを先に成立させる。

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
