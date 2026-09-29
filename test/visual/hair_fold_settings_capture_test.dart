import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush_presets_extension.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/canvas/widgets/brush_tip_settings.dart';
import 'package:niarim/screens/canvas/widgets/brush_extension_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NotoSerifJP')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifJP.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('capture the production fold settings and five-mode menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final brush = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0023',
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            fontFamily: 'NotoSerifJP',
            colorSchemeSeed: const Color(0xff7459b8),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('ブラシカスタム')),
            body: SingleChildScrollView(
              child: Builder(
                builder: (context) => BrushExtensionSettings(
                  brush: brush,
                  onChanged: (_) {},
                  labels: BrushExtensionLabels.fromLocalizations(
                    AppLocalizations.of(context)!,
                  ),
                  onPickOutlineColor: null,
                  onEyedropOutlineColor: null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> save(String name) async {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/hair_fold_visual/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await save('fold_settings_ja');
    await tester.ensureVisible(find.byKey(const Key('brush-fold-mode')));
    await tester.tap(find.byKey(const Key('brush-fold-mode')));
    await tester.pumpAndSettle();
    expect(find.text('三日月カール'), findsOneWidget);
    await save('fold_menu_ja');
    expect(tester.takeException(), isNull);
  });
  testWidgets('capture shared tip and image controls for custom brushes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = brushExtensionPresets().first;
    final images = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0024',
    );
    for (final entry in {
      'tip_settings_chain_ja': base.copyWith(
        id: 'custom-chain',
        tipShape: BrushTipShape.chainLink,
        tipSpacingFactor: .72,
        chainAspect: .56,
        chainThickness: .19,
      ),
      'tip_settings_images_ja': images.copyWith(
        id: 'custom-images',
        customImagePaths: images.customImagePaths.take(3).toList(),
        customImageSelectionMode: BrushImageSelectionMode.sequential,
      ),
    }.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              fontFamily: 'NotoSerifJP',
              colorSchemeSeed: const Color(0xff7459b8),
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('ペン先・画像素材')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BrushTipSettings(
                  brush: entry.value,
                  onChanged: (_) {},
                  onAddImages: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final path in entry.value.resolvedCustomImagePaths) {
          await precacheImage(
            AssetImage(path),
            tester.element(find.byType(BrushTipSettings)),
          );
        }
      });
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/hair_fold_visual/${entry.key}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  });
}
