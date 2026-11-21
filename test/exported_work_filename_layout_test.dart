import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/widgets/collection_action_controls.dart';

import 'helpers/exported_work_name.dart';
import 'helpers/load_app_fonts.dart';

const _stem = 'AUDIT_long_animation_export_filename_with_similar_suffix';

void main() {
  Widget host(
    String name, {
    required double width,
    required double scale,
    required bool grid,
    VoidCallback? onOpen,
    VoidCallback? onFavorite,
  }) => MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ListView(
            children: [
              SizedBox(
                height: grid ? 200 : null,
                child: ExportedWorkCard(
                  name: name,
                  metadata: '16/11/2026 11:38 · 109 o',
                  icon: Icons.image_outlined,
                  moveLabel: 'Déplacer',
                  shareLabel: 'Partager',
                  deleteLabel: 'Supprimer',
                  onOpen: onOpen ?? () {},
                  onMove: () {},
                  onShare: () {},
                  onDelete: () {},
                  gridTile: grid,
                  onToggleFavorite: onFavorite ?? () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  RenderParagraph paragraph(WidgetTester tester, Finder label) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );

  testWidgets('two-line export tiles distinguish similar names and formats', (
    tester,
  ) async {
    await loadAppFonts(tester);
    for (final (width, scale) in [
      (90.0, 1.0),
      (136.0, 1.3),
      (148.0, 2.0),
      (304.0, 2.0),
    ]) {
      for (final suffix in ['_10.png', '_11.png', '_03.jpg', '_04.jpeg']) {
        final name = '$_stem$suffix';
        await tester.pumpWidget(
          host(name, width: width, scale: scale, grid: true),
        );
        await tester.pumpAndSettle();
        final label = findExportedWorkName(name);
        final rendered = paragraph(tester, label);
        expect(tester.widget<Text>(label).maxLines, 2);
        expect(rendered.didExceedMaxLines, isFalse, reason: '$width x$scale');
        expect(
          rendered.text
              .toPlainText(includeSemanticsLabels: false)
              .replaceAll('\u200B', ''),
          endsWith(suffix),
        );
        expect(find.byTooltip(name), findsOneWidget);
      }
    }
  });

  testWidgets('export captions use the same cutoff across roomy sizes', (
    tester,
  ) async {
    await loadAppFonts(tester);
    const name = '${_stem}_10.png';
    String? reference;
    for (final width in [110.0, 172.0, 320.0]) {
      await tester.pumpWidget(host(name, width: width, scale: 1, grid: true));
      await tester.pumpAndSettle();
      final shown = paragraph(
        tester,
        findExportedWorkName(name),
      ).text.toPlainText(includeSemanticsLabels: false);
      expect(shown, contains('…'));
      reference ??= shown;
      expect(shown, reference, reason: 'width $width');
    }
  });

  testWidgets('automatic export timestamps remain distinguishable', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final captions = <String>[];
    for (final timestamp in ['1794796701416', '1794796701417']) {
      final name = 'niarim_frame_$timestamp.png';
      await tester.pumpWidget(host(name, width: 148, scale: 2, grid: true));
      await tester.pumpAndSettle();
      final shown = paragraph(tester, findExportedWorkName(name));
      expect(shown.didExceedMaxLines, isFalse);
      final caption = shown.text
          .toPlainText(includeSemanticsLabels: false)
          .replaceAll('\u200B', '');
      expect(
        caption,
        endsWith('${timestamp.substring(timestamp.length - 4)}.png'),
      );
      captions.add(caption);
    }
    expect(captions.toSet(), hasLength(2));
  });

  testWidgets(
    'long detail names use the whole column, with the actions reachable below',
    (tester) async {
      await loadAppFonts(tester);
      const name = '${_stem}_10.png';
      final actions = <String>[];
      await tester.pumpWidget(
        host(
          name,
          width: 320,
          scale: 2,
          grid: false,
          onOpen: () => actions.add('open'),
          onFavorite: () => actions.add('favorite'),
        ),
      );
      await tester.pumpAndSettle();
      final label = findExportedWorkName(name);
      final rendered = paragraph(tester, label);
      expect(
        rendered.text
            .toPlainText(includeSemanticsLabels: false)
            .replaceAll('\u200B', ''),
        name,
      );
      expect(rendered.didExceedMaxLines, isFalse);
      final favorite = find.byType(CollectionFavoriteButton);
      final menu = find.byKey(const Key('exportedWorkMoreMenu'));
      expect(
        tester.getTopLeft(favorite).dy,
        greaterThan(tester.getBottomLeft(label).dy),
      );
      await tester.tapAt(tester.getRect(favorite).topLeft - const Offset(3, 3));
      await tester.pumpAndSettle();
      expect(actions, ['favorite']);
      // The hit area extends past the drawn 40px circle, as it does inline.
      await tester.tapAt(tester.getRect(menu).centerRight + const Offset(4, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(actions, ['favorite', 'open']);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(host(name, width: 780, scale: 1, grid: false));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(menu).dy, tester.getTopLeft(label).dy);
      expect(tester.takeException(), isNull);
    },
  );
}
