import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';
import 'package:niarim/screens/canvas/widgets/brush_tip_settings.dart';

void main() {
  testWidgets('custom tip controls edit shared settings on a phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var brush = brushExtensionPresets().first.copyWith(id: 'my-tip');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => BrushTipSettings(
                brush: brush,
                onChanged: (value) => setState(() => brush = value),
                onAddImages: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<BrushTipShape>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('チェーンの輪').last);
    await tester.pumpAndSettle();
    expect(brush.tipShape, BrushTipShape.chainLink);
    await tester.tap(find.text('太さに比例する間隔'));
    await tester.pumpAndSettle();
    expect(brush.tipSpacingFactor, 1);
    await tester.tap(find.text('扁平なペン先'));
    await tester.pumpAndSettle();
    expect(brush.calligraphyAngle, 0);
    await tester.tap(find.text('扁平なペン先'));
    await tester.pumpAndSettle();
    expect(brush.calligraphyAngle, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'image controls reorder, change ink and remove the last legacy image',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var brush = brushExtensionPresets()
          .singleWhere((b) => b.id == 'Brush0024')
          .copyWith(
            id: 'custom-images',
            customImagePaths: const [
              'assets/brushes/bangs_01.png',
              'assets/brushes/bangs_02.png',
            ],
            customImagePath: 'assets/brushes/bangs_01.png',
          );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => BrushTipSettings(
                  brush: brush,
                  onChanged: (value) => setState(() => brush = value),
                  onAddImages: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('下へ移動').first);
      await tester.pumpAndSettle();
      expect(brush.resolvedCustomImagePaths.first, endsWith('bangs_02.png'));
      await tester.tap(find.byType(DropdownButtonFormField<BrushImageInkMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不透明な部分').last);
      await tester.pumpAndSettle();
      expect(brush.imageInkMode, BrushImageInkMode.alpha);
      await tester.tap(
        find.byType(DropdownButtonFormField<BrushImageSelectionMode>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('登録順').last);
      await tester.pumpAndSettle();
      expect(
        brush.customImageSelectionMode,
        BrushImageSelectionMode.sequential,
      );
      await tester.tap(find.byTooltip('素材を外す').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('素材を外す').first);
      await tester.pumpAndSettle();
      expect(brush.resolvedCustomImagePaths, isEmpty);
      expect(brush.customImagePath, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
