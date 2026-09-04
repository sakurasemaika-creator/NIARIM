from pathlib import Path

p = Path('lib/engine/drawing_engine.dart')
s = p.read_text()

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
