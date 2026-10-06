# NIARIM lock-after delta audit route

状態: \`active\`

## 目的

このファイルは、locked Baseline Route（A001–A104）の後に通常開発で追加・変更された製品機能を、全面監査から漏らさないための正式な追加監査ルート正本。

重要:
- Baseline RouteのID・順序・definition hashを変更しない。
- このファイルのD001以降はBaseline A/W IDとは別系統の正式delta TODO。
- 「登録済み」は「監査済み」ではない。
- 実装inventory、実操作、実描画、保存復元、targeted regression、実画面目視、必要な7言語・PC/SP・Premium、Visual evidence、修正後回帰まで揃って初めてdone。
- 最新dev_branchを毎回取得し、過去PDF・過去CI・過去会話だけで完了扱いしない。

## Formal delta status tracker

| ID | status |
|---|---|
| D001 | todo |
| D002 | todo |
| D003 | todo |
| D004 | todo |
| D005 | todo |
| D006 | todo |
| D007 | todo |
| D008 | todo |
| D009 | todo |
| D010 | todo |
| D011 | todo |
| D012 | todo |
| D013 | todo |
| D014 | todo |
| D015 | todo |
| D016 | todo |
| D017 | todo |
| D018 | todo |
| D019 | todo |
| D020 | todo |
| D021 | todo |
| D022 | todo |
| D023 | todo |
| D024 | todo |
| D025 | todo |
| D026 | todo |
| D027 | todo |
| D028 | todo |
| D029 | todo |
| D030 | todo |
| D031 | todo |

delta_current_id は、この表の先頭未完了D-IDと一致させる。`not_started` はBaseline/Discoveryが未完了の間だけ使用し、D001以降へ入ったら必ずD-IDを記録する。
## 実行順

1. D001で最新HEADの変更差分と実装実体を再inventoryする。
2. D002以降を番号順に実施する。
3. D002/D010/D011などのinventory系TODOで発見した対象は、同IDの末尾へ「対象名を明記した子TODO」を追加し、1対象=1子TODOにする。追加順は発見順ではなく、実装上の安定した並び順を採用し、再開可能なIDを付与する。
4. D020以降のCommunity/Web/API等も、App側変更であっても必要なWeb/Backend/Help/公開面まで追跡する。
5. 全Baseline完了後、D001以降の未完了を番号順に消化する。D-ID処理中に新発見したD-IDは末尾へ追加する。
6. D031でdelta coverageを再照合し、未割当0・未検証0を確認する。
7. 最終的にApp/Web共通のVisual closure PDFを最新HEADから再生成し、全ページrender＋実画像目視を実施する。

## 完了状態

D-IDのstatusは \`todo / in_progress / blocked / done\`。
blockedは環境・実機・外部サービス等の実在制約だけに使用し、未確認をblockedへ隠さない。全面監査completeにはBaseline未完了=0、Discovery未完了=0、delta未完了=0、advisor-pending=0、未登録Discovery=0が必要。

## D001 — 最新HEAD差分・全追加対象 inventory

対象:
- 最新App/Web dev_branch
- lock baseline以後の全commit差分
- 実装実体（route/navigation/filter/brush/preset/service/API/help/asset）
- 既存delta note

必須確認:
- Baseline A001–A104で既に表現可能な変更
- deltaとして独立追跡すべき新規画面/状態/操作
- 全フィルター集合
- 全Brush Custom preset集合
- Hair Fold/髪の毛/前髪 preset集合
- Community/API変更
- Web/Help/Tips変更
- 新しい保存形式・backend contract・native依存
- 旧実装の削除/renameによる死線・到達不能

成果:
- 最新HEAD SHA、App/Web SHA、差分範囲をEvidenceへ記録。
- 新規対象をD002以降の子TODOへ割当。
- unassigned target = 0。

## D002 — 全フィルター inventory → 個別監査

全フィルターを最新HEAD実装から確定し、**質感変更系・Gradient Map系・質感偏光フィルターを除外しない**。

各フィルター1件ずつ:
- 到達導線
- 全設定と境界値
- Apply/Cancel
- Undo/Redo
- 実処理
- 保存/復元
- 7言語
- PC/SP
- Free/Premium/current campaign
- disabled/loading/error
- 実描画
- Visual evidence

特に実処理がUI値を無視していないこと、名称だけのdead filterがないことを確認。

## D003 — 範囲選択の対象レイヤー

- 作業レイヤーのみ
- 表示レイヤーすべて
- toggle persistence
- 選択→操作→解除
- Undo/Redo
- multi-layer alpha/visibility
- save/restore
- PC/SP/7言語
- Visual

## D004 — 投げ縄「線に吸着」

- 単純な最近傍pixel吸着ではないことをsource確認。
- ユーザー軌跡、連続性、進行方向、交差角を考慮。
- 横切る別線への誤吸着を再現テスト。
- 複数領域 fixture。
- 粗い外周囲い→キャラクター境界へ吸着するケース。
- cancel/undo、PC/SP、Visual.

## D005 — 球体陰影フィルター

影色/光色（透明可）、各blend mode、楕円光領域、X/Yサイズ、位置、blurを全確認。
- slider
- +/- 1 unit
- 数値入力
- Canvas drag
- shadow outside light region
- undo/redo
- save/restore
- real render
- 透明色境界
- PC/SP/7言語
- Visual

単一passの自動陰影方式を使う場合は、blend semanticsを壊していないことも確認。

## D006 — Gaussian / Lens(Bokeh) / Prism blur

- 元のdrawing alpha/region境界で再clipしない。
- 描画領域外へ自然にblurが展開。
- edgeはhard cutoffではなくsoft feather。
- 3 filter同士の意味差。
- save/restore/undo/redo/Visual。

## D007 — Filter editor UI + Undo/Redo

- filter選択後に大型search/filter/card領域が残らずcanvasを最大化。
- top-right X / bottom-left Apply。
- canvas同様の透過UI。
- theme color text/outlines。
- mobile最大化。
- filter edit専用Undo/Redo。
- keyboard/back/cancel/error。
- 7言語/PC-SP/Visual。

## D008 — Tone Curve

- input→output graph
- histogram
- RGB/R/G/B
- 任意control point追加・移動・削除
- monotonic/edge/boundary cases
- preset fallback
- saved custom points
- engine application
- save/restore
- actual pixel comparison
- 7言語/PC-SP/Visual

## D009 — Levels

- Input Black / Gamma / White
- Output Black / White
- RGB/R/G/B
- boundaries/inversions/neutral
- UI→model→JSON→service→engine
- save/restore
- actual pixel comparison
- 7言語/PC-SP/Visual

## D010 — Outline

- line width
- inner erosion threshold
- do not draw directly onto working layer
- automatically create new layer one below
- gap/threshold UI→engine
- color/alpha
- boundaries
- save/restore
- undo/redo
- actual layer structure and render
- Visual

## D011 — Vignette / Retro Anime / CRT / VHS

### Vignette
corner darkening, soft feather, strength parameter, default around 50.

### Retro Anime
specified multi-step processing is actually automated; saturation change is +5% rather than old -2%; distinct from Film Grain.

### CRT
chromatic aberration strength + bleed/blur; scanline/RGB-phosphor semantics.

### VHS
tracking/chroma/time-noise semantics and dedicated route; visually distinguish from CRT.

All four: real rendering, save/restore, boundaries, 7 language, PC/SP, Visual.

## D012 — Removed/changed filter contracts

- Monochrome must be removed from UI **and** old FilterKind/engine route/dead references where applicable.
- Automation-only “オーロラホログラム” removal must not accidentally delete Gradient Map/texture-side same-name work.
- dead route/name/serialization compatibility must be investigated.
- analyze/test/build.

## D013 — Fisheye / Chromatic Aberration

### Fisheye
radius, distortion, center X/Y, center handle (+), drag, boundaries, save/restore, visual.

### Chromatic Aberration
strength + X/Y/Z direction controls, boundaries, save/restore, actual channel displacement.

## D014 — 眼鏡断層

- do not use “度数” / prescription-like label for the numeric setting.
- own lens-range mask editor if existing selection cannot be reused.
- mask pen / eraser / bucket.
- visible region, save/restore, undo/redo, localization, Visual.

## D015 — Pixel Art vs Mosaic

Pixel Art:
- blocks overlapping drawing area boundary remain full rectangular blocks.
- no clipping.
- no alpha averaging.
- diagonal crossing keeps rectangular pixel and same color.
- color fixture: black/white/red/yellow/blue/green.
- custom block size vs canvas-resolution-fit easy toggle.
- compare against Mosaic.
- actual pixel/sample assertions and Visual.

## D016 — Background blending / Ink Pool

### 背景なじませ
subject content as a whole receives color, not blur-only edge processing.

### 墨溜まり
range + maximum thickness; thickest inner corner; smooth taper to 1px at outer edge.

Both: actual pixel geometry, boundary, save/restore, undo/redo, Visual.

## D017 — Auto Lineart / line-color tracing

- Add/Delete control modes next to Apply.
- Add then line; Delete then point.
- Existing drag editing remains.
- Undo/Redo.
- Visual.
- line-color tracing: inspect actual output, identify root cause, fix if needed, regression and Visual.

## D018 — Blend 25 modes / picker preview / Prism

- 25 modes total.
- picker preview for each mode.
- Addition and Linear Dodge must remain distinct.
- Linear Dodge: lighten base, blend color reflected, black no effect, white reflected, inverse relationship to Linear Burn.
- verify all added modes.
- Prism final composite uses Linear Dodge and blur extends outward.
- math tests + production visual comparison + Visual PDF.

## D019 — Automation / Auto Fill / persistence regression

Automation:
- remove Automation-only オーロラホログラム.

Auto Fill:
- each preset captured with all parts painted at once in completed state.

Persistence:
- custom brush image bundling/import restores all images and order/mode.
- pressure profiles.
- chain/vegetation presets.
- save/restore/migration/invalid data.

All relevant targeted regression + Visual.

## D020 — Community AI-use and mute filters

Works:
- exact flag wording: “AI画像・AI動画使用”.
- author can set/unset at posting and later on own work.
- AI-use hidden setting is applied across new/ranking/following/repost/Shorts/other surfaces.
- mute title and mute tag registration.
- muted title/word/tag disappears from all applicable feed routes.
- SharedPreferences restore uses trim/lowercase/empty filtering.
- do not filter author’s own management view.

Test owner/non-owner/public/private/deleted/blocked states where applicable.

## D021 — Community backend/API consistency

- AI-use update propagates local model → service/API/backend → re-fetch → all read surfaces.
- auth/permission/owner checks.
- stale cache/refetch.
- network error/retry.
- no local-only state.
- isolated backend/stubs, no production user mutation.
- request/response evidence with secrets/PII removed.

## D022 — Selection / brush / filter state cross-feature interactions

- selection target layer vs filter application target.
- filter editor undo/redo vs global undo/redo.
- Brush Custom/Hair Fold + selection + layers.
- repeated apply/cancel.
- state reset when leaving/re-entering.
- save/restore across feature boundaries.
- no stale callbacks/listeners.

## D023 — Brush Custom

- create/edit/duplicate/delete
- all settings
- draw
- undo/redo
- save/restore
- import/export
- invalid/legacy data
- production UI
- 7 languages
- PC/SP
- Visual

## D024 — 縁取りペン

- normal outline drawing
- line width
- erosion threshold
- color/alpha
- layer insertion contract
- gap threshold
- boundaries
- save/restore
- undo/redo
- Visual

## D025 — Hair Fold: five modes

Hair Fold is explicitly an **outline-pen extension**, never a thick paint ribbon.

Per-mode child TODOs:
- ウェーブ俯瞰
- ウェーブ煽り
- 右カール
- 左カール
- 三日月カール

Each mode:
- brush thickness
- taper
- curvature/fold geometry
- direction-change trigger
- continuous bend handling
- boundary
- save/restore
- actual draw
- Visual

Crescent重点:
- centerline represents visual position.
- center thickness follows brush thickness.
- taper toward start/end.
- outer crescent curve stronger/tighter than centerline.
- inner curve weaker/looser.
- no straight closing line.
- end→start connection follows smooth curve/tangent.
- no sudden thickness jumps.
- brush width may affect activation threshold only; it must not secretly change requested stroke diameter.

## D026 — Preset 髪の毛ブラシ

- inventory latest production presets.
- 1 preset = 1 child TODO.
- preset settings and actual draw.
- back-hair use case.
- reproducibility via general outline-pen + Hair Fold controls.
- save/restore.
- Visual BEFORE/SETTINGS/AFTER.

Do not hide non-reproducible behavior behind preset-only special logic; record as general-function improvement target.

## D027 — Preset 前髪ブラシ

Same as D026 for every current bangs preset:
- inventory
- 1 preset = 1 child TODO
- settings
- actual bangs shape
- general-setting reproducibility
- save/restore
- Visual

## D028 — Help / Tips / 7-language consistency

- App/Web Help/Tips current feature inventory.
- stale legacy descriptions.
- “下塗りモード” or equivalent stale terminology search.
- new filter/brush/Hair Fold/Community terminology.
- 7-language semantic/back-translation.
- screenshots/links/anchors.
- App/Web terminology consistency.
- do not rely on key parity alone.

## D029 — Latest Visual closure

Generate new closure artifact from latest HEAD; historical 2026-09-29 PDFs are references only.

Required:
- all filters including texture-change/polarization
- all relevant filter settings
- Brush Custom
- 縁取りペン
- Hair Fold 5 modes
- each hair/bangs preset
- Community relevant visual surfaces
- BEFORE / SETTINGS / AFTER
- feature name / preset or mode / key settings burned into image
- manifest-backed cases
- full PDF render check
- direct human/agent image inspection
- no missing images / mojibake / layout break

## D030 — Full quality cross-matrix

For all completed Baseline + Delta IDs:
- status/evidence consistency.
- required state matrix.
- 336 viewport-language matrix where applicable.
- PC/SP distinction.
- theme/light-dark-custom.
- textScale.
- reduced motion.
- keyboard/IME/hover/touch.
- safe area/short height/keyboard.
- Premium/free/campaign.
- error/offline/loading/disabled/cancel/retry.
- save/restore/import/export.
- security/privacy/data-loss boundaries.
- targeted analysis/test/build.
- direct visual inspection separate from automation.

Do not interpret a passing automated matrix as proof of direct interaction or visual quality.

## D031 — Delta coverage and completion gate

Re-inventory latest HEAD and compare against:
- Baseline A001–A104
- Delta D001–D030
- Discovery TODOs
- AUDIT_INVENTORY
- source tree
- routes/navigation
- filters/effects
- brush/preset catalogs
- Community/API
- Help/Tips/Web

Required:
- unassigned feature/filter/preset/route/control = 0
- unregistered Discovery = 0
- incomplete delta = 0
- advisor-pending = 0
- no queued/running evidence needed for completion
- final build/test/analyze/visual closure completed
- latest HEAD after final fixes rechecked

## Delta evidence record schema

各D-IDには必要に応じて以下を記録:
- ID / substep
- execution SHA
- App/Web SHA
- date/time
- environment/device/viewport/mode/language/Premium
- fixture/input
- exact operations
- expected result
- actual result
- screenshots/PDF/manifest references
- targeted test/analyze/build/log
- visual inspection result
- discovered issue/root cause
- fix commit
- post-fix regression
- remaining unknown/blocker
- next_action

## Never-pass rules

以下だけではdoneにしない:
- UIが表示される
- widget testのみPASS
- unit testのみPASS
- CI GREENのみ
- old PDF exists
- old chat says completed
- source implementation appears plausible
- screenshot exists without known state/settings
- static translation key exists
- route/inventory assignment exists
- advisor says safe
