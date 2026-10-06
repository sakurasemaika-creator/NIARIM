# NIARIM Hands-on UI Audit Standard

この文書は全面監査における実操作・実画面確認の必須基準。QUALITY_STANDARD.mdと併用する。

## 必須範囲

App/Web双方について、通常利用で到達可能な全画面、route、dialog、sheet、popover、menu、context menu、toolbar、sidebar、panel、tab、設定、onboarding、およびempty/loading/error/disabled/offline等の主要状態をinventory化し、実際に起動した製品または本番相当環境で到達して実画面を目視確認する。

各画面から実行可能な操作を漏れなく棚卸しし、tap/click、long press、keyboard入力、shortcut、focus/Tab移動、hover、scroll、drag/drop、resize、zoom/pan、pinch、選択/複数選択、toggle、slider、数値入力、text/IME、確定/取消、戻る/閉じる、undo/redo、save/load/import/export、共有/公開、権限要求、retry/cancel等、実装上存在する操作方式を実際に操作する。コード上の存在確認や自動テストによるイベント発火だけで実操作確認の代替にしない。

各操作は、操作前・操作中・成功後・取消後・失敗時・境界値・空/長大データ・無効状態・loading/error/offline・権限拒否・再起動/再訪・二重操作・連打・途中離脱まで、該当する分岐を実行して確認する。制作系は実際の絵、レイヤー、frame、timeline、brush、selection、project、community data等を使用する。

「全通り」は数学的な全直積を意味しない。**ユーザーが取り得る固有の操作、状態遷移、分岐、境界は全件実操作**し、viewport/language/theme/device/settingsの組合せは自動matrixと条件差ケースで漏れを防ぐ。ある条件だけ挙動が変わる場合、その条件を独立した実操作ケースとして扱う。

自動操作・自動screenshot・widget/DOM検査と、担当者が実画面で行った操作・目視判定はEvidence上で明確に分離する。自動PASSだけで操作済み・見た目PASSとしない。

## 全プリセット

全built-in/custom presetをinventoryし、各プリセットをproduction UIから実際に適用・編集・確定・取消・再適用する。brush、filter、texture/material、theme/color、automation/action/workflow、size/pressure、timeline/animation、その他選択可能なpresetを含む。各presetの実結果、設定値、保存/復元、import/export、互換性、権限、7言語、PC/SPを確認する。

## テーマ・保存形式・設定変更

theme color、light/dark/custom、textScale、language、reduced motion、workspace/panel layout等を意図的に変更し、変更色/設定が文字、icon、outline、slider、background、selected/disabled/error、overlay等の全連動箇所へ反映されることを実画面で確認する。保存→再起動→再訪でも維持されることを確認する。

save schema/versionを変更・移行する場合、legacy/current/unknown/newer/invalid/truncated/corruptを隔離データで検証し、version/schema、順序、参照、embedded assets、画像、Undo/Redoを含めて完全に復元できることを確認する。

## 実行時間

主要操作ごとに入力サイズ、端末、測定方法、経過時間とp50/p95等を記録し、体感遅延、jank/frame drop、UI freeze、memory spikeを確認する。遅い箇所はprofile後に原因を特定し、同じ結果を維持できる範囲で時短・軽量化を実装し、変更前後を再実測する。

## ブラッシュアップ

機能が動くだけで満足せず、導線、発見可能性、操作手数、feedback、視覚階層、spacing、typography、contrast、accessibility、PC/SP最適化、theme一貫性、制作効率まで評価する。明確な改善余地は遠慮なく修正し、修正後は同じ実操作とvisual/regressionを再実行する。

## ソース衛生

未使用コード、dead route、obsolete service/model、debug output、temporary workaround、古いtest/fixture/workflow参照、TODO/FIXME/HACK/placeholder等を全体探索する。production commentはコードの意味・不変条件・恒久的制約・公開API/ライセンス情報に限定し、開発経緯やチャット由来メモは残さない。削除/refactor後はanalyze/lint/test/buildと関連実画面regressionを実行する。

## 証跡

inventoryには対象画面/状態、操作、PC/SP、入力方式、確認方法、結果、未確認理由を追跡できる証跡を残す。Visual evidenceは機能名、BEFORE/SETTINGS/AFTER、preset/mode、主要設定を識別可能にする。環境制約で実操作/実画面ができない場合はPASSにせずblockedと理由・必要環境を記録する。