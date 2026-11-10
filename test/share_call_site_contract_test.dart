import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 共有はlib配下のどこからも`ExportShareService`を通す。
///
/// `SharePlus.instance.share`を画面から直接呼ぶと、共有の仕組みが無い端末
/// （Linuxは`UnimplementedError`）や失敗の扱いが呼び出しごとにばらばらになり、
/// 「書き出しに失敗しました: UnimplementedError…」のように、できている
/// 書き出しを失敗と呼んで例外の文を見せていた。
void main() {
  test('only the share service talks to share_plus', () {
    const service = 'lib/services/export_share_service.dart';
    const feedback = 'lib/widgets/export_share_feedback.dart';
    final deprecatedApi = RegExp(r'\bShare\.(share|shareXFiles|shareUri)\(');
    final directCalls = <String>[];
    final imports = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        final where = '$path:${i + 1}: ${line.trim()}';
        if (path != service &&
            (line.contains('SharePlus.instance') ||
                deprecatedApi.hasMatch(line))) {
          directCalls.add(where);
        }
        if (path != service &&
            path != feedback &&
            line.contains('package:share_plus/')) {
          imports.add(where);
        }
      }
    }
    expect(
      directCalls,
      isEmpty,
      reason:
          'ExportShareServiceを通さずに共有している所：\n'
          '${directCalls.join('\n')}',
    );
    expect(
      imports,
      isEmpty,
      reason:
          'share_plusを直接importしている所（XFile等は'
          'export_share_service.dartから受け取る）：\n${imports.join('\n')}',
    );
    // 見張りそのものが空振りしていないこと（共有の入口は今もここにある）。
    expect(File(service).readAsStringSync(), contains('SharePlus.instance'));
  });
}
