// 訳の読みやすさのレビューで見つかった、言語ごとの言い回しの見張り。
//
// - 同じ画面に並ぶ別の操作が同じ文になっていた（フランス語のサムネイルの
//   ダイアログで「フレームを指定する」と「画像を選択」がどちらも
//   « Choisir une image »、中国語のホームで「コピー」と「複製」がどちらも
//   「复制」「複製」）。
// - 同じものを同じ言語の中で別の言葉で呼んでいた（簡体字の「非公開」が
//   「私享」「私密」「视频不公开」の3通り、繁体字の共有ファイルが
//   「分享檔案」と「共享檔案」）。
// - 数と単位の間に普通の空白があり、行の途中で「秒」だけが次の行へ落ちうる。
// - 読み違えやすい・文法の崩れた言い回し（下の表、理由つき）。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_thumbnail_dialog.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _locales = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

Map<String, String> _values(String locale) {
  final data =
      json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

/// 同じ画面に同時に出て、別々の操作・意味を持つ文（どの言語でも違う文にする）。
const _shownTogether = <String, List<String>>{
  'サムネイルのダイアログの選択肢とボタン': [
    'thumbnailLastSavedFrame',
    'thumbnailSelectFrame',
    'thumbnailChooseDeviceImage',
    'thumbnailHide',
    'thumbnailPickImage',
  ],
  // ホームのゴミ箱の「コピー」と共有のメニューの「複製」、タイムラインの
  // シーンのメニューの「複製」と「コピー」。素材の「複製」のボタン
  // （commonDuplicate）も同じ操作の名前。
  '「コピー」と「複製」': ['commonCopy', 'themeDuplicateAction'],
  '「コピー」と素材の「複製」': ['commonCopy', 'commonDuplicate'],
};

/// 言語 → キー → 出てはいけない言い回しと理由。
const _forbidden = <String, Map<String, Map<String, String>>>{
  'fr': {
    'thumbnailStillImageOneFrame': {
      'ne compte qu’une seule image': '« image » が静止画とフレームの2つの意味で並ぶ',
    },
    'communityRecentlyUnfollowedHeader': {
      'Plus suivis': '冠詞が無く「最もフォローされた」とも読める',
    },
    'pcLayoutAutoFoldHelp': {
      'Seulement si': '文頭の条件が主語とつながらない',
      'Désactivé, la colonne': '「Désactivé」が「la colonne」にかかって読める',
    },
    'communityPostScheduleTooSoon': {'plus tard': '何から後かが無い（現在時刻から）'},
  },
  'es': {
    'communityUnfollowedLabel': {' lo ': '相手を男性と決めつける代名詞'},
    'communityRecentlyUnfollowedHeader': {
      'Dejaste de seguir recientemente': '見出しなのに主語の無い節の途中',
    },
    'communityPostScheduleTooSoon': {'después de ahora': '直訳の言い回し'},
  },
  'en': {
    'pcLayoutAutoFoldHelp': {
      'Only when windows still don’t fit after being shortened, the':
          '文頭の「Only when」の後に倒置が無い',
    },
    'communityPostScheduleAt': {'Publishes:': 'ラベルとして不自然'},
  },
  'zh_Hant': {
    'homePasteRestrictionTitle': {'貼上到': '簡体字の「粘贴到」の直訳（このARBは「貼到」）'},
    'homePasteCrossFormatBody': {'貼上到': '簡体字の「粘贴到」の直訳（このARBは「貼到」）'},
  },
};

/// コピー・切り取りをやめて帯を閉じるボタン（homeClipboardClear）に使わない語
/// （切り取った項目を消すように読める）。
const _clipboardClearErase = <String, List<String>>{
  'es': ['Borrar', 'Eliminar'],
  'fr': ['Effacer', 'Supprimer'],
  'ko': ['지우기', '삭제'],
};

void main() {
  final values = {for (final locale in _locales) locale: _values(locale)};

  test('同じ画面に並ぶ別の操作は、どの言語でも違う文で出す', () {
    final offenders = <String>[];
    for (final MapEntry(key: where, value: keys) in _shownTogether.entries) {
      for (final locale in _locales) {
        final seen = <String, String>{};
        for (final key in keys) {
          final text = values[locale]![key]!;
          final previous = seen[text];
          if (previous != null) {
            offenders.add('$locale $where: $previous と $key が「$text」');
          }
          seen[text] = key;
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('読み違えやすい・崩れた言い回しが残っていない', () {
    final offenders = [
      for (final MapEntry(key: locale, value: byKey) in _forbidden.entries)
        for (final MapEntry(key: key, value: phrases) in byKey.entries)
          for (final MapEntry(key: phrase, value: why) in phrases.entries)
            if (values[locale]![key]!.contains(phrase))
              '$locale $key:「$phrase」($why)',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('コピー・切り取りの帯の「クリア」を、消す意味の語にしない', () {
    final offenders = [
      for (final MapEntry(key: locale, value: words)
          in _clipboardClearErase.entries)
        if (words.contains(values[locale]!['homeClipboardClear']))
          '$locale: ${values[locale]!['homeClipboardClear']}',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('簡体字の作品広場は、YouTubeの「非公開」をいつも同じ語（私享）で呼ぶ', () {
    final zh = values['zh']!;
    final private = zh['communityPostVisibilityPrivateTitle']!;
    final offenders = [
      for (final MapEntry(:key, :value) in zh.entries)
        if (key.startsWith('community') &&
            (value.contains('私密') || value.contains('视频不公开')))
          '$key: $value',
    ];
    expect(
      offenders,
      isEmpty,
      reason: '「$private」へそろえる:\n${offenders.join('\n')}',
    );
    expect(zh['communityPlaybackPrivateTitle'], contains(private));
    expect(zh['communityPlaybackUnavailableBody'], contains(private));
  });

  test('繁体字は共有ファイル（.niashare）をいつも「共享檔案」と呼ぶ', () {
    final offenders = [
      for (final MapEntry(:key, :value) in values['zh_Hant']!.entries)
        if (value.contains('分享檔案')) '$key: $value',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('中国語は数と「秒」の間に空白を入れない（行の途中で単位だけ次の行へ落ちる）', () {
    final spaced = RegExp(r'\} 秒');
    final offenders = [
      for (final locale in const ['zh', 'zh_Hant'])
        for (final MapEntry(:key, :value) in values[locale]!.entries)
          if (spaced.hasMatch(value)) '$locale $key: $value',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('ホームのコピー・切り取り・ゴミ箱の件数は単数・複数で書き分ける（item(s)にしない）', () {
    // 新しいコピー・切り取りの帯は「1 item copied」と書き分けているのに、
    // すぐ下の知らせは「Copied 1 item(s)」だった。
    final offenders = <String>[];
    for (final language in const ['en', 'es', 'fr']) {
      final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
      for (final count in const [1, 2]) {
        for (final text in [
          l10n.homeCopiedSnackbar(count),
          l10n.homeCutSnackbar(count),
          l10n.homeMoveToTrashConfirm(count),
          l10n.homeMovedToTrashSnackbar(count),
        ]) {
          if (text.contains('(s)')) offenders.add('$language $count: $text');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.homeCopiedSnackbar(1), startsWith('Copied 1 item. '));
    expect(en.homeCopiedSnackbar(3), startsWith('Copied 3 items. '));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.homeMovedToTrashSnackbar(1), '1 élément mis à la corbeille');
    expect(fr.homeMovedToTrashSnackbar(2), '2 éléments mis à la corbeille');
  });

  group('書き出した作品のサムネイルのダイアログ', () {
    late Directory dir;
    late File work;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('thumb-wording-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
      work = File('${dir.path}/still.png');
    });

    tearDown(() {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    for (final language in _locales) {
      testWidgets('$language: 同時に出る文がすべて違う', (tester) async {
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(
            const Rect.fromLTWH(0, 0, 8, 8),
            Paint()..color = const Color(0xFF3366CC),
          );
          final image = await recorder.endRecording().toImage(8, 8);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await work.writeAsBytes(png!.buffer.asUint8List(), flush: true);
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 1400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: localeFromLanguageCode(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showExportedWorkThumbnailDialog(context, file: work),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }

        List<String> shown() => [
          for (final widget in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          ))
            if ((widget.data ?? '').isNotEmpty) widget.data!,
        ];

        for (final mode in const ['exportCoverCustom', 'exportCoverFrame']) {
          await tester.tap(find.byKey(Key(mode)));
          await tester.pump(const Duration(milliseconds: 300));
          final texts = shown();
          final duplicated = [
            for (final text in texts.toSet())
              if (texts.where((t) => t == text).length > 1) text,
          ];
          expect(duplicated, isEmpty, reason: '$language $mode: $texts');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
