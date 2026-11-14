#!/usr/bin/env python3
"""韓国語・簡体字のフォールバック用フォントを生成する。

アプリは7言語（ja/en/es/fr/ko/zh/zh_Hant）に対応しているが、同梱フォントは
4つとも日本語系でハングルと簡体字を持たない。そのため韓国語UI・簡体字UIは
端末のシステムフォント任せになり、端末ごとに見た目が変わって明朝で統一した
意匠が崩れる（ハングルを持たない端末では豆腐になる）。

そこでNoto Serif KR/SC・Noto Sans KR/SCから、**アプリのUIに実際に出る文字**
だけを抜き出した軽量なフォントを作って同梱する。

  本文（白光明朝＝Noto Serif JP派生）の補完 → Noto Serif KR / SC の Regular
      同じSource Han Serif系なので骨格・字幅が揃い、混植しても継ぎ目が出ない。
  見出し（くらむぼん＝Dela Gothic派生＝超極太ゴシック）の補完
      → Noto Sans KR / SC の Black(900)
      見出しの補完に明朝を使うと「550엔」のように極太の数字と細い明朝の
      ハングルが同じ単語内に並んで明確に浮くため、太さの近いゴシックで補う。

使い方：
    python3 tool/build_fallback_fonts.py <元フォントを置いたディレクトリ>

元フォント（いずれもSIL Open Font License 1.1）は次から取得する：
    https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifkr/NotoSerifKR%5Bwght%5D.ttf
    https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf
    https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf
    https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf

UIの文言（lib/l10n/*.arb、およびlib/l10nに手で書いたDartファイルの
文字列）を増やしたあとは、このスクリプトを再実行してフォントを作り直すこと。作り直しを忘れると、増やした文字だけシステム
フォントで表示されて見た目が揃わなくなる。
test/font_coverage_test.dart がその取りこぼしを検出する。

中国語（簡体字・繁体字）の画面では、本文の主フォントがNoto Serif SC
（このサブセット）になる（lib/config/font_fallback.dart の
bodyFontFamilyFor）。そこに無い字は白光明朝（漢字は字幅0.65emの日本の
字形）へ落ち、1語の中で字幅と字形が混ざる。そのため NotoSerifSCSubset には、
lib配下の手書きのDartファイルの文字列に出る漢字・かな・全角の字（組み込みの
ブラシ・トーン・スタンプ等の名前。今は日本語のまま中国語の画面にも出る）と、
空白（U+0020・U+3000）も入れる。ほかの3つは主フォントにならない（本文・
見出しの代替）ので、今までどおりARBとlib/l10nの字だけ。
"""

import json
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
L10N = REPO / "lib" / "l10n"
OUT = REPO / "assets" / "fonts"

# 生成するフォント： (出力名, 元フォント, 太さ, 中国語の本文の主フォントか)
TARGETS = [
    ("NotoSerifKRSubset", "NotoSerifKR.ttf", 400, False),
    ("NotoSerifSCSubset", "NotoSerifSC.ttf", 400, True),
    ("NotoSansKRBlackSubset", "NotoSansKR.ttf", 900, False),
    ("NotoSansSCBlackSubset", "NotoSansSC.ttf", 900, False),
]


def _string_literals(path: pathlib.Path):
    """Dartファイルの文字列リテラルの中身（行全体のコメントは除く）。

    test/font_coverage_test.dart の handWrittenL10nCharsOf と同じ読み方。
    """
    code = "\n".join(
        line
        for line in path.read_text(encoding="utf-8").splitlines()
        if not line.lstrip().startswith("//")
    )
    for literal in re.findall(r"'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\"", code):
        text = re.sub(r"\{[^}]*\}", "", literal[1:-1])
        yield re.sub(r"\\.", "", text)


def is_cjk(c: str) -> bool:
    """漢字・かな・CJKの記号・全角の字（ハングルは除く：Noto Serif SCに無く、
    中国語の本文の代替列のNoto Serif KRが受け持つ）。

    test/font_coverage_test.dart の _isChineseBodyCjk と同じ範囲。
    """
    o = ord(c)
    return (
        0x2E80 <= o <= 0x312F  # 部首・CJKの記号と約物・かな・注音
        or 0x31A0 <= o <= 0x4DBF  # 注音拡張・CJKの画・カタカナ拡張・拡張A
        or 0x4E00 <= o <= 0x9FFF  # CJK統合漢字
        or 0xF900 <= o <= 0xFAFF  # CJK互換漢字
        or 0xFE30 <= o <= 0xFE4F  # CJK互換形
        or 0xFF00 <= o <= 0xFFEF  # 半角・全角形
        or 0x20000 <= o <= 0x3FFFF  # 拡張B以降
    )


def chinese_body_chars() -> set:
    """中国語の本文の主フォントにだけ足す字（lib配下の手書きの文字列の
    漢字・かな・全角の字と、空白）。"""
    chars = {" ", "\u3000"}
    for path in sorted((REPO / "lib").rglob("*.dart")):
        if path.name.startswith("app_localizations"):
            continue
        for text in _string_literals(path):
            chars.update(c for c in text if is_cjk(c))
    return chars


def required_chars() -> set:
    """アプリのUIに出る文字を集める。

    ARBの値（＝画面に出る文言）と、lib/l10nに手で書いたDartファイル
    （生成物のapp_localizations*.dartは除く）の文字列リテラルに加え、
    ASCII可読文字と一般的な約物を常に含める。ユーザーが入力した文字
    （作品名など）は対象外で、従来どおりシステムフォントが受け持つ
    （今と同じ挙動のため後退は無い）。手書きのDartファイルの読み方は
    test/font_coverage_test.dart の handWrittenL10nCharsOf と同じ。
    """
    chars = set()
    for path in sorted(L10N.glob("app_*.arb")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, value in data.items():
            if key.startswith("@") or not isinstance(value, str):
                continue
            # {count}のようなプレースホルダーは実文字ではないので除く
            chars.update(re.sub(r"\{[^}]*\}", "", value))
    for path in sorted(L10N.glob("*.dart")):
        if path.name.startswith("app_localizations"):
            continue
        for text in _string_literals(path):
            chars.update(text)
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update("、。「」『』（）〜・…—‐±×÷％＋－／：；！？　")
    return {c for c in chars if c.strip()}


def build(src_dir: pathlib.Path) -> int:
    from fontTools import ttLib
    from fontTools.varLib import instancer

    chars = required_chars()
    extra = chinese_body_chars() - chars
    print(f"UIに出る文字：{len(chars)}字（中国語の本文の主フォントは+{len(extra)}字）")
    OUT.mkdir(parents=True, exist_ok=True)

    for out_name, src_name, weight, chinese_body in TARGETS:
        text = "".join(sorted(chars | extra if chinese_body else chars))
        src = src_dir / src_name
        if not src.exists():
            print(f"  × {src} が無い（上記URLから取得してください）")
            return 1
        # 可変フォントを目的の太さで固定してからサブセット化する。
        font = ttLib.TTFont(src)
        instancer.instantiateVariableFont(font, {"wght": weight}, inplace=True)
        tmp = src_dir / f"_{out_name}_instance.ttf"
        font.save(tmp)
        font.close()

        dest = OUT / f"{out_name}.ttf"
        subprocess.run(
            [
                sys.executable,
                "-m",
                "fontTools.subset",
                str(tmp),
                f"--text={text}",
                f"--output-file={dest}",
                "--layout-features=*",
                "--no-hinting",
                "--desubroutinize",
            ],
            check=True,
        )
        tmp.unlink()
        print(
            f"  ○ {dest.name}: {dest.stat().st_size // 1024}KB "
            f"（{src_name} を wght={weight} で固定）"
        )
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(build(pathlib.Path(sys.argv[1])))
