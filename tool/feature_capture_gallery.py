#!/usr/bin/env python3
"""Package real Flutter UI captures into a comparison PDF and offline gallery.

Run test/visual/feature_operation_capture_test.dart first. Requires Pillow and
ReportLab; no network requests, generated screenshots, or production data.
"""
import argparse
import html
import json
from pathlib import Path
import shutil
import zipfile

from PIL import Image, ImageDraw
from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

EXPECTED = {"filters": 40, "automation": 4, "autofill": 55, "extras": 7}
GROUPS = {"filters": "フィルター", "automation": "公式の自動操作",
          "autofill": "自動塗りプリセット", "extras": "記録・再実行と自動塗りの追加確認"}
FONT = "NIARIM-Report-JP"


def display_name(case, labels):
    if case["group"] != "filters":
        return case["name"]
    filter_id, variant = case["id"].split("_", 1)
    name = case["name"].split(" / ", 1)[0]
    names = {"Filter0013": "filterNameMonochrome", "Filter0014": "filterNameThreshold",
             "Filter0015": "filterNameFisheye", "Filter0016": "filterNameChromaticAberration",
             "Filter0017": "filterNameLensDistortion", "Filter0018": "filterNamePixelate"}
    name = labels.get(names.get(filter_id), name)
    prefix = {"Filter0004": "filterToneCurve", "Filter0019": "filterAuroraHologramPreset",
              "Filter0018": "pixelColorMode"}.get(filter_id)
    label = "初期設定" if variant == "default" else variant
    if prefix:
        label = labels[prefix + variant[0].upper() + variant[1:]]
    return f"{name} / {label}"


def wrapped(text, width, size):
    lines, line = [], ""
    for ch in text:
        if ch == "\n" or pdfmetrics.stringWidth(line + ch, FONT, size) > width:
            lines.append(line)
            line = "" if ch == "\n" else ch
        else:
            line += ch
    if line:
        lines.append(line)
    return lines


def draw_text(c, text, x, y, width, size=11, leading=16, color="#253047"):
    c.setFont(FONT, size)
    c.setFillColor(HexColor(color))
    for line in wrapped(text, width, size):
        c.drawString(x, y, line)
        y -= leading
    return y


def thumbnail(path):
    """Add a checkerboard only behind artwork thumbnails, keeping PNGs intact."""
    im = Image.open(path).convert("RGBA")
    background = Image.new("RGBA", im.size, "#ffffff")
    d = ImageDraw.Draw(background)
    for y in range(0, im.height, 12):
        for x in range(0, im.width, 12):
            if (x // 12 + y // 12) % 2:
                d.rectangle((x, y, x + 11, y + 11), fill="#e8edf2")
    return ImageReader(Image.alpha_composite(background, im).convert("RGB"))


def build_pdf(path, gallery, groups, revision):
    # Embed the app's licensed Japanese font so PDF readers need no CJK fallback.
    font = Path(__file__).resolve().parents[1] / "assets/fonts/NotoSerifJP.ttf"
    pdfmetrics.registerFont(TTFont(FONT, str(font)))
    w, h = landscape(A4)
    c = canvas.Canvas(str(path), pagesize=(w, h))
    c.setTitle("NIARIM 操作キャプチャ - 全プリセット比較")
    c.setAuthor("NIARIM development verification")
    page = 0

    def start(title):
        nonlocal page
        page += 1
        c.setFillColor(HexColor("#f4f6fa"))
        c.rect(0, 0, w, h, fill=1, stroke=0)
        draw_text(c, title, 28, h - 33, w - 56, size=17, leading=23)
        draw_text(c, f"NIARIM / UI操作から取得 / {revision[:12]}", 28, 18,
                  w - 90, size=8, color="#64748b")
        c.drawRightString(w - 28, 18, str(page))

    start("NIARIM 操作キャプチャ")
    y = h - 93
    y = draw_text(c, "25フィルター・全選択肢 / 公式自動操作4種類 / 自動塗り3プリセット・55パーツ",
                  38, y, w - 76, size=18, leading=27) - 28
    for label, desc in [
        ("106ケースの実行結果", "フィルター40、自動操作4、自動塗り55、記録再生・色更新・グラデーション等7。"),
        ("確認方法", "本番のNiarimAppと画面ルートをFlutterテスト環境で起動し、ボタン・選択肢を操作。適用前後の画素と生成レイヤーを検証しました。"),
        ("撮影条件", "Flutter 3.47.3 / Linuxレンダラー。画面480×960、画像960×1920。比較用の入力画像と保存先はテスト用です。Android・iOS実機での撮影ではありません。"),
        ("画像の読み方", "左が適用前、右が適用後。別レイヤーを作る処理は、元画像を非表示にした生成レイヤーを右側に掲載。通常の合成表示もZIPに収録しています。市松模様は透明部分です。"),
        ("ヘルプ・Tips", "全25フィルターの説明を更新。操作記録・公式自動操作・質感／プリズム／VHSの案内を7言語に追加・更新しました。末尾に日本語画面を掲載しています。"),
        ("原本", "ZIP内のindex.htmlで全ケースを検索できます。適用前後・設定画面・生成レイヤーのPNGと、設定値を記録したmanifest.jsonを収録しています。"),
    ]:
        y = draw_text(c, label, 38, y, 145, size=12, leading=17)
        # Body occupies the same starting baseline in a separate column.
        y = draw_text(c, desc, 188, y + 17, w - 230, size=11, leading=17) - 23
    c.showPage()

    for group, cases in groups.items():
        for offset in range(0, len(cases), 4):
            start(f"{GROUPS[group]}  {offset + 1}-{min(offset + 4, len(cases))} / {len(cases)}")
            for n, case in enumerate(cases[offset:offset + 4]):
                col, row = n % 2, n // 2
                x, top = 28 + col * ((w - 68) / 2 + 12), h - 65 - row * 251
                cw = (w - 68) / 2
                c.setFillColor(HexColor("#ffffff"))
                c.roundRect(x, top - 242, cw, 242, 8, fill=1, stroke=0)
                title = case["displayName"]
                draw_text(c, title, x + 12, top - 18, cw - 24, size=10, leading=13)
                image_size = 160
                ix = [x + 12, x + cw - image_size - 12]
                iy = top - 213
                after = case.get("generated", case["after"])
                for px, filename in zip(ix, [case["before"], after]):
                    c.drawImage(thumbnail(gallery / group / filename), px, iy,
                                image_size, image_size)
                draw_text(c, "適用前", ix[0], top - 46, 150, size=9)
                label = "生成レイヤー（元画像を非表示）" if "generated" in case else "適用後"
                draw_text(c, label, ix[1], top - 46, 163, size=8)
                note = "初期値は恒等変換（画素変化なし）" if case["changedPixels"] == 0 else "UI実行・出力確認済み"
                draw_text(c, note, x + 12, top - 230, cw - 24, size=8, color="#64748b")
            c.showPage()

    help_pages = [
        ("ヘルプ", [("help-custom-automation", "自動操作（操作記録）"),
                    ("help-filters", "全フィルターの説明")]),
        ("Tips", [("tips-automation", "公式の自動操作プリセット"),
                  ("tips-texture", "質感・プリズム・VHS")]),
    ]
    for title, images in help_pages:
        start(f"更新した{title}画面")
        for i, (name, label) in enumerate(images):
            x = 112 + i * 375
            draw_text(c, label, x, h - 66, 260, size=11)
            c.drawImage(str(gallery / "extras" / f"{name}.png"), x, 40,
                        width=235, height=470)
        c.showPage()
    c.save()


def build_html(gallery, groups):
    cards = []
    for group, cases in groups.items():
        for case in cases:
            name = html.escape(case["displayName"])
            links = [("beforeUI", "操作前の画面"), ("configurationUI", "設定画面"),
                     ("afterUI", "実行後の画面"), ("generatedUI", "生成レイヤーの画面")]
            links_html = " / ".join(f'<a href="{group}/{case[key]}">{label}</a>'
                                    for key, label in links if key in case)
            after = case.get("generated", case["after"])
            label = "生成レイヤー（元画像を非表示）" if "generated" in case else "適用後"
            cards.append(f'<article data-search="{name} {group}"><small>{GROUPS[group]}</small>'
                         f'<h2>{name}</h2><div class="images"><figure><figcaption>適用前</figcaption>'
                         f'<img src="{group}/{case["before"]}"></figure><figure>'
                         f'<figcaption>{label}</figcaption><img src="{group}/{after}"></figure></div>'
                         f'<p>{html.escape(case.get("note") or "UI実行・出力確認済み")}</p>'
                         f'<p>{links_html}</p><details><summary>設定値</summary><pre>'
                         f'{html.escape(json.dumps(case["settings"], ensure_ascii=False, indent=2))}'
                         '</pre></details></article>')
    document = '''<!doctype html><html lang="ja"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>NIARIM 操作キャプチャ</title>
<style>body{font-family:system-ui,sans-serif;background:#f4f6fa;color:#253047;margin:24px auto;max-width:1200px;padding:0 16px}
input{padding:12px;width:min(90%,600px);font-size:16px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px;margin-top:24px}
article{background:white;padding:20px;border-radius:12px;min-width:0}h2{font-size:18px}small{color:#64748b}.images{display:flex;gap:12px}
figure{margin:0;width:50%}figcaption{font-size:12px;min-height:34px}img{width:100%;background:repeating-conic-gradient(#e8edf2 0% 25%,white 0% 50%) 50%/16px 16px}
pre{font-size:12px;overflow:auto}a{color:#284f9b}p{font-size:13px;line-height:1.7}[hidden]{display:none!important}</style>
<h1>NIARIM 操作キャプチャ</h1><p>全106ケース。Flutter本番UI / Linuxレンダラー。実機撮影ではありません。詳細はREADME.mdをご覧ください。</p>
<input aria-label="キャプチャを検索" placeholder="機能名で検索" oninput="document.querySelectorAll('article').forEach(x=>x.hidden=!x.dataset.search.toLowerCase().includes(this.value.toLowerCase()))">
<main>''' + "\n".join(cards) + "</main></html>"
    (gallery / "index.html").write_text(document, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("build/feature-captures"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args()
    gallery = args.output / "NIARIM-captures"
    gallery.mkdir(parents=True, exist_ok=True)
    labels = json.loads((Path(__file__).resolve().parents[1] / "lib/l10n/app_ja.arb").read_text())
    groups = {}
    for group, count in EXPECTED.items():
        manifest = json.loads((args.input / group / "manifest.json").read_text())
        cases = manifest["cases"]
        assert len(cases) == count, (group, len(cases), count)
        assert len({c["id"] for c in cases}) == count
        assert all(c["status"] == "passed" for c in cases)
        for case in cases:
            case["displayName"] = display_name(case, labels)
        groups[group] = cases
        shutil.copytree(args.input / group, gallery / group, dirs_exist_ok=True)
        for case in cases:
            for key in ["before", "after", "beforeUI", "afterUI", "configurationUI"]:
                assert (gallery / group / case[key]).is_file(), (case["id"], key)
    (gallery / "manifest.json").write_text(json.dumps({
        "revision": args.revision,
        "environment": "Flutter 3.47.3 / production UI / Linux renderer, not Android or iOS hardware",
        "counts": EXPECTED, "groups": groups,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    (gallery / "README.md").write_text(f'''# NIARIM 操作キャプチャ

検証ソース: {args.revision}

25フィルターの全選択肢40ケース、公式自動操作4種類、自動塗り3プリセットの
全55パーツ、記録・再実行と自動塗りの追加設定7ケース。計106ケースです。
連続スライダーの全数値の組合せを網羅するものではありません。

Flutter 3.47.3のLinuxテストレンダラーで、本番NiarimAppと画面ルートを起動。
選択・適用・自動操作実行・自動塗り割当は画面のタップで行いました。
保存先と比較用入力画像のみテスト用です。実機撮影ではありません。
画面: 480×960 logical pixels / DPR 2 / PNG 960×1920。
作品: 256×256 / 原寸RGBA。beforeとafterで比較できます。

index.htmlを開くとオフラインで検索・比較できます。
各フォルダに操作前・設定・操作後の画面を収録。
generatedは元のレイヤーを画面上で非表示にした生成レイヤーの表示です。
通常の合成表示はafterに保持しています。
レベル補正の初期値とトーンカーブlinearは恒等変換です。
ドット絵paletteは選択した4色をexplicitとして複製する仕様です。
manifestのchangedPixelsは生のRGBA差分で、透明部分のRGB差分も含みます。
extrasの自動塗り設定は機能比較用であり、出荷プリセットとは別枠です。

ヘルプ・Tips画面はextras/help-*.pngとextras/tips-*.pngに収録しています。
''', encoding="utf-8")
    build_html(gallery, groups)
    pdf = args.output / "NIARIM-operation-captures.pdf"
    build_pdf(pdf, gallery, groups, args.revision)
    archive = args.output / "NIARIM-captures.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(gallery.rglob("*")):
            if path.is_file():
                z.write(path, path.relative_to(args.output))
    print(json.dumps({"cases": sum(EXPECTED.values()), "pdf": str(pdf.resolve()),
                      "zip": str(archive.resolve()),
                      "pngs": len(list(gallery.rglob("*.png")))}, ensure_ascii=False))


if __name__ == "__main__":
    main()
