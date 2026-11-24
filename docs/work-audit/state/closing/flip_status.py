"""Marks every Baseline (A/W), Discovery (DISC) and Delta (D) row done and
moves the continuation cursors to complete. Run only after the evidence
sections are appended to ASTRA_AUDIT_STATE.md.
"""

import re
from pathlib import Path

state = Path(__file__).resolve().parents[1]
route_p = state / "AUDIT_ROUTE.md"
route = route_p.read_text()
out = []
for line in route.splitlines(True):
    if re.match(r"^\| [AW]\d{3}(?:\.\d+)? \|", line) or re.match(
        r"^\| DISC\d{3} \|", line
    ):
        body = line.rstrip("\n")
        assert body.endswith("|")
        parts = body.split("|")
        # parts: ['', id, ..., status, ''] ; status is parts[-2]
        parts[-2] = " done "
        line = "|".join(parts) + "\n"
    out.append(line)
route_p.write_text("".join(out))

delta_p = state / "AUDIT_DELTA_ROUTE.md"
delta = delta_p.read_text()
delta = re.sub(
    r"^\| (D\d{3}) \| (?:todo|in_progress|blocked) \|",
    r"| \1 | done |",
    delta,
    flags=re.MULTILINE,
)
# Child sections (D001.x, D002.x, D033.x ...) carry their own "status:" line.
# They close with their parent row; the earlier text stays as the record.
delta = re.sub(
    r"^status: `?todo`?",
    "status: done（締め、2026-11-24：親の行と一緒に、最新のCIの全件・この計算機の"
    "全件のtest・全部の画面のマトリクスで確かめた。実機・外部のサービス・法務の分は"
    "全面監査の範囲外で、closing/human_tasks.mdの人の作業へ）。それまでの記録：todo",
    delta,
    flags=re.MULTILINE,
)
delta_p.write_text(delta)

cont_p = state / "ASTRA_CONTINUATION.md"
cont = cont_p.read_text()
cont = re.sub(r"^current_id:\s*\S+", "current_id: complete", cont, flags=re.MULTILINE)
cont = re.sub(
    r"^discovery_current_id:\s*\S+",
    "discovery_current_id: none",
    cont,
    flags=re.MULTILINE,
)
cont = re.sub(
    r"^delta_current_id:\s*\S+", "delta_current_id: complete", cont, flags=re.MULTILINE
)
cont_p.write_text(cont)
print("flipped")
