import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/signal_colors.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/icon_notice.dart';
import 'package:niarim/widgets/menu_action_label.dart';

/// 警告色・注意色は、ちゃんと見てほしい所だけに使う（所有者の判断「基本と
/// なるベースカラー系や文字色系と、注意色・警告色は用途をしっかり使い分ける
/// ことで普段は世界観を壊さず、ちゃんと見てほしいところだけ目立たせる」
/// 「注意色はベースカラーなど注意や更新と無縁の部分には使わない」）。
///
/// - 警告色（テーマ・外観の「警告色」）：取り消せない操作の確かめのボタン
///   （`warningFilledButtonStyle`・`ProjectTrashDialog(destructive: true)`）、
///   メニューの取り消せない項目（`MenuActionLabel(destructive: true)`）、
///   作品が保存できない・失われうる失敗の知らせ（`IconNotice.warning`）。
/// - 注意色（＝更新マーク色）：更新の印と、何も失われないが気をつけてほしい
///   知らせ（`IconNotice.caution`、書き出されない範囲の枠、通知の数）。
/// - それ以外はいつもの色（`IconNotice`・`MenuActionLabel`の既定）。
///
/// 画面は`colorScheme.error`・`Colors.red`等・`updateMarkColor`・
/// `warningColor`を直接使わず、上の部品（[SignalColors]）を通す。部品を使う
/// 所は下の一覧に載せ、新しく使うときは警告・注意に当たるかを確かめて足す。

/// `colorScheme.error`等を書いてよい所（色そのものが役目のもの）。
const _errorColourAllowed = <String, int>{
  // 入力欄の誤りの状態（Materialの決まりどおりの枠・文字。テーマが警告色を
  // 入れてある）。
  'lib/services/theme_service.dart': 2,
  'lib/widgets/menu_surface.dart': 1,
  // テーマに警告色が無いとき（素のThemeDataのテスト等）の代わり。
  'lib/config/signal_colors.dart': 2,
  // 今のコマの赤い枠（中の差し色のカーソルと見分ける赤。所有者の判断待ち：
  // いつもの色にするか）と、フェードの色の見本の「赤」（作品に使う色）。
  'lib/screens/timeline/timeline_screen.dart': 2,
};

/// `Colors.red`等の赤・橙・黄を書いてよい所（作品に使う色そのもの）。
const _rawRedAllowed = <String, int>{
  // オニオンスキンの前後のコマの色の選択肢。
  'lib/screens/canvas/widgets/onion_skin_panel.dart': 3,
};

/// テーマの`updateMarkColor`・`warningColor`を直接読んでよい所（色を決める・
/// 選ばせる所）。
const _rawSignalAllowed = <String>{
  'lib/models/app_theme_preset.dart',
  'lib/services/theme_service.dart',
  'lib/utils/warning_color.dart',
  'lib/utils/color_contrast.dart',
  'lib/config/signal_colors.dart',
  // テーマ・外観の色の行・色の見本。
  'lib/screens/settings/theme_settings_screen.dart',
};

/// 警告色の部品（`warningFilledButtonStyle`・`IconNotice.warning`・
/// `destructive: true`）を使ってよい所と数。
const _warningAllowed = <String, int>{
  // 削除の確かめ（共通）。
  'lib/widgets/confirm_delete.dart': 1,
  // 完全削除・ゴミ箱を空にする（共通の確かめの部品・ホーム・容量削減）。
  'lib/widgets/project_trash_dialog.dart': 1,
  'lib/screens/home/home_screen.dart': 3,
  // 容量削減：ゴミ箱を空にする・使っていない素材の削除。
  'lib/screens/settings/storage_screen.dart': 2,
  // 全データを削除。
  'lib/screens/settings/widgets/erase_all_dialog.dart': 1,
  // 手動の保存：削除の項目・上書き・読み込み（今の作業を上書き）・保存の失敗。
  'lib/screens/save_tree/save_tree_screen.dart': 4,
  'lib/screens/save_tree/save_management_screen.dart': 2,
  'lib/screens/save_tree/widgets/save_restore_dialog.dart': 1,
  // 削除の確かめ（シーン・コマを減らす・作品広場の作品/タグ/保存した検索・
  // 待っている投稿・メイキングの記録・自動操作・完全削除の設定・テーマの
  // 色を戻す）。
  'lib/screens/timeline/timeline_screen.dart': 3,
  'lib/screens/community/community_work_detail_screen.dart': 1,
  'lib/screens/community/community_work_settings_screen.dart': 1,
  'lib/screens/community/community_screen.dart': 1,
  'lib/screens/community/community_post_screen.dart': 1,
  'lib/screens/project/making_screen.dart': 1,
  'lib/widgets/custom_automation_manager_sheet.dart': 1,
  'lib/screens/settings/performance_settings_screen.dart': 1,
  'lib/screens/settings/theme_settings_screen.dart': 2,
  // メニューの「削除」（ブラシ・トーン・スタンプ・自動塗り・キャンバスの大きさ）。
  'lib/screens/canvas/widgets/brush_panel.dart': 1,
  'lib/screens/canvas/widgets/tone_panel.dart': 1,
  'lib/screens/canvas/widgets/stamp_panel.dart': 1,
  'lib/screens/project/canvas_size_preset_manage_screen.dart': 1,
  // 自動塗りのプリセット：メニューの削除・プリセットとサムネイルの削除。
  'lib/screens/autofill/autofill_preset_screen.dart': 3,
  // 素材の削除（1件・使っていない素材）・タイムラインのレイヤーの削除。
  'lib/screens/materials/material_list_screen.dart': 2,
  'lib/screens/canvas/widgets/layer_panel.dart': 1,
};

/// 注意色の知らせ（`IconNotice.caution`）を使ってよい所と数。
const _cautionAllowed = <String, int>{
  // つながらない・読み込めない・作れない（やり直せる）。
  'lib/screens/community/community_post_screen.dart': 1,
  'lib/screens/premium/premium_screen.dart': 1,
  'lib/screens/rewards/opal_gifts.dart': 1,
  'lib/screens/export/export_screen.dart': 1,
  'lib/screens/project/new_project_screen.dart': 1,
  'lib/screens/project/making_screen.dart': 2,
  'lib/screens/settings/error_log_screen.dart': 1,
  'lib/screens/settings/workspace_settings_screen.dart': 1,
  'lib/screens/home/widgets/exported_work_thumbnail_dialog.dart': 1,
  'lib/screens/home/widgets/folder_thumbnail.dart': 1,
  'lib/screens/home/widgets/project_thumbnail_dialog.dart': 1,
  'lib/screens/canvas/widgets/reference_window.dart': 1,
  'lib/widgets/square_image_crop_dialog.dart': 1,
  // 入れられなかった音・読み上げを作れない・キーフレームが重なる・未設定の
  // パーツ。
  'lib/screens/export/widgets/export_complete_dialog.dart': 1,
  'lib/screens/timeline/timeline_screen.dart': 2,
  'lib/screens/autofill/autofill_preset_screen.dart': 1,
};

/// `SignalColors.of`で色を直接読んでよい所（部品と、注意色の印）。
const _signalAccessAllowed = <String>{
  'lib/config/signal_colors.dart',
  'lib/widgets/icon_notice.dart',
  'lib/widgets/menu_action_label.dart',
  'lib/widgets/project_trash_dialog.dart',
  // 書き出されない範囲の枠（注意色）。
  'lib/screens/canvas/widgets/canvas_area.dart',
  // 起動に失敗した画面の大きな印（やり直せる＝注意色）。
  'lib/widgets/startup_failure_app.dart',
  // テーマの見本一覧の通知の数（注意色、本物のバッジと同じ）。
  'lib/screens/settings/theme_preview_gallery_screen.dart',
};

/// lib配下の手書きのDartファイルの、`//`の注釈を除いた中身。
Map<String, String> _libSources() {
  final sources = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/l10n/')) continue;
    sources[path] = entity
        .readAsLinesSync()
        .map((line) {
          final comment = line.indexOf('//');
          return comment < 0 ? line : line.substring(0, comment);
        })
        .join('\n');
  }
  return sources;
}

Map<String, int> _count(
  Map<String, String> sources,
  RegExp pattern, {
  Set<String> skip = const {},
}) => {
  for (final MapEntry(:key, :value) in sources.entries)
    if (!skip.contains(key) && pattern.allMatches(value).isNotEmpty)
      key: pattern.allMatches(value).length,
};

void main() {
  final sources = _libSources();

  void expectWithin(
    Map<String, int> found,
    Map<String, int> allowed,
    String reason,
  ) {
    final unexpected = {
      for (final MapEntry(:key, :value) in found.entries)
        if (value > (allowed[key] ?? 0)) key: value,
    };
    expect(unexpected, isEmpty, reason: reason);
    // 一覧に残った使われていない所（直したら一覧からも外す）。
    final stale = allowed.keys.where((path) => !found.containsKey(path));
    expect(stale, isEmpty, reason: 'Remove stale entries from the list.');
  }

  test('screens do not use the raw error colour', () {
    expectWithin(
      _count(
        sources,
        RegExp(
          r'\b(?:colorScheme|activeColorScheme|scheme|cs|colors|c)\s*\.\s*'
          r'(?:error|onError|errorContainer|onErrorContainer)\b',
        ),
      ),
      _errorColourAllowed,
      'Use IconNotice.warning / MenuActionLabel(destructive: true) / '
      'warningFilledButtonStyle (SignalColors) instead of colorScheme.error.',
    );
  });

  test('screens do not use raw red, orange or yellow', () {
    expectWithin(
      _count(
        sources,
        RegExp(
          r'\bColors\s*\.\s*(?:red|redAccent|deepOrange|deepOrangeAccent|'
          r'orange|orangeAccent|amber|amberAccent|yellow|yellowAccent|pink|'
          r'pinkAccent)\b',
        ),
      ),
      _rawRedAllowed,
      'Warnings use SignalColors (the theme warning colour), not Colors.red.',
    );
  });

  test('only the theme code reads the update mark and warning colours', () {
    final found = _count(
      sources,
      RegExp(r'\b(?:updateMarkColor|warningColor)\b'),
    );
    expect(
      found.keys.toSet().difference(_rawSignalAllowed),
      isEmpty,
      reason:
          'Use IconNotice.caution / SignalColors.caution for caution and '
          'update marks; base colours for anything else.',
    );
  });

  test('the warning colour is used only where the list says', () {
    expectWithin(
      _count(
        sources,
        RegExp(
          r'\bwarningFilledButtonStyle\s*\(|\bIconNotice\.warning\s*\(|'
          r'\bdestructive:\s*true\b',
        ),
        skip: {'lib/config/signal_colors.dart', 'lib/widgets/icon_notice.dart'},
      ),
      _warningAllowed,
      'The warning colour is only for irreversible actions and failures '
      'that can lose work. Add the place to the list after checking.',
    );
  });

  test('the caution colour is used only where the list says', () {
    expectWithin(
      _count(
        sources,
        RegExp(r'\bIconNotice\.caution\s*\('),
        skip: {'lib/widgets/icon_notice.dart'},
      ),
      _cautionAllowed,
      'The caution colour is only for update marks and notices that need '
      'attention while nothing is lost. Add the place after checking.',
    );
  });

  test('SignalColors is read directly only by the shared widgets', () {
    final found = _count(sources, RegExp(r'\bSignalColors\s*\.\s*of\s*\('));
    expect(found.keys.toSet().difference(_signalAccessAllowed), isEmpty);
  });

  group('IconNotice severities', () {
    const text = Color(0xFF123456);
    const warning = Color(0xFFC0182B);
    const caution = Color(0xFFE09A00);

    Future<void> pump(WidgetTester tester, Widget notice) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(error: Colors.red),
          extensions: const [
            SignalColors(
              warning: warning,
              onWarning: Colors.white,
              caution: caution,
              onCaution: text,
            ),
          ],
        ),
        home: Scaffold(
          body: DefaultTextStyle(
            style: const TextStyle(color: text, fontSize: 14),
            child: notice,
          ),
        ),
      ),
    );

    testWidgets('a plain notice is in the surface text colour', (tester) async {
      await pump(tester, const IconNotice('Could not load the image'));
      expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, text);
      expect(
        tester.widget<Text>(find.text('Could not load the image')).style?.color,
        text,
      );
    });

    testWidgets('a caution notice colours only its mark', (tester) async {
      await pump(tester, const IconNotice.caution('Could not connect'));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
        caution,
      );
      expect(
        tester.widget<Text>(find.text('Could not connect')).style?.color,
        text,
      );
    });

    testWidgets('a warning notice writes the mark and text in the warning '
        'colour', (tester) async {
      await pump(tester, const IconNotice.warning('Could not save'));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
        warning,
      );
      expect(
        tester.widget<Text>(find.text('Could not save')).style?.color,
        warning,
      );
    });
  });

  testWidgets('a destructive menu item is in the warning colour, a move to '
      'the trash is not', (tester) async {
    final service = ThemeService();
    addTearDown(service.dispose);
    service.previewCurrent(AppThemePreset.defaultLight);
    await tester.pumpWidget(
      MaterialApp(
        theme: service.themeData,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(0, 0, 0, 0),
                items: const [
                  PopupMenuItem(
                    value: 'trash',
                    child: MenuActionLabel(
                      icon: Icons.delete_outline,
                      label: 'Move to trash',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: MenuActionLabel(
                      icon: Icons.delete_forever_outlined,
                      label: 'Delete',
                      destructive: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'off',
                    enabled: false,
                    child: MenuActionLabel(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Empty',
                      destructive: true,
                    ),
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final warning = service.themeData.extension<SignalColors>()!.warning;
    final menuInk = service.current.menuTextColor;
    Color? textColour(String label) => DefaultTextStyle.of(
      tester.element(find.text(label)),
    ).style.merge(tester.widget<Text>(find.text(label)).style).color;

    expect(
      tester.widget<Icon>(find.byIcon(Icons.delete_outline)).color,
      menuInk,
    );
    expect(textColour('Move to trash'), menuInk);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.delete_forever_outlined)).color,
      warning,
    );
    expect(textColour('Delete'), warning);
    // 押せない項目は項目の薄さのまま。
    expect(textColour('Empty')!.a, lessThan(0.6));
    expect(textColour('Empty')!.withValues(alpha: 1), warning);
  });
}
