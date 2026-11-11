import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_codec;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/exported_work_thumbnail_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Export covers persist without modifying source file bytes', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('export_cover_test_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final original = File('${temp.path}/animation.png')
      ..writeAsBytesSync([1, 2, 3, 4]);
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
    await ExportedWorkCoverStore.write(
      original, mode: 'none');
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'none');
    expect(await ExportedWorkCoverStore.displayPath(original), isNull);
    expect(await original.readAsBytes(), [1, 2, 3, 4]);
    await ExportedWorkCoverStore.write(
      original, mode: 'latest');
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
    expect(await ExportedWorkCoverStore.displayPath(original), original.path);
    // An external overwrite must not retain an obsolete selected cover.
    original.writeAsBytesSync([1, 2, 3, 4, 5]);
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
  });

  test('Exported raster covers are downscaled, cached and deleted safely',
      () async {
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('cover_cache_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final source = image_codec.Image(width: 1000, height: 600);
    image_codec.fill(source, color: image_codec.ColorRgba8(16, 122, 188, 255));
    final originalBytes = image_codec.encodePng(source);
    final file = File('${temp.path}/original.png');
    await file.writeAsBytes(originalBytes, flush: true);

    final setting = await ExportedWorkCoverStore.ensureCached(file);
    expect(setting['mode'], 'latest');
    expect(setting['frameIndex'], 0);
    final path = setting['imagePath'] as String;
    expect(path, isNot(file.path));
    final cover = File(path);
    expect(await cover.exists(), isTrue);
    final rendered = image_codec.decodeImage(await cover.readAsBytes())!;
    expect(rendered.width, lessThanOrEqualTo(420));
    expect(rendered.height, lessThanOrEqualTo(420));
    expect(await file.readAsBytes(), originalBytes);
    await ExportedWorkCoverStore.write(file, mode: 'none');
    expect(await cover.exists(), isFalse);
    expect(await file.readAsBytes(), originalBytes);
  });

  testWidgets('Exported card exposes a three-dot thumbnail action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body:
      ExportedWorkCard(
        name: 'movie.mp4',
        metadata: '2026/11/11',
        icon: Icons.movie,
        moveLabel: '移動',
        shareLabel: '共有',
        deleteLabel: '削除',
        onOpen: () {},
        onMove: () {},
        onShare: () {},
        onDelete: () {},
        onChangeThumbnail: () {},
      ),
    )));
    final menu = find.byKey(const Key('exportedWorkMoreMenu'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('サムネイル変更'), findsOneWidget);
    expect(find.text('移動'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'exported cover fills card height while name and metadata stay to its right',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final width in [280.0, 320.0, 390.0, 768.0]) {
        for (final textScale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 900);
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          await tester.pumpWidget(MaterialApp(
            locale: const Locale('ja'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ExportedWorkCard(
                name: 'a_very_long_exported_animation_filename_episode_01.mp4',
                metadata: '2026/11/11 18:00 ・ 123.5 MB',
                icon: Icons.movie_outlined,
                moveLabel: '移動',
                shareLabel: '共有',
                deleteLabel: '削除',
                thumbnailHidden: true,
                onOpen: () {},
                onMove: () {},
                onCopy: () {},
                onShare: () {},
                onDelete: () {},
                onChangeThumbnail: () {},
              ),
            ),
          ));
          await tester.pumpAndSettle();
          final scope = 'width=$width textScale=$textScale';
          final card = find.descendant(
            of: find.byType(ExportedWorkCard),
            matching: find.byType(InkWell),
          ).first;
          final content = tester.getRect(card);
          final thumb = tester.getRect(
            find.byKey(const Key('exportedWorkThumbnailArea')),
          );
          final title = tester.getRect(
            find.byKey(const Key('exportedWorkTitle')),
          );
          final metadata = tester.getRect(
            find.byKey(const Key('exportedWorkMetadata')),
          );
          expect(thumb.top, closeTo(content.top, 0.5), reason: scope);
          expect(thumb.bottom, closeTo(content.bottom, 0.5),
              reason: scope);
          expect(title.left, greaterThan(thumb.right), reason: scope);
          expect(metadata.left, greaterThan(thumb.right), reason: scope);
          for (final key in [
            'exportedWorkMoreMenu',
          ]) {
            final rect = tester.getRect(find.byKey(Key(key)));
            expect(rect.left, greaterThanOrEqualTo(thumb.right),
                reason: '$scope $key');
            expect(rect.right, lessThanOrEqualTo(content.right + 0.5),
                reason: '$scope $key');
            expect(rect.bottom, lessThanOrEqualTo(content.bottom + 0.5),
                reason: '$scope $key');
          }
          expect(tester.takeException(), isNull, reason: scope);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets('exported work grid exposes only the unified three-dot menu',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SizedBox(
        width: 240, height: 230,
        child: ExportedWorkCard(
          gridTile: true,
          name: 'long_movie_name.mp4',
          metadata: '2026/11/11 ・ 2.0 MB',
          icon: Icons.movie,
          moveLabel: '移動',
          shareLabel: '共有',
          deleteLabel: '削除',
          onOpen: () {},
          onMove: () {},
          onCopy: () {},
          onShare: () {},
          onDelete: () {},
          onChangeThumbnail: () {},
        ),
      )),
    ));
    expect(find.byKey(const Key('exportedWorkMoreMenu')), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsNothing);
    await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
    await tester.pumpAndSettle();
    for (final name in ['開く', 'コピー', '移動', '共有',
                        'サムネイル変更', '削除']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(tester.takeException(), isNull);
  });

}
