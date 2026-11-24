#!/usr/bin/env python3
"""Assign the production files added after the baseline inventory to audit IDs.

The baseline inventory (AUDIT_INVENTORY.json, 2026-09-09) lists the files that
existed then. Files added later are assigned here: first by the feature words
in their path (brush, timeline, export, ...), then by the IDs of the baseline
files in the same directory. Writes D031_DELTA_FILE_ASSIGNMENT.md and prints
the counts; exits 1 if a file stays unassigned.

Usage: python3 docs/work-audit/state/assign_delta_files.py
"""

import collections
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
STATE = Path(__file__).resolve().parent
PRODUCT = (
    "lib/",
    "android/app/src/",
    "backend/src/",
    "backend/lib/",
    "assets/",
    "tool/",
)

# Asset folders decide the feature themselves (a brush tip named "marker" is a
# brush, not a timeline marker); Tips images also count for the feature shown.
FOLDER_IDS = [
    ("assets/brushes/", ["A013", "A014"]),
    ("assets/stamps/", ["A026"]),
    ("assets/tones/", ["A025"]),
    ("assets/tips/", ["A087"]),
]

# Feature words in a path, most specific first.
KEYWORDS = [
    ("messagingservice", ["A097", "A100"]),
    ("communitynotices", ["A097", "A100"]),
    ("loginbonus", ["A089"]),
    ("creatorwork", ["A089"]),
    ("creatorqualified", ["A089"]),
    ("creatoredit", ["A096", "A098"]),
    ("editsession", ["A096", "A098"]),
    ("playverification", ["A088", "A098"]),
    ("workmetadata", ["A096"]),
    ("worksplayback", ["A091"]),
    ("dependency_inventory", ["A085", "A104"]),
    ("home_list", ["A004"]),
    ("clipboard", ["A005"]),
    ("home_selection", ["A005"]),
    ("home_collection_selection", ["A005"]),
    ("folder_save", ["A006"]),
    ("preferences", ["A001"]),
    ("ink_clip", ["A011", "A101"]),
    ("preset_stroke", ["A013"]),
    ("stroke_sample", ["A013"]),
    ("backgroundblend", ["A037"]),
    ("background_blend", ["A037"]),
    ("lensblur", ["A037"]),
    ("lens_blur", ["A037"]),
    ("login_bonus", ["A089"]),
    ("creator_mission", ["A089", "A097"]),
    ("mission", ["A089"]),
    ("reward", ["A089"]),
    ("coin", ["A089"]),
    ("membership", ["A088", "A089"]),
    ("premium", ["A088"]),
    ("admob", ["A089"]),
    ("advert", ["A089"]),
    ("ad_mock", ["A089"]),
    ("ad_modal", ["A089"]),
    ("ad_placement", ["A089"]),
    ("ad_live", ["A089"]),
    ("creator_edit", ["A096"]),
    ("app_locale", ["A001", "A102"]),
    ("google_auth", ["A094"]),
    ("account", ["A094"]),
    ("youtube", ["A091", "A096"]),
    ("community_post", ["A096"]),
    ("post_", ["A096"]),
    ("follow", ["A097"]),
    ("notification", ["A097"]),
    ("push", ["A097"]),
    ("ranking", ["A090", "A099"]),
    ("community", ["A090", "A091"]),
    ("author", ["A092"]),
    ("shorts", ["A093"]),
    ("export_audio", ["A050", "A063"]),
    ("export", ["A063", "A064"]),
    ("exported_work", ["A064"]),
    ("share", ["A065"]),
    ("trash", ["A066"]),
    ("storage", ["A069"]),
    ("autosave", ["A061"]),
    ("niapro", ["A061"]),
    ("archive", ["A061", "A065"]),
    ("serializer", ["A061"]),
    ("save_tree", ["A059", "A060"]),
    ("save_", ["A059", "A060"]),
    ("niatra", ["A083"]),
    ("transfer", ["A083"]),
    ("autofill", ["A036", "A067", "A068"]),
    ("automation", ["A043", "A044"]),
    ("onion", ["A040"]),
    ("quick_tool", ["A041"]),
    ("frame_strip", ["A042"]),
    ("keyframe", ["A035"]),
    ("camera", ["A052"]),
    ("marker", ["A053"]),
    ("effect", ["A054"]),
    ("end_card", ["A055"]),
    ("endcard", ["A055"]),
    ("watermark", ["A056", "A082"]),
    ("audio", ["A050"]),
    ("waveform", ["A050"]),
    ("sound", ["A050"]),
    ("timeline_material", ["A048", "A049"]),
    ("material", ["A048", "A062"]),
    ("clip", ["A048", "A049"]),
    ("scene", ["A046"]),
    ("timeline", ["A045", "A047"]),
    ("ink_pool", ["A037"]),
    ("lineart", ["A037"]),
    ("pixel_art", ["A037", "A039"]),
    ("pixel", ["A039"]),
    ("sphere", ["A037"]),
    ("watercolor_border", ["A037"]),
    ("prism", ["A037"]),
    ("fisheye", ["A037"]),
    ("lens", ["A037"]),
    ("anime", ["A037"]),
    ("texture", ["A037", "A013"]),
    ("tone_curve", ["A037", "A038"]),
    ("filter", ["A037", "A038"]),
    ("moonlit", ["A037"]),
    ("blend", ["A032"]),
    ("premultiplied", ["A012", "A037"]),
    ("hair_fold", ["A013", "A014"]),
    ("outline_accent", ["A013", "A014"]),
    ("watercolor", ["A013"]),
    ("perceptual_color", ["A013"]),
    ("spectral", ["A013"]),
    ("brush", ["A013", "A014"]),
    ("stroke", ["A012"]),
    ("eraser", ["A015"]),
    ("palette", ["A017"]),
    ("hsv", ["A016"]),
    ("color", ["A016"]),
    ("bucket", ["A018", "A078"]),
    ("lasso", ["A018"]),
    ("selection", ["A019", "A020"]),
    ("perspective", ["A021"]),
    ("mesh", ["A021"]),
    ("transform", ["A020", "A021"]),
    ("shape", ["A023"]),
    ("vertical_text", ["A024"]),
    ("text_object", ["A024"]),
    ("tone", ["A025"]),
    ("stamp", ["A026"]),
    ("asset_", ["A027"]),
    ("ruler", ["A028"]),
    ("reference", ["A030"]),
    ("navigator", ["A030"]),
    ("layer", ["A031", "A032", "A033"]),
    ("dock", ["A011", "A075", "A076"]),
    ("desktop", ["A011", "A076"]),
    ("pc_", ["A011", "A076"]),
    ("workspace", ["A075", "A076", "A077"]),
    ("canvas_size", ["A008"]),
    ("canvas", ["A010", "A029"]),
    ("gesture", ["A072"]),
    ("shortcut_widget", ["A079"]),
    ("home_widget", ["A079", "A080"]),
    ("widget_artwork", ["A080"]),
    ("shortcut", ["A073"]),
    ("keyboard", ["A073"]),
    ("pen_", ["A074"]),
    ("pressure", ["A074"]),
    ("theme", ["A081"]),
    ("accent", ["A081"]),
    ("font", ["A084"]),
    ("license", ["A085"]),
    ("legal", ["A085"]),
    ("privacy", ["A085"]),
    ("terms", ["A085"]),
    ("guide", ["A086"]),
    ("help", ["A086"]),
    ("tip", ["A087"]),
    ("tutorial", ["A003"]),
    ("drawer", ["A003"]),
    ("clipboard", ["A005"]),
    ("folder", ["A006"]),
    ("breadcrumb", ["A006"]),
    ("new_project", ["A007"]),
    ("project_detail", ["A009"]),
    ("home", ["A003", "A004"]),
    ("collection", ["A004"]),
    ("project", ["A004", "A009"]),
    ("splash", ["A002"]),
    ("startup", ["A001"]),
    ("bootstrap", ["A001"]),
    ("settings", ["A070", "A071"]),
    ("performance", ["A071", "A103"]),
    ("error_log", ["A070"]),
    ("_labels", ["A102"]),
    ("l10n", ["A102"]),
    ("name_collation", ["A004"]),
    ("api", ["A098"]),
    ("batch", ["A099"]),
    ("kotlin", ["A100"]),
    ("res/values", ["A100", "A102"]),
]


def main() -> int:
    inventory = json.loads((STATE / "AUDIT_INVENTORY.json").read_text(encoding="utf-8"))
    entries = [f for f in inventory["source_files"] if f["repo"] == "NIARIM"]
    known = {f["path"] for f in entries}
    by_dir = collections.defaultdict(collections.Counter)
    for entry in entries:
        directory = os.path.dirname(entry["path"])
        while True:
            for audit_id in entry["ids"]:
                by_dir[directory][audit_id] += 1
            if not directory:
                break
            directory = os.path.dirname(directory)

    listed = subprocess.run(
        ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.splitlines()
    new = sorted(
        f
        for f in listed
        if f.startswith(PRODUCT)
        and f not in known
        and not f.startswith("lib/l10n/app_localizations")
    )

    rows = []
    unassigned = []
    by_rule = collections.Counter()
    for path in new:
        lower = path.lower()
        ids = None
        folder_ids = next(
            (i for prefix, i in FOLDER_IDS if path.startswith(prefix)), None
        )
        if folder_ids is not None and not path.startswith("assets/tips/"):
            ids, rule = folder_ids, f"name: {path.split('/')[1]}"
        else:
            for word, word_ids in KEYWORDS:
                if word in lower:
                    ids, rule = word_ids, f"name: {word}"
                    break
            if folder_ids is not None:
                ids = folder_ids + [i for i in (ids or []) if i not in folder_ids]
                rule = rule if ids != folder_ids else "name: tips"
        if ids is None:
            directory = os.path.dirname(path)
            while directory and directory not in by_dir:
                directory = os.path.dirname(directory)
            counter = by_dir.get(directory)
            if counter:
                ids = [i for i, _ in counter.most_common(3)]
                rule = f"directory: {directory or '.'}"
        if ids is None:
            unassigned.append(path)
            continue
        by_rule[rule.split(":")[0]] += 1
        rows.append((path, ids, rule))

    lines = [
        "# D031 — ベースラインの後に足された製品のファイルの割り当て",
        "",
        (
            "`assign_delta_files.py`が作る。ベースラインの棚卸し（AUDIT_INVENTORY.json、2026-09-09）に無い"
            "製品のファイル（lib・android・backend・assets・tool）を、パスの機能の語（brush・timeline・"
            "export…）、無ければ同じフォルダのベースラインのファイルのIDで、監査のIDへ割り当てる。"
        ),
        "",
        f"- 対象：{len(new)}件、割り当て：{len(rows)}件、未割当：{len(unassigned)}件",
        f"- 機能の語で：{by_rule['name']}件、フォルダで：{by_rule['directory']}件",
        "",
        "| ファイル | ID | 決め方 |",
        "| --- | --- | --- |",
    ]
    for path, ids, rule in rows:
        lines.append(f"| `{path}` | {'・'.join(ids)} | {rule} |")
    for path in unassigned:
        lines.append(f"| `{path}` | 未割当 | - |")
    (STATE / "D031_DELTA_FILE_ASSIGNMENT.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "new_files": len(new),
                "assigned": len(rows),
                "by_name": by_rule["name"],
                "by_directory": by_rule["directory"],
                "unassigned": len(unassigned),
            },
            ensure_ascii=False,
        )
    )
    return 1 if unassigned else 0


if __name__ == "__main__":
    sys.exit(main())
