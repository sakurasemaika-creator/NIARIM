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

  // `ExportShareService`を通していても、自分のcatchで受けて「作成に失敗
  // しました: $error」と出すと同じことが起きる（保存した共有ファイルの共有が
  // そうだった）。失敗を言葉にするのは`exportShareFailureText`だけにする。
  test('share failures are worded in one place', () {
    const service = 'lib/services/export_share_service.dart';
    // 入口を直接呼んでよい所：知らせの入口そのものと、知らせをその場（作品
    // 一覧の行・プレビューのダイアログの中）に出す所。ほかは
    // export_share_feedback.dartの入口を通す。
    const direct = {
      'lib/widgets/export_share_feedback.dart',
      'lib/screens/home/home_screen.dart',
    };
    final call = RegExp(r'ExportShareService\s*\.\s*share(Files)?\s*\(');
    final offenders = <String>[];
    final callers = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path == service) continue;
      final source = entity.readAsStringSync();
      for (final match in call.allMatches(source)) {
        final lineStart = source.lastIndexOf('\n', match.start) + 1;
        final lineEnd = source.indexOf('\n', match.start);
        final line = source.substring(
          lineStart,
          lineEnd < 0 ? source.length : lineEnd,
        );
        if (line.trimLeft().startsWith('//')) continue;
        callers.add(path);
        if (direct.contains(path)) continue;
        final number = '\n'.allMatches(source.substring(0, lineStart)).length;
        offenders.add('$path:${number + 1}: ${line.trim()}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '共有の結果・失敗を自分で受けている所（shareExportedFileWithNotice・'
          'shareFilesWithNotice・shareExportedFileCatchingを通す）：\n'
          '${offenders.join('\n')}',
    );
    for (final path in direct) {
      expect(callers, contains(path), reason: '$pathはもう直接呼んでいない');
      expect(
        File(path).readAsStringSync(),
        contains('exportShareFailureText'),
        reason: '$pathは共有の失敗を共有の文で知らせる',
      );
    }
  });
}
