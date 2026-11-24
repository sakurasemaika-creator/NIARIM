# 全面監査の締めの道具（2026-11-24、Claude・S56）

- `map_tests.py <out.json> [NIARIM-webのパス]`：AUDIT_ROUTE.mdのA/Wの行ごとに、その実装を読み込むApp・バックエンドのtestと、そのページを確かめるWebの監査を集める。
- `build_sections.py <id_tests.json> <route-matrix.csv> <out.md> <App SHA> <Web SHA> <CIの文>`：行ごとの正式doneの節（判定・test・表示の組み合わせ・範囲外）を作る。
- `flip_status.py`：A/W・DISCの行とD001〜D037をdoneにし、ASTRA_CONTINUATION.mdのcurrent_idをcompleteにする（節をASTRA_AUDIT_STATE.mdへ足した後に使う）。
- `human_tasks.md`：全面監査の範囲外（実機・外部のサービス・法務）として人が行う作業の一覧。
