import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['NIARIM_FIVE_FIXES_CAPTURE'];
  if (directory == null) return;

  Future<void> capture(
    GlobalKey root,
    String filename,
    WidgetTester tester,
  ) async {
    expect(tester.takeException(), isNull, reason: filename);
    await tester.runAsync(() async {
      final render =
          root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory(directory).createSync(recursive: true);
      File(
        '$directory/$filename.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  CommunityWork example(String id) => CommunityWork(
    id: id,
    title: '秋の風景を描いてみた',
    authorId: 'artist-01',
    authorName: '手描きアニメ作家',
    viewCount: 12847,
    likeCount: 30,
    bookmarkCount: 348,
    postedAt: DateTime.utc(2026, 10, 29),
    durationSeconds: 87,
    thumbnailColorIndex: 3,
  );

  for (final (status, file) in <(CommunityPlaybackStatus, String)>[
    (CommunityPlaybackStatus.deleted, '16_deleted_video_preview'),
    (CommunityPlaybackStatus.private, '17_private_video_preview'),
    (CommunityPlaybackStatus.unavailable, '18_unavailable_video_preview'),
    (CommunityPlaybackStatus.unknown, '19_playback_check_failed'),
  ]) {
    testWidgets('real Flutter playback state: ${status.name}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themes = ThemeService();
      await themes.init();
      addTearDown(themes.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final work = example('work-${status.name}');
      final httpClient = MockClient(
        (request) async => http.Response(
          jsonEncode({'status': status.name}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final apiClient = NiarimApiClient(
        baseUrl: 'https://mock.invalid',
        httpClient: httpClient,
      );
      final community = CommunityService(api: CommunityApi(apiClient));
      final preview = CommunityPreviewService();
      addTearDown(community.dispose);
      addTearDown(preview.dispose);
      addTearDown(apiClient.close);
      preview.show(work);
      final root = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: community),
              ChangeNotifierProvider.value(value: preview),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: themes.themeData,
              home: Scaffold(
                appBar: AppBar(title: const Text('作品広場')),
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    CommunityWorkGrid(
                      works: [work],
                      bookmarkedIds: const {},
                      onTapWork: (_) {},
                      onToggleBookmark: (_) {},
                    ),
                    const CommunityFloatingPreview(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Work statuses come from the real CommunityApi -> CommunityService
      // asynchronous preflight, not a screenshot-only substitution.
      expect(
        find.byKey(const Key('communityPlaybackStatusPanel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('communityPlaybackStatusTitle')),
        findsOneWidget,
      );
      await capture(root, file, tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('real Flutter card after control relocation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final community = CommunityService();
    addTearDown(community.dispose);
    final root = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: root,
        child: ChangeNotifierProvider.value(
          value: community,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: themes.themeData,
            home: Scaffold(
              appBar: AppBar(title: const Text('作品広場')),
              body: CommunityWorkGrid(
                works: [
                  example('fresh-01'),
                  example('fresh-02'),
                  example('fresh-03'),
                  example('fresh-04'),
                ],
                bookmarkedIds: const {'fresh-02'},
                rankNumbers: const {'fresh-01': 1, 'fresh-02': 2},
                onTapWork: (_) {},
                onToggleBookmark: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('community-bookmark-fresh-01')),
      findsOneWidget,
    );
    await capture(root, '20_updated_plaza_card_layout', tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
