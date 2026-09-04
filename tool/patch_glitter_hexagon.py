from pathlib import Path

# 1) DrawingEngine: Brush0016だけ六角形スタンプにする。既に実装済みなら再適用しない。
p = Path('lib/engine/drawing_engine.dart')
s = p.read_text()

if "final isGlitterHexagon = brush.id == 'Brush0016';" not in s:
    old = """    final radius = size / 2.0;\n    final alphaInt = (opacity * 255).round().clamp(0, 255);\n    if (alphaInt == 0) return;\n"""
    new = """    final radius = size / 2.0;\n    final alphaInt = (opacity * 255).round().clamp(0, 255);\n    if (alphaInt == 0) return;\n\n    // グリッターペンは大きな六角形フレークとして描画する。粒ごとに向きを\n    // ランダム化し、同じ向きの六角形が機械的に並ぶ見た目を避ける。\n    // ラメペンを含む他ブラシは従来どおり円形スタンプのまま。\n    final isGlitterHexagon = brush.id == 'Brush0016';\n    final particleRotation = isGlitterHexagon\n        ? _scatterRng.nextDouble() * math.pi * 2.0\n        : 0.0;\n"""
    assert old in s, 'anchor 1 not found'
    s = s.replace(old, new, 1)

    old = """      edgeJitter: brush.edgeJitter,\n      edgeJitterStrength: brush.edgeJitterStrength,\n    );\n"""
    new = """      edgeJitter: brush.edgeJitter,\n      edgeJitterStrength: brush.edgeJitterStrength,\n      hexagon: isGlitterHexagon,\n      particleRotation: particleRotation,\n    );\n"""
    assert old in s, 'anchor 2 not found'
    s = s.replace(old, new, 1)

    old = """    bool edgeJitter = false,\n    int edgeJitterStrength = 50,\n  }) {\n"""
    new = """    bool edgeJitter = false,\n    int edgeJitterStrength = 50,\n    bool hexagon = false,\n    double particleRotation = 0.0,\n  }) {\n"""
    assert old in s, 'anchor 3 not found'
    s = s.replace(old, new, 1)

    old = """            } else if (pixelMode) {\n              // ピクセルモード：エッジをシャープに（アンチエイリアス無し）\n              pixelAlpha = dist <= radius ? 1.0 : 0.0;\n"""
    new = """            } else if (hexagon) {\n              // グリッターフレーク：正六角形。傾き変形後のローカル座標を\n              // 粒固有の角度だけ回転し、六角形の符号付き近似距離でAAする。\n              final cosH = math.cos(-particleRotation);\n              final sinH = math.sin(-particleRotation);\n              final hx = ux * cosH - uy * sinH;\n              final hy = ux * sinH + uy * cosH;\n              final ax = hx.abs();\n              final ay = hy.abs();\n              const sqrt3 = 1.7320508075688772;\n              final hexDist = math.max(\n                ay / (sqrt3 / 2.0),\n                (sqrt3 * ax + ay) / sqrt3,\n              );\n              pixelAlpha = (radius + 0.5 - hexDist).clamp(0.0, 1.0);\n            } else if (pixelMode) {\n              // ピクセルモード：エッジをシャープに（アンチエイリアス無し）\n              pixelAlpha = dist <= radius ? 1.0 : 0.0;\n"""
    assert old in s, 'anchor 4 not found'
    s = s.replace(old, new, 1)
    p.write_text(s)

# 2) Default preset: 角を潰していたぼかし/エッジジッターを除き、六角形が独立して見える密度にする。
p = Path('lib/services/brush_service.dart')
s = p.read_text()
old = """      id: 'Brush0016',\n      name: 'グリッターペン',\n      size: 12,\n      opacity: 90,\n      spacing: 8,\n      blurRadius: 6,\n      stabilization: false,\n      stabilizationStrength: 0,\n      pixelMode: false,\n      pressureMode: PressureMode.opacity,\n      pressureStrength: 35,\n      fadeMode: FadeMode.off,\n      strokeDecay: false,\n      mixingMode: BrushMixingMode.off,\n      mixingRate: 0,\n      density: 1.7,\n      scatter: 0.85,\n      edgeJitter: true,\n      edgeJitterStrength: 55,\n"""
new = """      id: 'Brush0016',\n      name: 'グリッターペン',\n      size: 14,\n      opacity: 90,\n      spacing: 18,\n      blurRadius: 0,\n      stabilization: false,\n      stabilizationStrength: 0,\n      pixelMode: false,\n      pressureMode: PressureMode.opacity,\n      pressureStrength: 35,\n      fadeMode: FadeMode.off,\n      strokeDecay: false,\n      mixingMode: BrushMixingMode.off,\n      mixingRate: 0,\n      density: 1.2,\n      scatter: 0.9,\n      edgeJitter: false,\n      edgeJitterStrength: 0,\n"""
if old in s:
    s = s.replace(old, new, 1)
elif "id: 'Brush0016'" in s and "size: 14" in s and "spacing: 18" in s:
    pass
else:
    raise AssertionError('Brush0016 preset anchor not found')
p.write_text(s)

# 3) Visual capture must use exactly the same preset values.
p = Path('test/visual/glitter_lame_render_capture_test.dart')
s = p.read_text()
old = """const _glitter = Brush(\n  id: 'Brush0016', name: 'グリッターペン', size: 12, opacity: 90,\n  spacing: 8, blurRadius: 6, stabilization: false,\n  stabilizationStrength: 0, pixelMode: false,\n  pressureMode: PressureMode.opacity, pressureStrength: 35,\n  fadeMode: FadeMode.off, strokeDecay: false,\n  mixingMode: BrushMixingMode.off, mixingRate: 0,\n  density: 1.7, scatter: 0.85, edgeJitter: true, edgeJitterStrength: 55,\n);\n"""
new = """const _glitter = Brush(\n  id: 'Brush0016', name: 'グリッターペン', size: 14, opacity: 90,\n  spacing: 18, blurRadius: 0, stabilization: false,\n  stabilizationStrength: 0, pixelMode: false,\n  pressureMode: PressureMode.opacity, pressureStrength: 35,\n  fadeMode: FadeMode.off, strokeDecay: false,\n  mixingMode: BrushMixingMode.off, mixingRate: 0,\n  density: 1.2, scatter: 0.9, edgeJitter: false, edgeJitterStrength: 0,\n);\n"""
if old in s:
    s = s.replace(old, new, 1)
elif "size: 14" in s and "spacing: 18" in s and "density: 1.2" in s:
    pass
else:
    raise AssertionError('visual glitter preset anchor not found')
p.write_text(s)
