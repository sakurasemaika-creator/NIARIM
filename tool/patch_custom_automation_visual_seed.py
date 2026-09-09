from pathlib import Path

p = Path('test/custom_automation_production_visual_test.dart')
s = p.read_text()
old = """    final tile = tm.getOrCreateTile(key, 0, 0);
    tile.fillRange(0, tile.length, 0);
    for (var y = 36; y < 284; y++) {
      for (var x = 36; x < 284; x++) {
        final i = (y * TileManager.tileSize + x) * 4;
        var shade = 20 + ((x - 36) * 225 ~/ 247);
        if ((x > 92 && x < 118) || (y > 148 && y < 174)) {
          shade = 18;
        }
        if (x > 188 && x < 242 && y > 78 && y < 132) {
          shade = 235;
        }
        tile[i] = shade;
        tile[i + 1] = shade;
        tile[i + 2] = shade;
        tile[i + 3] = 255;
      }
    }
    tm.invalidateTile(key, 0, 0);
"""
new = """    for (var ty = 0; ty < tm.tilesY; ty++) {
      for (var tx = 0; tx < tm.tilesX; tx++) {
        final tile = tm.getOrCreateTile(key, tx, ty);
        tile.fillRange(0, tile.length, 0);
        for (var localY = 0; localY < TileManager.tileSize; localY++) {
          final y = ty * TileManager.tileSize + localY;
          if (y >= tm.canvasHeight) continue;
          for (var localX = 0; localX < TileManager.tileSize; localX++) {
            final x = tx * TileManager.tileSize + localX;
            if (x >= tm.canvasWidth) continue;
            if (x < 36 || x >= 284 || y < 36 || y >= 284) continue;
            final i = (localY * TileManager.tileSize + localX) * 4;
            var shade = 20 + ((x - 36) * 225 ~/ 247);
            if ((x > 92 && x < 118) || (y > 148 && y < 174)) {
              shade = 18;
            }
            if (x > 188 && x < 242 && y > 78 && y < 132) {
              shade = 235;
            }
            tile[i] = shade;
            tile[i + 1] = shade;
            tile[i + 2] = shade;
            tile[i + 3] = 255;
          }
        }
        tm.invalidateTile(key, tx, ty);
      }
    }
"""
if old not in s:
    raise SystemExit('canvas seed anchor changed')
s = s.replace(old, new, 1)
s = s.replace("import 'dart:typed_data';\n", '')
s = s.replace('handleCanvasStateCommand: (_, __) async {},', 'handleCanvasStateCommand: (_, _) async {},')
p.write_text(s)
