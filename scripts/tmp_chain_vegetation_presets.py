from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f'marker not found: {path}: {old[:100]!r}')
    p.write_text(s.replace(old, new, 1))

# ── Brush presets ────────────────────────────────────────────────────────────
p = Path('lib/services/brush_service.dart')
s = p.read_text()
marker = """    const Brush(\n      id: 'Brush0017',\n      name: 'ラメペン',"""
idx = s.find(marker)
if idx < 0:
    raise SystemExit('Brush0017 marker missing')
end = s.find('    ),\n  ];', idx)
if end < 0:
    raise SystemExit('default brush list end missing')
end += len('    ),\n')
new_brushes = r'''    // チェーン（太）：工事・係留用の頑丈な鎖を想定。リンクは肉厚で
    // やや角張った縦長楕円、間隔も詰めて「重量感」と噛み合いを優先する。
    const Brush(
      id: 'Brush0018',
      name: 'チェーン（太）',
      size: 34,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 35,
      pixelMode: false,
      pressureMode: PressureMode.off,
      pressureStrength: 0,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      rotation: true,
      density: 1.0,
      scatter: 0,
      tags: [AssetTagKeys.decoration, AssetTagKeys.background, AssetTagKeys.clothing],
    ),
    // チェーン（中）：メンズアクセサリー向け。太よりリンクを細長くし、
    // 肉厚を少し抑えて輪郭がシャープに見えるバランス。
    const Brush(
      id: 'Brush0019',
      name: 'チェーン（中）',
      size: 22,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 40,
      pixelMode: false,
      pressureMode: PressureMode.off,
      pressureStrength: 0,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      rotation: true,
      density: 1.0,
      scatter: 0,
      tags: [AssetTagKeys.decoration, AssetTagKeys.clothing],
    ),
    // チェーン（細）：華奢なネックレス用。小さく細いリンクを高密度に並べる。
    const Brush(
      id: 'Brush0020',
      name: 'チェーン（細）',
      size: 12,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 48,
      pixelMode: false,
      pressureMode: PressureMode.off,
      pressureStrength: 0,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      rotation: true,
      density: 1.0,
      scatter: 0,
      tags: [AssetTagKeys.decoration, AssetTagKeys.clothing],
    ),
    // ボールチェーン：小球を等間隔でつなぐ細身の装飾チェーン。
    const Brush(
      id: 'Brush0021',
      name: 'ボールチェーン',
      size: 7,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 42,
      pixelMode: false,
      pressureMode: PressureMode.off,
      pressureStrength: 0,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      rotation: false,
      density: 1.0,
      scatter: 0,
      tags: [AssetTagKeys.decoration, AssetTagKeys.clothing],
    ),
'''
s = s[:end] + new_brushes + s[end:]
p.write_text(s)

# ── DrawingEngine procedural chain tips ──────────────────────────────────────
p = Path('lib/engine/drawing_engine.dart')
s = p.read_text()
s = s.replace(
    """    final safeDensity = brush.density.clamp(0.1, 5.0).toDouble();\n    final spacing = math.max(1.0, brush.spacing.toDouble() / safeDensity);\n""",
    """    final safeDensity = brush.density.clamp(0.1, 5.0).toDouble();\n    final spacing = _brushStampSpacing(brush, safeDensity);\n""",
    1,
)
# Add per-brush procedural metadata before tilt calculation.
old = """    final particleRotation = isGlitterHexagon\n        ? _scatterRng.nextDouble() * math.pi * 2.0\n        : 0.0;\n\n    // 傾き変形"""
new = r'''    final isChainLink =
        brush.id == 'Brush0018' ||
        brush.id == 'Brush0019' ||
        brush.id == 'Brush0020';
    final isBallChain = brush.id == 'Brush0021';
    final chainStep = isChainLink
        ? (strokeLength / math.max(1.0, _brushStampSpacing(brush, 1.0))).round()
        : 0;
    final particleRotation = isGlitterHexagon
        ? _scatterRng.nextDouble() * math.pi * 2.0
        : isChainLink
        // 実鎖の「交互に別平面を向く」印象を2Dで読めるよう、隣接リンクを
        // 接線に対して左右へ交互に傾ける。完全な90度交互より連結が自然。
        ? (chainStep.isEven ? -0.48 : 0.48)
        : 0.0;
    final chainAspect = switch (brush.id) {
      'Brush0018' => 0.64,
      'Brush0019' => 0.56,
      'Brush0020' => 0.50,
      _ => 1.0,
    };
    final chainThickness = switch (brush.id) {
      'Brush0018' => 0.25,
      'Brush0019' => 0.19,
      'Brush0020' => 0.14,
      _ => 0.0,
    };

    // 傾き変形'''
if old not in s:
    raise SystemExit('drawing metadata marker missing')
s = s.replace(old, new, 1)
old = """      hexagon: isGlitterHexagon,\n      particleRotation: particleRotation,\n    );\n"""
new = """      hexagon: isGlitterHexagon,\n      particleRotation: particleRotation,\n      chainLink: isChainLink,\n      chainAspect: chainAspect,\n      chainThickness: chainThickness,\n      ballChain: isBallChain,\n    );\n"""
if old not in s:
    raise SystemExit('render stamp call marker missing')
s = s.replace(old, new, 1)
old = """    bool hexagon = false,\n    double particleRotation = 0.0,\n  }) {\n"""
new = """    bool hexagon = false,\n    double particleRotation = 0.0,\n    bool chainLink = false,\n    double chainAspect = 1.0,\n    double chainThickness = 0.0,\n    bool ballChain = false,\n  }) {\n"""
if old not in s:
    raise SystemExit('render stamp signature marker missing')
s = s.replace(old, new, 1)
# Chain-aware pixel alpha before pixelMode branch.
old = """            } else if (hexagon) {\n              // グリッターフレーク：正六角形。傾き変形後のローカル座標を\n"""
new = r'''            } else if (chainLink) {
              // 中抜き楕円リンク。接線座標へ揃えたあと、リンク固有の交互角度
              // だけ回す。outer/innerの楕円距離差で肉厚を作るため、拡縮しても
              // リングの穴が潰れずチェーンとして読める。
              final cosL = math.cos(-particleRotation);
              final sinL = math.sin(-particleRotation);
              final lx = ux * cosL - uy * sinL;
              final ly = ux * sinL + uy * cosL;
              final outerX = radius;
              final outerY = radius * chainAspect;
              final wall = radius * chainThickness;
              final innerX = math.max(0.5, outerX - wall);
              final innerY = math.max(0.5, outerY - wall);
              final outerD = math.sqrt(
                (lx * lx) / (outerX * outerX) +
                    (ly * ly) / (outerY * outerY),
              );
              final innerD = math.sqrt(
                (lx * lx) / (innerX * innerX) +
                    (ly * ly) / (innerY * innerY),
              );
              final outerAa = ((1.0 - outerD) * radius + 0.7).clamp(0.0, 1.0);
              final innerAa = ((innerD - 1.0) * radius + 0.7).clamp(0.0, 1.0);
              pixelAlpha = math.min(outerAa, innerAa);
            } else if (hexagon) {
              // グリッターフレーク：正六角形。傾き変形後のローカル座標を
'''
if old not in s:
    raise SystemExit('chain alpha marker missing')
s = s.replace(old, new, 1)
# Ball chain remains circular but receives a tiny center highlight by alpha profile.
old = """            } else {\n              // 通常ブラシ：アンチエイリアス\n              if (edgeJitter && dist > radius - 1.5) {\n"""
new = """            } else {\n              // 通常ブラシ／ボールチェーン：アンチエイリアス。ボールチェーンは\n              // 円形そのものを保ち、専用spacingで粒がつながり過ぎないようにする。\n              if (edgeJitter && dist > radius - 1.5) {\n"""
s = s.replace(old, new, 1)
# Add spacing helper before _stableDouble.
marker = """  double _stableDouble(double value) => (value * 1000000).round() / 1000000;\n"""
helper = r'''  double _brushStampSpacing(Brush brush, double safeDensity) {
    // 装飾チェーンはブラシ径を変更したときもリンク同士の比率が崩れないよう、
    // 絶対pxのspacingではなくブラシサイズ比例で配置する。
    final factor = switch (brush.id) {
      'Brush0018' => 0.68,
      'Brush0019' => 0.72,
      'Brush0020' => 0.76,
      'Brush0021' => 1.35,
      _ => 0.0,
    };
    if (factor > 0) {
      return math.max(1.0, brush.size * factor / safeDensity);
    }
    return math.max(1.0, brush.spacing.toDouble() / safeDensity);
  }

'''
if marker not in s:
    raise SystemExit('spacing helper marker missing')
s = s.replace(marker, helper + marker, 1)
p.write_text(s)

# ── Stamp presets ────────────────────────────────────────────────────────────
p = Path('lib/services/stamp_service.dart')
s = p.read_text()
old = """    const Stamp(id: 'Stamp0024', name: '両矢印', tags: [AssetTagKeys.symbol]),\n  ];\n"""
new = r'''    const Stamp(id: 'Stamp0024', name: '両矢印', tags: [AssetTagKeys.symbol]),
    // 背景をストローク1本で埋めるための連続スタンプ。単発の葉アイコンではなく、
    // 内部テクスチャ自体が複数の葉・色を持つ小さな植生クラスター。
    const Stamp(
      id: 'Stamp0025',
      name: '葉っぱ（背景）',
      rotation: true,
      density: 2.3,
      scatter: 22,
      opacity: 94,
      tags: [AssetTagKeys.background, AssetTagKeys.texture, AssetTagKeys.decoration],
    ),
    const Stamp(
      id: 'Stamp0026',
      name: '草（背景）',
      rotation: false,
      density: 2.8,
      scatter: 18,
      opacity: 96,
      tags: [AssetTagKeys.background, AssetTagKeys.texture],
    ),
  ];
'''
if old not in s:
    raise SystemExit('stamp list marker missing')
s = s.replace(old, new, 1)
p.write_text(s)

# ── Procedural multicolor vegetation textures ───────────────────────────────
p = Path('lib/engine/procedural_texture.dart')
s = p.read_text()
old = """  if (texture == null) {\n    final recorder = ui.PictureRecorder();\n    final canvas = ui.Canvas(recorder);\n    final paint = ui.Paint()..color = const ui.Color(0xFF222222);\n    canvas.drawPath(_shapePathForName(stamp.name, size.toDouble()), paint);\n"""
new = r'''  if (texture == null) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (stamp.name.contains('葉っぱ（背景）')) {
      _drawLeafCluster(canvas, size.toDouble());
    } else if (stamp.name.contains('草（背景）')) {
      _drawGrassCluster(canvas, size.toDouble());
    } else {
      final paint = ui.Paint()..color = const ui.Color(0xFF222222);
      canvas.drawPath(_shapePathForName(stamp.name, size.toDouble()), paint);
    }
'''
if old not in s:
    raise SystemExit('stamp texture generation marker missing')
s = s.replace(old, new, 1)
# Insert helpers before shape path.
marker = """ui.Path _shapePathForName(String name, double s) {\n"""
helpers = r'''void _drawLeafCluster(ui.Canvas canvas, double s) {
  final rng = math.Random(25025);
  const colors = <ui.Color>[
    ui.Color(0xFF1F6B38),
    ui.Color(0xFF2F8745),
    ui.Color(0xFF4B9A43),
    ui.Color(0xFF6EAE42),
    ui.Color(0xFF91BD45),
    ui.Color(0xFFB2C94B),
  ];
  for (var i = 0; i < 13; i++) {
    final cx = s * (0.18 + rng.nextDouble() * 0.64);
    final cy = s * (0.18 + rng.nextDouble() * 0.64);
    final length = s * (0.18 + rng.nextDouble() * 0.16);
    final width = length * (0.34 + rng.nextDouble() * 0.18);
    final angle = rng.nextDouble() * math.pi * 2;
    final paint = ui.Paint()..color = colors[i % colors.length];
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    final leaf = ui.Path()
      ..moveTo(-length * 0.52, 0)
      ..cubicTo(
        -length * 0.18,
        -width,
        length * 0.30,
        -width * 0.82,
        length * 0.52,
        0,
      )
      ..cubicTo(
        length * 0.28,
        width * 0.82,
        -length * 0.20,
        width,
        -length * 0.52,
        0,
      )
      ..close();
    canvas.drawPath(leaf, paint);
    // 葉脈を僅かに暗くして、縮小しても単色の楕円に潰れないようにする。
    final vein = ui.Paint()
      ..color = const ui.Color(0x55204E2B)
      ..strokeWidth = math.max(0.7, s * 0.008)
      ..style = ui.PaintingStyle.stroke;
    canvas.drawLine(
      ui.Offset(-length * 0.38, 0),
      ui.Offset(length * 0.40, 0),
      vein,
    );
    canvas.restore();
  }
}

void _drawGrassCluster(ui.Canvas canvas, double s) {
  final rng = math.Random(26026);
  const colors = <ui.Color>[
    ui.Color(0xFF285F31),
    ui.Color(0xFF34783B),
    ui.Color(0xFF4A8F3E),
    ui.Color(0xFF65A542),
    ui.Color(0xFF7DB544),
    ui.Color(0xFFA0C74D),
  ];
  final baseY = s * 0.82;
  for (var i = 0; i < 31; i++) {
    final x = s * (0.08 + rng.nextDouble() * 0.84);
    final height = s * (0.24 + rng.nextDouble() * 0.52);
    final bend = (rng.nextDouble() * 2 - 1) * s * 0.16;
    final width = s * (0.008 + rng.nextDouble() * 0.012);
    final paint = ui.Paint()..color = colors[i % colors.length];
    final blade = ui.Path()
      ..moveTo(x - width, baseY)
      ..quadraticBezierTo(
        x + bend * 0.35 - width,
        baseY - height * 0.55,
        x + bend,
        baseY - height,
      )
      ..quadraticBezierTo(
        x + bend * 0.35 + width,
        baseY - height * 0.55,
        x + width,
        baseY,
      )
      ..close();
    canvas.drawPath(blade, paint);
  }
}

'''
if marker not in s:
    raise SystemExit('vegetation helper marker missing')
s = s.replace(marker, helpers + marker, 1)
p.write_text(s)

print('chain brushes and vegetation stamps patch applied')
