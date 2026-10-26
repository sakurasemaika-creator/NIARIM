import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/project/widgets/project_playback_status.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets('playback does not move controls when frame digits grow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    await loadAppFonts(tester);
    for (final width in [320.0, 360.0, 430.0, 560.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final bold in [false, true]) {
        double? initialHeight;
        for (final frame in [1, 9, 99, 999, 9999, 10008]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.themeData,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2), boldText: bold),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ProjectPlaybackStatus(
                      currentFrame: frame,
                      totalFrames: 10008,
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
          final height = tester
              .getSize(find.byType(ProjectPlaybackStatus))
              .height;
          initialHeight ??= height;
          expect(
            height,
            initialHeight,
            reason: 'width=$width bold=$bold frame=$frame',
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
