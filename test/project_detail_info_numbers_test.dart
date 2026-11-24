// プロジェクト詳細の「プロジェクト情報」のカードの値（解像度・描画領域・
// フレーム数・制作時間・最終保存・容量）を、数の途中で折り返さないことを
// 見張る（同梱の書体・本物のアプリ）。
//
// 項目名と値を幅の半分ずつの列に並べていたので、中国語の本文を字の広い
// Noto Serif SCで描くと（DISC132）、320px・360px×文字2倍で「1280×7 / 20」
// 「2026/11/ / 10 19:29」のように数の途中で切れた（白光明朝の数字は細く、
// 基準では「1280×720」は1行に入り、日付は日付と時刻の間で折れていた）。
// 値の数のかたまり（解像度「W×H」・数と単位・大きさ・日付・時刻）は途中で
// 折らず、日付と時刻の間・かたまりの間でだけ折る。項目名も語の途中で折らない。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/widgets/grouped_sheet.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/number_split_problems.dart';
import 'helpers/text_fit_problems.dart';

String _tag(Locale l) =>
    l.scriptCode == null ? l.languageCode : '${l.languageCode}_${l.scriptCode}';

/// 保存した作品の最終保存の日時と制作時間を書き換える（数の桁が多い日付・
/// 午後の時刻・時と分の両方がある制作時間にする）。
void _rewriteManifest(
  String path, {
  required DateTime updatedAt,
  required int workSeconds,
}) {
  final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  final out = Archive();
  for (final entry in archive.files) {
    if (entry.name == 'manifest.json') {
      final json =
          jsonDecode(utf8.decode(entry.content as List<int>))
              as Map<String, dynamic>;
      json['updatedAt'] = updatedAt.toIso8601String();
      json['totalWorkSeconds'] = workSeconds;
      out.addFile(
        ArchiveFile('manifest.json', 0, utf8.encode(jsonEncode(json))),
      );
    } else {
      out.addFile(entry);
    }
  }
  File(path).writeAsBytesSync(ZipEncoder().encode(out)!);
}

void main() {
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('7言語×320/360px×文字1.0/1.3/2.0で、プロジェクト情報の値の数'
      '（解像度・フレーム数・制作時間・日付・時刻・容量）を途中で折らない', (tester) async {
    await loadAppFonts(tester);
    final saved = DateTime(2026, 11, 10, 19, 29);
    final problems = <String>[];
    var rowsSeen = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = _tag(locale);
      final l = lookupAppLocalizations(locale);
      final dir = Directory.systemTemp.createTempSync('niarim_info_numbers_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => dir.path);
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': tag,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      // 作品を作って保存し、最終保存の日時と制作時間を書き換えてから
      // 読み込み直す。
      final first = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(providers: first, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final service = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>();
      final id = (await tester.runAsync(() async {
        final project = await service.createProject(
          name: 'Juliet',
          fps: 24,
          durationSeconds: 5,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 1280,
          exportHeight: 720,
          drawingAreaScale: 2.0,
        );
        await service.saveProject(project.id);
        return project.id;
      }))!;
      appRouter.go('/home');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () async => _rewriteManifest(
          '${dir.path}/niarim/projects/$id/$id.niapro',
          updatedAt: saved,
          workSeconds: 5100,
        ),
      );
      final providers = (await tester.runAsync(buildAppProviders))!;
      final dates = [
        DateFormat.yMd(l.localeName).format(saved),
        DateFormat.jm(l.localeName).format(saved),
      ];

      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          final where = '$tag ${width.round()}px ×$scale';
          tester.view.physicalSize = Size(width, 760);
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString().split('\n').first);
          final seen = <String>{};
          try {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 760),
                  textScaler: TextScaler.linear(scale),
                ),
                child: MultiProvider(
                  providers: providers,
                  child: const NiarimApp(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            appRouter.go('/project/$id');
            for (var i = 0; i < 6; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 40)),
              );
              await tester.pump(const Duration(milliseconds: 100));
            }
            // 作品の情報は1枚の面（GroupedSheet）に並ぶ。
            final card = find.ancestor(
              of: find.text(l.projectDetailInfoExportSize),
              matching: find.byType(GroupedSheet),
            );
            final list = find
                .ancestor(of: card, matching: find.byType(Scrollable))
                .first;
            await tester.scrollUntilVisible(
              find.text(l.projectDetailInfoSize),
              120,
              scrollable: list,
            );
            await tester.pump();
            final paragraphs = tester
                .renderObjectList<RenderParagraph>(
                  find.descendant(of: card, matching: find.byType(RichText)),
                )
                .toList();
            rowsSeen += paragraphs.length;
            for (final p in paragraphs) {
              for (final problem in [
                ...numberSplitProblems(p, extra: dates),
                ...textFitProblems(p),
              ]) {
                final line =
                    '$where: «${p.text.toPlainText().replaceAll('\u2060', '')}» '
                    '$problem';
                if (seen.add(line)) problems.add(line);
              }
            }
          } finally {
            FlutterError.onError = previous;
          }
          for (final e in errors.toSet()) {
            problems.add('$where: $e');
          }
        }
      }
      appRouter.go('/home');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
    // 7言語×2幅×3倍率×（項目名と値の7行）を見ていること。
    expect(rowsSeen, greaterThanOrEqualTo(7 * 6 * 14));
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
