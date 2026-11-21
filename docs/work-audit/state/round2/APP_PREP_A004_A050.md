# Round-2 prep A004-A050 (App product HEAD 2939841e, origin/dev_branch 04ba3f96)

Status: F=fixed_looking, U=unfixed_looking, ?=unclear. All repair commits listed are ancestors of origin/dev_branch.

- **A004** プロジェクト一覧・検索・表示・ソート — 126:F, 262:F, 263:F, 266:F
- **A005** プロジェクト単体・複数選択・クリップボード — 262:F, 264:F, 267:F
- **A006** プロジェクトフォルダ・パンくず — 267:F, 252:F, 262:F
- **A007** 新規プロジェクト /new-project — 268:F, 269:F
- **A008** キャンバスサイズのプリセット管理（直接遷移） — 269:F, 198:U
- **A009** プロジェクト詳細 /project/:id — 270:F, 271:F, 18:F, 19:F, 78:?, 79:F
- **A010** キャンバス /canvas/:id・復旧・終了 — 272:F, 66:U
- **A011** PC/SP・ドック・ツールバー・パネル共通 — 66:U, 273:F, 20:F, 87:F, 117:F, 133:F, 148:F, 149:F
- **A012** 描画入力・ストローク・Undo/Redo — 274:F, 275:U, 271:F, 81:F, 51:F, 53:?, 80:F
- **A013** ブラシ選択・全組込・カスタム管理 — 276:F, 277:F, 107:U, 112:F, 132:F, 133:F, 230:F, 198:U
- **A014** ブラシ詳細・サイズ/不透明度・サブツール — 67:?, 254:F, 255:?
- **A015** 消しゴム・透明色 — 67:?, 51:F, 53:?, 275:U
- **A016** カラーピッカー・スポイト — 278:F, 279:F, 254:F, 255:?
- **A017** パレット・ドット絵パレット・QR — 280:F, 281:F, 198:U
- **A018** バケツ・投げ縄塗り — 282:F, 283:F, 271:F
- **A019** 選択・反転・全選択・解除 — 284:U, 262:F, 313:F
- **A020** 選択範囲の移動・拡縮・回転 — 285:F, 286:F, 287:F, 288:F
- **A021** 自由変形・メッシュ — 289:F, 290:F, 291:F
- **A022** 指・ぼかし・モザイク — 292:F, 284:U
- **A023** 図形・OFF/線/四角形/円 — 274:F
- **A024** テキスト入力・編集・縦書き — no DISC
- **A025** トーン全種・設定と素材管理 — 293:F, 294:F, 277:F, 283:F
- **A026** スタンプ全種・管理 — 294:F
- **A027** ブラシ/トーン/スタンプ共通フォルダ・タグ — 295:F, 296:F, 297:F
- **A028** 定規パネル・全種別 — 298:F, 299:F, 271:F, 198:U
- **A029** キャンバス操作・背景・描画領域 — 66:U
- **A030** 参考画像・プレビューナビゲータ — 300:F, 66:U
- **A031** レイヤー一覧・追加・順序・削除 — 301:F, 302:F, 303:F
- **A032** レイヤーblend/opacity/clipping/明度→alpha — 304:F
- **A033** レイヤーフォルダ・group・複数選択 — 305:F, 301:F, 302:F
- **A034** 共通レイヤー・表示範囲・変換 — 306:F, 302:F
- **A035** レイヤーキーフレーム — no DISC
- **A036** 自動塗りレイヤー・実行 — 271:F, 107:U
- **A037** 描画フィルター管理・適用共通 — 307:F, 308:F, 309:F, 310:F, 311:F, 312:F, 313:F, 271:F, 294:F, 149:F
- **A038** 色調整・filterへの登録 — 314:F, 315:F, 316:F, 307:F, 309:F, 310:F
- **A039** pixel mode・量子化・専用パレット — 317:F
- **A040** オニオンスキン — 318:F
- **A041** 早替えツール — 319:F, 198:U, 292:F
- **A042** canvasフレームstrip — 320:F, 321:F, 322:F, 276:F
- **A043** カスタム自動操作・管理・記録 — 323:F, 268:F
- **A044** 自動操作の実行範囲・安全性・組込 — no DISC
- **A045** タイムライン /timeline/:id・往復 — 324:F, 325:F, 66:U
- **A046** シーンタブ・操作 — 326:F, 327:F, 198:U
- **A047** タイムラインフレーム編集 — 328:F, 291:F
- **A048** 素材track・clip操作 — 329:F
- **A049** 画像/動画clip編集・crop — 330:F, 329:F
- **A050** 音声・波形・動画音・同期 — no DISC

## Not fixed / unclear

- DISC066 (unfixed_looking): Owner decision still pending (HANDOFF L2473/L2484). Code: lib/screens/canvas/canvas_screen.dart:3924 _buildDesktopMenuBar()/MenuBar still built (used at :4100); only CanvasViewAction.centerOn is referenced (:2587) so zoom/fit/rotate actions are still unwired. 95a76d8f restored a PC timeline workspace; b31e620f only stops the menu bar overflowing.
- DISC107 (unfixed_looking): Owner decision pending (HANDOFF L532 "DISC066/067/107 skipped"). No localized built-in brush/tone name helper found in lib (grep builtinBrushName/localizedBrushName: none); 7f65d544 only changed the font of preset rows.
- DISC198 (unfixed_looking): AUDIT_REPAIR_HANDOFF.md L25 fixes only the saved-size delete menu. colorScheme.error still used for delete actions at quick_tool_panel.dart:510, ruler_panel.dart:66, color_picker_panel.dart:681/685 (palette sheet), brush_panel.dart:370-374 (custom brush delete), timeline_screen.dart:3966-3975 (scene delete), layer_panel.dart:1529/1533.
- DISC275 (unfixed_looking): AUDIT_REPAIR_HANDOFF.md L68/L195/L217: left as a requirement decision (should lock be in history?). Code: layer_panel.dart:2068-2074 update(isLocked) -> ProjectService.updateLayer (project_service.dart:2173, recordUndo defaults true). f1579fca only made the test pass recordUndo:false.
- DISC284 (unfixed_looking): AUDIT_REPAIR_HANDOFF.md L195/L217: left as a requirement decision (pen vs selection). Code: canvas_area.dart uses _selectionMask only for lasso/bucket fill (:2433), mesh (:2927) and selection transform; no restriction in the stroke path, drawing_engine.dart has no selection reference.
- DISC053 (unclear): AUDIT_REPAIR_HANDOFF.md L525/L557 list it only together with DISC051; no return says the exported PNG was compared. Needs a PNG export comparison.
- DISC067 (unclear): Listed as owner-decision pending (AUDIT_REPAIR_HANDOFF.md L532). But the DISC292 repair (f2d6c0cd, L150) split eraser/finger/blur temporary values from the pen brush values, which changes the reported behaviour. Re-check hands-on.
- DISC078 (unclear): No return in the handoff. AUDIT_ROUTE DISC078 row: "S38: fix published as an A009 review finding (Undo restores what it can, logs the failure and shows the Home trash wording); hands-on of a failing Undo not done" - no SHA given. Round 1 did not exercise it.
- DISC255 (unclear): AUDIT_ROUTE DISC255 row: other session af50df1d (unverified). canvas_screen.dart no longer has maxHeight: 680 (now :4590 maxWidth 520/maxHeight 720); later colour-wheel commits b01fd435/e91684c4/f1579fca. Needs an SP look.
