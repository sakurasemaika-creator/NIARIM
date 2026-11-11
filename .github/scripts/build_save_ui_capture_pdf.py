#!/usr/bin/env python3
"""Bundle actual Flutter test PNG captures into one clearly labeled PDF."""
import argparse
import os
from pathlib import Path

from PIL import Image
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


def build(input_dir: Path, output: Path, revision: str) -> int:
    photos = sorted(p for p in input_dir.glob("*.png") if p.is_file())
    if not photos:
        raise RuntimeError(f"No Flutter screenshots found in {input_dir}")
    output.parent.mkdir(parents=True, exist_ok=True)

    pdf = canvas.Canvas(str(output), pagesize=A4, pageCompression=1)
    pdf.setTitle("NIARIM - save slot and save tree Flutter UI captures")
    pdf.setAuthor("NIARIM automated Flutter widget capture")
    w, h = A4
    pdf.setFillColor(colors.HexColor("#1C2A40"))
    pdf.rect(0, h - 178, w, 178, fill=1, stroke=0)
    pdf.setFillColor(colors.white)
    pdf.setFont("Helvetica-Bold", 22)
    pdf.drawString(45, h - 88, "NIARIM  /  SAVE UI")
    pdf.setFont("Helvetica", 12)
    pdf.drawString(45, h - 112, "Actual Flutter widget screenshots")
    pdf.setFillColor(colors.HexColor("#243244"))
    pdf.setFont("Helvetica", 11)
    pdf.drawString(45, h - 225, f"Revision: {revision[:16] if revision else 'unspecified'}")
    pdf.drawString(45, h - 248, f"Screenshot count: {len(photos)}")
    pdf.drawString(45, h - 271, "Covers save slots, save trees, rename and loading dialogs.")
    pdf.setFont("Helvetica", 10)
    pdf.drawString(45, h - 317, "Test-rendered Flutter UI; not an Android-device screenshot.")
    pdf.drawString(45, h - 333, "Images are embedded unaltered and scaled to fit the pages.")
    pdf.showPage()

    for idx, path in enumerate(photos, 1):
        with Image.open(path) as src:
            rgb = src.convert("RGB")
            image_w, image_h = rgb.size
            page_w, page_h = landscape(A4) if image_w > image_h else A4
            pdf.setPageSize((page_w, page_h))
            margin = 35
            top = 48
            bottom = 35
            max_w = page_w - 2 * margin
            max_h = page_h - top - bottom
            scale = min(max_w / image_w, max_h / image_h)
            draw_w, draw_h = image_w * scale, image_h * scale
            x = (page_w - draw_w) / 2
            y = bottom + (max_h - draw_h) / 2
            pdf.setFillColor(colors.HexColor("#243244"))
            pdf.setFont("Helvetica-Bold", 10)
            label = path.stem.replace("_", " ")
            pdf.drawString(margin, page_h - 28, label[:96])
            pdf.setFont("Helvetica", 8)
            pdf.drawRightString(page_w - margin, 17, f"{idx} / {len(photos)}")
            pdf.drawImage(ImageReader(rgb), x, y, width=draw_w,
                          height=draw_h, preserveAspectRatio=True)
        pdf.showPage()
    pdf.save()
    return len(photos)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path,
                        default=Path("build/save-slot-visual-audit"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision", default=os.environ.get("GITHUB_SHA", ""))
    args = parser.parse_args()
    print(f"Embedded {build(args.input, args.output, args.revision)} captures in {args.output}")


if __name__ == "__main__":
    main()
