import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/widgets/ad_banner_mock_widget.dart';

import 'helpers/load_app_fonts.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/google_auth_service.dart';

void main() {
  testWidgets('作品詳細にNIARIM制作情報が表示される', (tester) async {
    final service = CommunityService();
    final work = service.works.first;
    service.applyServerWork(
      work.copyWith(containsGenerativeAiImageOrVideo: true),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: service),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => GoogleAuthService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityWorkDetailScreen(workId: work.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('${work.projectFrameCount}f'), findsOneWidget);
    expect(find.byKey(const Key('communityDetailSeekBar')), findsOneWidget);
    expect(find.byKey(const Key('communityDetailFrameCounter')), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.text('${work.projectFps}fps'), findsOneWidget);
    expect(
      find.text('${work.projectCanvasWidth}×${work.projectCanvasHeight}'),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CommunityWorkDetailScreen)),
    )!;
    final workTime = find.text(
      formatProjectWorkTime(l10n, work.projectWorkSeconds),
    );
    final aiLabel = find
        .text(l10n.communityContainsGenerativeAiImageVideo)
        .first;
    expect(workTime, findsOneWidget);
    expect(
      tester.getTopLeft(aiLabel).dx,
      greaterThan(tester.getTopRight(workTime).dx),
    );
    expect(
      tester.getCenter(aiLabel).dy,
      closeTo(tester.getCenter(workTime).dy, 1),
    );
  });

  testWidgets('tag edit and delete require explicit actions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    final work = service.works.firstWhere(
      (work) => work.tags.any((tag) => !work.lockedTags.contains(tag)),
    );
    service.setCurrentUserId('viewer-for-detail-test');
    final original = work.tags.firstWhere(
      (tag) => !work.lockedTags.contains(tag),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: service),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => GoogleAuthService()),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityWorkDetailScreen(workId: work.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(CommunityWorkDetailScreen)),
    )!;
    final originalChip = find.byKey(ValueKey('communityDetailTag-$original'));
    expect(
      find.descendant(
        of: originalChip,
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip(l.communityRemoveTagTooltip), findsNothing);
    await tester.ensureVisible(originalChip);
    await tester.tap(originalChip);
    await tester.pumpAndSettle();
    expect(find.text(l.communityTagLockAction), findsNothing);
    await tester.tap(find.text(l.commonDelete));
    await tester.pumpAndSettle();
    expect(find.text(l.communityTagDeleteConfirm), findsOneWidget);
    await tester.tap(find.text(l.commonCancel));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.tags, contains(original));

    await tester.tap(originalChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.commonEdit));
    await tester.pumpAndSettle();
    final editor = find.byKey(const Key('communityDetailTagEditor'));
    expect(tester.widget<TextField>(editor).controller!.text, original);
    await tester.enterText(editor, '回帰テスト用のタグ');
    await tester.tap(find.text(l.commonApply));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.tags, contains('回帰テスト用のタグ'));
    expect(service.byId(work.id)!.tags, isNot(contains(original)));
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('横画面と縦画面の詳細操作が選んだ作品の本番ルートへ遷移する', (tester) async {
    SharedPreferences.setMockInitialValues({
      'is_premium': true,
      'first_launch': false,
    });
    final temp = Directory.systemTemp.createTempSync('niarim_detail_routes_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    appRouter.go('/community');
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(CommunityScreen));
    final community = context.read<CommunityService>();
    final work = community.discoverableWorks.first;
    final preview = context.read<CommunityPreviewService>();
    preview.show(work);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityPreviewDetails')));
    await tester.pumpAndSettle();
    expect(preview.work, isNull);
    expect(
      GoRouterState.of(
        tester.element(find.byType(CommunityWorkDetailScreen)),
      ).uri.path,
      '/community/work/${work.id}',
    );
    expect(
      tester
          .widget<CommunityWorkDetailScreen>(
            find.byType(CommunityWorkDetailScreen),
          )
          .workId,
      work.id,
    );
    expect(tester.takeException(), isNull);

    appRouter.go('/community');
    await tester.pumpAndSettle();
    final communityContext = tester.element(find.byType(CommunityScreen));
    Navigator.of(communityContext).push(
      adMockMaterialPageRoute(
        builder: (_) => CommunityShortsScreen(
          works: [work],
          bookmarkedIds: const {},
          onToggleBookmark: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
    expect(
      GoRouterState.of(
        tester.element(find.byType(CommunityWorkDetailScreen)),
      ).uri.path,
      '/community/work/${work.id}',
    );
    expect(
      tester
          .widget<CommunityWorkDetailScreen>(
            find.byType(CommunityWorkDetailScreen),
          )
          .workId,
      work.id,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('縦画面の作品情報UIは動画領域の後ろにある別Material領域', () {
    final source = File(
      'lib/screens/community/widgets/community_shorts_viewer.dart',
    ).readAsStringSync();
    // The YouTube player is now implemented. Protect the real production
    // widget boundary instead of requiring a deleted placeholder comment.
    final videoMarker = source.indexOf('child: CommunityYoutubePlayer(');
    final outsideMarker = source.indexOf('// 作者・タグ・制作情報・詳細導線はすべて動画領域の外。');
    final infoIcon = source.indexOf(
      'Icons.info_outline_rounded',
      outsideMarker,
    );

    expect(
      videoMarker,
      greaterThanOrEqualTo(0),
      reason: 'A production YouTube player must own the video surface',
    );
    expect(
      outsideMarker,
      greaterThan(videoMarker),
      reason: 'The information panel must come after the video surface',
    );
    expect(
      infoIcon,
      greaterThan(outsideMarker),
      reason: 'Details must remain outside the YouTube player',
    );
  });
}
