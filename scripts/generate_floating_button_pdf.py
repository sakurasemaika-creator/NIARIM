"""Build real Flutter screenshot evidence for floating action buttons."""
import os
from pathlib import Path

from PIL import Image
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

src = Path("build/floating-button-captures")
pngs = sorted(src.glob("*.png"))
if len(pngs) != 7:
    raise SystemExit(f"Expected seven real Flutter screenshots, found {len(pngs)}")
target = src / "NIARIM_floating_buttons_actual_screens.pdf"
c = canvas.Canvas(str(target), pagesize=A4)
c.setTitle("NIARIM - actual Flutter floating button screenshots")
for index, file in enumerate(pngs, 1):
    with Image.open(file) as im:
        width, height = im.size
        c.setFillColorRGB(0.04, 0.11, 0.20)
        c.setFont("Helvetica-Bold", 14)
        c.drawString(26, A4[1]-34, "NIARIM  /  Floating actions")
        c.setFont("Helvetica", 10)
        c.drawString(26, A4[1]-51, file.stem.replace("_", " "))
        image = im.convert("RGB")
        available_width = A4[0] - 52
        available_height = A4[1] - 120
        factor = min(available_width / width, available_height / height)
        dw, dh = width * factor, height * factor
        x, y = (A4[0]-dw)/2, 35+(available_height-dh)/2
        c.drawImage(ImageReader(image), x, y, dw, dh)
        c.setStrokeColorRGB(0.75, 0.79, 0.84)
        c.rect(x, y, dw, dh, stroke=1, fill=0)
        c.setFont("Helvetica", 8)
        c.drawString(26, 17, "Flutter UI capture / dev_branch " +
            os.environ.get("GITHUB_SHA", "local")[:12])
        c.drawRightString(A4[0]-26, 17, f"{index} / {len(pngs)}")
        c.showPage()
c.save()
print(target)
