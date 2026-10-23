import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/config/accent_text_theme.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_models.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

// Opt-in audit captures complement the fast state/recovery tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureRoot = Platform.environment['NIARIM_AUDIT_CAPTURE'];
  final output = captureRoot == null ? null : '$captureRoot/bookmarks';
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
  const languages = ['ja', 'en', 'zh', 'zh_Hant', 'ko', 'fr', 'es'];
  const states = [
    'empty',
    'filtered',
    'unresolved',
    'loading',
    'error',
    'not-loaded',
    'guest',
    'nonempty',
    'cached-error',
  ];
  final manifest = <Map<String, Object?>>[];
  for (final state in states) {
    testWidgets(
      'bookmark display matrix: $state',
      (tester) async {
        final boundary = GlobalKey();
        SharedPreferences.setMockInitialValues({
          'first_launch': false,
          'language': 'ja',
          'force_pc_mode': 0,
          firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        });
        final directory = Directory.systemTemp.createTempSync(
          'bookmark-matrix-',
        );
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => directory.path);
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          if (directory.existsSync()) directory.deleteSync(recursive: true);
        });
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        await loadAppFonts(tester);
        final held = Completer<http.Response>();
        var fail = state == 'error';
        final fixture = {
          'workId': 'fixture-saved',
          'authorId': 'fixture-other',
          'title': 'Audit saved work',
          'postedAt': '2026-10-22T00:00:00Z',
          'isNiarimPublished': true,
          'containsGenerativeAiImageOrVideo': state == 'filtered',
        };
        http.Response reply(Object value, {int status = 200}) =>
            http.Response(jsonEncode(value), status);
        final service = CommunityService(
          api: state == 'filtered' || state == 'unresolved'
              ? null
              : CommunityApi(
                  NiarimApiClient(
                    baseUrl: 'https://example.invalid',
                    tokenProvider: () async => 'fixture',
                    maxGetRetries: 0,
                    timeout: const Duration(hours: 1),
                    httpClient: MockClient((r) async {
                      if (r.url.path.endsWith('/bookmarks')) {
                        if (state == 'loading') return held.future;
                        if (fail) {
                          return reply({'error': 'unavailable'}, status: 503);
                        }
                        return reply({
                          'works':
                              state == 'nonempty' || state == 'cached-error'
                              ? [fixture]
                              : [],
                        });
                      }
                      if (r.url.path.endsWith('/following')) {
                        return reply({'following': []});
                      }
                      return reply({'reposts': []});
                    }),
                  ),
                ),
        );
        await tester.runAsync(() => service.contentFiltersReady);
        if (state != 'guest' && service.isBackendConnected) {
          service.setCurrentUserId('fixture-owner');
        }
        appRouter.go('/home');
        final providers = await tester.runAsync(buildAppProviders);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MultiProvider(
              providers: [
                ...providers!,
                ChangeNotifierProvider<CommunityService>.value(value: service),
              ],
              child: const NiarimApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(HomeScreen));
        final settings = context.read<SettingsService>();
        final theme = context.read<ThemeService>();
        if (state == 'filtered' || state == 'unresolved') {
          if (state == 'filtered') {
            service.applyServerWork(
              ApiWork.fromJson(fixture).toCommunityWork(),
            );
          }
          await service.toggleBookmark('fixture-saved');
          await tester.runAsync(
            () => service.setHideGenerativeAiImageVideo(true),
          );
        } else if (state != 'guest' &&
            state != 'not-loaded' &&
            state != 'loading') {
          await tester.runAsync(() => service.loadSocial());
          if (state == 'cached-error') {
            fail = true;
            await tester.runAsync(() => service.loadSocial());
          }
        }
        final tab = find.byKey(const ValueKey('home_tab_2'));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        Future<bool>? loading;
        if (state == 'loading') {
          loading = service.loadSocial();
          await tester.pump();
        }
        Future<void> capture(String name, Map<String, Object?> cell) async {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            final file = File('$output/$name.png');
            file.parent.createSync(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
          manifest.add({...cell, 'file': '$name.png'});
        }

        for (final language in languages) {
          await tester.runAsync(() => settings.setLanguage(language));
          final profiles =
              <
                ({
                  bool pc,
                  Size size,
                  double scale,
                  AppThemePreset theme,
                  String suffix,
                })
              >[
                for (final pc in [false, true])
                  for (final width in widths)
                    (
                      pc: pc,
                      size: Size(width.toDouble(), pc ? 900 : 844),
                      scale: 1,
                      theme: AppThemePreset.defaultLight,
                      suffix: '',
                    ),
                (
                  pc: false,
                  size: const Size(320, 844),
                  scale: 2,
                  theme: AppThemePreset.defaultDark,
                  suffix: 'dark-scale2',
                ),
                (
                  pc: false,
                  size: const Size(390, 844),
                  scale: 1.3,
                  theme: AppThemePreset.defaultLight.copyWith(
                    accentColor: Colors.white,
                    selectionColor: Colors.black,
                  ),
                  suffix: 'custom-scale1.3',
                ),
                (
                  pc: true,
                  size: const Size(1440, 900),
                  scale: 2,
                  theme: AppThemePreset.defaultLight.copyWith(
                    accentColor: Colors.white,
                    selectionColor: Colors.black,
                  ),
                  suffix: 'custom-scale2',
                ),
                (
                  pc: true,
                  size: const Size(760, 900),
                  scale: 1.3,
                  theme: AppThemePreset.defaultDark,
                  suffix: 'dark-scale1.3',
                ),
                (
                  pc: false,
                  size: const Size(559, 844),
                  scale: 2,
                  theme: AppThemePreset.defaultLight,
                  suffix: 'light-scale2',
                ),
                (
                  pc: true,
                  size: const Size(641, 360),
                  scale: 1,
                  theme: AppThemePreset.defaultLight,
                  suffix: 'short',
                ),
                (
                  pc: false,
                  size: const Size(640, 360),
                  scale: 2,
                  theme: AppThemePreset.defaultLight,
                  suffix: 'short-scale2',
                ),
              ];
          for (final p in profiles) {
            tester.view.physicalSize = p.size;
            tester.platformDispatcher.textScaleFactorTestValue = p.scale;
            await tester.runAsync(() => settings.setForcePcMode(p.pc));
            theme.previewCurrent(p.theme);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            // Finish the button foreground animation after AnimatedTheme.
            await tester.pump(const Duration(milliseconds: 400));
            final suffix =
                '$state-$language-${p.pc ? 'pc' : 'sp'}-${p.size.width.toInt()}${p.suffix.isEmpty ? '' : '-${p.suffix}'}';
            expect(tester.takeException(), isNull, reason: suffix);
            expect(
              tester.widget<Semantics>(tab).properties.selected,
              isTrue,
              reason: suffix,
            );
            final selectedRect = tester.getRect(tab);
            expect(
              selectedRect.left,
              greaterThanOrEqualTo(-.01),
              reason: suffix,
            );
            expect(
              selectedRect.right,
              lessThanOrEqualTo(p.size.width + .01),
              reason: suffix,
            );
            expect(settings.forcePcMode, p.pc, reason: suffix);
            final home = tester.element(find.byType(HomeScreen));
            final l10n = AppLocalizations.of(home)!;
            expect(
              l10n.localeName.replaceAll('-', '_'),
              language,
              reason: suffix,
            );
            expect(
              MediaQuery.textScalerOf(home).scale(1),
              p.scale,
              reason: suffix,
            );
            final String? heading = switch (state) {
              'filtered' || 'unresolved' => l10n.homeBookmarkedHiddenTitle,
              'loading' => l10n.homeBookmarkedLoading,
              'error' => l10n.homeBookmarkedLoadFailed,
              'not-loaded' => l10n.homeBookmarkedLoadPrompt,
              'nonempty' || 'cached-error' => null,
              _ => l10n.homeBookmarkedEmptyTitle,
            };
            if (heading != null) {
              expect(find.text(heading), findsOneWidget, reason: suffix);
              final title = tester.widget<Text>(find.text(heading));
              final bg = opaqueOver(
                Theme.of(home).scaffoldBackgroundColor,
                Colors.black,
              );
              expect(
                contrastRatio(bg, opaqueOver(title.style!.color!, bg)),
                greaterThanOrEqualTo(4.5),
                reason: suffix,
              );
            } else {
              expect(
                find.text('Audit saved work'),
                findsOneWidget,
                reason: suffix,
              );
            }
            for (final scroll in tester.stateList<ScrollableState>(
              find.descendant(
                of: find.byType(HomeScreen),
                matching: find.byType(Scrollable),
              ),
            )) {
              if (scroll.position.axis == Axis.vertical &&
                  scroll.position.hasPixels) {
                scroll.position.jumpTo(0);
              }
            }
            await tester.pump();
            final cell = <String, Object?>{
              'state': state,
              'locale': language,
              'forced_pc': p.pc,
              'width': p.size.width,
              'height': p.size.height,
              'text_scale': p.scale,
              'theme': p.theme.toJson(),
              'heading': heading,
              'layout_exception': false,
            };
            await capture(suffix, cell);
            final buttons = find.descendant(
              of: find.byType(HomeScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is OutlinedButton ||
                    (w is IconButton &&
                        (w.tooltip == l10n.communityRetry ||
                            w.tooltip == l10n.communityReloadTooltip)),
              ),
            );
            final actionBackground = opaqueOver(
              Theme.of(home).scaffoldBackgroundColor,
              Colors.black,
            );
            // 「再読み込み」「作品広場」のボタンは他のボタンと同じテーマの
            // 「アクセントの文字・アイコン色」（未指定なら差し色。ユーザー
            // 指定で、読みやすさのために黒や白へ自動で差し替えない）。
            // 右上の再読み込みのアイコンは文字の色のまま。
            final accent = AccentTextTheme.of(home);
            for (final paragraph in tester.renderObjectList<RenderParagraph>(
              find.descendant(
                of: find.descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(OutlinedButton),
                ),
                matching: find.byType(RichText),
              ),
            )) {
              expect(
                paragraph.text.style?.color,
                accent,
                reason: '$suffix rendered action foreground',
              );
            }
            for (final paragraph in tester.renderObjectList<RenderParagraph>(
              find.descendant(
                of: find.descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is IconButton &&
                        (w.tooltip == l10n.communityRetry ||
                            w.tooltip == l10n.communityReloadTooltip),
                  ),
                ),
                matching: find.byType(RichText),
              ),
            )) {
              final color = paragraph.text.style?.color;
              if (color == null) continue;
              expect(
                contrastRatio(
                  actionBackground,
                  opaqueOver(color, actionBackground),
                ),
                greaterThanOrEqualTo(4.5),
                reason: '$suffix rendered refresh icon',
              );
            }
            for (final button
                in buttons
                    .evaluate()
                    .map((e) => find.byWidget(e.widget))
                    .toList()) {
              await tester.ensureVisible(button);
              await tester.pump();
              expect(
                button.hitTestable(),
                findsOneWidget,
                reason: '$suffix action must remain reachable',
              );
            }
            if (p.suffix.startsWith('short') && buttons.evaluate().isNotEmpty) {
              await capture('$suffix-controls', {
                ...cell,
                'phase': 'controls-scrolled',
              });
            }
            expect(tester.takeException(), isNull, reason: suffix);
          }
          debugPrint(
            'A003/S8 matrix $state $language complete: ${profiles.length} cells',
          );
        }
        if (loading != null) {
          held.complete(reply({'works': []}));
          await tester.pump();
          await loading;
        }
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.runAsync(() async {
          await File('$output/manifest.json').writeAsString(
            jsonEncode({
              'scope': 'A003/S8 bookmark states, not comprehensive closure',
              'captures': manifest,
            }),
          );
        });
      },
      timeout: const Timeout(Duration(minutes: 10)),
      skip: output == null,
    );
  }
}
