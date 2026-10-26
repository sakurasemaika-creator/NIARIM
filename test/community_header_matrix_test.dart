import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/video_type_filter.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'community_header_quality_test.dart' as quality;
import 'helpers/load_app_fonts.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final output = Platform.environment['NIARIM_AUDIT_CAPTURE'];
  final smoke = Platform.environment['NIARIM_AUDIT_SMOKE'] == '1';
  final onlyCase = Platform.environment['NIARIM_AUDIT_CASE'];
  const widths = [
    320,
    360,
    375,
    390,
    430,
    480,
    520,
    559,
    560,
    600,
    640,
    641,
    700,
    759,
    760,
    834,
    900,
    1024,
    1180,
    1280,
    1366,
    1440,
    1600,
    1920,
  ];
  const states = [
    'new',
    'ranking',
    'following',
    'portrait',
    'search',
    'tag-search',
  ];
  for (final state in states) {
    testWidgets(
      'plaza header matrix: $state',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final themes = ThemeService();
        await themes.init();
        final community = CommunityService();
        final preview = CommunityPreviewService();
        await tester.runAsync(() => community.contentFiltersReady);
        // Only the header is under this matrix; synthetic hidden data keeps
        // unrelated cards out of its layout/pixel assertions.
        await tester.runAsync(
          () => community.setMutedWords(
            community.discoverableWorks.map((w) => w.title),
          ),
        );
        addTearDown(themes.dispose);
        addTearDown(community.dispose);
        addTearDown(preview.dispose);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        await loadAppFonts(tester);
        final boundary = GlobalKey();
        final manifest = <Map<String, Object?>>[];
        final locales = smoke
            ? [const Locale('en'), const Locale('fr')]
            : AppLocalizations.supportedLocales;
        for (final locale in locales) {
          if (onlyCase != null &&
              !onlyCase.startsWith('${locale.toLanguageTag()}/')) {
            continue;
          }
          final cases =
              <({int width, int height, bool pc, double scale, String theme})>[
                for (final pc in [false, true])
                  for (final width in smoke ? [320, 390, 640, 1440] : widths)
                    (
                      width: width,
                      height: pc ? 900 : 844,
                      pc: pc,
                      scale: 1,
                      theme: 'light',
                    ),
                (width: 320, height: 844, pc: false, scale: 2, theme: 'dark'),
                (
                  width: 390,
                  height: 844,
                  pc: false,
                  scale: 1.3,
                  theme: 'white',
                ),
                (width: 640, height: 360, pc: false, scale: 2, theme: 'dark'),
                (width: 1440, height: 900, pc: true, scale: 2, theme: 'dark'),
                (width: 320, height: 900, pc: true, scale: 2, theme: 'white'),
                (width: 390, height: 900, pc: true, scale: 1.3, theme: 'dark'),
                (width: 640, height: 360, pc: true, scale: 2, theme: 'white'),
              ];
          await tester.pumpWidget(const SizedBox.shrink());
          for (final c in cases) {
            final caseId =
                '${locale.toLanguageTag()}/${c.pc ? 'pc' : 'sp'}/${c.width}/${c.theme}/${c.scale}';
            if (onlyCase != null && onlyCase != caseId) continue;
            tester.view.physicalSize = Size(
              c.width.toDouble(),
              c.height.toDouble(),
            );
            themes.previewCurrent(
              c.theme == 'dark'
                  ? AppThemePreset.defaultDark
                  : c.theme == 'white'
                  ? AppThemePreset.defaultLight.copyWith(
                      accentColor: Colors.white,
                      selectionColor: Colors.black,
                    )
                  : AppThemePreset.defaultLight,
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: quality.host(
                  themes,
                  community,
                  preview,
                  locale: locale,
                  scale: c.scale,
                ),
              ),
            );
            await tester.pumpAndSettle();
            final screen = tester.element(find.byType(CommunityScreen));
            await tester.runAsync(
              () => screen.read<SettingsService>().setForcePcMode(c.pc),
            );
            await tester.pumpAndSettle();
            final l10n = AppLocalizations.of(screen)!;
            expect(
              l10n.localeName.replaceAll('_', '-').toLowerCase(),
              locale.toLanguageTag().toLowerCase(),
            );
            if (state == 'search' || state == 'tag-search') {
              if (find.byType(TextField).evaluate().isEmpty) {
                await tester.tap(find.byTooltip(l10n.commonSearch));
                await tester.pumpAndSettle();
              }
              if (state == 'tag-search') {
                await tester.tap(find.text(l10n.communityTagSearchHint).last);
                await tester.pumpAndSettle();
              }
            } else if (state == 'portrait') {
              final portrait = find.byTooltip(l10n.communityShortsModeTooltip);
              if (portrait.evaluate().isEmpty) {
                await tester.tap(
                  find.byTooltip(l10n.communityVideoTypeFilterTooltip),
                );
                await tester.pumpAndSettle();
                await tester.tap(
                  find.byWidgetPredicate(
                    (w) =>
                        w is CheckedPopupMenuItem<VideoTypeFilter> &&
                        w.value == VideoTypeFilter.shortOnly,
                  ),
                );
                await tester.pumpAndSettle();
              }
              expect(
                tester
                    .widget<VideoTypeFilterButton>(
                      find.byType(VideoTypeFilterButton),
                    )
                    .value,
                VideoTypeFilter.shortOnly,
              );
              expect(
                find.byTooltip(l10n.communityShortsModeTooltip),
                findsOneWidget,
              );
            } else if (state != 'new') {
              final label = state == 'ranking'
                  ? l10n.communityTabRanking
                  : l10n.communityTabFavoriteAuthors;
              final tab = find.descendant(
                of: find.byType(TabBar),
                matching: find.text(label),
              );
              await tester.ensureVisible(tab);
              await tester.tap(tab);
              await tester.pumpAndSettle();
            }
            final failures = <String>[];
            expect(
              tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
              state == 'ranking'
                  ? 1
                  : state == 'following'
                  ? 2
                  : 0,
            );
            if (state == 'search' || state == 'tag-search') {
              expect(
                tester
                    .widget<SegmentedButton<bool>>(
                      find.byType(SegmentedButton<bool>),
                    )
                    .selected,
                {state == 'tag-search'},
              );
            }
            final bar = find.byType(AppBar);
            final theme = Theme.of(tester.element(bar));
            final labels = [
              l10n.communityTabNew,
              l10n.communityTabRanking,
              l10n.communityTabFavoriteAuthors,
            ];
            if (state != 'search' && state != 'tag-search') {
              labels.add(l10n.communityScreenTitle);
            }
            for (final label in labels) {
              final f = find.descendant(of: bar, matching: find.text(label));
              final paragraph = tester.renderObject<RenderParagraph>(f);
              if (paragraph.didExceedMaxLines) failures.add('$label truncated');
              final tabs = tester.widget<TabBar>(find.byType(TabBar));
              final expected = label == l10n.communityScreenTitle
                  ? theme.appBarTheme.foregroundColor
                  : label == labels[tabs.controller!.index]
                  ? tabs.labelColor
                  : tabs.unselectedLabelColor;
              expect(
                paragraph.text.style!.color,
                expected,
                reason: '$label configured role',
              );
            }
            final tips = state == 'search' || state == 'tag-search'
                ? [l10n.commonClose]
                : [
                    l10n.communityFollowNotificationsTooltip,
                    l10n.communityVideoTypeFilterTooltip,
                    l10n.communityContentFilterTitle,
                    l10n.commonSearch,
                    l10n.layerPanelHelpTooltip,
                    if (state == 'portrait') l10n.communityShortsModeTooltip,
                  ];
            for (final tip in tips) {
              final f = find.byTooltip(tip);
              expect(f, findsOneWidget);
              final rect = tester.getRect(f);
              if (rect.width < 47.99 ||
                  rect.height < 47.99 ||
                  rect.left < -.01 ||
                  rect.right > c.width + .01 ||
                  rect.bottom > c.height) {
                failures.add('$tip target $rect');
              }
            }
            if (state == 'search' || state == 'tag-search') {
              for (final label in [
                l10n.communitySearchHint,
                l10n.communityTagSearchHint,
              ]) {
                final f = find.descendant(
                  of: find.byType(SegmentedButton<bool>),
                  matching: find.text(label),
                );
                final p = tester.renderObject<RenderParagraph>(f);
                if (p.didExceedMaxLines) failures.add('$label truncated');
                final button = find
                    .ancestor(of: f, matching: find.byType(TextButton))
                    .first;
                final bounds = tester.getRect(button);
                final text = tester.getRect(f);
                if (text.left < bounds.left + 4 ||
                    text.right > bounds.right - 4 ||
                    text.top < bounds.top ||
                    text.bottom > bounds.bottom) {
                  failures.add(
                    '$label paints outside its mode button $text / $bounds',
                  );
                }
                // didExceedMaxLines cannot detect a group border clipping
                // otherwise fully laid-out text. Check the actual renderer's
                // resolved inner clip, including every line of the label.
                final group = find.descendant(
                  of: find.byType(SegmentedButton<bool>),
                  matching: find.byWidgetPredicate(
                    (w) => w.runtimeType.toString().startsWith(
                      '_SegmentedButtonRenderWidget',
                    ),
                  ),
                );
                final dynamic render = tester.renderObject(group);
                final padding = render.tapTargetVerticalPadding as double;
                final size = render.size as Size;
                final clip = (render.enabledBorder as OutlinedBorder)
                    .getInnerPath(
                      Rect.fromLTWH(
                        0,
                        padding / 2,
                        size.width,
                        size.height - padding,
                      ),
                      textDirection: render.textDirection as TextDirection,
                    );
                final origin = (render as RenderBox).localToGlobal(Offset.zero);
                final offset = p.localToGlobal(Offset.zero) - origin;
                final boxes = p.getBoxesForSelection(
                  TextSelection(
                    baseOffset: 0,
                    extentOffset: p.text.toPlainText().length,
                  ),
                );
                for (final box in boxes) {
                  final glyph = box.toRect().shift(offset).deflate(0.5);
                  if ([
                    glyph.topLeft,
                    glyph.topRight,
                    glyph.bottomLeft,
                    glyph.bottomRight,
                  ].any((point) => !clip.contains(point))) {
                    failures.add(
                      '$label clipped by mode group border glyph=$glyph clip=${clip.getBounds()} paragraph=${p.size} group=$size',
                    );
                    break;
                  }
                }
              }
            }
            final selected = tester
                .widget<TabBar>(find.byType(TabBar))
                .controller!
                .index;
            final selectedRect = tester.getRect(
              find.descendant(
                of: find.byType(TabBar),
                matching: find.text(labels[selected]),
              ),
            );
            if (selectedRect.left < -.01 ||
                selectedRect.right > c.width + .01) {
              failures.add('selected tab outside viewport $selectedRect');
            }
            expect(tester.takeException(), isNull, reason: '$state/$locale/$c');
            final file =
                '$state-${locale.toLanguageTag()}-${c.pc ? 'pc' : 'sp'}-${c.width}x${c.height}-${c.theme}-${c.scale}.png';
            if (failures.isNotEmpty) {
              await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                final dir = Directory('$output/failures')
                  ..createSync(recursive: true);
                File(
                  '${dir.path}/$file',
                ).writeAsBytesSync(bytes!.buffer.asUint8List());
                File('${dir.path}/$file.json').writeAsStringSync(
                  jsonEncode({'case': caseId, 'failures': failures}),
                );
              });
            }
            expect(failures, isEmpty, reason: '$state/$locale/$c');
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              final directory = Directory('$output/$state')
                ..createSync(recursive: true);
              File(
                '${directory.path}/$file',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              manifest.add({
                'file': file,
                'locale': locale.toLanguageTag(),
                'mode': c.pc ? 'pc' : 'sp',
                'width': c.width,
                'height': c.height,
                'theme': c.theme,
                'scale': c.scale,
                'header_assertions': 'pass',
                'scope': 'header only; hidden synthetic data',
                'color_policy':
                    'configured roles; no automatic contrast correction',
                'readability_assessment':
                    'separate original-image review; user-chosen low contrast permitted',
              });
              File(
                '${directory.path}/manifest.json',
              ).writeAsStringSync(jsonEncode(manifest));
            });
          }
        }
        expect(
          manifest.length,
          onlyCase != null ? 1 : (smoke ? 2 : 7) * ((smoke ? 4 : 24) * 2 + 7),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: output == null,
      timeout: const Timeout(Duration(minutes: 20)),
    );
  }
}
