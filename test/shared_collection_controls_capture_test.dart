import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// Capture real Flutter UI, including a received share and a separately
/// exported outgoing .niashare archive with the same favorite/menu controls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('received and outgoing share files have outlined menu/favorite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'quality_level': 'medium',
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('shared-controls-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => tempDir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle() async {
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    final boundaryKey = GlobalKey();
    Future<void> capture(String name) async {
      await settle();
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final out = Directory('build/save-slot-visual-audit')
        ..createSync(recursive: true);
      await tester.runAsync(
        () => File('${out.path}/$name.png').writeAsBytes(bytes!),
      );
    }

    void expectProjectStyleTileActions(String itemId) {
      final favorite = find.byKey(Key('collectionFavorite_$itemId'));
      final menu = find.byKey(Key('collectionMenu_$itemId'));
      expect(favorite, findsOneWidget);
      expect(menu, findsOneWidget);
      final favoriteRect = tester.getRect(favorite);
      final menuRect = tester.getRect(menu);
      final card = find
          .ancestor(of: favorite, matching: find.byType(Card))
          .first;
      final cardRect = tester.getRect(card);
      expect(favoriteRect.left, closeTo(cardRect.left + 4, 2));
      expect(menuRect.right, closeTo(cardRect.right - 4, 2));
      expect(favoriteRect.center.dy, greaterThan(menuRect.center.dy));
      expect(favoriteRect.size, const Size(40, 40));
      expect(menuRect.size, const Size(40, 40));
    }

    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await settle();
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: '共有UI確認用の作品',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFAFAFA,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    final archive = (await tester.runAsync(
      () => ps.createOutgoingShare(project: project),
    ))!;
    final imported = await tester.runAsync(
      () => NiaproSerializer.loadShare(archive.path),
    );
    await tester.runAsync(() => ps.importSharedProject(imported!));
    expect(ps.shared, isNotEmpty);
    expect(ps.outgoingShares, isNotEmpty);

    appRouter.go('/shared');
    await settle();
    // Received shares default to the same small-tile grid as Projects.
    expect(find.byType(SliverGrid), findsWidgets);
    expect(find.byType(CollectionFavoriteButton), findsWidgets);
    expect(find.byType(PopupMenuButton<String>), findsWidgets);
    expectProjectStyleTileActions(ps.shared.first.id);
    await capture('sp_360x760_20_received_share_with_action_buttons');

    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await settle();
    // Outgoing .niashare archives also default to tiled presentation.
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(CollectionFavoriteButton), findsWidgets);
    expect(find.byType(PopupMenuButton<String>), findsWidgets);
    expectProjectStyleTileActions(archive.path);
    await capture('sp_360x760_21_outgoing_share_with_action_buttons');

    final favorite = find.byType(CollectionFavoriteButton).first;
    await tester.tap(favorite);
    await settle();
    expect(ps.isOutgoingShareFavorite(archive.path), isTrue);
    await capture('sp_360x760_22_outgoing_share_favorite_selected');
  }, timeout: const Timeout(Duration(seconds: 150)));
}
