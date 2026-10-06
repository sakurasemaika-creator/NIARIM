#!/usr/bin/env python3
"""Read-only preflight validator for NIARIM full-audit state.

Validates the locked Baseline Route, the Discovery section, and the
dedicated lock-after Delta Route without mutating any state.
"""
import argparse
import json
import re
import hashlib
from pathlib import Path

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def main(root: Path, peer: Path | None = None) -> int:
    state = root / "docs/work-audit/state"
    errors = []
    route = (state / "AUDIT_ROUTE.md").read_text(encoding="utf-8")
    lock = json.loads((state / "AUDIT_ROUTE_LOCK.json").read_text(encoding="utf-8"))
    progress = (state / "ASTRA_CONTINUATION.md").read_text(encoding="utf-8")
    delta = (state / "AUDIT_DELTA_ROUTE.md").read_text(encoding="utf-8")

    rows=[]
    for line in route.splitlines():
        if re.match(r"^\| [AW]\d{3}(?:\.\d+)? \|", line):
            f=[x.strip() for x in line.strip("|").split("|")]
            if len(f)==8: rows.append(f)
            else: errors.append("Invalid baseline row schema")
    ids=[r[0] for r in rows]
    if ids != lock["ids"]: errors.append("Locked baseline ID order/membership changed")
    definition="\n".join("|".join(r[:-1]) for r in rows)
    if sha(definition) != lock["definition_sha256"]: errors.append("Locked baseline definition hash changed")
    preamble=route.split("\n| A001 |",1)[0] if "\n| A001 |" in route else route
    if sha(preamble) != lock.get("preamble_sha256"): errors.append("Locked baseline preamble hash changed")
    first=next((r[0] for r in rows if r[-1] != "done"), "complete")
    m=re.search(r"^current_id:\s*(\S+)", progress, re.M)
    if not m or m.group(1) != first: errors.append(f"current_id mismatch: expected {first}")
    dm=re.search(r"^discovery_current_id:\s*(\S+)", progress, re.M)
    xm=re.search(r"^delta_current_id:\s*(\S+)", progress, re.M)
    if not dm: errors.append("Missing discovery_current_id")
    if not xm: errors.append("Missing delta_current_id")

    disc_rows=[]
    for line in route.splitlines():
        if re.match(r"^\| DISC\d{3} \|", line):
            f=[x.strip() for x in line.strip("|").split("|")]
            if len(f)==6: disc_rows.append(f)
    if disc_rows:
        disc_ids=[r[0] for r in disc_rows]
        disc_unfinished=[r[0] for r in disc_rows if r[5]!="done"]
        disc_first=disc_unfinished[0] if disc_unfinished else "none"
        if dm and dm.group(1)!=disc_first: errors.append(f"discovery_current_id mismatch: expected {disc_first}")
        if len(disc_ids)!=len(set(disc_ids)): errors.append("Duplicate Discovery IDs")
        if "none" in disc_ids and len(disc_ids)>1: errors.append("Discovery table still contains none row")
        if len([r for r in disc_rows if r[5] in {"in_progress","blocked"}]) > 1: errors.append("Multiple active Discovery IDs")
        for row in disc_rows:
            if row[5] not in {"todo","in_progress","blocked","done"}: errors.append(f"Invalid Discovery status: {row[0]}")
    elif dm and dm.group(1)!="none":
        errors.append("discovery_current_id must be none when Discovery has no rows")

    drows=[]
    for line in delta.splitlines():
        if re.match(r"^\| D\d{3}(?:\.\d+)? \|", line):
            f=[x.strip() for x in line.strip("|").split("|")]
            if len(f)==2: drows.append(f)
    dids=[r[0] for r in drows]
    expected=[f"D{i:03d}" for i in range(1,33)]
    if dids != expected: errors.append("Delta status tracker IDs are missing, duplicated, or reordered")
    allowed={"todo","in_progress","blocked","done"}
    if any(r[1] not in allowed for r in drows): errors.append("Invalid Delta status")
    if len([r for r in drows if r[1] in {"in_progress","blocked"}]) > 1: errors.append("Multiple active Delta IDs")
    d_unfinished=[r[0] for r in drows if r[1]!="done"]
    d_first=d_unfinished[0] if d_unfinished else "complete"
    if xm:
        expected_delta = "not_started" if first!="complete" or (dm and dm.group(1)!="none") else d_first
        if xm.group(1)!=expected_delta: errors.append(f"delta_current_id mismatch: expected {expected_delta}")
    unfinished=[r[0] for r in drows if r[1]!="done"]
    if unfinished and dm and dm.group(1)=="none" and first=="complete":
        errors.append("Discovery must be exhausted before Delta starts")

    if peer is not None:
        peer_state=peer/"docs/work-audit/state"
        for name in ["AUDIT_ROUTE.md","AUDIT_ROUTE_LOCK.json","AUDIT_INVENTORY.json","ASTRA_CONTINUATION.md","ASTRA_AUDIT_STATE.md","verify_audit_route.py","AUDIT_DELTA_ROUTE.md","verify_audit_delta.py","verify_full_audit_state.py"]:
            a=state/name; b=peer_state/name
            if a.exists() and b.exists() and a.read_bytes()!=b.read_bytes(): errors.append(f"Mirror differs: {name}")
            elif a.exists()!=b.exists(): errors.append(f"Mirror presence differs: {name}")

    result={"ok":not errors,"baseline_todo_count":len(ids),"baseline_current_id":first,"delta_todo_count":len(dids),"errors":errors}
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 0 if not errors else 1

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[3])
    p.add_argument("--peer",type=Path)
    a=p.parse_args()
    raise SystemExit(main(a.root,a.peer.resolve() if a.peer else None))
