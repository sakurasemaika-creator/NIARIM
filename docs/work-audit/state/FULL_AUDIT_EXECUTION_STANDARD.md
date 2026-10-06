# NIARIM 全面監査実行標準

状態: `active`
適用日: 2026-10-06
適用範囲: App / Web / Backend / Native連携 / production UI / source / assets / presets / save-export

## 1. 「全面監査」依頼の起動契約

ユーザーが「全面監査」「全体監査」「全面的に監査」「全画面・全機能を監査」等、製品全体を対象とする監査を依頼した場合、依頼文に個別項目が列挙されていなくても、この標準を自動的に適用する。

全面監査は「テストを流す作業」ではない。最新の `dev_branch` を取得して実装実体を再inventoryし、Baseline Route、Discovery、lock後Deltaをすべて対象にして、次の順で検証・修正・再検証する。

1. 全画面・全route・全UI surface・全visible controlのinventory
2. 全機能・全プリセット・全workflow・全分岐のinventory
3. 実際のユーザー操作と同じ hands-on 操作
4. 機能結果・意図挙動・見た目・使いやすさ・導線を別々に判定
5. 問題があれば修正可能なものをその場で改善
6. 修正後に同じ操作を再実行し、関連regressionを実施
7. 品質設定・テーマ・言語・保存形式等を意図的に変更して再監査
8. 性能測定と軽量化
9. source hygiene / dead code / obsolete comment 等の整理
10. 最新HEADで最終Visual closure・coverage・completion gate

## 2. 「全通り」の定義

「全通り」は、利用者が実際に到達・操作できるすべての画面、control、状態、分岐、操作方式、プリセットを対象にすることを意味する。

各control/featureについて、該当するものは必ず実行する。
- 初期/default
- 有効/無効/disabled
- 最小/最大/境界値
- 代表的中間値
- 空/長大/不正/破損
- success/error/loading/offline
- apply/cancel/back/close
- 二重実行/連打/途中離脱/再訪
- undo/redo
- save/load/import/export
- 権限・Premium/free/campaign
- PC/SP/keyboard/mouse/touch/stylus/IME/hover/drag等、実装されている入力方式

同じUI部品が別画面・別workflowで使われていても、状態や権限、データflowが異なる場合は別経路として確認する。

数値パラメータについて、無限個の値を全件試すという意味ではなく、仕様上意味のある境界・代表値・相互作用を網羅する。離散値（preset、blend mode、channel、format、language等）は全件確認する。

## 3. 実操作・実描画を必須とする

widget test、unit test、CI、snapshot、DOM検査、source reviewだけでは実操作PASSにしない。

制作機能は可能な限りproduction UIで、
「画面へ到達→設定→実データへ操作→結果確認→確定/取消→再操作→保存→再読込」
まで実行する。

描画系は実際の絵・レイヤー・フレーム・選択範囲・ブラシ・プリセットを使用する。フィルターは実canvasへ適用し、画像そのものの変化を確認する。

## 4. 判定は4軸+製品品質で行う

各操作について以下を独立判定する。

### 機能
入力が意図したstate/data/imageに変換される。値が途中層で欠落・無視・丸め過ぎされない。

### 挙動
操作中の追従、focus、selection、drag、slider、feedback、transition、cancel、undo/redo、再実行、境界が自然で仕様どおり。

### 見た目
layout、spacing、alignment、typography、icon、theme、contrast、outline、overlay、animation、clipping、overflow、scroll、density、touch target、canvas露出を操作前/操作中/操作後で確認する。

### 継続性
画面遷移、再訪、再起動、save/load、import/export後もstateと意味が維持される。

### 製品品質
手数、発見可能性、理解しやすさ、誤操作耐性、導線、一貫性、アクセシビリティ、制作効率、体感速度を評価する。

## 5. ブラッシュアップ権限

仕様どおり動いていても、UX/UI、情報設計、視覚品質、操作効率、feedback、一貫性、アクセシビリティ、導線に明確な改善余地がある場合は、監査中に修正してよい。

改善は「好み」で行わず、具体的な利用上の問題、既存UIとの不整合、操作回数、視認性、誤操作、性能、保守性などの根拠をEvidenceへ記録する。

改善を行った場合は、
修正前確認 → 修正 → targeted test/analyze → 同じ実操作 → Visual再確認 → 関連regression
を完了させる。

## 6. 全プリセット監査

「preset」は代表例だけで終わらせない。

最新HEADから、ユーザーが選択・適用・編集・保存できる全プリセットを再inventoryする。

対象:
- built-in/custom brush
- 髪の毛/前髪
- 縁取りペン/Hair Fold関連
- filter
- texture/material/質感変更/質感偏光
- blend
- automation/action/workflow
- size/pressure
- theme/color
- timeline/animation
- canvas size
- その他のcatalog/preset

離散プリセットは1件ずつ実操作し、設定、結果、保存復元、複製/削除、権限、PC/SP、7言語、Visualを確認する。

## 7. 品質設定・テーマ・保存形式の意図的mutation

監査中に設定を変えて「その設定が本当に全体へ伝播するか」を再監査する。

- theme colorを複数系統変更し、文字/icon/outline/slider/background/selected/disabled/error/overlay/dialog/canvas chromeまで確認
- light/dark/custom、textScale、language、reduced-motion、workspace/panel、performance/quality設定を変更
- 変更後に画面遷移・再訪・再起動して整合を確認
- save schema/versionを変更する場合はlegacy/current/unknown-newer/invalid/truncated/corruptを隔離データで検証
- project saveだけでなく実装されている全export/output formatを実ファイルで確認
- extension/MIME/codec/encoding、canvas size、alpha、color/profile、frame/audio、metadata、透明部分、filename/location、cancel/error、reloadabilityを確認
- UI→model→serialization→service→engine→render→reloadを往復させる
- 一部だけ更新されるhalf-updated stateをPASSにしない

## 8. 速度・端末負荷

主要操作の処理時間だけでなく「入力から最初の視覚的feedbackまで」を測定する。

最低限、対象に含める:
- cold/warm startup
- route transition
- filter/brush apply
- drawing/stroke
- slider/drag
- undo/redo
- save/load
- import/export
- search/list
- share/publish
- heavy canvas / large asset / large project

可能な限りp50/p95、jank/frame drop、UI freeze、memory spike、I/O待ち、rebuild/allocation/cloneを記録する。

遅い処理はprofile/traceで原因を特定し、同じ結果・安全性・互換性を維持できる範囲でcache、差分更新、非同期化、allocation/clone削減、algorithm改善、buffer削減、widget rebuild削減、I/O batching、serialization最適化等を行う。

「コードを短くする」こと自体は目的にしない。低性能端末でも体感速度を優先する。

## 9. Source hygiene

App/Web/Backendを横断して、次を探索する。

- unused import
- dead code / unreachable route
- obsolete service/model
- stale serialization branch
- unused asset
- debug print/log
- temporary workaround
- stale test/fixture/workflow reference
- unnecessary generated artifact
- obsolete TODO/FIXME/HACK/placeholder

削除前にstatic参照だけでなくdynamic loading、reflection、serialization名、asset catalog、generated code等を確認する。

production commentは、
- コードの意味
- 不変条件
- 非自明な制約
- 公開API契約
- license/attribution等の恒久情報
のみを残す。

「いつ何を直したか」「開発中に何が起きたか」「作業メモ」「チャット履歴」はproduction source commentへ残さない。

監査専用workflow、audit-state、証跡を構成するファイルは、production dead codeと誤認して削除しない。

## 10. Visual evidence

Visual対象はproduction UIから取得し、単なるplaceholder/snapshotではなく実際の状態を示す。

必要に応じて画像へ、
- feature name
- BEFORE / SETTINGS / AFTER
- preset/mode
- key settings
- device/viewport/language
- changedPixels等の客観値
を焼き込む。

最新HEADでPDFを再生成し、全ページrender成功、欠落、文字化け、layout breakを確認する。実画像の目視判定をautomation PASSと分離する。

## 11. 7言語 / responsive / accessibility

App/Webに該当する全機能について、ja/en/es/fr/ko/zh/zh-Hantを確認する。

レスポンシブ確認は所定の24幅×7言語matrixを基準とし、PC/SPの固有入力差を確認する。必要に応じてlight/dark/custom、textScale、reduced-motion、safe-area、short-height、keyboard、left-handed、external inputも確認する。

翻訳keyが存在するだけではPASSにしない。意味、register、文法、用語、placeholder、数値、CTA、error、法務文言を実画面で確認する。

## 12. 修正の扱い

監査中に発見した問題は、
発見 → 原因特定 → 最小で安全な修正 → targeted regression → 同じ実操作 → Visual再確認
の順で閉じる。

修正後の新HEADが以前の監査証跡より新しい場合、古いPASSを無条件に引き継がない。影響範囲を再確認する。

## 13. 完全面監査の最終条件

全面監査完了は、単にCIがGREENになった時点ではない。

次をすべて満たすこと。
- 全画面/route/surface/visible controlがinventory済み
- 全実在操作方式を実操作済み
- 全状態・分岐・境界・cancel/retry/undo/redo等の未確認0
- 全プリセットを個別inventory・実操作済み
- 全フィルターを個別inventory・実描画済み（質感変更・質感偏光を含む）
- theme/settings/save-format mutation済み
- performance測定・必要なoptimization・再検証済み
- source hygieneが完了
- 7言語/responsive/accessibility/Premium条件が必要範囲で閉鎖
- targeted test/analyze/build + production hands-on + Visual inspectionが最新HEADで確認済み
- 修正後regression済み
- queued/running/未説明blockedを残さない
- Baseline/Discovery/Deltaの未完了が0

未確認事項、実機不足、外部依存等で実操作できないものはPASSにせず、明確なblocked/未確認理由と必要環境をEvidenceに残す。

