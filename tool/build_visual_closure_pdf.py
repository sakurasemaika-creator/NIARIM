"""Compose the visual closure PDF (full audit D029).

Reads build/visual-closure/manifest.json (written by
test/visual/visual_closure_capture_test.dart) and lays out each preset as a
row: kind, name and ID, its settings, BEFORE and AFTER. Writes
build/visual-closure/visual_closure.pdf and one PNG per page for eye review.

Usage: python3 tool/build_visual_closure_pdf.py [commit] [screen-dir ...]

Each screen-dir (for example build/community-five-icon-captures, written by
the community capture tests) adds its PNG files as screen rows after the
presets.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "visual-closure"
FONT = ROOT / "assets" / "fonts" / "NotoSerifJP.ttf"
PAGE_W, PAGE_H = 1654, 2339  # A4 at 200 dpi
MARGIN = 60
ROW_H = 300
THUMB_H = 250
KIND_LABEL = {
    "filter": "描画フィルター",
    "brush": "ブラシ",
    "brushmode": "ブラシの設定",
    "tone": "トーン",
    "stamp": "スタンプ",
    "theme": "テーマ",
    "screen": "画面",
    "setting": "設定の変更",
}


def wrap(draw, text, font, width):
    lines, line = [], ""
    for ch in text:
        if draw.textlength(line + ch, font=font) > width:
            lines.append(line)
            line = ch
        else:
            line += ch
    if line:
        lines.append(line)
    return lines


def thumb(path, max_width=980):
    image = Image.open(path).convert("RGB")
    scale = min(THUMB_H / image.height, max_width / image.width)
    return image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    )


def main():
    commit = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    items = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    for directory in sys.argv[2:]:
        for png in sorted((ROOT / directory).glob("*.png")):
            items.append(
                {
                    "kind": "screen",
                    "id": directory.rstrip("/").split("/")[-1],
                    "name": png.stem,
                    "settings": "",
                    "before": None,
                    "after": str(png.relative_to(ROOT)),
                }
            )
    title = ImageFont.truetype(str(FONT), 34)
    body = ImageFont.truetype(str(FONT), 22)
    small = ImageFont.truetype(str(FONT), 18)
    rows_per_page = (PAGE_H - MARGIN * 2 - 80) // ROW_H
    pages = []
    for start in range(0, len(items), rows_per_page):
        page = Image.new("RGB", (PAGE_W, PAGE_H), "white")
        draw = ImageDraw.Draw(page)
        number = start // rows_per_page + 1
        draw.text(
            (MARGIN, MARGIN),
            f"NIARIM 見た目の締め（D029）  App {commit}  "
            f"{number}/{(len(items) + rows_per_page - 1) // rows_per_page}",
            font=title,
            fill="black",
        )
        y = MARGIN + 80
        for item in items[start : start + rows_per_page]:
            draw.rectangle(
                (MARGIN, y, PAGE_W - MARGIN, y + ROW_H - 16), outline=(200, 200, 200)
            )
            text_x, text_w = MARGIN + 16, 520
            draw.text(
                (text_x, y + 12),
                f"{KIND_LABEL.get(item['kind'], item['kind'])}  {item['id']}",
                font=small,
                fill=(90, 90, 90),
            )
            ty = y + 42
            for line in wrap(draw, item["name"], body, text_w)[:2]:
                draw.text((text_x, ty), line, font=body, fill="black")
                ty += 30
            draw.text((text_x, ty + 6), "SETTINGS", font=small, fill=(150, 60, 80))
            ty += 32
            for line in wrap(draw, item["settings"] or "（既定）", small, text_w)[:7]:
                draw.text((text_x, ty), line, font=small, fill=(60, 60, 60))
                ty += 24
            x = MARGIN + 560
            for label, key in (
                ("BEFORE", "before"),
                ("SETTINGS", "settingsImage"),
                ("AFTER", "after"),
            ):
                if not item.get(key):
                    continue
                image = thumb(ROOT / item[key])
                draw.text((x, y + 8), label, font=small, fill=(150, 60, 80))
                page.paste(image, (x, y + 34))
                # A thin frame, so a blank (white) canvas still shows.
                draw.rectangle(
                    (x - 1, y + 33, x + image.width, y + 34 + image.height),
                    outline=(210, 210, 210),
                )
                x += image.width + 24
            y += ROW_H
        pages.append(page)
        page.save(OUT / f"page-{number:02d}.png")
    pages[0].save(OUT / "visual_closure.pdf", save_all=True, append_images=pages[1:])
    print(f"{len(items)} items, {len(pages)} pages -> {OUT / 'visual_closure.pdf'}")


if __name__ == "__main__":
    main()
