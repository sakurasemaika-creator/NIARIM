#!/usr/bin/env python3
"""Package real Flutter UI captures into a labelled PDF and offline gallery.

Run test/visual/feature_operation_capture_test.dart first. Requires Pillow
only; no network requests. Every case becomes one card image with the
feature's name, its settings (named as the filter panel names them) and the
before/after artwork burned in; the PDF's pages are made of those cards.
"""

import argparse
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
GROUP_ORDER = ["filters", "pixel-compare", "blend", "automation", "autofill", "extras"]
GROUPS = {
    "filters": "フィルター（質感変更を除外）",
    "pixel-compare": "Pixel Art / Mosaic 同一fixture比較",
    "blend": "ブレンドモード（全25種）",
    "automation": "公式の自動操作",
    "autofill": "自動塗りプリセット（完成状態）",
    "extras": "記録・再実行と自動塗りの追加確認",
}
# Work of other sessions that this capture set must leave out: the texture
# change filter (質感変更 / Gradient Map) and the brush fold modes.
EXCLUDED_FILTER_IDS = {"Filter0019"}
EXCLUDED_KINDS = {"auroraHologram"}

HEADING_FONT = ROOT / "assets/fonts/Kuramubon.otf"
BODY_FONT = ROOT / "assets/fonts/NotoSerifJP.ttf"
PAGE_W, PAGE_H = 1754, 1240  # A4 landscape at 150 dpi
CARD_W, CARD_H = 817, 520
INK = "#253047"
MUTED = "#64748b"


def font(path, size):
    return ImageFont.truetype(str(path), size)


def display_name(case, labels):
    settings = case.get("settings") or {}
    if case["group"] == "pixel-compare" and settings.get("kind") == "pixelate":
        how = (
            labels["filterPixelateModeDots"]
            if settings.get("pixelArtByDots")
            else labels["filterPixelateModeBlock"]
        )
        size = settings.get("canvas")
        suffix = (
            f"（キャンバス{size.replace(' x ', '×')}）"
            if size and size != "256 x 256"
            else ""
        )
        return f"{labels['filterNamePixelate']} / {how}{suffix}"
    if case["group"] == "pixel-compare" and settings.get("kind") == "mosaic":
        return labels["filterNameMosaic"]
    if case["group"] != "filters":
        return case["name"]
    filter_id, variant = case["id"].split("_", 1)
    name = case["name"].split(" / ", 1)[0]
    names = {
        "Filter0014": "filterNameThreshold",
        "Filter0015": "filterNameFisheye",
        "Filter0016": "filterNameChromaticAberration",
        "Filter0017": "filterNameLensDistortion",
        "Filter0018": "filterNamePixelate",
    }
    name = labels.get(names.get(filter_id), name)
    prefix = {
        "Filter0004": "filterToneCurve",
        "Filter0018": "pixelColorMode",
    }.get(filter_id)
    label = {"default": "初期設定", "bold": "線を濃く・太く"}.get(variant, variant)
    flat = filter_id == "Filter0018" and variant.endswith("_flat")
    if flat:
        variant = variant.removesuffix("_flat")
    if prefix:
        label = labels.get(prefix + variant[0].upper() + variant[1:], variant)
    if filter_id == "Filter0018" and variant != "none":
        label += f"（{labels['filterPixelateDither']} {'OFF' if flat else 'ON'}）"
    return f"{name} / {label}"


def panel_fields():
    """The settings each filter kind's panel shows, as (label key, field),
    read from the panel's own source so the names match the app."""
    src = (ROOT / "lib/screens/canvas/widgets/filter_panel.dart").read_text(
        encoding="utf-8"
    )
    start = src.index("    switch (current.kind) {")
    body = src[start : src.index("Widget _hint(String text)")]
    parts = re.split(r"\n\s*case FilterKind\.(\w+):", body)
    fields, pending = {}, []
    for i in range(1, len(parts), 2):
        pending.append(parts[i])
        block = parts[i + 1]
        if not block.strip():
            continue
        pairs = re.findall(r"l10n\.(\w+),\s*current\.(\w+)", block)
        for kind in pending:
            fields[kind] = pairs
        pending = []
    sphere = src[src.index("Widget _sphereShadingControls") :]
    sphere = sphere[: sphere.index("\n  }\n")]
    fields["sphereShading"] = re.findall(r"l10n\.(\w+),\s*current\.(\w+)", sphere)
    # Settings the panel shows through its own widgets rather than a
    # labelled slider.
    fields["pixelate"] = [
        ("filterPixelateBlockSize", "strength"),
        ("pixelColorModeLabel", "pixelColorMode"),
        ("pixelColorModeExplicit", "pixelExplicitColors"),
        ("filterPixelateDither", "pixelDither"),
    ]
    fields["prism"] = [
        ("filterPrismBlurAmount", "prismBlurPx"),
        ("filterPrismColorDirection", "prismDirectionDegrees"),
    ]
    fields["toneCurve"] = [
        ("filterNameToneCurve", "toneCurvePreset"),
        ("RGB", "toneCurvePoints"),
        ("R", "toneCurveRedPoints"),
        ("G", "toneCurveGreenPoints"),
        ("B", "toneCurveBluePoints"),
    ]
    fields["levels"] = [
        ("filterLevelsInputBlack", "inputBlack"),
        ("filterLevelsInputWhite", "inputWhite"),
        ("filterLevelsGamma", "inputGamma"),
        ("filterLevelsOutputBlack", "outputBlack"),
        ("filterLevelsOutputWhite", "outputWhite"),
    ]
    return fields


def format_value(field, value):
    if isinstance(value, bool):
        return "ON" if value else "OFF"
    if isinstance(value, int) and (field.endswith("Color") or value > 0xFFFFFF):
        rgb = f"#{value & 0xFFFFFF:06X}"
        alpha = (value >> 24) & 0xFF
        return rgb if alpha == 0xFF else f"{rgb} α{round(alpha / 2.55)}%"
    if isinstance(value, float):
        return str(int(value)) if value == int(value) else f"{value:.2f}".rstrip("0")
    if isinstance(value, list):
        if not value:
            return "なし"
        if all(isinstance(v, int) for v in value) and field.endswith("Colors"):
            return " ".join(f"#{v & 0xFFFFFF:06X}" for v in value)
        pts = [
            f"({format_value('', value[i])},{format_value('', value[i + 1])})"
            for i in range(0, len(value) - 1, 2)
        ]
        return " ".join(pts) if len(pts) == len(value) // 2 else str(value)
    return str(value)


ENUM_PREFIXES = {
    "Blend": "blendMode",
    "blendMode": "blendMode",
    "lineColorMode": "autofillLineColorMode",
    "pixelColorMode": "pixelColorMode",
    "toneCurvePreset": "filterToneCurve",
}


def enum_label(field, value, labels):
    """A setting's value, with enum values named as the app names them."""
    if isinstance(value, str) and value:
        for suffix, prefix in ENUM_PREFIXES.items():
            if field.endswith(suffix) or field == suffix:
                key = prefix + value[0].upper() + value[1:]
                if key in labels:
                    return labels[key]
    return format_value(field, value)


AUTOFILL_PART_FIELDS = [
    ("color", "autofillPartFillColorLabel"),
    ("opacity", "autofillPartFillOpacityLabel"),
    ("blendMode", "autofillPartBlendModeLabel"),
    ("gradient", "autofillPartGradientTypeLabel"),
    ("lineColorMode", "autofillPartLineColorLabel"),
    ("lineColor", "autofillPartLineColorLabel"),
    ("lineOpacity", "autofillPartLineOpacityLabel"),
    ("traceHue", "autofillPartTraceHueLabel"),
    ("traceSaturation", "autofillPartTraceSaturationLabel"),
    ("traceLightness", "autofillPartTraceLightnessLabel"),
    ("outlineEnabled", "autofillPartOutlineLabel"),
    ("outlineColor", "autofillPartOutlineLabel"),
    ("outlineWidth", "autofillPartOutlineWidthLabel"),
    ("lineGapFill", "autofillPartLineGapLabel"),
]


def settings_summary(case, labels, fields):
    settings = case.get("settings") or {}
    if case["group"] == "filters":
        kind = settings.get("kind")
        parts = []
        for key, field in fields.get(kind, []):
            if field not in settings:
                continue
            value = settings[field]
            if isinstance(value, list) and not value:
                continue
            # Sphere shading shows one combined blend mode or one per colour.
            combined = settings.get("sphereCombined")
            if field == "sphereCombinedBlend" and not combined:
                continue
            if field in ("sphereShadowBlend", "sphereLightBlend") and combined:
                continue
            # Pixel art shows the colours only where the mode uses them.
            mode = settings.get("pixelColorMode")
            if field == "pixelExplicitColors" and mode not in ("explicit", "palette"):
                continue
            # The dithering switch only shows (and matters) when colours are
            # limited.
            if field == "pixelDither" and mode in (None, "none"):
                continue
            name = labels.get(key, key)
            parts.append(f"{name}: {enum_label(field, value, labels)}")
            if field == "pixelColorMode" and value == "count":
                count = settings.get("colorLevels")
                parts.append(f"{labels.get('filterColorLevels', '色数')}: {count}")
        return "設定値  " + " / ".join(parts) if parts else "設定値  初期値"
    if case["group"] == "blend":
        return f"合成モード: {case['name']}（{settings.get('blendMode')}）"
    if case["group"] == "pixel-compare":
        if settings.get("kind") != "pixelate":
            size = format_value("", settings.get("blockSize", "?"))
            return f"設定値  {labels['filterPixelateBlockSize']}: {size}px"
        colors = " ".join(f"#{c & 0xFFFFFF:06X}" for c in settings.get("colors", []))
        mode = enum_label("pixelColorMode", settings.get("colorMode"), labels)
        dither = (
            f" / {labels['filterPixelateDither']}: "
            f"{format_value('', settings['dither'])}"
            if "dither" in settings and settings.get("colorMode") != "none"
            else ""
        )
        return (
            f"設定値  {labels['filterPixelateBlockSize']}: "
            f"{format_value('', settings.get('cellSize'))}px / "
            f"{labels['pixelColorModeLabel']}: {mode} / {colors}{dither}"
        )
    if "parts" in settings:
        names = [part.get("name", "") for part in settings["parts"]]
        return f"パーツ{len(names)}件: " + "、".join(names)
    if case["group"] == "automation":
        steps = settings.get("steps", [])
        return "手順  " + " → ".join(step.get("label", "") for step in steps)
    if "steps" in settings:
        steps = settings.get("steps", [])
        return "手順  " + " → ".join(step.get("label", "") for step in steps)
    # An auto-fill part, named as its settings screen names each field.
    parts = []
    for field, key in AUTOFILL_PART_FIELDS:
        if field not in settings or settings[field] is None:
            continue
        mode = settings.get("lineColorMode")
        if field.startswith("trace") and mode != "traceAdjust":
            continue
        if field == "lineColor" and mode != "specified":
            continue
        if field in ("outlineColor", "outlineWidth") and not settings.get(
            "outlineEnabled"
        ):
            continue
        value = settings[field]
        if isinstance(value, dict):
            value = value.get("type", "ON")
        label = re.sub(r"[:：]?\s*\{value\}.*$", "", labels.get(key, field))
        parts.append(f"{label}: {enum_label(field, value, labels)}")
    return "設定値  " + " / ".join(parts) if parts else ""


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for ch in text:
        if ch == "\n" or draw.textlength(line + ch, font=fnt) > width:
            lines.append(line)
            line = "" if ch == "\n" else ch
        else:
            line += ch
    if line:
        lines.append(line)
    return lines


def artwork(path, size):
    """The artwork over a checkerboard (its transparent parts): at its own
    size when it fits, so pixels stay as rendered, else scaled down."""
    im = Image.open(path).convert("RGBA")
    im.thumbnail((size, size), Image.LANCZOS)
    board = Image.new("RGBA", im.size, "#ffffff")
    d = ImageDraw.Draw(board)
    for y in range(0, im.height, 14):
        for x in range(0, im.width, 14):
            if (x // 14 + y // 14) % 2:
                d.rectangle((x, y, x + 13, y + 13), fill="#e8edf2")
    return Image.alpha_composite(board, im).convert("RGB")


def build_card(gallery, group, case, labels, fields):
    """One case as an image: its name, settings, and before/after."""
    card = Image.new("RGB", (CARD_W, CARD_H), "#ffffff")
    d = ImageDraw.Draw(card)
    title_font, body_font = font(HEADING_FONT, 26), font(BODY_FONT, 17)
    small = font(BODY_FONT, 15)
    y = 14
    for line in wrap(d, case["displayName"], title_font, CARD_W - 32)[:2]:
        d.text((16, y), line, font=title_font, fill=INK)
        y += 34
    summary = settings_summary(case, labels, fields)
    lines = wrap(d, summary, small, CARD_W - 32)
    if len(lines) > 4:
        lines = lines[:4]
        lines[-1] = lines[-1][:-1] + "…"
    for line in lines:
        d.text((16, y), line, font=small, fill=MUTED)
        y += 21
    side = 330
    top = CARD_H - 256 - 52
    # 墨溜まり lies under the line art: it reads only together with it.
    with_lines = (case.get("settings") or {}).get("kind") == "inkPool"
    after_key = "generated" if "generated" in case and not with_lines else "after"
    after_label = (
        "生成レイヤー（元画像を非表示）"
        if after_key == "generated"
        else "適用後（線画の下に墨溜まりのレイヤー）"
        if with_lines
        else "適用後"
    )
    for i, (key, label) in enumerate([("before", "適用前"), (after_key, after_label)]):
        x = 40 + i * (side + 77)
        d.text((x + (side - 256) // 2, top - 26), label, font=body_font, fill=INK)
        image = artwork(gallery / group / case[key], side)
        ix = x + (side - image.width) // 2
        card.paste(image, (ix, top))
        d.rectangle(
            (ix - 1, top - 1, ix + image.width, top + image.height),
            outline="#cbd5e1",
        )
    if (case.get("settings") or {}).get("kind") == "prism" and not case.get("note"):
        case["note"] = (
            "背景の絵の上に合成モード「"
            + labels.get("blendModeLinearDodge", "linearDodge")
            + "」で重ねた見え方（キャンバスと同じ）。"
        )
    note = case.get("note") or (
        "初期値は恒等変換（画素変化なし）"
        if case["changedPixels"] == 0
        else f"本番UIで実行・出力確認済み（変化画素 {case['changedPixels']:,}）"
    )
    note_lines = wrap(d, note, small, CARD_W - 32)[:2]
    for n, line in enumerate(note_lines):
        d.text(
            (16, CARD_H - 14 - 21 * (len(note_lines) - n)), line, font=small, fill=MUTED
        )
    return card


# Screens of the new and reworked features, written by their own tests
# (paths under build/). Each page shows one feature, labelled in the image.
# Pages of shots taken by the feature's own tests (paths are relative to the
# build directory). Each says how its shots were made, so an engine's output
# is not mistaken for a screen of the app.
UI = "本番の画面をFlutterテスト環境で実操作"
FEATURE_PAGES = [
    (
        "投げ縄「線に吸着」",
        "赤＝大まかに描いた投げ縄、青＝選ばれた範囲。バケツ塗りと同じように線画で区切られた領域のうち投げ縄の内側に大部分が入るものを選び、縁は線の中央にぴったり沿う。",
        "上2枚：選択エンジンへテスト用の線画を直接入力／下2枚：本番のキャンバス部品を実ドラッグ",
        [
            (
                "lasso-snap/regions_bucket_edge.png",
                "人物をざっくり囲む（内側の線ごと）",
            ),
            ("lasso-snap/shared_line.png", "線を共有する2つの形：大部分が内側の方だけ"),
            ("lasso-snap/canvas_raw.png", "キャンバス：吸着なし"),
            ("lasso-snap/canvas_snap.png", "キャンバス：線に吸着"),
        ],
    ),
    (
        "球体陰影フィルター・魚眼の中心（キャンバス上で操作）",
        "調整中はキャンバス自体がプレビュー。光の位置・大きさ、魚眼の中心はキャンバス上の＋とつまみでドラッグできる。",
        UI,
        [
            ("sphere-shading/canvas_1_opened.png", "球体陰影を開いた直後"),
            ("sphere-shading/canvas_2_dragged.png", "光をドラッグで移動"),
            (
                "sphere-shading/canvas_3_combined.png",
                "影色→光色をまとめて1つのブレンドで",
            ),
            ("sphere-shading/canvas_6_fisheye_moved.png", "魚眼の中心をドラッグで移動"),
        ],
    ),
    (
        "選択範囲の中だけに適用・眼鏡断層のレンズ範囲",
        "選択範囲があると描画フィルターはその内側だけを変える。眼鏡断層はパネルのペン・消しゴム・バケツで塗った範囲だけを歪ませる。",
        UI,
        [
            (
                "filter-selection/01_threshold_preview_in_selection.png",
                "二値化：選択範囲内のプレビュー",
            ),
            (
                "filter-selection/02_threshold_applied.png",
                "二値化：適用後（外側はそのまま）",
            ),
            (
                "filter-selection/05_lens_area_painted.png",
                "眼鏡断層：ペンでレンズ範囲を塗る",
            ),
            ("filter-selection/06_lens_applied.png", "眼鏡断層：適用後"),
        ],
    ),
    (
        "ブレンドモードの選択ダイアログ",
        "レイヤー設定の「ブレンドモード」から開く本番のダイアログ。各モードの左に、そのモードで色の帯を重ねた見本が出る（下半分は半透明で重ねた見え方）。",
        UI,
        [
            ("feature-captures/blend/blend_normal-settings.png", "一覧の先頭"),
            ("feature-captures/blend/blend_addition-settings.png", "加算・発光"),
            (
                "feature-captures/blend/blend_linearDodge-settings.png",
                "覆い焼き（リニア）",
            ),
            ("feature-captures/blend/blend_divide-settings.png", "一覧の末尾"),
        ],
    ),
    (
        "「加算・発光」と「覆い焼き（リニア）」の違い",
        "どちらも不透明な所では同じ明るさになる。違いは半透明の所で、加算・発光は上の色に不透明度を掛けた分をそのまま足すので、覆い焼き（リニア）より明るく光る。",
        UI,
        [
            ("feature-captures/blend/blend_addition-before.png", "重ねる前"),
            ("feature-captures/blend/blend_addition-after.png", "加算・発光"),
            (
                "feature-captures/blend/blend_linearDodge-after.png",
                "覆い焼き（リニア）",
            ),
        ],
    ),
    (
        "自動塗り「線画と塗りの隙間を埋める」・線画色トレス",
        "黒い線画を塗りの上に重ねた状態。隙間を埋める量を上げるほど、線の薄いふちの下まで塗り、白い隙間が消える。線画色トレスは背景透過の線画の下にキャラクターの塗りレイヤーだけを置き、線を隣の塗りより深い色にする公式の自動操作。",
        "隙間の3枚：自動塗りエンジンへテスト用の線画を直接入力／線画色トレス：本番の自動操作をタップで実行",
        [
            ("autofill-line-gap/small.png", "線画と塗りの隙間を埋める：0"),
            ("autofill-line-gap/medium.png", "線画と塗りの隙間を埋める：50"),
            ("autofill-line-gap/large.png", "線画と塗りの隙間を埋める：100"),
            (
                "feature-captures/automation/builtin_lineart_color_trace-before.png",
                "線画色トレス：実行前",
            ),
            (
                "feature-captures/automation/builtin_lineart_color_trace-after.png",
                "線画色トレス：実行後",
            ),
        ],
    ),
    (
        "墨溜まり：鋭角・直角の内側（初期値の最大角度90°、線画1px）",
        "線が鋭角か直角に出会う所（V字・交差の狭い側・T字・四角い角）の内側にだけ溜まり、鈍角には溜まらない（オリンピックの輪の広い側は約106°）。出会う点では線の縁から「中央の太さ」、そこから「範囲」の端までまっすぐ細くなり、端で0px（なめらかにとがって消える）。範囲の途中で線が途切れていれば、その線ではそこを終点に0pxまで細くなる（線ごとに長さが変わる）。そのときも2つの墨溜まりは角の真ん中で、どちらの線からも同じ太さで出会い、長い方はそこから範囲の端まで細くなる（角の中心が短い方へずれない）。左＝墨溜まりだけ（赤）、中＝線画の下に重ねた状態、右＝線と同じ黒で重ねた実際の見え方。設定は既定の範囲12px・中央の太さ6px（交差とV字は範囲30px・中央の太さ10px／範囲24px・8px）。",
        "フィルターエンジンへテスト用の線画を直接入力",
        [
            (
                "ink-pool/olympic_rings_1px.png",
                "オリンピックの輪：交点ごとに狭い角2か所だけ",
            ),
            ("ink-pool/crossing_40_1px.png", "40°の交差：狭い側だけ"),
            ("ink-pool/corner_1px.png", "50°のV字：内側"),
            ("ink-pool/t_junction_1px.png", "T字・四角い角：直角の内側"),
            ("ink-pool/obtuse_1px.png", "110°・120°・135°の角：溜まらない"),
            (
                "ink-pool/line_end_1px.png",
                "途中で途切れる線：そこで0px、角の真ん中で同じ太さ",
            ),
        ],
        "rows",
    ),
    (
        "墨溜まり：中央の太さ（W）×範囲（R）",
        "50°の角（線画1px）に、中央の太さ2〜24px・範囲6〜60pxの30通りを適用（赤が墨溜まり）。どの組み合わせでも、角では線の縁から指定の太さ、そこから範囲の端まで直線的に細くなって0pxで終わり（なめらかにとがる）、中央の太さが範囲に比べて大きいと両端を結ぶ直線で平らに止まり（ふくらまない）、角の外や範囲の先には何も出ない。理想の形との画素比較・太さの断面・段差の有無をテストで確認済み。",
        "フィルターエンジンへテスト用の線画を直接入力",
        [
            (
                "ink-pool/sweep.png",
                "W＝中央の太さ（下へ2・4・6・10・16・24px）、R＝範囲（右へ6・12・24・40・60px）",
            ),
        ],
    ),
    (
        "墨溜まり：最大角度（0〜180°）",
        "「最大角度」以下の角度で線が出会う角の内側に溜まる（初期値90°＝鋭角と直角）。手描きの線のぶれを見込んで設定の1割（最大6°）の余裕があり、まっすぐな線の両側（180°）には溜まらない。左から0°・30°・90°・120°・150°・180°。各段は50°・110°・135°・160°の角、右はT字（下側が直角2つ、上側はまっすぐ）。",
        "フィルターエンジンへテスト用の線画を直接入力",
        [
            (
                "ink-pool/max_angle.png",
                "0°：なし／30°：なし／90°：50°とT字／120°：＋110°／150°：＋135°／180°：＋160°",
            ),
        ],
    ),
    (
        "墨溜まり：太い線でも",
        "線が太くても、見える幅（線の縁からの幅）は同じ設定どおり。オリンピックの輪（線6px）・40°の交差（線3px）・T字（線8px）。",
        "フィルターエンジンへテスト用の線画を直接入力",
        [
            ("ink-pool/olympic_rings.png", "オリンピックの輪（線6px）"),
            ("ink-pool/crossing_40.png", "40°の交差（線3px）"),
            ("ink-pool/t_junction_thick.png", "T字（線8px）：縦線の両側"),
        ],
        "rows",
    ),
    (
        "ドット絵：ディザリング（色を限るとき）",
        "色を限ると、1色では元の色から遠い所を、使える色のうち2〜3色を4×4の規則的な並びで混ぜて近づける（並びは画面に固定なのでアニメーションでもちらつかない）。明るさの差が大きい点ほど目立つので、少し近づくだけなら混ぜない（地平線近くの明るい空は白1色のまま）。原色6色のように絵から離れた色だけを指定すると、空の中ほどのような中間の色は青・白・黒の点の模様になる。輪郭の所は混ぜずにくっきり。色数を指定するときは、絵の多くを占める色から選ぶ（以前は互いに最も離れた色から選んでいた）。上段＝6色（黒・白・赤・黄・青・緑）を指定、下段＝色数6。flat＝「ディザリング」スイッチをオフにした場合（上段では肌色の顔が白のベタ塗りになる）、dithered＝オン（既定）。",
        "フィルターエンジンへテスト用の絵を直接入力",
        [
            ("pixel-art-dither/compare.png", "original／flat／dithered"),
        ],
    ),
    (
        "自動線画",
        "一定の太さのラフから途切れない中心線を描く。近くに並んだ線も、間に紙が見えていれば2本のまま（細長い輪・2px離れた平行線・頭の輪郭と生え際）。入り抜きはオン・オフできる。左＝ラフ、右＝結果。",
        "フィルターエンジンへテスト用の絵を直接入力",
        [
            ("auto-lineart/continuity.png", "一定幅のラフ→中心線"),
            ("auto-lineart/close_lines.png", "近い2本の線は2本のまま"),
            ("auto-lineart/taper_on.png", "入り抜きオン"),
            ("auto-lineart/taper_off.png", "入り抜きオフ"),
        ],
    ),
    (
        "眼鏡断層",
        "レンズ越しの景色を一様に縮め、縁で輪郭が段になる（本物の強度近視の眼鏡と同じ）。",
        "フィルターエンジンへテスト用の絵を直接入力",
        [
            ("filter-glasses/minus_lens.png", "レンズ越しに約0.88倍"),
        ],
    ),
    (
        "魚眼パース定規・背景馴染ませ",
        "魚眼パース定規は円の中で横・縦の線が弧を描く5点の曲線透視。背景馴染ませは内容全体に背景の光と色をハードライトでなじませる。",
        "定規：本番のキャンバス部品を実操作／背景馴染ませ：フィルターエンジンへ直接入力",
        [
            ("fisheye-ruler/1_guide.png", "魚眼パース定規のガイド"),
            ("fisheye-ruler/2_stroke.png", "定規に沿って描いた線"),
            ("background-acclimation-v2/sunset.png", "背景馴染ませ：夕焼け"),
            ("background-acclimation-v2/snow.png", "背景馴染ませ：雪景色"),
        ],
    ),
]


def feature_shot_paths(build_dir):
    return [build_dir / path for entry in FEATURE_PAGES for path, _ in entry[3]]


def feature_pages(build_dir, revision, start_number):
    pages, number = [], start_number
    title_font, body = font(HEADING_FONT, 22), font(BODY_FONT, 19)
    for entry in FEATURE_PAGES:
        title, desc, source, shots = entry[:4]
        rows = len(entry) > 4 and entry[4] == "rows"
        shots = [(build_dir / path, label) for path, label in shots]
        missing = [str(path) for path, _ in shots if not path.is_file()]
        assert not missing, (title, "missing shots", missing)
        number += 1
        im, d = page(title, revision, number, source=source)
        y = 92
        for line in wrap(d, desc, body, PAGE_W - 96):
            d.text((48, y), line, font=body, fill=MUTED)
            y += 28
        top = y + 20
        if rows:
            # Wide strips, one to a row, so thin lines keep their width.
            label_w = 280
            row_h = (PAGE_H - top - 70) // len(shots)
            for i, (path, label) in enumerate(shots):
                ry = top + i * row_h
                for n, line in enumerate(wrap(d, label, title_font, label_w - 20)[:4]):
                    d.text((48, ry + 8 + n * 28), line, font=title_font, fill=INK)
                shot = Image.open(path).convert("RGB")
                area_w = PAGE_W - 96 - label_w
                scale = min(area_w / shot.width, (row_h - 16) / shot.height)
                size = (
                    max(1, int(shot.width * scale)),
                    max(1, int(shot.height * scale)),
                )
                shot = shot.resize(size, Image.NEAREST if scale >= 2 else Image.LANCZOS)
                sx, sy = 48 + label_w, ry + 4
                im.paste(shot, (sx, sy))
                d.rectangle(
                    (sx - 1, sy - 1, sx + shot.width, sy + shot.height),
                    outline="#cbd5e1",
                )
            pages.append(im)
            continue
        column = (PAGE_W - 96 - 24 * (len(shots) - 1)) // len(shots)
        height = PAGE_H - top - 110
        for i, (path, label) in enumerate(shots):
            x = 48 + i * (column + 24)
            lines = wrap(d, label, title_font, column)
            for n, line in enumerate(lines[:2]):
                d.text((x, top + n * 28), line, font=title_font, fill=INK)
            shot = Image.open(path).convert("RGB")
            # Small engine outputs are enlarged with hard pixel edges.
            scale = min(column / shot.width, (height - 60) / shot.height)
            size = (max(1, int(shot.width * scale)), max(1, int(shot.height * scale)))
            shot = shot.resize(size, Image.NEAREST if scale >= 2 else Image.LANCZOS)
            sx, sy = x + (column - shot.width) // 2, top + 62
            im.paste(shot, (sx, sy))
            d.rectangle(
                (sx - 1, sy - 1, sx + shot.width, sy + shot.height),
                outline="#cbd5e1",
            )
        pages.append(im)
    return pages


def page(title, revision, number, source="本番UIの操作から取得"):
    im = Image.new("RGB", (PAGE_W, PAGE_H), "#f4f6fa")
    d = ImageDraw.Draw(im)
    d.text((48, 30), title, font=font(HEADING_FONT, 34), fill=INK)
    footer = font(BODY_FONT, 16)
    d.text(
        (48, PAGE_H - 40),
        f"NIARIM / {source} / {revision[:12]}",
        font=footer,
        fill=MUTED,
    )
    d.text((PAGE_W - 80, PAGE_H - 40), str(number), font=footer, fill=MUTED)
    return im, d


def build_pdf(path, gallery, groups, revision, labels, screens):
    fields = panel_fields()
    cards_dir = gallery / "labelled"
    cards_dir.mkdir(exist_ok=True)
    pages = []
    total = sum(len(cases) for cases in groups.values())
    cover, d = page("NIARIM 操作キャプチャ", revision, 1)
    body, head = font(BODY_FONT, 21), font(HEADING_FONT, 24)
    y = 120
    d.text(
        (70, y),
        f"{total}ケース（質感変更・折り畳みモードは別作業のため除外）",
        font=head,
        fill=INK,
    )
    y += 70
    for label, desc in [
        (
            "収録対象",
            "描画フィルター（トーンカーブ6種・ドット絵4種を含む）、Pixel Art / Mosaicの同一fixture比較、全25ブレンドモード、公式の自動操作3種、出荷済み自動塗りプリセットの完成状態、記録・再実行。",
        ),
        (
            "確認方法",
            "本番のNiarimAppと画面ルートをFlutterテスト環境で起動し、ボタン・選択肢をタップして実行。適用前後の画素と生成レイヤーを検証しました。",
        ),
        (
            "焼き込み",
            "各カードの見出しが機能名、その下が設定値（フィルターパネルと同じ項目名）。カード画像はZIPのlabelled/にも1枚ずつ収録しています。",
        ),
        (
            "撮影条件",
            "Flutter 3.47.3 / Linuxレンダラー。作品256×256（ドット絵の比較のみ320×240も）。Android・iOS実機での撮影ではありません。市松模様は透明部分です。各ページの下端に、その画像の撮り方（本番画面の実操作か、エンジンへの直接入力か）を記載。",
        ),
    ]:
        d.text((70, y), label, font=head, fill=INK)
        for line in wrap(d, desc, body, PAGE_W - 420):
            d.text((300, y + 2), line, font=body, fill=INK)
            y += 32
        y += 30
    pages.append(cover)
    number = 1
    for group, cases in groups.items():
        for offset in range(0, len(cases), 4):
            number += 1
            im, _ = page(
                f"{GROUPS[group]}  {offset + 1}-{min(offset + 4, len(cases))} / {len(cases)}",
                revision,
                number,
            )
            for n, case in enumerate(cases[offset : offset + 4]):
                card = build_card(gallery, group, case, labels, fields)
                card.save(cards_dir / f"{case['id']}.png")
                col, row = n % 2, n // 2
                im.paste(card, (48 + col * (CARD_W + 24), 100 + row * (CARD_H + 24)))
            pages.append(im)
    features = feature_pages(screens, revision, number)
    pages.extend(features)
    number += len(features)
    for title, images in [
        (
            "更新したヘルプ画面",
            [
                ("help-custom-automation", "自動操作（操作記録）"),
                ("help-filters", "全フィルターの説明"),
            ],
        ),
        (
            "更新したTips画面",
            [
                ("tips-automation", "公式の自動操作プリセット"),
            ],
        ),
    ]:
        shots = [(gallery / "extras" / f"{n}.png", label) for n, label in images]
        if not all(p.is_file() for p, _ in shots):
            continue
        number += 1
        im, d = page(title, revision, number)
        for i, (shot, label) in enumerate(shots):
            x = 260 + i * 640
            d.text((x, 100), label, font=head, fill=INK)
            screen = Image.open(shot).convert("RGB")
            screen.thumbnail((500, 1000), Image.LANCZOS)
            im.paste(screen, (x, 150))
        pages.append(im)
    pages[0].save(
        path,
        save_all=True,
        append_images=pages[1:],
        resolution=150,
        title="NIARIM 操作キャプチャ",
        author="NIARIM development verification",
    )
    return len(pages)


def build_html(gallery, groups):
    cards = []
    for group, cases in groups.items():
        for case in cases:
            name = html.escape(case["displayName"])
            links = [
                ("beforeUI", "操作前の画面"),
                ("configurationUI", "設定画面"),
                ("afterUI", "実行後の画面"),
                ("generatedUI", "生成レイヤーの画面"),
            ]
            links_html = " / ".join(
                f'<a href="{group}/{case[key]}">{label}</a>'
                for key, label in links
                if key in case
            )
            after = case.get("generated", case["after"])
            label = (
                "生成レイヤー（元画像を非表示）" if "generated" in case else "適用後"
            )
            cards.append(
                f'<article data-search="{name} {group}"><small>{GROUPS[group]}</small>'
                f'<h2>{name}</h2><div class="images"><figure><figcaption>適用前</figcaption>'
                f'<img src="{group}/{case["before"]}"></figure><figure>'
                f'<figcaption>{label}</figcaption><img src="{group}/{after}"></figure></div>'
                f"<p>{html.escape(case.get('note') or 'UI実行・出力確認済み')}</p>"
                f"<p>{links_html}</p><details><summary>設定値</summary><pre>"
                f"{html.escape(json.dumps(case['settings'], ensure_ascii=False, indent=2))}"
                "</pre></details></article>"
            )
    document = (
        """<!doctype html><html lang="ja"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>NIARIM 操作キャプチャ</title>
<style>body{font-family:system-ui,sans-serif;background:#f4f6fa;color:#253047;margin:24px auto;max-width:1200px;padding:0 16px}
input{padding:12px;width:min(90%,600px);font-size:16px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px;margin-top:24px}
article{background:white;padding:20px;border-radius:12px;min-width:0}h2{font-size:18px}small{color:#64748b}.images{display:flex;gap:12px}
figure{margin:0;width:50%}figcaption{font-size:12px;min-height:34px}img{width:100%;background:repeating-conic-gradient(#e8edf2 0% 25%,white 0% 50%) 50%/16px 16px}
pre{font-size:12px;overflow:auto}a{color:#284f9b}p{font-size:13px;line-height:1.7}[hidden]{display:none!important}</style>
<h1>NIARIM 操作キャプチャ</h1><p>全"""
        + str(sum(len(c) for c in groups.values()))
        + """ケース。Flutter本番UI / Linuxレンダラー。実機撮影ではありません。詳細はREADME.mdをご覧ください。</p>
<input aria-label="キャプチャを検索" placeholder="機能名で検索" oninput="document.querySelectorAll('article').forEach(x=>x.hidden=!x.dataset.search.toLowerCase().includes(this.value.toLowerCase()))">
<main>"""
        + "\n".join(cards)
        + "</main></html>"
    )
    (gallery / "index.html").write_text(document, encoding="utf-8")


def check_revision(revision, shots):
    """The shots must show [revision]: it is the checked-out commit, the code
    has no changes on top of it, and every shot was taken after it."""

    def git(*command):
        return subprocess.run(
            ["git", *command], cwd=ROOT, check=True, capture_output=True, text=True
        ).stdout.strip()

    head = git("rev-parse", "HEAD")
    assert git("rev-parse", revision) == head, (revision, "is not HEAD", head)
    changed = git(
        "status", "--porcelain", "--", "lib", "test", "assets", "pubspec.yaml"
    )
    assert not changed, ("uncommitted code changes", changed)
    committed = int(git("log", "-1", "--format=%ct", head))
    stale = [str(p) for p in shots if p.stat().st_mtime < committed]
    assert not stale, ("shots older than", revision, stale[:10], len(stale))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("build/feature-captures"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument(
        "--allow-stale",
        action="store_true",
        help="skip checking that the shots were taken at --revision",
    )
    args = parser.parse_args()
    gallery = args.output / "NIARIM-captures"
    gallery.mkdir(parents=True, exist_ok=True)
    labels = json.loads(
        (Path(__file__).resolve().parents[1] / "lib/l10n/app_ja.arb").read_text()
    )
    groups = {}
    for group in GROUP_ORDER:
        manifest_path = args.input / group / "manifest.json"
        if not manifest_path.is_file():
            continue
        manifest = json.loads(manifest_path.read_text())
        cases = [
            case
            for case in manifest["cases"]
            if case["id"].split("_", 1)[0] not in EXCLUDED_FILTER_IDS
            and (case.get("settings") or {}).get("kind") not in EXCLUDED_KINDS
        ]
        assert cases, f"{group} capture group is empty"
        assert len({case["id"] for case in cases}) == len(cases)
        assert all(case["status"] == "passed" for case in cases)
        if group == "pixel-compare":
            assert {case["id"] for case in cases} == {
                "pixel_art_blocks_six_colours",
                "pixel_art_dots_canvas_resolution",
                "mosaic_same_fixture",
                "pixel_art_blocks_six_colours_320x240",
                "pixel_art_dots_canvas_resolution_320x240",
            }
        if group == "blend":
            assert len(cases) == 25, ("blend", len(cases), 25)
            assert any(case["id"] == "blend_addition" for case in cases)
            assert any(case["id"] == "blend_linearDodge" for case in cases)
        for case in cases:
            case["displayName"] = display_name(case, labels)
        groups[group] = cases
        excluded = {case["id"] for case in manifest["cases"]} - {
            case["id"] for case in cases
        }
        shutil.copytree(
            args.input / group,
            gallery / group,
            dirs_exist_ok=True,
            ignore=lambda _, names: [
                n for n in names if any(n.startswith(e) for e in excluded)
            ],
        )
        if excluded:
            print(f"{group}: excluded {sorted(excluded)}")
        for case in cases:
            for key in ["before", "after", "beforeUI", "afterUI"]:
                assert (gallery / group / case[key]).is_file(), (case["id"], key)
            # Not every group opens a settings screen of its own.
            if not (gallery / group / case.get("configurationUI", "")).is_file():
                case.pop("configurationUI", None)
    required = {"filters", "pixel-compare", "blend", "automation", "autofill"}
    assert required.issubset(groups), ("missing capture groups", required - set(groups))
    if not args.allow_stale:
        check_revision(
            args.revision,
            [p for g in groups for p in (args.input / g).glob("*.png")]
            + feature_shot_paths(args.input.parent),
        )
    (gallery / "manifest.json").write_text(
        json.dumps(
            {
                "revision": args.revision,
                "environment": "Flutter 3.47.3 / production UI / Linux renderer, not Android or iOS hardware",
                "counts": {group: len(cases) for group, cases in groups.items()},
                "groups": groups,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    (gallery / "README.md").write_text(
        f"""# NIARIM 操作キャプチャ

検証ソース: {args.revision}

質感変更フィルター（と別作業の折り畳みモード）を除外したVisual closure成果物です。
labelled/には、機能名・設定値・適用前後を1枚に焼き込んだカード画像があります。
通常フィルター、Pixel Art / Mosaic同一fixture比較、全25ブレンドモード、
公式自動操作、自動塗り、記録・再実行を収録します。
連続スライダーの全数値の組合せを網羅するものではありません。

Flutter 3.47.3のLinuxテストレンダラーで、本番NiarimAppと画面ルートを起動。
選択・適用・自動操作実行・自動塗り割当は画面のタップで行いました。
保存先と比較用入力画像のみテスト用です。実機撮影ではありません。
画面: 480×960 logical pixels / DPR 2 / PNG 960×1920。
作品: 256×256（ドット絵の比較のみ320×240も） / 原寸RGBA。beforeとafterで比較できます。

index.htmlを開くとオフラインで検索・比較できます。
各フォルダに操作前・設定・操作後の画面を収録。
generatedは元のレイヤーを画面上で非表示にした生成レイヤーの表示です。
通常の合成表示はafterに保持しています。
レベル補正の初期値とトーンカーブlinearは恒等変換です。
ドット絵paletteは選択した4色をexplicitとして複製する仕様です。
manifestのchangedPixelsは生のRGBA差分で、透明部分のRGB差分も含みます。
extrasの自動塗り設定は機能比較用であり、出荷プリセットとは別枠です。

ヘルプ・Tips画面はextras/help-*.pngとextras/tips-*.pngに収録しています。
""",
        encoding="utf-8",
    )
    build_html(gallery, groups)
    pdf = args.output / "NIARIM-operation-captures.pdf"
    pages = build_pdf(pdf, gallery, groups, args.revision, labels, args.input.parent)
    archive = args.output / "NIARIM-captures.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(gallery.rglob("*")):
            if path.is_file():
                z.write(path, path.relative_to(args.output))
    print(
        json.dumps(
            {
                "cases": sum(len(cases) for cases in groups.values()),
                "pdf": str(pdf.resolve()),
                "zip": str(archive.resolve()),
                "pages": pages,
                "pngs": len(list(gallery.rglob("*.png"))),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
