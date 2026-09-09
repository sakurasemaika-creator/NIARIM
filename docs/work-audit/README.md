# Work Audit ownership boundary

このディレクトリと、そこから参照される `docs/product-audit/*` / `docs/work-continuation.md` は、NIARIM全面監査Work専用の管理領域です。

- **Policy（原則変更しない）**: `ASTRA_WORK.md`、`docs/product-audit/QUALITY_STANDARD.md`、`docs/product-audit/LEGAL_IP_STANDARD.md` 等。通常タスクは編集禁止。監査システム自体の変更をユーザーが明示した場合だけ更新する。
- **Mutable audit state**: `docs/work-continuation.md`、`docs/product-audit/README.md`。全面監査Workだけがcheckpoint/stateとして更新する。通常タスクは読込・更新しない。

通常のChatGPT/Codex/Sol作業では、ルート `AGENTS.md` のguardに従い、この監査領域を実行指示や一般的なcontinuationとして利用しない。全面監査が明示的に起動されたときだけ `ASTRA_WORK.md` を入口とする。
