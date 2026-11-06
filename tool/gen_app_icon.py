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

レンダリングにChromium（Playwright経由）を使う理由：
  当初cairosvgで描画していたが、app_logo.svgが<mask>要素（ペンと
  フィルムコマの交差部分を斜めに切り欠く「penClearance」、ペン軸の
  ボタン部分を楕円形にくり抜く「buttonClearance」）を使っており、
  cairosvgはこの2つのマスクを正しく適用できず、切り欠き・くり抜きが
  消えた（＝ただの塗りつぶし帯になった）状態でレンダリングしてしまう
  不具合があった。Chromium（Blinkのsvgレンダラー）は仕様通りに
  マスクを解釈できるため、アプリ内（flutter_svgで描画）と同じ見た目を
  再現できる。

使い方：
  pip install playwright pillow
  python3 tool/gen_app_icon.py
  dart run flutter_launcher_icons   # 生成した画像から各OS向けアイコンを書き出す

背景色は既定テーマ（レッド・ライト、lib/models/app_theme_preset.dart の
defaultLight）のaccentColorに合わせている。既定テーマの配色を変更した
場合は、このファイルとpubspec.yamlのadaptive_icon_backgroundの両方を
同じ色に更新すること。
"""

import io
import os

from PIL import Image
from playwright.sync_api import sync_playwright

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_PATH = os.path.join(REPO_ROOT, "assets/logo/app_logo.svg")
OUT_DIR = os.path.join(REPO_ROOT, "assets/icon")

CANVAS = 1024
RENDER_SIZE = 2048  # SVGを白抜きでレンダリングする際の解像度
ACCENT = (
    255,
    92,
    122,
    255,
)  # 0xFFFF5C7A コーラルピンク（既定テーマのアクセントカラー）


def _find_chromium_executable() -> str | None:
    """PLAYWRIGHT_BROWSERS_PATH配下から実際にインストール済みのchrome
    実行ファイルを探す。pipでインストールしたplaywrightパッケージの
    バージョンと、環境に事前インストール済みのブラウザのリビジョンが
    一致しないことがあり、その場合`p.chromium.launch()`のデフォルト
    パス解決は失敗する（headless_shellの別リビジョンを探しに行って
    しまう）ため、実在するパスを自前で探して明示的に渡す。見つから
    なければNoneを返し、Playwright側の既定解決に委ねる。
    """
    browsers_dir = os.environ.get("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers")
    if not os.path.isdir(browsers_dir):
        return None
    candidates = []
    for name in os.listdir(browsers_dir):
        if not name.startswith("chromium-"):
            continue
        candidate = os.path.join(browsers_dir, name, "chrome-linux", "chrome")
        if os.path.isfile(candidate):
            candidates.append(candidate)
    return sorted(candidates)[-1] if candidates else None


def render_white_glyph_via_chromium() -> Image.Image:
    with open(SVG_PATH, encoding="utf-8") as f:
        svg_src = f.read()
    # 元SVGのfill="#4A4636"を白へ置換してレンダリングする。
    svg_white = svg_src.replace('fill="#4A4636"', 'fill="#FFFFFF"')

    html = f"""<!doctype html><html><head><style>
html,body{{margin:0;padding:0;background:transparent;}}
svg{{width:{RENDER_SIZE}px;height:{RENDER_SIZE}px;display:block;}}
</style></head><body>{svg_white}</body></html>"""
    html_path = os.path.join(OUT_DIR, ".render_tmp.html")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=_find_chromium_executable())
            page = browser.new_page(
                viewport={"width": RENDER_SIZE, "height": RENDER_SIZE},
                device_scale_factor=1,
            )
            page.goto("file://" + os.path.abspath(html_path))
            png_bytes = page.locator("svg").screenshot(omit_background=True)
            browser.close()
    finally:
        os.remove(html_path)

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
    glyph = render_white_glyph_via_chromium()

    # フルブリード正方形：グリフはキャンバスの約86%を占める（「スマホ
    # アプリ版Claudeのアイコンくらいのバランス」という要望を受けて
    # 0.58→0.74→0.86と段階的に拡大）。丸角マスキングで削れる四隅の
    # ごく近くまでは寄せず、わずかに余白を残している。
    full = compose(glyph, CANVAS, 0.86, transparent_bg=False)
    full.convert("RGB").save(os.path.join(OUT_DIR, "app_icon.png"))

    # Android adaptive icon前景：Androidのセーフゾーン仕様（108dp中央
    # 66dp＝約61%の円内に収める）があるため、フルブリード版ほどは
    # 拡大できない。本グリフ（ペンが対角に伸びる非正方形の輪郭）は
    # 0.46時点でバウンディングボックスの対角先端がセーフゾーン円の
    # 半径に対して約8.9%の余白しか無く、その余白のほぼ上限である
    # 0.50に既に達しているため、フルブリード版のようにはこれ以上
    # 拡大できない（0.50を超えるとランチャーによっては円形マスクで
    # 四隅が欠ける）。
    fg = compose(glyph, CANVAS, 0.50, transparent_bg=True)
    fg.save(os.path.join(OUT_DIR, "app_icon_foreground.png"))

    print(f"generated: {OUT_DIR}/app_icon.png, {OUT_DIR}/app_icon_foreground.png")


if __name__ == "__main__":
    main()
