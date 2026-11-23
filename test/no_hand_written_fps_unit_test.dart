import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// コマ毎秒の単位は ARB の文（`pcStatusFps`・`homeProjectMeta` 等、仏語は
/// 「i/s」）で出す。手で `'$fps fps'`・`'24fps'` と書くと、仏語でも fps と出た
/// （設定の既定のコマ毎秒・作品広場の作品の詳細と縦の一覧・テーマの見本）。
void main() {
  test('no hand-written fps unit in the screens', () {
    final unit = RegExp(r"""['"][^'"\n]*(?:\$\{?[\w.]+\}?|\d)\s?fps['"]""");
    final found = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/l10n/')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.contains('//')
            ? line.substring(0, line.indexOf('//'))
            : line;
        if (unit.hasMatch(code)) found.add('$path:${i + 1}: ${line.trim()}');
      }
    }
    expect(found, isEmpty);
  });
}
