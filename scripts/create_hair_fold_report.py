#!/usr/bin/env python3
"""Build a visual report from production DrawingEngine capture PNGs.

Baseline captures must use the current fixture/settings with only
hair_fold_raster.dart replaced by the specified previous revision.
Requires reportlab and Pillow. No drawing is synthesized by this script.
"""
import argparse
from pathlib import Path

from PIL import Image
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision", default="fe92485f")
    parser.add_argument("--baseline-revision", default="2189afa7")
    args = parser.parse_args()
    font = Path(__file__).resolve().parents[1] / "assets/fonts/NotoSerifJP.ttf"
    pdfmetrics.registerFont(TTFont("JP", str(font)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    width, height = 842, 595
    pdf = canvas.Canvas(str(args.output), pagesize=(width, height))
    pdf.setTitle("NIARIM 折り畳みモード - 連続カール・共通設定の確認")
    pdf.setAuthor("NIARIM")
    page = 0

    def text(x, y, value, size=11, color="#263447"):
        pdf.setFillColor(HexColor(color))
        pdf.setFont("JP", size)
        pdf.drawString(x, y, value)

    def begin(title, subtitle):
        nonlocal page
        page += 1
        pdf.setFillColor(HexColor("#faf9f6"))
        pdf.rect(0, 0, width, height, fill=1, stroke=0)
        text(32, 551, title, 23)
        text(32, 525, subtitle, 10)
        pdf.setStrokeColor(HexColor("#d7dce2"))
        pdf.line(32, 508, width - 32, 508)
        text(32, 22, f"NIARIM / dev_branch / 描画実装 {args.revision} / 2026-09-30", 8)
        text(width - 60, 22, f"{page:02d}", 9)

    def panel(root, name, label, x, y, w, h, crop=None):
        text(x, y + h - 15, label, 12)
        path = root / f"{name}.png"
        image = Image.open(path).convert("RGB")
        if crop:
            image = image.crop(crop)
        available = h - 26
        scale = min(w / image.width, available / image.height)
        iw, ih = image.width * scale, image.height * scale
        pdf.drawImage(ImageReader(image), x + (w - iw) / 2, y + (available - ih) / 2,
                      width=iw, height=ih)

    def end():
        pdf.showPage()

    current, baseline = args.current, args.baseline
    spiral_crop = (120, 140, 660, 730)
    strand_crop = (160, 55, 570, 1000)
    modes = [
        ("wave_top_view", "ウェーブ俯瞰"),
        ("wave_low_angle", "ウェーブ煽り"),
        ("curl_right", "右巻き"),
        ("curl_left", "左巻き"),
        ("crescent", "三日月カール"),
    ]

    begin("折り畳みモード：連続カールと共通設定", "本番 DrawingEngine の実描画。前髪・後ろ髪の使用例と修正前後を収録。")
    panel(current, "usage_back_crescent", "後ろ髪 / 三日月カール", 32, 80, 270, 412)
    panel(current, "usage_front_crescent", "前髪 / 三日月カール", 316, 80, 270, 412)
    for index, line in enumerate([
        "今回の確認内容",
        "・270° / 540° 前後の接続",
        "・半回転 / 一回転前後の形状",
        "・髪・前髪の5モード",
        "・プリセットとカスタムの描画一致",
        "・共通のペン先・画像素材設定",
        "固定の入力線で比較し、",
        "描画処理は入力線を置換しません。",
    ]):
        text(606, 464 - index * 31, line, 11 if index else 14)
    text(32, 56, "比較は同じ素材・太さ・入力線で実施。修正前は旧輪郭処理のみを差し替えた比較環境です。", 10)
    end()

    for boundary, degrees in [(270, (265, 275)), (540, (535, 545))]:
        begin(f"連続カール：{boundary}° の前後", f"左：旧輪郭処理 {args.baseline_revision} / 右：現在 {args.revision}。共通条件：太さ64 px、縁取り2.5 px。")
        boundary_crop = (210, 258, 482, 560) if boundary == 270 else (150, 250, 538, 625)
        for row, degree in enumerate(degrees):
            y = 278 if row == 0 else 62
            name = f"hair_crescent_{degree}deg_continuous"
            panel(baseline, name, f"修正前 / {degree}°", 38, y, 370, 212, boundary_crop)
            panel(current, name, f"現在 / {degree}°", 434, y, 370, 212, boundary_crop)
        text(32, 44, "検出角度を越えた瞬間の丸い蓋を撤去。続きは実際の曲がりに合わせて成長します。", 10)
        end()

    begin("描き進めた途中：半回転・一回転の前後", "同じ螺旋入力の途中で止めた画像。別の位置で毛先が急に太くならないか確認。")
    for col, degree in enumerate((175, 185, 355, 365)):
        panel(current, f"hair_crescent_{degree}deg_continuous", f"{degree}°", 32 + col * 197, 95, 183, 391, spiral_crop)
    text(32, 66, "中心線の半回転を基準に三日月を接続。次のカールを丸い蓋で閉じません。", 11)
    end()

    for prefix, title in [("hair", "髪の毛ブラシ"), ("bangs", "前髪ブラシ / 画像素材")]:
        begin(f"5モードの比較：{title}", "全モードに同一の入力線・太さ・色を使用。前後関係と三日月の輪郭を確認。")
        for col, (mode, label) in enumerate(modes):
            panel(current, f"{prefix}_{mode}_same_curve", label, 32 + col * 157, 58, 148, 431, strand_crop)
        end()

    begin("縁取りペンとしての確認：同じ手描き曲線", "青線は元の入力。4つの重なりモードは同じ外形、三日月は描いた曲線から輪郭を作ります。")
    outline_modes = [("input", "折り畳みOFF / 入力線"), ("waveTopView", "ウェーブ俯瞰"),
                     ("waveLowAngle", "ウェーブ煽り"), ("curlRight", "右巻き"),
                     ("curlLeft", "左巻き"), ("crescent", "三日月カール")]
    for i, (mode, label) in enumerate(outline_modes):
        panel(current, f"outline_{mode}", label, 32 + i * 131, 62, 122, 427, (230, 40, 500, 920))
    end()

    for mode, title in [("waveTopView", "ウェーブ俯瞰"), ("crescent", "三日月カール")]:
        begin(f"髪型の使用例：{title}", "複数ストロークで作成。前髪の画像素材も共通のブラシ・折り畳み処理を使用。")
        panel(current, f"usage_back_{mode}", "後ろ髪", 56, 52, 342, 443)
        panel(current, f"usage_front_{mode}", "前髪", 444, 52, 342, 443)
        end()

    begin("プリセットとユーザーカスタム：描画の一致", "別ID・別名への変更とJSON保存復元後、髪・前髪 × 5モードのレイヤー画素を比較。全10組が一致。")
    for col, (name, label) in enumerate([
        ("hair_crescent_same_curve", "髪 / プリセット"),
        ("hair_crescent_custom_same_curve", "髪 / カスタム"),
        ("bangs_crescent_same_curve", "前髪 / プリセット"),
        ("bangs_crescent_custom_same_curve", "前髪 / カスタム"),
    ]):
        panel(current, name, label, 32 + col * 197, 57, 183, 437, strand_crop)
    end()

    begin("ブラシカスタム：折り畳み設定", "スマートフォン幅の本番ウィジェット。5種類のモードを共通設定として選択。")
    panel(current, "fold_settings_ja", "設定画面", 104, 52, 284, 440)
    panel(current, "fold_menu_ja", "モード選択", 454, 52, 284, 440)
    end()

    begin("ブラシカスタム：ペン先・画像素材", "共通設定で形状・チェーン比率・間隔・画像の濃淡・素材の順序を指定できます。")
    panel(current, "tip_settings_chain_ja", "チェーンの共通設定", 84, 50, 300, 444, (0, 0, 860, 1520))
    panel(current, "tip_settings_images_ja", "画像素材の共通設定", 448, 50, 310, 444, (0, 0, 860, 1320))
    end()

    begin("三日月カール：ストロークの向き", "同じ前髪素材と設定で、描く向きを変えた実描画。")
    panel(current, "crescent_stroke_angles", "入力の向きに合わせた輪郭", 38, 192, 766, 286)
    text(38, 151, "描く向き・角度・長さを本番 DrawingEngine に入力した結果です。", 12)
    text(38, 121, "この資料は折り畳みと関連共通設定の確認です。アプリ全機能の検証完了を意味しません。", 10)
    text(38, 91, "PNGはテストによる実描画・実ウィジェットのキャプチャです。画像生成による補正はありません。", 10)
    end()
    pdf.save()
    print(f"Created {args.output} ({page} pages)")


if __name__ == "__main__":
    main()
