from pathlib import Path
p=Path('test/final_remaining_strict_evidence_test.dart')
s=p.read_text()
s=s.replace("      final effect = EffectFilterInstance(id: 'b$strength', type: EffectFilterType.blur, startFrame: 0, endFrame: 0, param1: strength.toDouble());\n      final got = FilterEngine().applyEffectFilters(Uint8List.fromList(input), w, h, [effect], 0);", "      final got = FilterEngine().applyGaussianBlur(Uint8List.fromList(input), w, h, strength.toDouble());")
s=s.replace("const ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())", "ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())")
p.write_text(s)
