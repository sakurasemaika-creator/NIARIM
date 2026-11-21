"""Build a PDF from actual Flutter screenshots captured by clipboard tests.

Only image files written by passing widget tests are included.
Usage: python3 scripts/generate_home_clipboard_pdf.py [png_dir] [pdf_file]
"""
from pathlib import Path
import os
import sys

from PIL import Image
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

CAPTIONS = {
    "01_received_share_tab": "Received share collection",
    "02_received_folder_copied": "Received folder copied to clipboard",
    "03_received_folder_trash_confirmation": "Confirmation before moving received folder to Trash",
    "04_received_folder_in_trash": "Received folder (with contents) in Trash",
    "05_received_folder_restore_confirmation": "Confirmation before restoring received folder",
    "06_received_folder_restored": "Received folder and its projects restored",
    "07_works_empty_folder": "Exported works: empty folder",
    "08_empty_folder_cross_tab_paste": "Format-neutral empty folder pasted into Projects",
    "09_project_cross_format_restriction": "Incompatible project-to-Works paste explains why",
    "10_project_trash_30days_confirmation": "Project Trash confirmation and 30-day retention",
    "11_project_in_trash": "Project displayed in Trash",
    "12_project_restore_confirmation": "Project restoration confirmation",
    "13_project_restored": "Project returned to Projects collection",
    "14_outgoing_share_pill": "Created outgoing share collection (separate pill format)",
    "15_outgoing_trash_confirmation": "Confirmation before moving own shared export to Trash",
    "16_outgoing_in_trash": "Own exported share shown in Trash",
    "17_outgoing_restore_confirmation": "Confirmation before restoring outgoing share",
    "18_outgoing_restored": "Own shared export restored into its original pill",
    "19_works_folder_trash_confirmation": "Confirmation before moving exported-work folder into Trash",
    "20_works_folder_in_trash": "Exported-work folder in Trash",
    "21_works_folder_restore_confirmation": "Confirmation before restoring exported-work folder",
    "22_works_folder_restored": "Empty exported-work folder restored successfully",
    "23_bulk_folder_trash_confirmation": "Bulk folder and project deletion confirmation",
    "24_project_right_click_menu": "Project right-click context menu before renaming",
}

def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "build/home-clipboard-captures")
    dest = Path(sys.argv[2] if len(sys.argv) > 2 else "build/home-clipboard-captures/NIARIM_clipboard_trash_screenshots.pdf")
    files = sorted(src.glob("*.png"))
    if len(files) < 24:
        raise SystemExit(f"Expected at least 24 real captures; found {len(files)}: {[p.name for p in files]}")
    missing = set(CAPTIONS) - {p.stem for p in files}
    if missing:
        raise SystemExit("Missing required real screenshots: " + ", ".join(sorted(missing)))
    dest.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(dest), pagesize=A4, pageCompression=1)
    c.setTitle("NIARIM - Clipboard and Trash - Flutter screen captures")
    sha = os.environ.get("GITHUB_SHA", "local")[:12]
    for index, path in enumerate(files, 1):
        with Image.open(path) as im:
            image_width, image_height = im.size
            rotated = image_width > image_height * 1.2
            page_width, page_height = landscape(A4) if rotated else A4
            c.setPageSize((page_width, page_height))
            margin = 24
            c.setFillColorRGB(1, 1, 1)
            c.rect(0, 0, page_width, page_height, fill=1, stroke=0)
            c.setFillColorRGB(0.07, 0.12, 0.19)
            c.setFont("Helvetica-Bold", 13)
            c.drawString(margin, page_height - 32, "NIARIM  /  Create works: clipboard and Trash")
            c.setFont("Helvetica", 10)
            c.drawString(margin, page_height - 49, CAPTIONS.get(path.stem, path.stem.replace("_", " ")))
            usable_width = page_width - 2 * margin
            usable_height = page_height - 109
            factor = min(usable_width / image_width, usable_height / image_height)
            draw_width, draw_height = image_width * factor, image_height * factor
            draw_x = (page_width - draw_width) / 2
            draw_y = 34 + (usable_height - draw_height) / 2
            c.drawImage(ImageReader(im.convert("RGB")), draw_x, draw_y,
                        width=draw_width, height=draw_height)
            c.setStrokeColorRGB(0.83, 0.86, 0.88)
            c.rect(draw_x, draw_y, draw_width, draw_height, stroke=1, fill=0)
            c.setFillColorRGB(0.3, 0.35, 0.4)
            c.setFont("Helvetica", 8)
            c.drawString(margin, 16, f"Actual Flutter widget-test screenshot | dev_branch SHA: {sha}")
            c.drawRightString(page_width - margin, 16, f"{index} / {len(files)}")
            c.showPage()
    c.save()
    print(f"Created {dest} from {len(files)} real Flutter screenshots")

if __name__ == "__main__":
    main()
