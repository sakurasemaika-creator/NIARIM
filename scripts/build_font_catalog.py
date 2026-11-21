#!/usr/bin/env python3
"""google/fontsリポジトリのMETADATA.pb群からテキストツール用の
追加フリーフォントカタログ（JSON）を生成する。

出力: assets/font_catalog/font_catalog.json
（`設定 → フォント管理 → 追加フリーフォントを探す`で表示するカタログ。
仕様書15参照）

使い方:
    python3 scripts/build_font_catalog.py

- 対象: ofl/（SIL Open Font License）・apache/（Apache License 2.0）・
  ufl/（Ubuntu Font License）配下の全ファミリー
- 各ファミリーからweight:400・style:normalの静的ファイル（無ければ先頭の
  fontsブロック）を1つだけ選び、ダウンロード対象ファイルとする
  （複数ウェイトは対象外）
- google/fontsの全量ダウンロードを避けるため、`git clone --filter=
  blob:none --no-checkout`（ツリー構造のみ取得）→ 必要なMETADATA.pb
  のblobだけを`git fetch --stdin`で一括取得、という手順でネットワーク
  転送量を最小化している（フォント本体のバイナリは一切取得しない）。
- 生成後、各URLが実際に200を返すことを簡易チェックすることを推奨
  （本スクリプトには含まない。大量リクエストになるため必要な時のみ
  別途 `xargs -P` 等で確認する）。
"""

import json
import os
import re
import shutil
import subprocess
import tempfile
from urllib.parse import quote

REPO_URL = "https://github.com/google/fonts.git"
LICENSE_DIRS = ["ofl", "apache", "ufl"]
LICENSE_NAMES = {
    "ofl": "SIL Open Font License 1.1",
    "apache": "Apache License 2.0",
    "ufl": "Ubuntu Font License 1.0",
}

# 除外するファミリー（アプリに常時同梱済みで重複するもの等）
EXCLUDE_FAMILIES = {
    "notoserifjp",
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_PATH = os.path.join(REPO_ROOT, "assets", "font_catalog", "font_catalog.json")


def run(cmd, cwd=None, input_bytes=None, check=True):
    proc = subprocess.run(cmd, cwd=cwd, input=input_bytes, capture_output=True)
    if check and proc.returncode != 0:
        raise RuntimeError(
            f"command failed: {cmd}\n{proc.stderr.decode(errors='replace')}"
        )
    return proc


def clone_treeless(workdir):
    run(
        [
            "git",
            "clone",
            "--filter=blob:none",
            "--no-checkout",
            "--depth",
            "1",
            REPO_URL,
            workdir,
        ]
    )
    run(["git", "config", "gc.auto", "0"], cwd=workdir)


def list_metadata_paths(workdir):
    """ls-tree -r（ローカルのみ・ネットワーク不要）でMETADATA.pbのpath→shaを得る。"""
    proc = run(["git", "ls-tree", "-r", "HEAD", "--"] + LICENSE_DIRS, cwd=workdir)
    mapping = {}
    for line in proc.stdout.decode("utf-8").splitlines():
        if not line.endswith("METADATA.pb"):
            continue
        meta, path = line.split("\t", 1)
        sha = meta.split()[2]
        mapping[path] = sha
    return mapping


def batch_fetch(workdir, shas):
    """必要なblobだけを1回のfetchでまとめて取得する
    （checkout単位で自動的に行われる逐次フェッチより大幅に高速）。"""
    input_data = ("\n".join(shas) + "\n").encode("utf-8")
    run(
        [
            "git",
            "-c",
            "fetch.negotiationAlgorithm=noop",
            "fetch",
            "origin",
            "--no-tags",
            "--no-write-fetch-head",
            "--recurse-submodules=no",
            "--filter=blob:none",
            "--stdin",
        ],
        cwd=workdir,
        input_bytes=input_data,
    )


def batch_read_blobs(workdir, sha_list):
    input_data = ("\n".join(sha_list) + "\n").encode("utf-8")
    proc = run(["git", "cat-file", "--batch"], cwd=workdir, input_bytes=input_data)
    out = proc.stdout
    result = {}
    pos = 0
    for sha in sha_list:
        nl = out.index(b"\n", pos)
        header = out[pos:nl].decode("utf-8").split()
        assert header[0] == sha, f"sha mismatch: {header[0]} != {sha}"
        size = int(header[2])
        content_start = nl + 1
        result[sha] = out[content_start : content_start + size].decode(
            "utf-8", errors="replace"
        )
        pos = content_start + size + 1
    return result


def parse_metadata(text):
    name_m = re.search(r'^name:\s*"([^"]*)"', text, re.MULTILINE)
    category_m = re.search(r'^category:\s*"([^"]*)"', text, re.MULTILINE)
    name = name_m.group(1) if name_m else None
    category = category_m.group(1) if category_m else "SANS_SERIF"

    blocks = re.findall(r"fonts\s*\{([^}]*)\}", text, re.DOTALL)
    entries = []
    for b in blocks:
        style_m = re.search(r'style:\s*"([^"]*)"', b)
        weight_m = re.search(r"weight:\s*(\d+)", b)
        filename_m = re.search(r'filename:\s*"([^"]*)"', b)
        if not filename_m:
            continue
        entries.append(
            {
                "style": style_m.group(1) if style_m else "normal",
                "weight": int(weight_m.group(1)) if weight_m else 400,
                "filename": filename_m.group(1),
            }
        )
    if not entries:
        return None

    chosen = next(
        (e for e in entries if e["weight"] == 400 and e["style"] == "normal"),
        entries[0],
    )
    return {"name": name, "category": category, "filename": chosen["filename"]}


def main():
    workdir = tempfile.mkdtemp(prefix="google-fonts-")
    try:
        print(f"Cloning {REPO_URL} (treeless) into {workdir} ...")
        clone_treeless(workdir)

        path_sha = list_metadata_paths(workdir)
        print(f"Found {len(path_sha)} METADATA.pb files")

        print("Batch-fetching METADATA.pb blobs ...")
        batch_fetch(workdir, list(path_sha.values()))

        paths = sorted(path_sha.keys())
        blob_contents = batch_read_blobs(workdir, [path_sha[p] for p in paths])

        catalog = []
        skipped = []
        for path in paths:
            license_dir, family_dir, _ = path.split("/")
            if family_dir in EXCLUDE_FAMILIES:
                continue
            text = blob_contents[path_sha[path]]
            parsed = parse_metadata(text)
            if parsed is None or not parsed["name"]:
                skipped.append(path)
                continue
            source_url = (
                f"https://raw.githubusercontent.com/google/fonts/main/"
                f"{license_dir}/{family_dir}/{quote(parsed['filename'])}"
            )
            catalog.append(
                {
                    "id": f"dlfont_{family_dir}",
                    "displayName": parsed["name"],
                    "fileName": parsed["filename"],
                    "sourceUrl": source_url,
                    "category": parsed["category"],
                    "license": LICENSE_NAMES[license_dir],
                }
            )

        catalog.sort(key=lambda e: e["displayName"])
        print(f"Catalog entries: {len(catalog)}, skipped: {len(skipped)}")
        if skipped:
            print("Skipped paths (first 10):", skipped[:10])

        os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
        with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
            json.dump(catalog, f, ensure_ascii=False, separators=(",", ":"))
        print(f"Wrote {OUTPUT_PATH}")

        from collections import Counter

        print("Category counts:", dict(Counter(e["category"] for e in catalog)))
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
