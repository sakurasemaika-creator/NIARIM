# 折り畳みモードの引き継ぎ確認（2026-09-30）

対象は`dev_branch`の連続三日月カールと、関連プリセットをユーザーカスタムで
再現する共通設定。描画実装は`fe92485f8a392e4f8b123dd3f47e2c14e236110a`。
本確認はこの通常タスクの記録であり、アプリ全機能の検証完了を意味しない。

## 実施結果

- 折り畳み・共通設定・保存・フィルター再生・画面・実描画の対象131件が成功。
  `hair-fold-production-green.yml`の17ファイルと、
  `hair-fold-bangs-visual-capture.yml`の4ファイルを一括実行した。
- 髪の毛・前髪の各5モードについて、別ID・別名のカスタム定義をJSON保存復元し、
  同じ入力線で本番DrawingEngineへ渡した。レイヤーのRGBA画素は全10組で一致。
  比較時は画像素材の選択を登録順に固定し、ランダム選択の差を除いた。
- `.niabrush`、`.niatra`、複製、保存後の再起動は既存の
  `brush_fold_mode_lifecycle_test.dart`で確認した。
- 対象モデル・描画・設定画面・保存サービスの15ファイルを解析。
  エラー0、警告0。`brush_service.dart`の既存style info43件は残存。
  今回変更したキャプチャテストの指摘は解消した。
- 元のPNG61枚を取得。髪・前髪の5モード、連続カールの途中経過、
  前髪・後ろ髪の使用例、ストローク方向、共通設定画面を確認した。
- 並行作業の`aed9cde6`まで取り込み。髪の描画経路に変更はなく、更新された
  フィルターの共通設定・複製・再生など10件を再実行して成功。
  同じ15ファイルを再解析し、エラー・警告0、既存style info43件を確認。

## 修正前との比較

入力、モデル、素材、設定、DrawingEngine、キャプチャコードは現行に揃え、
独立した比較環境で`hair_fold_raster.dart`だけを`2189afa7`へ差し替えた。
270°、540°前後の旧輪郭処理では終端が丸く太り、現在は尖った続きを保つ。
175°/185°、355°/365°の途中画像でも急な丸い蓋は見られなかった。

回帰テスト`continuous crescent geometry does not reset at detector boundaries`
は旧輪郭処理で失敗（同じ入力なのに7493画素が変化）、現行では成功。
旧輪郭処理を意図的に実行したこの失敗は、現行コードのテスト失敗ではない。

## 比較資料の再作成

`scripts/create_hair_fold_report.py`は取得済みPNGを配置するPDF生成処理。
画像を生成・補正して描画結果を変えない。比較環境は上記の条件に揃える。

```sh
python3 scripts/create_hair_fold_report.py \
  --current build/hair_fold_visual \
  --baseline /path/to/baseline/build/hair_fold_visual \
  --output /path/to/NIARIM_HairFold_ContinuousCurl_Customization.pdf
```

13ページのPDFをPopplerで描画し、全ページのレイアウトを確認。
内容は270°/540°の修正前後、途中経過、5モード、入力線、髪型の使用例、
プリセットとカスタムの一致、折り畳みと共通設定画面、ストローク方向。
