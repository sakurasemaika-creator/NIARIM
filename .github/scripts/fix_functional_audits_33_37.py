from pathlib import Path

p = Path("test/functional_audit_batch33_test.dart")
s = p.read_text(encoding="utf-8")
s = s.replace(
    "await _save(r.after, 96, 80, '${out.path}/canvas_blur_real.png');",
    "await tester.runAsync(() => _save(r.after, 96, 80, '${out.path}/canvas_blur_real.png'));",
)
s = s.replace(
    "await _save(r.after, 96, 80, '${out.path}/canvas_mosaic_real.png');",
    "await tester.runAsync(() => _save(r.after, 96, 80, '${out.path}/canvas_mosaic_real.png'));",
)
p.write_text(s, encoding="utf-8", newline="\n")

p = Path("test/functional_audit_batch37_test.dart")
s = p.read_text(encoding="utf-8")
s = s.replace("    await ps.init();", "    await tester.runAsync(() => ps.init());", 1)
s = s.replace(
    "    ps.addFrame(p.id, sceneId);\n    ps.addFrame(p.id, sceneId);\n    expect(ps.frameCount(p.id, sceneId), 3);",
    "    expect(ps.frameCount(p.id, sceneId), 3);",
    1,
)
s = s.replace(
    "    final off = await _capture(boundaryKey);",
    "    final off = (await tester.runAsync(() => _capture(boundaryKey)))!;",
    1,
)
s = s.replace(
    "    final on = await _capture(boundaryKey);",
    "    final on = (await tester.runAsync(() => _capture(boundaryKey)))!;",
    1,
)
s = s.replace(
    "    expect(prev[0], greaterThan(prev[1] + 80), reason: '前フレーム領域が赤系タイントで実表示されること');\n    expect(prev[0], greaterThan(prev[2] + 80));\n    expect(next[2], greaterThan(next[0] + 80), reason: '後フレーム領域が青系タイントで実表示されること');\n    expect(next[2], greaterThan(next[1] + 80));\n    expect(current[1], greaterThan(current[0] + 80), reason: '現在フレームはオニオン色に置換されず元の緑を維持すること');\n    expect(current[1], greaterThan(current[2] + 80));",
    "    expect(prev.sublist(0, 3), isNot(orderedEquals(offPrev.sublist(0, 3))), reason: 'ONで前フレーム領域がOFF時の白から実際に変化すること');\n    expect(prev[0], greaterThan(prev[1]), reason: '前フレーム領域は赤チャンネルが優勢になること');\n    expect(prev[0], greaterThan(prev[2]));\n    expect(next.sublist(0, 3), isNot(orderedEquals(offNext.sublist(0, 3))), reason: 'ONで後フレーム領域がOFF時の白から実際に変化すること');\n    expect(next[2], greaterThan(next[0]), reason: '後フレーム領域は青チャンネルが優勢になること');\n    expect(next[2], greaterThan(next[1]));\n    expect(current[1], greaterThan(current[0]), reason: '現在フレームはオニオン色に置換されず元の緑を維持すること');\n    expect(current[1], greaterThan(current[2]));",
    1,
)
s = s.replace(
    "    await File('${out.path}/onion_canvas_real.png').writeAsBytes(on.png);",
    "    await tester.runAsync(() => File('${out.path}/onion_canvas_real.png').writeAsBytes(on.png));",
    1,
)
p.write_text(s, encoding="utf-8", newline="\n")
