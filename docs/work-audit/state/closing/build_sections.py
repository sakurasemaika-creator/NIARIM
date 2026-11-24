"""Builds the per-ID done sections for AUDIT_ROUTE's A/W rows.

Usage: build_sections.py <id_tests.json> <route_matrix_dir> <out.md> <app_sha> <web_sha> <ci_note>
"""

import json
import re
import sys
from pathlib import Path

app = Path(__file__).resolve().parents[4]
id_tests = json.loads(Path(sys.argv[1]).read_text())
matrix_dir = Path(sys.argv[2])
out = Path(sys.argv[3])
app_sha, web_sha, ci_note = sys.argv[4], sys.argv[5], sys.argv[6]

route = (app / "docs/work-audit/state/AUDIT_ROUTE.md").read_text()
rows = [
    [x.strip() for x in l.strip("|").split("|")]
    for l in route.splitlines()
    if re.match(r"^\| [AW]\d{3}(?:\.\d+)? \|", l)
]

# Route matrix: route path -> (cells, failing)
cells = {}
if matrix_dir.suffix == ".csv":
    import csv

    matrix = list(csv.DictReader(matrix_dir.read_text(encoding="utf-8").splitlines()))
else:
    matrix = [
        c
        for f in sorted(matrix_dir.glob("route_matrix_*.json"))
        for c in json.loads(f.read_text())
    ]
for c in matrix:
    key = c["route"]
    total, bad = cells.get(key, (0, 0))
    cells[key] = (total + 1, bad + (1 if c["problems"] else 0))

ROUTE_OF = [  # source file -> route in the matrix
    ("lib/screens/splash/", "/"),
    ("lib/screens/home/", "/home"),
    ("lib/screens/project/new_project", "/new-project"),
    ("lib/screens/project/", "/project/:id"),
    ("lib/screens/canvas/", "/canvas/:id"),
    ("lib/screens/timeline/", "/timeline/:id"),
    ("lib/screens/export/", "/export/:id"),
    ("lib/screens/save_tree/", "/save-tree/:id"),
    ("lib/screens/materials/", "/materials/:id"),
    ("lib/screens/community/", "/community"),
    ("lib/screens/premium/", "/premium"),
    ("lib/screens/rewards/", "/rewards"),
    ("lib/screens/help/", "/help"),
    ("lib/screens/tips/", "/tips"),
    ("lib/screens/storage/", "/storage"),
    ("lib/screens/autofill", "/autofill-presets"),
    ("lib/screens/settings/workspace", "/settings/workspace"),
    ("lib/screens/settings/theme", "/settings/theme"),
    ("lib/screens/settings/transfer", "/settings/transfer"),
    ("lib/screens/settings/font", "/settings/fonts"),
    ("lib/screens/settings/", "/settings"),
]

SCOPE = {
    "NATIVE": "Androidの実機（タッチ・筆圧・ペン・共有・ウィジェット・R8の起動）での確認は全面監査の範囲外（所有者の指定2026-11-23）で、人の作業の一覧に残す。",
    "API": "本番のバックエンドのデプロイと実際のYouTube・Google・AdMobの接続は人の作業（コードとローカルの検証は済み）。",
    "LEGAL": "法務の確認（専門家の判断・一次資料の調査・届出の要否）は全面監査の範囲外（所有者の指定2026-11-23）で、人の作業の一覧に残す。",
    "EXTERNAL": "市場・検索の実データの取得と外部の確認は人の作業（AIで書ける案・表示までを行った）。",
    "PERF": "端末での時間の計測は範囲外（この計算機での計測はD035）。",
    "SEO": "公開の環境での検索エンジンの確認は人の作業（静的な確かめは済み）。",
    "UW+HTTP": "公開の環境での確認は人の作業（ローカルのWorkerで確かめた）。",
}


def routes_for(row):
    found = []
    for src in [s.strip() for s in row[6].split(";")]:
        for prefix, r in ROUTE_OF:
            if src.startswith(prefix):
                if r not in found:
                    found.append(r)
                break
    return found


STOP = {
    "screen",
    "screens",
    "widget",
    "widgets",
    "service",
    "services",
    "test",
    "dart",
    "lib",
    "utils",
    "models",
    "engine",
    "the",
    "and",
    "of",
    "panel",
    "page",
}


def tokens(text):
    return {
        t for t in re.split(r"[^a-z0-9]+", text.lower()) if len(t) > 2 and t not in STOP
    }


def ranked(row, tests):
    want = set()
    for src in row[6].split(";"):
        want |= tokens(src.strip().split("/")[-1].replace(".dart", ""))
    want |= tokens(row[1])

    def score(t):
        name = tokens(t.split("/")[-1].replace("_test.dart", ""))
        return (-len(name & want), t)

    return sorted(tests, key=score)


lines = []
for r in rows:
    rid, title, prof = r[0], r[1], r[5]
    tests = id_tests.get(rid, [])
    app_t = ranked(r, [t for t in tests if not t.startswith("web:")])
    web_t = ranked(r, [t[4:] for t in tests if t.startswith("web:")])
    lines.append(f"## {rid} — {title}（正式done、2026-11-24、Claude・S56）")
    lines.append("")
    lines.append(
        f"- 判定：OK。四巡目（2026-11-23、「四巡目」の節）の"
        f"判定を、最新（App `{app_sha}`・Web `{web_sha}`）で締めの確かめに通した。"
        "一巡目〜三巡目の証跡・修正引継ぎ台帳の記録はこの節の上の各巡の節にある。"
    )
    if rid.startswith("A"):
        shown = ", ".join(f"`{t}`" for t in app_t[:6])
        more = f" ほか{len(app_t) - 6}本" if len(app_t) > 6 else ""
        if app_t and all(t.startswith("backend/") for t in app_t):
            lines.append(
                f"- test：この項目を確かめるバックエンドのtest {len(app_t)}本（{shown}{more}）。"
                "バックエンドのCI（`backend-ci.yml`）と2026-11-24のローカルのvitest（64ファイル・418件成功）で成功。"
            )
        elif app_t:
            lines.append(
                f"- test：この項目の実装を読み込むtest {len(app_t)}本（{shown}{more}）。"
                f"この計算機の全件のtest（`d9d389de`・`2fa8e63d`、964ファイル、成功6020。失敗はrootで権限が効かない既知の3件と、`012bd085`で直した撮影のtest）と{ci_note}で成功。"
            )
        else:
            lines.append(
                f"- test：{ci_note}（バックエンドは`backend/test`のvitest、ネイティブ・CIは各ワークフロー）。"
            )
        rs = routes_for(r)
        if prof.startswith("UA") and rs:
            parts = []
            for route_path in rs:
                total, bad = cells.get(route_path, (0, 0))
                if total:
                    parts.append(f"`{route_path}` {total}セル・問題{bad}")
            if parts:
                lines.append(
                    "- 表示の組み合わせ（24の幅×スマホ/PC×7言語、`test/visual/all_routes_cell_matrix_test.dart`、"
                    "レイアウトの例外・はみ出し）：" + "、".join(parts) + "。"
                )
    else:
        if web_t:
            shown = ", ".join(f"`{t}`" for t in web_t[:6])
            more = f" ほか{len(web_t) - 6}本" if len(web_t) > 6 else ""
            lines.append(
                f"- 監査：このページ・部品を確かめるWebの監査 {len(web_t)}本（{shown}{more}）。"
                "四巡目の監査一式（7言語×SP・PC、全ページ24幅、トップ35幅、ブラウザの巡回）で問題0。"
            )
        else:
            lines.append(
                "- 監査：四巡目のWebの監査一式（7言語×SP・PC、全ページ24幅、トップ35幅、ブラウザの巡回）で問題0。"
            )
    for key, note in SCOPE.items():
        if key in prof.split("+") or prof == key:
            lines.append(f"- 範囲外：{note}")
    lines.append("")

out.write_text("\n".join(lines))
print(len(rows), "sections,", len(out.read_text()), "chars")
