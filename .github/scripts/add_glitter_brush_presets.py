from pathlib import Path

p = Path('lib/services/brush_service.dart')
s = p.read_text(encoding='utf-8')

if "name: 'グリッターペン'" in s or "name: 'ラメペン'" in s:
    raise SystemExit('glitter presets already present')

anchor = """    const Brush(
      id: 'Brush0015',
      name: '面相筆',
      size: 8,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 55,
      pixelMode: false,
      pressureMode: PressureMode.size,
      pressureStrength: 90,
      fadeMode: FadeMode.strong,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.taper],
    ),
"""

addition = anchor + """    // グリッターペン：大きめの輝点を広く散らす装飾用ペン。
    // 粒を独立して見せるため間隔と散布を大きめにし、わずかなぼかしで
    // 強い反射光のようなきらめきを作る。
    const Brush(
      id: 'Brush0016',
      name: 'グリッターペン',
      size: 12,
      opacity: 90,
      spacing: 8,
      blurRadius: 6,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureMode: PressureMode.opacity,
      pressureStrength: 35,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      density: 1.7,
      scatter: 0.85,
      edgeJitter: true,
      edgeJitterStrength: 55,
      tags: [AssetTagKeys.effect, AssetTagKeys.decoration],
    ),
    // ラメペン：グリッターより細かい粒を高密度で線に沿わせるペン。
    // 散布幅を抑え、細かな反射粒が連続してきらめく質感にする。
    const Brush(
      id: 'Brush0017',
      name: 'ラメペン',
      size: 5,
      opacity: 76,
      spacing: 4,
      blurRadius: 1,
      stabilization: true,
      stabilizationStrength: 20,
      pixelMode: false,
      pressureMode: PressureMode.opacity,
      pressureStrength: 25,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      density: 2.8,
      scatter: 0.45,
      edgeJitter: true,
      edgeJitterStrength: 30,
      tags: [AssetTagKeys.effect, AssetTagKeys.decoration],
    ),
"""

if anchor not in s:
    raise SystemExit('Brush0015 anchor not found')

s = s.replace(anchor, addition, 1)
p.write_text(s, encoding='utf-8')
print('Added Brush0016 グリッターペン and Brush0017 ラメペン')
