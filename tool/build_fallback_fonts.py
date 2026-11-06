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

UIの文言（lib/l10n/*.arb）を増やしたあとは、このスクリプトを再実行して
フォントを作り直すこと。作り直しを忘れると、増やした文字だけシステム
フォントで表示されて見た目が揃わなくなる。
test/font_coverage_test.dart がその取りこぼしを検出する。
"""

import json
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
L10N = REPO / "lib" / "l10n"
OUT = REPO / "assets" / "fonts"

# 生成するフォント： (出力名, 元フォント, 太さ)
TARGETS = [
    ("NotoSerifKRSubset", "NotoSerifKR.ttf", 400),
    ("NotoSerifSCSubset", "NotoSerifSC.ttf", 400),
    ("NotoSansKRBlackSubset", "NotoSansKR.ttf", 900),
    ("NotoSansSCBlackSubset", "NotoSansSC.ttf", 900),
]


def required_chars() -> set:
    """アプリのUIに出る文字を集める。

    ARBの値（＝画面に出る文言）に加え、ASCII可読文字と一般的な約物を常に
    含める。ユーザーが入力した文字（作品名など）は対象外で、従来どおり
    システムフォントが受け持つ（今と同じ挙動のため後退は無い）。
    """
    chars = set()
    for path in sorted(L10N.glob("app_*.arb")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, value in data.items():
            if key.startswith("@") or not isinstance(value, str):
                continue
            # {count}のようなプレースホルダーは実文字ではないので除く
            chars.update(re.sub(r"\{[^}]*\}", "", value))
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update("、。「」『』（）〜・…—‐±×÷％＋－／：；！？　")
    return {c for c in chars if c.strip()}


def build(src_dir: pathlib.Path) -> int:
    from fontTools import ttLib
    from fontTools.varLib import instancer

    chars = required_chars()
    text = "".join(sorted(chars))
    print(f"UIに出る文字：{len(chars)}字")
    OUT.mkdir(parents=True, exist_ok=True)

    for out_name, src_name, weight in TARGETS:
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
