import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_codec;
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/material_asset.dart' as assets;
import 'package:niarim/screens/materials/material_list_screen.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

class _Materials extends MaterialService {
  @override
  List<assets.MaterialAsset> materialsOf(String projectId) => [
    assets.MaterialAsset(
      id: 'used',
      originalFileName: 'tone.wav',
      type: assets.MaterialType.audio,
      sizeBytes: 100,
      addedAt: DateTime.utc(2026),
    ),
    assets.MaterialAsset(
      id: 'unused',
      originalFileName: 'image.png',
      type: assets.MaterialType.image,
      sizeBytes: 100,
      addedAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<List<assets.MaterialAsset>> detectMissing(String projectId) async =>
      [];

  @override
  Future<String?> pathOf(String projectId, String materialId) async => null;
}

class _Projects extends ProjectService {
  @override
  bool isMaterialUsed(String projectId, String materialId) =>
      materialId == 'used';
}

void main() {
  useTemporaryProjectStorage();

  testWidgets('DISC527: imported and existing materials show their metadata', (
    tester,
  ) async {
    const projectId = 'metadata';
    Future<Duration?> probe(String path) async =>
        switch (path.split('.').last) {
          'wav' => const Duration(seconds: 65),
          'mp4' => const Duration(seconds: 17),
          _ => throw const FormatException('No media information'),
        };
    final materials = MaterialService(readMediaDuration: probe);
    addTearDown(materials.dispose);
    late final File manifest;
    await tester.runAsync(() async {
      final root = await getApplicationDocumentsDirectory();
      final image = File('${root.path}/drawing.png');
      await image.writeAsBytes(
        image_codec.encodePng(image_codec.Image(width: 7, height: 11)),
      );
      for (final (name, type) in [
        ('drawing.png', assets.MaterialType.image),
        ('sound.wav', assets.MaterialType.audio),
        ('movie.mp4', assets.MaterialType.video),
        ('unknown.avi', assets.MaterialType.video),
      ]) {
        final file = File('${root.path}/$name');
        if (name != 'drawing.png') await file.writeAsString(name);
        await materials.addMaterial(
          projectId: projectId,
          sourcePath: file.path,
          type: type,
        );
      }
      final added = materials.materialsOf(projectId);
      expect((added[0].width, added[0].height), (7, 11));
      expect(added[1].duration, const Duration(seconds: 65));
      expect(added[2].duration, const Duration(seconds: 17));
      expect(added[3].duration, isNull);

      manifest = File(
        '${root.path}/niarim/projects/$projectId/Materials/materials.json',
      );
      final legacy = jsonDecode(await manifest.readAsString()) as Map;
      for (final record in legacy['materials'] as List) {
        (record as Map)
          ..remove('width')
          ..remove('height')
          ..remove('durationMs');
      }
      await manifest.writeAsString(jsonEncode(legacy));
    });

    final reopened = MaterialService(readMediaDuration: probe);
    addTearDown(reopened.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MaterialService>.value(value: reopened),
          ChangeNotifierProvider<ProjectService>(create: (_) => _Projects()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MaterialListScreen(projectId: projectId),
        ),
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('7×11'), findsOneWidget);
    expect(find.textContaining('1:05'), findsOneWidget);
    expect(find.textContaining('0:17'), findsOneWidget);
    expect(find.text('unknown.avi'), findsOneWidget);
    final persisted = jsonDecode(manifest.readAsStringSync()) as Map;
    final records = persisted['materials'] as List;
    expect(records[0]['width'], 7);
    expect(records[0]['height'], 11);
    expect(records[1]['durationMs'], 65000);
    expect(records[2]['durationMs'], 17000);
    expect(records[3]['durationMs'], isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-use materials explain the lock and cannot be deleted', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MaterialService>(create: (_) => _Materials()),
          ChangeNotifierProvider<ProjectService>(create: (_) => _Projects()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MaterialListScreen(projectId: 'project'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lock = find.widgetWithIcon(IconButton, Icons.lock_outline);
    expect(lock, findsOneWidget);
    await tester.tap(lock);
    await tester.pumpAndSettle();
    expect(find.text(l10n.materialDeleteTooltipUsed), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('tone.wav'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text(l10n.materialRemoveOneConfirmTitle), findsOneWidget);
  });

  testWidgets('narrow layouts keep the bulk delete action reachable', (
    tester,
  ) async {
    const locale = Locale('fr');
    final l10n = lookupAppLocalizations(locale);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 320);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadAppFonts(tester);
    final theme = ThemeService();
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MaterialService>(create: (_) => _Materials()),
          ChangeNotifierProvider<ProjectService>(create: (_) => _Projects()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: MaterialApp(
          theme: theme.themeDataFor(locale),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MaterialListScreen(projectId: 'project'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final bulkDelete = find.byTooltip(l10n.materialRemoveUnused(1));
    expect(bulkDelete.hitTestable(), findsOneWidget);
    await tester.tap(bulkDelete);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(tester.widget<AlertDialog>(dialog).scrollable, isTrue);
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text(l10n.commonCancel)),
    );
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.text('image.png'), findsOneWidget);
  });
}
