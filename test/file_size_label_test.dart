import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/utils/file_size_label.dart';

/// ファイルの大きさの書き方（DISC130）。以前は言語によらず「1.4KB」「0B」と
/// 書いていた（仏語は「1,4 Ko」、英語は「1.4 KB」と書く）。数は言語の小数点で、
/// 数と単位の間は言語の書き方（日本語・韓国語は空けない、ほかは改行しない
/// 空白）、単位の名前は言語の名前（仏語は octet の o・Ko・Mo）。
void main() {
  const nbsp = '\u00a0';

  group('fileSizeLabel: each language writes sizes its own way', () {
    final expected = <String, List<String>>{
      // 0B / 512B / 1.4KB / 1.5MB / 1023.96KB→1.0MB / 5TB
      'ja': ['0B', '512B', '1.4KB', '1.5MB', '1.0MB', '5.0TB'],
      'ko': ['0B', '512B', '1.4KB', '1.5MB', '1.0MB', '5.0TB'],
      'en': [
        '0${nbsp}B',
        '512${nbsp}B',
        '1.4${nbsp}KB',
        '1.5${nbsp}MB',
        '1.0${nbsp}MB',
        '5.0${nbsp}TB',
      ],
      'es': [
        '0${nbsp}B',
        '512${nbsp}B',
        '1,4${nbsp}KB',
        '1,5${nbsp}MB',
        '1,0${nbsp}MB',
        '5,0${nbsp}TB',
      ],
      'fr': [
        '0${nbsp}o',
        '512${nbsp}o',
        '1,4${nbsp}Ko',
        '1,5${nbsp}Mo',
        '1,0${nbsp}Mo',
        '5,0${nbsp}To',
      ],
      'zh': [
        '0${nbsp}B',
        '512${nbsp}B',
        '1.4${nbsp}KB',
        '1.5${nbsp}MB',
        '1.0${nbsp}MB',
        '5.0${nbsp}TB',
      ],
      'zh_Hant': [
        '0${nbsp}B',
        '512${nbsp}B',
        '1.4${nbsp}KB',
        '1.5${nbsp}MB',
        '1.0${nbsp}MB',
        '5.0${nbsp}TB',
      ],
    };
    const bytes = <num>[
      0,
      512,
      1434,
      1.5 * 1024 * 1024,
      1023.96 * 1024,
      5.0 * 1024 * 1024 * 1024 * 1024,
    ];
    for (final MapEntry(key: language, value: labels) in expected.entries) {
      test(language, () {
        final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
        expect([for (final b in bytes) fileSizeLabel(l10n, b)], labels);
      });
    }
  });

  test('lib does not write byte units by hand (one helper for every size)', () {
    // 「'${bytes}B'」「toStringAsFixed(1)}KB'」「'0B'」「['B', 'KB', …]」の
    // ような手書きの単位（'B'だけの文字列は色の青〔RGBのB〕にも使うので見ない）。
    final unit = RegExp(r"""(\}|\d)(B|KB|MB|GB|TB)'|'(KB|MB|GB|TB)'""");
    final unicodeEscape = RegExp(r'\\u(\{[0-9A-Fa-f]+\}|[0-9A-Fa-f]{4})');
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.contains('lib/l10n/'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        // 文字のエスケープ（'\u200B'＝ゼロ幅スペース等）は単位ではない。
        final code = line.replaceAll(unicodeEscape, '');
        if (unit.hasMatch(code)) offenders.add('${file.path}:${i + 1}: $line');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
