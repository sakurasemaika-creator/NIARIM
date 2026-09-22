import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush_presets_extension.dart';
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
}
