# NIARIM 全面監査 — 開始入口

## 起動トリガー

ユーザーが「NIARIMの全面監査をしてください」「NIARIMを全面監査して」「前回のNIARIM全面監査を再開してください」と明示したら、追加質問なしで全面監査モードへ入る。

## 実行順

1. App / Web の最新 dev_branch HEAD を取得して開始SHAを記録する。
2. AGENTS.md → docs/work-audit/policy/ASTRA_WORK.md → locked Baseline Route → Progress/Evidence → AUDIT_DELTA_ROUTE.md を確認する。
3. baseline verifier、delta verifier、combined full-audit state preflightを実行して監査Stateの整合性を確認する。
4. Baseline current_idから固定順序で全面監査する。未登録の新規画面・状態・操作・品質リスクはDISC-IDへ登録する。
5. Baseline完了後、Discoveryを番号順に消化し、その後D001からDeltaを番号順に消化する。
6. Deltaでは最新HEADの実装inventoryを再取得し、全フィルター（質感変更系・質感偏光を含む）、Brush Custom、縁取りペン、Hair Fold 5モード、髪の毛/前髪preset、Community/API、Help/Tipsを漏れなく個別追跡する。
7. 問題は列挙だけで終わらせず、修正可能ならroot cause→fix→test→実画面→regressionまで行う。
8. 最終Visual closureは最新HEADで再生成し、BEFORE/SETTINGS/AFTER、機能名、preset/mode、主要設定を画像へ焼き込み、全ページrender＋実画像目視を行う。
9. 全画面・全機能・全visible controlの実操作を完了し、機能結果・意図挙動・見た目を別々に合格判定する。さらにD032で商用品質としてのブラッシュアップ候補を洗い出し、必要な改善はその場で修正→再操作→regressionする。
10. Baseline/Discovery/Deltaの未完了0、advisor-pending 0、未登録Discovery 0、必要証拠の未完了0を確認して初めて完了とする。

## 重要

過去会話、旧PDF、旧CI、旧checkpoint、Stateに書かれた古いHEADは現在製品状態の代用にしない。現在のdev_branchを常に一次事実として扱う。