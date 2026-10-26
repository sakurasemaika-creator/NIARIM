import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

class _ThumbnailProjects extends ProjectService {
  _ThumbnailProjects(this.project);
  final Project project;
  @override
  List<Project> get projects => [project];
  @override
  List<ProjectFolder> get folders => [];
}

void main() {
  testWidgets(
    'transparent thumbnail keeps the project background in every view',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync(
        'niarim_transparent_thumb_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/transparent.png');
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder);
        final picture = recorder.endRecording();
        final image = await picture.toImage(4, 4);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      final boundaryKey = GlobalKey();
      var longPresses = 0;
      Future<void> show(ProjectViewMode mode, int background) async {
        final service = _ThumbnailProjects(
          Project(
            id: 'thumb',
            name: 'Project name',
            fps: 24,
            durationSeconds: 1,
            backgroundColor: background,
            thumbnailPath: file.path,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            totalWorkSeconds: 0,
          ),
        );
        addTearDown(service.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<ProjectService>.value(
            value: service,
            child: MaterialApp(
              theme: theme.themeData,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RepaintBoundary(
                key: boundaryKey,
                child: Scaffold(
                  body: ProjectListWidget(
                    viewMode: mode,
                    sortMode: ProjectSortMode.nameAsc,
                    isSelectionMode: false,
                    selectedIds: const {},
                    onLongPress: (_) => longPresses++,
                    onSelectionChanged: (_) {},
                    currentFolderId: null,
                    onOpenFolder: (_) {},
                    onPickProject: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        for (var round = 0; round < 12; round++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
          if (tester.widget<RawImage>(find.byType(RawImage).first).image !=
              null) {
            break;
          }
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<RawImage>(find.byType(RawImage).first).image,
          isNotNull,
        );
      }

      Future<Color> pixel(Offset point) async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final color = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final i = (point.dy.floor() * image.width + point.dx.floor()) * 4;
          final result = Color.fromARGB(
            data.getUint8(i + 3),
            data.getUint8(i),
            data.getUint8(i + 1),
            data.getUint8(i + 2),
          );
          image.dispose();
          return result;
        });
        return color!;
      }

      for (final mode in ProjectViewMode.values) {
        for (final background in [0xFFFFFFFF, 0xFF20B37F]) {
          await show(mode, background);
          final rect = tester.getRect(find.byType(Image).first);
          expect(
            await pixel(rect.center),
            Color(background),
            reason: '$mode/$background',
          );
          expect(tester.takeException(), isNull);
        }
      }

      theme.previewCurrent(
        AppThemePreset.defaultDark.copyWith(
          textColor: const Color(0xFF92C8D1),
          menuBgColor: const Color(0xFF1B3055),
          menuTextColor: const Color(0xFFF2D59C),
        ),
      );
      await show(ProjectViewMode.medium, 0xFFFFFFFF);
      final name = find.text('Project name');
      final card = tester.getRect(
        find.ancestor(of: name, matching: find.byType(Card)),
      );
      final text = tester.getRect(name);
      expect(
        await pixel(Offset(card.left + 4, text.center.dy)),
        theme.themeData.popupMenuTheme.color,
      );
      expect(
        tester.widget<Text>(name).style!.color,
        theme.themeData.popupMenuTheme.textStyle!.color,
      );
      await tester.longPress(name);
      await tester.pumpAndSettle();
      expect(
        longPresses,
        1,
        reason: 'Caption tooltip must not consume selection long-press',
      );
    },
  );
}
