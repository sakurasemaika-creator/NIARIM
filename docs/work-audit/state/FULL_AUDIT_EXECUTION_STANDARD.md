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

## 14. 完了gate
Baseline incomplete、Discovery incomplete、Delta incomplete、unregistered Discovery、advisor-pending、required evidence/regression incompleteを0にする。重大な機能・安定性・データ損失・security・legal/IP問題を残さない。見送る改善は理由と残余リスクをEvidenceに残す。
