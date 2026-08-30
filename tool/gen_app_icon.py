#!/usr/bin/env python3
"""
アプリランチャーアイコンの元画像（assets/icon/）を
assets/logo/app_logo.svg から生成するスクリプト。

生成物：
- assets/icon/app_icon.png            フルブリード正方形
  （テーマカラー背景＋白抜きモノグラム。iOS/macOS/Windows/レガシー
  Androidの元画像として使う。角丸はここでは焼き込まず各OSの自動
  マスキングに委ねる — iOSは自前で角丸マスクを適用する仕様のため、
  あらかじめ角丸を焼き込むと二重マスキングで見た目が崩れる）
- assets/icon/app_icon_foreground.png  Android adaptive icon前景
  （透明背景＋白抜きモノグラムのみ。背景はpubspec.yamlの
  adaptive_icon_background側でテーマカラーを指定する）

使い方：
  pip install cairosvg pillow
  python3 tool/gen_app_icon.py
  dart run flutter_launcher_icons   # 生成した画像から各OS向けアイコンを書き出す

背景色は既定テーマ（レッド・ライト、lib/models/app_theme_preset.dart の
defaultLight）のaccentColorに合わせている。既定テーマの配色を変更した
場合は、このファイルとpubspec.yamlのadaptive_icon_backgroundの両方を
同じ色に更新すること。
"""

import io
import os

import cairosvg
from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_PATH = os.path.join(REPO_ROOT, "assets/logo/app_logo.svg")
OUT_DIR = os.path.join(REPO_ROOT, "assets/icon")

CANVAS = 1024
ACCENT = (255, 92, 122, 255)  # 0xFFFF5C7A コーラルピンク（既定テーマのアクセントカラー）


def render_white_glyph():
    with open(SVG_PATH, encoding="utf-8") as f:
        svg_src = f.read()
    # 元SVGのfill="#4A4636"を白へ置換してレンダリングする。
    svg_white = svg_src.replace('fill="#4A4636"', 'fill="#FFFFFF"')

    render_size = 2048
    png_bytes = cairosvg.svg2png(
        bytestring=svg_white.encode("utf-8"),
        output_width=render_size,
        output_height=render_size,
    )
    glyph = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    # 実際に描画されているピクセルのバウンディングボックスで切り出す
    # （viewBox全体に対して図形が余白込みで配置されているため）。
    bbox = glyph.split()[-1].getbbox()
    return glyph.crop(bbox)


def compose(glyph_cropped, canvas_size, glyph_target_ratio, transparent_bg):
    canvas = Image.new(
        "RGBA", (canvas_size, canvas_size), (0, 0, 0, 0) if transparent_bg else ACCENT
    )
    gw, gh = glyph_cropped.size
    scale = (canvas_size * glyph_target_ratio) / max(gw, gh)
    new_w, new_h = round(gw * scale), round(gh * scale)
    glyph_resized = glyph_cropped.resize((new_w, new_h), Image.LANCZOS)
    x = (canvas_size - new_w) // 2
    y = (canvas_size - new_h) // 2
    canvas.alpha_composite(glyph_resized, (x, y))
    return canvas


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    glyph = render_white_glyph()

    # フルブリード正方形：グリフはキャンバスの約58%を占める。
    full = compose(glyph, CANVAS, 0.58, transparent_bg=False)
    full.convert("RGB").save(os.path.join(OUT_DIR, "app_icon.png"))

    # Android adaptive icon前景：Androidのセーフゾーン仕様（108dp中央
    # 66dp＝約61%の円内に収める）に合わせ、フルブリード版よりやや
    # 小さめの約46%に抑える。
    fg = compose(glyph, CANVAS, 0.46, transparent_bg=True)
    fg.save(os.path.join(OUT_DIR, "app_icon_foreground.png"))

    print(f"generated: {OUT_DIR}/app_icon.png, {OUT_DIR}/app_icon_foreground.png")


if __name__ == "__main__":
    main()
