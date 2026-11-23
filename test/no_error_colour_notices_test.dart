import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/icon_notice.dart';

/// 知らせ・削除の操作を`colorScheme.error`の赤で描かない。
///
/// エラーの色は差し色から作られる色で、テーマ・外観で選ぶ色ではない。暗い
/// 面では暗い赤で読めず、色を見分けにくい人には何の知らせか分からない。
/// 知らせは`IconNotice`（その面の文字色＋先頭の印）、メニューの危ない操作は
/// `MenuActionLabel`、削除の確かめは`confirmDelete`と同じ塗りのボタンにする。
///
/// 残してよいのは次の所だけ（色そのものが役目のもの）。
const _allowed = <String, int>{
  // 入力欄の誤りの状態（Materialの決まりどおりの枠・文字）。
  'lib/services/theme_service.dart': 2,
  'lib/widgets/menu_surface.dart': 1,
  // テーマの見本一覧の模型（テーマのエラーの色そのものを見せる）。
  'lib/screens/settings/theme_preview_gallery_screen.dart': 2,
  // 今のコマの赤い枠と、フェードの色の見本の「赤」。
  'lib/screens/timeline/timeline_screen.dart': 2,
  // 起動に失敗した画面の大きな印（文はその下に本文の色で出す）。
  'lib/widgets/startup_failure_app.dart': 1,
};

void main() {
  test('notices and delete actions are not drawn in the error colour', () {
    final pattern = RegExp(
      r'\b(?:colorScheme|activeColorScheme|scheme|cs|colors|c)\s*\.\s*'
      r'(?:error|onError|errorContainer|onErrorContainer)\b',
    );
    final found = <String, int>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/l10n/')) continue;
      final code = entity
          .readAsLinesSync()
          .map((line) {
            final comment = line.indexOf('//');
            return comment < 0 ? line : line.substring(0, comment);
          })
          .join('\n');
      final count = pattern.allMatches(code).length;
      if (count > 0) found[path] = count;
    }
    final unexpected = {
      for (final MapEntry(:key, :value) in found.entries)
        if (value > (_allowed[key] ?? 0)) key: value,
    };
    expect(
      unexpected,
      isEmpty,
      reason:
          'Use IconNotice / MenuActionLabel / the plain FilledButton of '
          'confirmDelete instead of the error colour.',
    );
  });

  testWidgets('IconNotice draws the mark and text in the surface text colour', (
    tester,
  ) async {
    const text = Color(0xFF123456);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(error: Colors.red),
        ),
        home: const Scaffold(
          body: DefaultTextStyle(
            style: TextStyle(color: text, fontSize: 14),
            child: IconNotice('Could not load the image'),
          ),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, text);
    final label = tester.widget<Text>(find.text('Could not load the image'));
    expect(label.style?.color, text);
  });
}
