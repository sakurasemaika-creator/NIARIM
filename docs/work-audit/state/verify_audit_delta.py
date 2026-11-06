#!/usr/bin/env python3
"""Read-only validator for the lock-after delta audit route.

This intentionally does not mutate the locked Baseline Route. It validates
the dedicated D-series delta route and required comprehensive-audit anchors.
"""
import argparse
from pathlib import Path
import re
import sys

REQUIRED = [
    "D001", "D002", "D003", "D004", "D005", "D006", "D007", "D008",
    "D009", "D010", "D011", "D012", "D013", "D014", "D015", "D016",
    "D017", "D018", "D019", "D020", "D021", "D022", "D023", "D024",
    "D025", "D026", "D027", "D028", "D029", "D030", "D031", "D032", "D033", "D034", "D035", "D036", "D037",
]

def main(root: Path) -> int:
    path = root / "docs/work-audit/state/AUDIT_DELTA_ROUTE.md"
    text = path.read_text(encoding="utf-8")
    ids = re.findall(r"^## (D\d{3}(?:\.\d+)?) —", text, flags=re.M)
    errors = []
    if len(ids) != len(set(ids)):
        errors.append("Duplicate delta TODO IDs")
    expected = [f"D{i:03d}" for i in range(1, 38)]
    missing = [x for x in expected if x not in ids]
    if missing:
        errors.append("Missing required delta IDs: " + ", ".join(missing))
    top_level = [x for x in ids if re.fullmatch(r"D\d{3}", x)]
    if top_level[:len(expected)] != expected:
        errors.append("Delta top-level IDs are missing or out of order")
    if "## D037 — 最終全面closure gate" not in text:
        errors.append("D037 final closure gate missing")
    if "状態: `active`" not in text:
        errors.append("Delta route is not active")
    if "全フィルター" not in text or "質感偏光フィルター" not in text:
        errors.append("All-filter / polarization coverage missing")
    for label in ["Brush Custom", "縁取りペン", "Hair Fold", "髪の毛", "前髪"]:
        if label not in text:
            errors.append(f"Brush coverage missing: {label}")
    for label in ["BEFORE", "SETTINGS", "AFTER", "Visual evidence", "保存/復元", "7言語", "PC/SP"]:
        if label not in text:
            errors.append(f"Evidence rule missing: {label}")
    result = {
        "ok": not errors,
        "required_ids": len(REQUIRED),
        "declared_ids": len(ids),
        "errors": errors,
    }
    import json
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not errors else 1

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    raise SystemExit(main(p.parse_args().root))
