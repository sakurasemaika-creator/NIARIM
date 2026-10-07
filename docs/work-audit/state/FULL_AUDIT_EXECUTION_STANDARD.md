# NIARIM 全面監査実行標準

状態: `active`
適用範囲: App / Web / Backend / Native連携 / production UI / source / assets / presets / save-export

## 1. 全面監査
全面監査はテスト実行だけではない。最新dev_branchを取得し、実装inventory→Baseline→Discovery→Delta→横断品質→最終Visual closureまで行う。全画面・全route・全UI surface・全visible control、全機能・全preset・全workflow・全分岐を対象に、実操作→判定→修正→再操作→regressionを行う。

## 2. 全通り
ユーザーが到達・操作できる固有の画面、control、状態、分岐、入力方式、離散preset/選択肢は全件実操作する。数値はdefault、min/max、boundary、代表中間、empty/large/invalid、相互作用を確認する。success/error/loading/offline、apply/cancel/back/close、double execution、rapid input、interruption、revisit、undo/redo、save/load/import/export、permission、Free/Premium等も該当する場合は確認する。

## 3. 実操作・実描画
unit/widget test、snapshot、DOM/source inspection、CIだけではPASSにしない。production UIで「到達→設定→実データ操作→結果確認→確定/取消→再操作→保存→再読込」を行う。描画系は実canvas・実絵・実レイヤー・実frame・実selection・実brush・実presetを使う。

## 4. 5軸判定
機能 / 挙動 / 見た目 / 継続性 / 製品品質を独立判定する。製品品質には手数、発見性、誤操作耐性、導線、IA、一貫性、accessibility、制作効率、体感速度、独自性を含める。

## 5. UI操作性・IA
button/touch targetのサイズ・位置・spacing、隣接操作、destructive actionの安全距離、one-handed/handedness、scroll/gesture競合、PC mouse/drag競合、文字拡大、小画面、boundary widthを確認する。機能が存在するだけでなく、parent-child、grouping、menu/panel/tab/dialog/settings/navigation/shortcutの階層、重複導線、頻用機能の埋没を再評価する。現構造維持を正解とせず、必要なら再設計する。

## 6. Theme
background/text/icon/button/border/selection/focus/disabled/panel/dialog/menu等は可能な限りtheme/appearance/design tokenを使う。light/dark/custom/accent等を変更して不可視化、低contrast、色だけに依存する意味伝達を確認する。ただしcolor circle、canvas背景、実画像・作画・素材色等の機能上独立した色は無理にtheme化しない。

## 7. Visual output
描画/演出filter、質感変更/質感偏光、blend、blur、light/shadow/glow、noise/film/CRT/VHS、brush、material、presetは処理成功だけでPASSにしない。強度、色、brightness/contrast/saturation、alpha、reflection、texture、grain、edge、detail、blur spread、depth、animationを実出力で評価し、banding、muddy color、blown highlight、crushed black、unwanted transparency、hard cutoff、clipping、edge loss、color shift、過剰blur/noiseを探す。

## 8. PC/SP・responsive・7言語
PC/SPを別設計として確認する。指定width matrix `320/360/375/390/430/480/520/559/560/600/640/641/700/759/760/834/900/1024/1180/1280/1366/1440/1600/1920px` とcontinuous resize、特に559/560、640/641、759/760を確認する。7言語は日本語の意味・意図・温度感を基準に自然さ、register、専門用語、overflow、ellipsis、CJK glyph、font fallbackを確認し、不要なslangや過剰marketing toneを加えない。

## 9. Preset / setting / save
最新HEADから全presetを再inventoryする。Brush Custom、縁取りペン、Hair Fold 5 modes、髪/前髪preset、filters、質感変更/質感偏光、blend、automation、theme/color、timeline、canvas、size/pressure等を含む。theme、language、textScale、reduced motion、workspace/panel、performance/quality、save schema/versionを意図的にmutationし、legacy/current/unknown-newer/invalid/truncated/corruptを隔離データで確認する。実装されている全export/output formatを実ファイルで確認する。

## 10. Performance
cold/warm startup、route transition、filter/brush apply、drawing、slider/drag、undo/redo、save/load、import/export、search/list、share/publish、heavy canvas/large asset/projectを測定し、可能ならp50/p95、jank/frame drop、UI freeze、memory spike、I/O待ちを記録する。必要ならprofileして改善する。

## 11. Accessibility / Security / Legal / Source
各Standardに従い、contrast、screen reader、keyboard/focus、text scaling、reduced motion、auth/authz、validation、API abuse、race/concurrency、resource lifecycle、PII/token/secret、OSS/license、copyright、trademark、patent/utility model、GUI design rights、privacy、consumer/contract等を確認する。法務はAIで保証せず、不確実事項を専門家確認候補として記録する。

## 12. ブラッシュアップ
明確な改善余地があれば、root cause→fix→targeted test/analyze→同じ実操作→Visual再確認→関連regressionまで行う。refactor/rewrite/redesignを妨げない。機能削除は、目的、入力、出力、精度、UX、速度、自由度、保存互換性、undo/redo、share/export、Free/Premium差を確認して判断する。

## 13. Evidence / Visual closure
Audit ID、target、precondition、procedure、expected、actual、environment、PC/SP、viewport、language、theme、preset/mode、settings、test/visual result、regression、evidence location、未確認理由を追跡可能にする。Visual evidenceはBEFORE/SETTINGS/AFTER、feature、preset/mode、主要設定を識別可能にし、captureしただけでPASSにしない。最新HEADで最終Visual closureを再生成し、全ページrender＋実画像目視を行う。

## 外部サービス連携を「あと接続するだけ」にする基準

人間操作が必須となる外部サービス連携は、「外部サービスへまだログインしていない」ことと「アプリ/Web側が未完成」であることを明確に分離する。YouTube API、Google AdMob等を含む該当連携について、全面監査では次を実装・検証する。

- production code path、client/SDK/adapter、設定注入、環境変数/secret参照、認証・OAuth、scope、redirect/callback、API/SDK呼出し、成功/error/retry/timeout/rate/quota、権限拒否、offline/再接続、ログ・secret redaction、analytics/privacy/consent連携まで、必要なコード側を完成させる。
- 外部コンソールでしか作成できないID、secret、OAuth credential、ad unit、API有効化、redirect URI登録、審査/承認、契約同意等は、最後に人間が投入・実行する前提のhuman-action-pendingとして整理してよい。ただし、それを理由にコード上のTODO、placeholder、未接続経路、未検証error stateを残さない。
- 実credentialが監査環境に置けない場合は、test/sandbox/mock boundary等で本番経路と同一の設定・状態遷移を可能な範囲で実操作し、実credential投入後に追加実装が不要であることを確認する。
- YouTube APIは、必要なAPI有効化、認証/credential、scope、callback、対象endpoint、quota/error/retry、secret管理等をinventoryし、コード側を接続-readyにする。
- Google AdMobは、必要なSDK/adapter、app/ad-unit等の設定注入、test/production切替、広告表示、consent/privacy、レイアウト/表示崩れ、失敗時の安全なフォールバック等をinventoryし、コード側を接続-readyにする。
- 連携に必要なPrivacy Policy、Terms、consent、store disclosure、third-party notices等がある場合は、機能だけでなく法務/IP監査と同時に整合性を確認する。
- 人間作業として残した項目にはhuman-action-pendingを付け、**作業名 / サービス / App-Web / 実施場所 / 必要なID・secret・設定 / 前提 / 実施手順 / 完了確認 / evidence / 実施できない理由**を記録する。

全面監査の最終状態では、implementation-pending = 0 を必須とし、human-action-pendingは「外部サービス側でしか実行できない操作」に限定する。監査後の人間作業は最終報告に一括して提示し、ユーザーがそのまま実行できる粒度まで具体化する。

## 14. 完了gate
Baseline incomplete、Discovery incomplete、Delta incomplete、unregistered Discovery、advisor-pending、required evidence/regression incompleteを0にする。重大な機能・安定性・データ損失・security・legal/IP問題を残さない。見送る改善は理由と残余リスクをEvidenceに残す。


## 初心者向け導線・チュートリアル・隠れ操作の発見性監査

NIARIMでは、制作中のキャンバスを極力邪魔しないことと、初見ユーザーが操作方法を理解できることを両立させる。特にキャンバスモードのツール操作は、**「慣れれば使える」だけでは完了としない**。

### キャンバスモードのツール切替とサブ操作
- ツールアイコンのシングルタップで当該ツールへ切り替える操作を、制作中の反復操作として優先的に評価する。
- シングルタップと競合させないために長押し・上スワイプ等へ割り当てているカスタム画面、サブツール選択、追加操作について、初見ユーザーがその存在と操作方法を自然に発見できるか実操作で確認する。
- 「長押し」「上スワイプ」等の不可視・非標準的なジェスチャーを前提にする場合、視覚的な手掛かり、ヒント、初回ガイド、チュートリアル等によって発見可能性を確保する。単にヘルプを読まないと分からない状態は問題候補とする。
- 長押しやスワイプを維持すること自体を正解とせず、**シングルタップ、長押し、上スワイプ、二段階UI、展開ボタン、サブツールバー、オーバーレイ、コンテキストUI等を含めて、制作効率・キャンバス占有率・誤操作耐性・発見性を比較し、必要なら操作体系そのものを再設計する。**
- 改修する場合は、ワンタップ切替による制作効率を失わず、サブ操作との競合を避け、PC/SPそれぞれで自然に使える構成を目指す。
- 実際の初心者を想定し、説明なしの初見状態で「ツール切替」「サブツール選択」「カスタム画面への到達」ができるかを確認する。できない場合は、操作方法または案内方法の改善対象とする。

### チュートリアル・オンボーディング
- チュートリアルは「文章を読めば分かる」ことだけを基準にせず、**図、UIキャプチャ、操作位置の強調、矢印、番号、短い手順、実際の操作例**を活用して視覚的に理解できるか確認する。
- Help/Tipsだけでなく、初心者が機能を初めて使う場面のチュートリアル・オンボーディングにも同じ視覚説明品質を適用する。
- 複数ページのチュートリアルは、必要に応じて横スワイプ/カード形式など、現在の操作環境に自然な方法で順番に理解できるUIを検討する。
- 各ページが前ページの理解を前提とする場合、途中で閉じたことで重要な操作を知らないまま進まないよう、**全ページ閲覧を促す／必要な導入部分は完了まで閉じにくくする／未読状態を明示する**等の設計を検討する。ただし、ユーザーを不必要に拘束することや制作を妨げることも避け、重要度に応じて解除・スキップ・再表示方法を設計する。
- チュートリアルは7言語、PC/SP、画面幅、text scaling、theme、長い翻訳文でも図と説明が破綻しないことを確認する。
- 図やキャプチャは実際の現行UIと一致している必要があり、古い画面・古いラベル・現在存在しない操作を案内しない。UI変更時は関連チュートリアルも更新し、実画面で再確認する。
- チュートリアルを読んだ後に実際の機能を一人で再現できるかを確認し、説明の分かりやすさだけでなく**学習→実操作への移行成功率、手戻り、迷い、誤操作**まで評価する。

### 改善判断
- 現在の操作方法・UI・チュートリアル構造を維持することを前提にしない。
- 「キャンバスを広く保つ」「制作中のワンタップ切替を速くする」「サブ機能を発見しやすくする」「初心者が自力で習得できる」の目的を同時に満たす案を比較し、必要ならUI/gesture/情報設計/チュートリアルを大幅に再設計する。
- 改修後は、初見状態→チュートリアル→実操作→再訪の一連の流れを実際に確認し、既存ユーザーの連続操作効率、誤操作、キャンバス作業領域、performance、accessibility、保存/復元等へのregressionも確認する。

**原則：高度な操作を「知っている人だけが快適」な状態で完成とせず、初心者には発見しやすく、経験者には制作を邪魔せず速く使える操作体系を目指す。**
