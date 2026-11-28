#!/usr/bin/env python3
"""くらむぼん（assets/fonts/Kuramubon.otf）の字形のデータを詰め直す。

くらむぼんは見出し・題・ボタンの書体で、起動のたびに読み込まれる。Androidでは
APKの中で圧縮されているので、エンジン（AAsset_getBuffer）がファイル全体を
展開してメモリに置き、アプリを閉じるまで残す。配布されているくらむぼんの
CFF（字形の輪郭）は、どの字も同じ部品を何度も書き並べた形（サブルーチンなし）
で、ファイル全体が15.6MBある。

ここでは、tx（AFDKO、cffsubrに同梱）でCFFの字形にサブルーチンを付ける
（字形の中で繰り返し出る命令の並びを1か所にまとめ、そこを呼ぶ形にする）。
輪郭の点・字の幅は1つも変えないので、描かれる字は元と同じになる。
ほかの表（cmap・hmtx・GSUB・GPOS・name 等）は元のバイト列のまま写す
（head はファイル全体のチェックサムの4バイトだけ変わる）。CFFの FontBBox も
元の値に戻す（txは字形から計算し直す）。

作った後、次を確かめ、1つでも違えば書き出さずに止まる：
  - CFF・head 以外の表が元とバイト単位で同じこと
  - CFFの Top DICT・FDArray・Private の値が元と同じこと
    （サブルーチンの一覧 Subrs と、字の幅の基準 nominalWidthX だけは変わる）
  - 全部の字形（9354個）の輪郭の点の並びと字の幅が元と同じこと
  - freetype-py があれば、FreeType で読み込んだ全部の字形の点・種類・送り幅が、
    いくつかの大きさとヒンティングの方式で元と同じこと

使い方：
    pip install fonttools cffsubr freetype-py
    python3 tool/build_kuramubon_font.py <配布されているKuramubon.otf>

配布されているくらむぼん（SHA-256 は ORIGINAL_SHA256）は、このスクリプトを
入れる前のコミットの assets/fonts/Kuramubon.otf にある：
    git show 367d8b07:assets/fonts/Kuramubon.otf > /tmp/Kuramubon-original.otf
くらむぼんを新しい版に入れ替えたときは、このスクリプトを通してから置くこと。
すでに詰め直したファイルを渡しても同じ結果になる（輪郭は変わらない）。
"""

import argparse
import hashlib
import io
import pathlib
import struct
import sys

import cffsubr
from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.sfnt import SFNTReader, SFNTWriter

REPO = pathlib.Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "fonts" / "Kuramubon.otf"

# 配布されているくらむぼん（Version 1.02）のファイルの SHA-256。
ORIGINAL_SHA256 = "15638fee24b4d9d428b9c580742659e6831043c62404668cf78435bca14dd06b"

# head の checkSumAdjustment（ファイル全体のチェックサム）の位置。
HEAD_CHECKSUM = slice(8, 12)

# FreeType で比べる大きさ（px）とヒンティングの方式。
FREETYPE_SIZES = (9, 11, 12, 14, 16, 20, 24, 32, 45, 57, 100)


def _top_dict_values(cff):
    top = cff.topDictIndex[0]
    skip = {"CharStrings", "charset", "FDSelect", "FDArray", "Private"}
    values = {k: v for k, v in top.rawDict.items() if k not in skip}
    values.setdefault("isFixedPitch", 0)
    fds = []
    for fd in top.FDArray:
        private = {
            k: v
            for k, v in fd.Private.rawDict.items()
            if k not in ("Subrs", "nominalWidthX")
        }
        fds.append(({k: v for k, v in fd.rawDict.items() if k != "Private"}, private))
    return values, fds, list(top.charset), list(top.FDSelect)


def _outlines(cff):
    top = cff.topDictIndex[0]
    out = {}
    for name in top.charset:
        charstring = top.CharStrings[name]
        pen = RecordingPen()
        charstring.draw(pen)
        out[name] = (charstring.width, pen.value)
    return out


def _check_tables(source: bytes, built: bytes):
    a = SFNTReader(io.BytesIO(source))
    b = SFNTReader(io.BytesIO(built))
    tags = sorted(a.tables)
    if tags != sorted(b.tables):
        sys.exit(f"表の並びが違う: {tags} / {sorted(b.tables)}")
    for tag in tags:
        if tag == "CFF ":
            continue
        old, new = a[tag], b[tag]
        if tag == "head":
            old = old[: HEAD_CHECKSUM.start] + old[HEAD_CHECKSUM.stop :]
            new = new[: HEAD_CHECKSUM.start] + new[HEAD_CHECKSUM.stop :]
        if old != new:
            sys.exit(f"{tag} の表が元と違う")


def _check_cff(source_font: TTFont, built: bytes):
    old_cff = source_font["CFF "].cff
    new_cff = TTFont(io.BytesIO(built))["CFF "].cff
    if old_cff.fontNames != new_cff.fontNames:
        sys.exit("CFFのフォント名が違う")
    if _top_dict_values(old_cff) != _top_dict_values(new_cff):
        sys.exit("CFFの Top DICT・FDArray・Private の値が違う")
    old = _outlines(old_cff)
    new = _outlines(new_cff)
    if old.keys() != new.keys():
        sys.exit("字形の並びが違う")
    for name in old:
        if old[name] != new[name]:
            sys.exit(f"{name} の輪郭か字の幅が違う")
    return len(old)


def _check_freetype(source: bytes, built: bytes):
    try:
        import ctypes

        import freetype
    except ImportError:
        print("freetype-py が無いので FreeType の比較は飛ばした")
        return 0

    flags = {
        "ヒンティングなし": freetype.FT_LOAD_NO_HINTING,
        "ライト": freetype.FT_LOAD_TARGET_LIGHT,
        "標準": freetype.FT_LOAD_DEFAULT,
    }
    old_face = freetype.Face(io.BytesIO(source))
    new_face = freetype.Face(io.BytesIO(built))
    if old_face.num_glyphs != new_face.num_glyphs:
        sys.exit("FreeType で読んだ字形の数が違う")

    def snapshot(face):
        slot = face.glyph
        outline = slot.outline._FT_Outline
        n_points, n_contours = outline.n_points, outline.n_contours
        metrics = slot.metrics
        return (
            ctypes.string_at(
                outline.points, n_points * ctypes.sizeof(freetype.FT_Vector)
            ),
            ctypes.string_at(outline.tags, n_points),
            ctypes.string_at(outline.contours, n_contours * 2),
            outline.flags,
            slot.advance.x,
            slot.advance.y,
            slot.linearHoriAdvance,
            slot.linearVertAdvance,
            (
                metrics.width,
                metrics.height,
                metrics.horiBearingX,
                metrics.horiBearingY,
                metrics.horiAdvance,
                metrics.vertBearingX,
                metrics.vertBearingY,
                metrics.vertAdvance,
            ),
        )

    compared = 0
    for size in FREETYPE_SIZES:
        old_face.set_pixel_sizes(0, size)
        new_face.set_pixel_sizes(0, size)
        for label, flag in flags.items():
            for gid in range(old_face.num_glyphs):
                old_face.load_glyph(gid, flag)
                new_face.load_glyph(gid, flag)
                if snapshot(old_face) != snapshot(new_face):
                    sys.exit(f"FreeType: 字形 {gid}（{size}px・{label}）が違う")
                compared += 1
    return compared


def build(source_path: pathlib.Path) -> bytes:
    source = source_path.read_bytes()
    font = TTFont(io.BytesIO(source), recalcBBoxes=False, recalcTimestamp=False)
    font_bbox = list(font["CFF "].cff.topDictIndex[0].FontBBox)

    cffsubr.subroutinize(font)
    top = font["CFF "].cff.topDictIndex[0]
    top.FontBBox = font_bbox
    cff_data = font["CFF "].compile(font)

    reader = SFNTReader(io.BytesIO(source))
    order = sorted(reader.tables.values(), key=lambda entry: entry.offset)
    out = io.BytesIO()
    writer = SFNTWriter(out, len(order), reader.sfntVersion)
    for entry in order:
        writer[entry.tag] = cff_data if entry.tag == "CFF " else reader[entry.tag]
    writer.close()
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", type=pathlib.Path, help="配布されているKuramubon.otf")
    parser.add_argument("--output", type=pathlib.Path, default=OUT)
    args = parser.parse_args()

    source = args.source.read_bytes()
    digest = hashlib.sha256(source).hexdigest()
    if digest != ORIGINAL_SHA256:
        print(
            f"注意: 配布されている版（{ORIGINAL_SHA256[:12]}…）と違うファイル（{digest[:12]}…）"
        )

    built = build(args.source)
    _check_tables(source, built)
    glyphs = _check_cff(TTFont(io.BytesIO(source)), built)
    renders = _check_freetype(source, built)
    if len(built) > len(source):
        sys.exit(f"大きくなった: {len(source)} → {len(built)} バイト")

    args.output.write_bytes(built)
    head = struct.unpack(">I", built[HEAD_CHECKSUM])[0]
    print(
        f"{args.output}: {len(source):,} → {len(built):,} バイト"
        f"（字形 {glyphs} 個の輪郭が同じ、FreeType {renders:,} 回が同じ、"
        f"checkSumAdjustment 0x{head:08X}）"
    )


if __name__ == "__main__":
    main()
