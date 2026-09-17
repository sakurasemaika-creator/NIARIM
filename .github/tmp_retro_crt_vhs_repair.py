from pathlib import Path

p = Path('lib/engine/filter_engine_legacy.dart')
s = p.read_text()
old = '''  /// レトロアニメ風：暖色寄りのカラーグレーディング・彩度低下・粒状ノイズを
  /// 組み合わせた、昔のセルアニメ・VHS録画のような質感。1画素あたりの
  /// 色変換とノイズ処理1回分のみで、既存のanimeStyle（ポスタリゼーション＋
  /// Sobelエッジ検出）より軽い。
  Uint8List applyRetroAnime(
    Uint8List data,
    int width,
    int height,
    double strength,
  ) {'''
new = '''  /// レトロアニメ風：暖色寄りのカラーグレーディング・彩度低下・
  /// ニュートラルなフィルムグレインを組み合わせ、古いセル画をフィルム撮影
  /// したような質感にする。CRTの走査線・周辺減光やVHSのトラッキングずれ・
  /// 色にじみは含めないため、表示機器／テープ由来の効果とは明確に分離する。
  /// [seed]はテスト・再現可能なプレビュー用。通常利用では省略できる。
  Uint8List applyRetroAnime(
    Uint8List data,
    int width,
    int height,
    double strength, {
    int? seed,
  }) {'''
if s.count(old) != 1:
    raise SystemExit('retro signature anchor mismatch')
s = s.replace(old, new, 1)
old2 = '    return applyNoise(result, width, height, amount * 0.15, NoiseType.gaussian);'
new2 = '''    return applyFilmGrain(
      result,
      width,
      height,
      amount * 0.15,
      seed: seed,
    );'''
if s.count(old2) != 1:
    raise SystemExit('retro noise anchor mismatch')
p.write_text(s.replace(old2, new2, 1))
