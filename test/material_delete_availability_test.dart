import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/material_asset.dart' as assets;
import 'package:niarim/screens/materials/material_list_screen.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';

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
}
