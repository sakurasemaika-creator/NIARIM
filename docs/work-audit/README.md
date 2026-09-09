# Work Audit ownership boundary

NIARIM全面監査の専用領域。通常ChatGPT/Codex/Solタスクは、ルート `AGENTS.md` に従い、このディレクトリや監査専用 `docs/product-audit/**` を検索・read・実行指示として利用しない。

## Policy — どう監査するか

- `docs/work-audit/policy/ASTRA_WORK.md`
- `docs/product-audit/QUALITY_STANDARD.md`
- `docs/product-audit/LEGAL_IP_STANDARD.md`
- その他の明示された監査基準

原則固定。ユーザーが監査システム変更を明示した場合だけ変更する。

## State — どこまで監査済みか

- `docs/work-audit/state/ASTRA_CONTINUATION.md`: 最新の確定進捗、未解決、次の1手
- `docs/work-audit/state/ASTRA_AUDIT_STATE.md`: 監査マップと検証根拠

Stateは全面監査モードで**実際に検証した事実だけ**更新する。通常タスクの実装、別チャット/別Workの話題、ユーザーの未検証な進捗申告を自動的に監査済みStateへ昇格させない。通常タスクはStateをread/writeしない。

## 起動経路

- 通常タスク: `AGENTS.md` → 通常ルート。ここで終了し監査領域へ進まない。
- 全面監査: `AGENTS.md` → `policy/ASTRA_WORK.md` → `state/*` → 必要な品質基準。
- 監査システム保守: 必要なPolicyだけ。State移行/修復が依頼に含まれる場合だけStateへ触る。
