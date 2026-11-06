import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/project/widgets/project_playback_status.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets('playback values and loop state keep their meaning', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    var loop = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ProjectPlaybackStatus(
              currentFrame: 3,
              totalFrames: 20,
              fps: 10,
              loopPlayback: loop,
              onToggleLoop: () => setState(() => loop = !loop),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0.2s'), findsOneWidget);
    expect(find.text('2.0s'), findsOneWidget);
    expect(find.text('3/20'), findsOneWidget);
    final button = find.byKey(const Key('projectDetailLoopButton'));
    expect(tester.getSize(button), const Size(48, 48));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(loop, isFalse);
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: button, matching: find.byIcon(Icons.repeat)),
          )
          .color,
      theme.themeData.colorScheme.onSurfaceVariant,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail status hides seconds, retaining frame counter and loop', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectPlaybackStatus(
            currentFrame: 3,
            totalFrames: 120,
            fps: 12,
            loopPlayback: true,
            onToggleLoop: () {},
            showTimes: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('projectDetailCurrentSeconds')), findsNothing);
    expect(find.byKey(const Key('projectDetailTotalSeconds')), findsNothing);
    expect(find.byKey(const Key('projectDetailFrameCounter')), findsOneWidget);
    expect(find.byKey(const Key('projectDetailLoopButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'playback status fits all widths, languages and large frame counts',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      await loadAppFonts(tester);
      final failures = <String>[];
      var cases = 0;
      const widths = <double>[
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
      for (final locale in AppLocalizations.supportedLocales) {
        for (final width in widths) {
          tester.view.physicalSize = Size(width, 900);
          for (final scale in [1.0, 2.0]) {
            for (final outerPadding in [0.0, 16.0]) {
              for (final frames in [
                (0, 0),
                (1, 1),
                (1, 12),
                (5000, 10008),
                (864000, 864000),
              ]) {
                await tester.pumpWidget(
                  MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: theme.themeData,
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: Padding(
                        padding: EdgeInsets.all(outerPadding),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ProjectPlaybackStatus(
                            currentFrame: frames.$1,
                            totalFrames: frames.$2,
                            fps: 24,
                            loopPlayback: true,
                            onToggleLoop: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                cases++;
                final tag = '$locale/$width/$scale/$outerPadding/$frames';
                final root = tester.getRect(find.byType(ProjectPlaybackStatus));
                for (final key in [
                  'projectDetailCurrentSeconds',
                  'projectDetailFrameCounter',
                  'projectDetailTotalSeconds',
                  'projectDetailLoopButton',
                ]) {
                  final rect = tester.getRect(find.byKey(Key(key)));
                  if (rect.left < root.left - .01 ||
                      rect.right > root.right + .01 ||
                      rect.top < root.top - .01 ||
                      rect.bottom > root.bottom + .01) {
                    failures.add('$tag $key outside $rect/$root');
                  }
                }
                final loop = tester.getSize(
                  find.byKey(const Key('projectDetailLoopButton')),
                );
                if (loop.width < 48 || loop.height < 48) {
                  failures.add('$tag small loop');
                }
                for (final p in tester.renderObjectList<RenderParagraph>(
                  find.descendant(
                    of: find.byType(ProjectPlaybackStatus),
                    matching: find.byType(Text),
                  ),
                )) {
                  if (p.didExceedMaxLines) failures.add('$tag clipped text');
                }
                final error = tester.takeException();
                if (error != null) failures.add('$tag $error');
              }
            }
          }
        }
      }
      // ignore: avoid_print
      print(
        'Project playback status: $cases cases, ${failures.length} failures',
      );
      expect(failures, isEmpty);
    },
  );
}
