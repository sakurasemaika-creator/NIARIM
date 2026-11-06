# NIARIM 全面監査依頼用プロンプト

以下をそのまま全面監査担当AIへ渡して、NIARIMのApp/Webを全面監査してください。

あなたはNIARIMの全面監査の主担当実行者です。今回の依頼は、単なるテスト実行・バグ探し・コードレビューではありません。最新製品を実際に操作し、全画面・全機能・全操作・全状態・全プリセットを確認したうえで、機能、意図した挙動、見た目、操作性、情報設計、性能、アクセシビリティ、国際化、セキュリティ、保存互換性、法務/IP、商用品質まで監査し、問題があれば修正して再検証してください。

## 開始
最新dev_branchのApp/Web HEADと開始SHAを記録してください。次を現在HEADから確認してください。
- AGENTS.md
- docs/work-audit/README.md
- docs/work-audit/FULL_AUDIT_ENTRYPOINT.md
- docs/work-audit/policy/ASTRA_WORK.md
- docs/work-audit/state/AUDIT_ROUTE.md
- docs/work-audit/state/AUDIT_DELTA_ROUTE.md
- docs/work-audit/state/FULL_AUDIT_EXECUTION_STANDARD.md
- docs/product-audit/QUALITY_STANDARD.md
- docs/product-audit/ENGINEERING_QUALITY_STANDARD.md
- docs/product-audit/HANDS_ON_UI_STANDARD.md
- docs/product-audit/LEGAL_IP_STANDARD.md
- State / inventory / verifier群

docs/AI設計書/**、機能別verification、security audit、operation capture等は仕様・過去証拠の補助資料として必要な箇所だけ参照してください。古い資料・旧PDF・過去CI・過去会話・古いHEADを現在の完了根拠にしないでください。

## Route
Baseline RouteのID・順序・definitionを勝手に変更しないでください。新しい画面、状態、操作、分岐、preset、品質リスクはDiscovery/Deltaへ登録し、実検証・修正・regression・証拠まで完了してください。

## 実操作
production UIまたは本番相当環境で実際に操作してください。全画面、dialog/sheet/popover/menu/context menu、toolbar/sidebar/panel/tab、settings/onboarding/empty/loading/error/offline/disabled、全visible control、全workflow、全presetを対象にします。tap/click/long press/scroll/drag/drop/slider/numeric input/keyboard/shortcut/focus/Tab/mouse/wheel/hover/touch/pinch/pan/stylus/pressure/IME/undo/redo/apply/cancel/back/close/save/load/import/export/share/publish/permission/retry等、実装されている入力方式を実行してください。

各機能で、default、enabled/disabled、min/max、boundary、代表中間、empty、large/long、invalid/corrupt、success/error/loading/offline、double execution/rapid input/interruption/revisit、undo/redo、save/load/import/export、permission、Free/Premium/campaign等の該当分岐を確認してください。離散preset/mode/blend/channel/format/languageは全件確認してください。

## 判定
各操作を、機能 / 挙動 / 見た目 / 継続性 / 製品品質の5軸で独立判定してください。テストPASSやコード存在だけで実操作PASSにしないでください。

## UI操作性・IA
button/touch targetのサイズ・位置・spacing、似た操作の隣接、destructive action安全距離、one-handed/handedness、scroll/gesture競合、PC mouse/drag競合、小画面、text scaling、boundary widthを確認してください。機能が存在するだけでなく、parent-child、grouping、menu/panel/tab/dialog/settings/navigation/shortcutの階層、重複導線、頻用機能の埋没を再評価してください。現構造維持を正解とせず、必要なら再設計してください。

## Theme
UIのbackground/text/icon/button/border/selection/focus/disabled/panel/dialog/menu等は可能な限りtheme/appearance/design tokenを使ってください。light/dark/custom/accent等を変更し、不可視化やcontrast不足を探してください。ただしcolor circle、canvas背景、実画像・作画・素材色等の機能上独立した色は無理にtheme化しないでください。

## Visual
描画/演出filter、質感変更/質感偏光、blend、blur、light/shadow/glow、noise/film/CRT/VHS、brush、material、presetは処理成功だけでPASSにしないでください。実出力の強度、色、brightness/contrast/saturation、alpha、reflection、texture、grain、edge、detail、blur spread、depth、animationを確認し、banding、muddy color、blown highlight、crushed black、unwanted transparency、hard cutoff、clipping、edge loss、color shift、過剰blur/noiseを探してください。弱すぎて効果が知覚できない場合も改善候補です。

## PC/SP・responsive・7言語
PC/SPを別設計として確認してください。width matrixは320/360/375/390/430/480/520/559/560/600/640/641/700/759/760/834/900/1024/1180/1280/1366/1440/1600/1920px。559/560、640/641、759/760の1px境界とcontinuous resizeを重点確認してください。7言語はja/en/zh/zh-Hant/ko/fr/esを基本とし、Webで表記体系が別なら実装上の7言語を確認してください。日本語原文の意味・意図・温度感を基準に自然さ、register、専門用語、overflow、ellipsis、CJK glyph、font fallbackを確認し、不要なslangや過剰marketing toneを加えないでください。

## Preset / Save
最新HEADから全presetを再inventoryしてください。Brush Custom、縁取りペン、Hair Fold 5 modes、髪/前髪preset、filters、質感変更/質感偏光、blend、automation、theme/color、timeline、canvas、size/pressure等を含みます。theme/language/textScale/reduced motion/workspace/performance/quality/save schemaを意図的にmutationし、legacy/current/unknown-newer/invalid/truncated/corruptを隔離データで確認してください。実装されている全export/output formatを実ファイルで確認してください。

## Performance / Accessibility / Security / Legal
startup、route transition、filter/brush、drawing、slider/drag、undo/redo、save/load、import/export、search/list、share/publish、heavy canvas/large asset/projectを測定し、可能ならp50/p95、jank/frame drop、UI freeze、memory spikeを記録してください。Accessibility、auth/authz、validation、API abuse、race/concurrency、resource lifecycle、PII/token/secret、OSS/license、copyright、trademark、patent/utility model、GUI design rights、privacy、consumer/contractも各Standardに従って確認してください。法務はAIで保証せず、不確実事項を専門家確認候補として記録してください。

## 修正
問題は列挙だけで終わらせず、可能ならroot cause→fix→targeted test/analyze→同じ実操作→Visual確認→related regressionまで行ってください。refactor/rewrite/redesignを妨げません。機能削除は目的、入力、出力、精度、UX、速度、自由度、保存互換性、undo/redo、share/export、Free/Premium差を確認して判断してください。

## Evidence
Audit ID、target、precondition、procedure、expected、actual、environment、PC/SP、viewport、language、theme、preset/mode、settings、test/visual result、regression、evidence location、未確認理由を残してください。Visual evidenceはBEFORE/SETTINGS/AFTER、feature、preset/mode、主要設定を識別可能にしてください。captureしただけでVisual PASSにしないでください。バイナリ証拠は長期保管先へバックアップし、失敗時はbackup-pendingとして記録してください。

## 完了
Baseline incomplete=0、Discovery incomplete=0、Delta incomplete=0、unregistered Discovery=0、advisor-pending=0、required evidence/regression incomplete=0を確認してください。重大な機能・安定性・データ損失・security・legal/IP問題を残さず、明確な商用品質改善候補を放置しないでください。見送る場合は理由と残余リスクをEvidenceへ記録してください。最後に最新HEADからVisual closureを再生成し、全ページrender＋実画像目視＋coverage確認を完了してください。

「テストが通った」「コードが存在する」「画面が表示された」だけで全面監査完了とはしないでください。実際の製品を使った結果として、安心して使え、見た目も動きも自然で、機能の配置も理解しやすく、商用品質として完成している状態まで確認・改善してください。
