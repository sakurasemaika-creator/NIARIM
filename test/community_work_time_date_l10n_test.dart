// 作品広場の制作時間と日付を、表示言語の書き方で出すことを見張る（DISC134）。
//
// 以前は制作時間が全言語「6h 40m」、日付が全言語「2026/10/13」（yyyy/MM/dd）で、
// 作品広場の作品の詳細とテーマの見本一覧の模型に出ていた。
//
// 制作時間はプロジェクト詳細と同じ文（newProjectDurationHm・H・M）で書き、
// 同じ時間はどの画面でも同じに読める（英語で「6h 40m」と「6 hr 40 min」、
// 中国語で「6小时40分」と「6小时40分钟」が隣の画面に並んでいた）。ちょうどの
// 時間は「1時間0分」と書かず「1時間」。日付は作品の詳細の中のYouTubeの
// コメント・通知の一覧・プロジェクト詳細の最終保存も同じ書き方（yMd・jm）で、
// 見本一覧の模型は本物の画面と同じ文を出す。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/community/community_follow_notifications_screen.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/screens/community/widgets/community_youtube_comments_section.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_milestone_store.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// その言語の制作時間の書き方（プロジェクト詳細・新規作成の長さと同じ文）。
/// ちょうどの時間は分を書かない。
String _workTime(AppLocalizations l, int hours, int minutes) {
  if (hours == 0) return l.newProjectDurationM(minutes);
  if (minutes == 0) return l.newProjectDurationH(hours);
  return l.newProjectDurationHm(hours, minutes);
}

/// 語結合子・改行しない空白を除いた文（画面の文と比べるため）。
String _plain(String? text) => (text ?? '')
    .replaceAll('\u2060', '')
    .replaceAll('\u00A0', ' ')
    .replaceAll('\u202F', ' ');

/// 画面に出ている文（読み上げの文も含む）。
Set<String> _shownTexts(WidgetTester tester) => {
  for (final text in tester.widgetList<Text>(find.bySubtype<Text>())) ...[
    _plain(text.data),
    _plain(text.semanticsLabel),
  ],
};

String _tag(Locale l) =>
    l.scriptCode == null ? l.languageCode : '${l.languageCode}_${l.scriptCode}';

void main() {
  testWidgets('作品の詳細の制作情報：制作時間と作った日は表示言語の書き方', (tester) async {
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = _tag(locale);
      final service = CommunityService();
      final work = service.works.firstWhere(
        (w) => w.projectWorkSeconds >= 3600 && w.projectCreatedAt != null,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: service),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => GoogleAuthService()),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CommunityWorkDetailScreen(workId: work.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(locale);
      final hours = work.projectWorkSeconds ~/ 3600;
      final minutes = (work.projectWorkSeconds % 3600) ~/ 60;
      final time = _workTime(l, hours, minutes);
      if (find.text(time).evaluate().isEmpty) {
        problems.add('$tag: 制作時間「$time」が出ていない');
      }
      final created = DateFormat.yMd(
        l.localeName,
      ).format(work.projectCreatedAt!);
      if (find.text(created).evaluate().isNotEmpty) {
        problems.add('$tag: 制作情報の行に日付が残っている');
      }
      final posted = l.communityWorkDetailPostedLabel(
        DateFormat.yMd(l.localeName).add_Hm().format(work.postedAt.toLocal()),
      );
      if (find.text(posted).evaluate().isEmpty) {
        problems.add('$tag: 「$posted」が出ていない');
      }
      await tester.pumpWidget(const SizedBox());
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('見本一覧の作品の詳細の模型も、制作時間と日付を表示言語の書き方で出す', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = _tag(locale);
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: theme,
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: theme.themeData,
            home: const ThemePreviewGalleryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pager = tester.widget<PageView>(
        find.byKey(const Key('themePreviewPager')),
      );
      pager.controller!.jumpToPage(
        themePreviewEntries.indexWhere((e) => e.id == 'work'),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(locale);
      for (final expected in [
        formatProjectWorkTime(l, 6 * 3600 + 40 * 60),
        _workTime(l, 6, 40),
        DateFormat.yMd(l.localeName).format(DateTime(2026, 10, 13)),
        l.communityWorkDetailPostedLabel(
          DateFormat.yMd(l.localeName).format(DateTime(2026, 10, 14)),
        ),
      ]) {
        if (find.text(expected).evaluate().isEmpty) {
          problems.add('$tag: 「$expected」が出ていない');
        }
      }
      // 見本一覧のプロジェクト詳細・通知の模型も、本物の画面と同じ書き方。
      for (final (page, expected) in [
        ('detail', _workTime(l, 1, 25)),
        (
          'detail',
          DateFormat.yMd(
            l.localeName,
          ).add_jm().format(DateTime(2026, 10, 23, 10)),
        ),
        (
          'notifications',
          DateFormat.yMd(l.localeName).format(DateTime(2026, 10, 23)),
        ),
      ]) {
        pager.controller!.jumpToPage(
          themePreviewEntries.indexWhere((e) => e.id == page),
        );
        await tester.pumpAndSettle();
        if (!_shownTexts(tester).contains(_plain(expected))) {
          problems.add('$tag $page の模型：「$expected」が出ていない');
        }
      }
      theme.dispose();
      await tester.pumpWidget(const SizedBox());
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('制作時間：ちょうどの時間は分を書かず、1分未満は1分（どの言語も）', () {
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = _tag(locale);
      final l = lookupAppLocalizations(locale);
      for (final (seconds, expected) in [
        (3600, l.newProjectDurationH(1)),
        (3659, l.newProjectDurationH(1)),
        (7200, l.newProjectDurationH(2)),
        (6 * 3600 + 40 * 60, l.newProjectDurationHm(6, 40)),
        (59, l.newProjectDurationM(1)),
        (40 * 60, l.newProjectDurationM(40)),
        (0, ''),
      ]) {
        final shown = formatProjectWorkTime(l, seconds);
        if (shown != expected) {
          problems.add('$tag $seconds秒：「$shown」（期待「$expected」）');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('プロジェクト詳細の制作時間と最終保存も、作品広場と同じ書き方', (tester) async {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = _tag(locale);
      final dir = Directory.systemTemp.createTempSync('niarim_detail_date_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => dir.path);
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': tag,
      });
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(providers: providers, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final service = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>();
      final project = (await tester.runAsync(
        () => service.createProject(
          name: 'p',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 32,
          exportHeight: 32,
        ),
      ))!;
      appRouter.push('/project/${project.id}');
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      final l = lookupAppLocalizations(locale);
      final shown = _shownTexts(tester);
      final saved = service.projects
          .firstWhere((p) => p.id == project.id)
          .updatedAt;
      for (final expected in [
        _workTime(l, 0, 0),
        DateFormat.yMd(l.localeName).add_jm().format(saved),
      ]) {
        if (!shown.contains(_plain(expected))) {
          problems.add('$tag：「$expected」が出ていない');
        }
      }
      appRouter.go('/home');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('作品の詳細の中のYouTubeのコメントの日付も、投稿日と同じ書き方', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'comments': [
                  {
                    'author': 'viewer',
                    'text': 'nice',
                    'publishedAt': '2026-10-04T12:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          maxGetRetries: 0,
        ),
      ),
    );
    addTearDown(service.dispose);
    final published = DateTime.parse('2026-10-04T12:00:00Z').toLocal();
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = _tag(locale);
      await tester.pumpWidget(
        ChangeNotifierProvider<CommunityService>.value(
          value: service,
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityYoutubeCommentsSection(
                  workId: 'w$tag',
                  onOpenYouTube: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('communityYoutubeCommentsExpansion')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(locale);
      final expected = DateFormat.yMd(l.localeName).format(published);
      if (!_shownTexts(tester).contains(_plain(expected))) {
        problems.add(
          '$tag：コメントの日付「$expected」が出ていない '
          '${_shownTexts(tester).where((t) => t.contains('2026')).toList()}',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('YouTube comments reveal a single batch before opening YouTube', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    var opens = 0;
    final service = CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) async {
            requests++;
            expect(request.url.queryParameters, {'limit': '100'});
            return http.Response(
              jsonEncode({
                'comments': [
                  for (var i = 1; i <= 100; i++) {'text': 'Comment $i'},
                ],
                'nextCursor': 'next-page',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          maxGetRetries: 0,
        ),
      ),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityYoutubeCommentsSection(
                workId: 'abcdefghijk',
                onOpenYouTube: () => opens++,
              ),
            ),
          ),
        ),
      ),
    );

    const more = Key('communityYoutubeCommentsLoadMore');
    const youtube = Key('communityYoutubeCommentsOpenYouTube');
    expect(requests, 0);
    await tester.tap(
      find.byKey(const Key('communityYoutubeCommentsExpansion')),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);
    for (var count = 20; count <= 100; count += 20) {
      expect(find.byType(SelectableText), findsNWidgets(count));
      if (count == 100) break;
      final button = find.byKey(more);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(requests, 1);
    }
    expect(find.byKey(more), findsNothing);
    final link = find.byKey(youtube);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    expect(opens, 1);
    expect(requests, 1);
  });

  testWidgets('作品広場の通知の一覧の日付も、表示言語の書き方', (tester) async {
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = _tag(locale);
      SharedPreferences.setMockInitialValues({});
      final service = CommunityService();
      final store = CommunityMilestoneStore();
      await tester.runAsync(() async {
        await store.observe(kDummySelfAuthorId, followers: 9);
        await store.observe(kDummySelfAuthorId, followers: 10);
        await service.loadMilestones();
      });
      final event = service.milestoneNotifications.single;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: service),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => GoogleAuthService()),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const CommunityFollowNotificationsScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(locale);
      final expected = DateFormat.yMd(
        l.localeName,
      ).add_jm().format(event.createdAt);
      if (!_shownTexts(tester).contains(_plain(expected))) {
        problems.add('$tag：通知の日付「$expected」が出ていない');
      }
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('作品広場・プロジェクト詳細で、日付を「年/月/日」と手で組み立てない', () {
    final offenders = <String>[];
    final files = [
      ...Directory('lib/screens/community')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      File('lib/screens/project/project_detail_screen.dart'),
      File('lib/screens/settings/theme_preview_gallery_screen.dart'),
    ];
    final handBuilt = RegExp(r"year\}/|'\d{4}/\d{1,2}/");
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (handBuilt.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
