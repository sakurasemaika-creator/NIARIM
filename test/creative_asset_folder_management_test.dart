import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/widgets/name_entry_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  for (final kind in ['brush', 'tone', 'stamp']) {
    testWidgets(
      '$kind folders can be named and removed without hiding assets',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        });
        final brushes = BrushService();
        final tones = ToneService();
        final stamps = StampService();
        addTearDown(brushes.dispose);
        addTearDown(tones.dispose);
        addTearDown(stamps.dispose);
        final (panel, assetId, folderList, assetFolder, move) = switch (kind) {
          'brush' => (
            BrushPanel(onClose: () {}),
            'Brush0001',
            () => {for (final f in brushes.folders) f.name: f.id},
            () =>
                brushes.brushes.firstWhere((b) => b.id == 'Brush0001').folderId,
            brushes.moveToFolder,
          ),
          'tone' => (
            TonePanel(onClose: () {}),
            'Tone0001',
            () => {for (final f in tones.folders) f.name: f.id},
            () => tones.tones.firstWhere((t) => t.id == 'Tone0001').folderId,
            tones.moveToFolder,
          ),
          _ => (
            StampPanel(onClose: () {}),
            'Stamp0001',
            () => {for (final f in stamps.folders) f.name: f.id},
            () => stamps.stamps.firstWhere((s) => s.id == 'Stamp0001').folderId,
            stamps.moveToFolder,
          ),
        };
        await tester.runAsync(() async {
          await brushes.init();
          await tones.init();
          await stamps.init();
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BrushService>.value(value: brushes),
              ChangeNotifierProvider<ToneService>.value(value: tones),
              ChangeNotifierProvider<StampService>.value(value: stamps),
            ],
            child: MaterialApp(
              locale: const Locale('ja'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(body: Center(child: panel)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('ja'));

        Future<void> openFolders() async {
          await tester.tap(
            find.byIcon(Icons.folder_outlined).hitTestable().first,
          );
          await tester.pumpAndSettle();
        }

        Future<void> enterName(String name) async {
          await tester.enterText(
            find.descendant(
              of: find.byType(NameEntryDialog),
              matching: find.byType(TextField),
            ),
            name,
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
        }

        Future<void> createFolder(String name) async {
          await tester.tap(find.text(l10n.folderManagementCreateNew));
          await tester.pumpAndSettle();
          await enterName('  ');
          expect(find.byType(NameEntryDialog), findsOneWidget);
          await enterName(name);
          expect(find.byType(NameEntryDialog), findsNothing);
        }

        await openFolders();
        await createFolder('  Audit  ');
        await createFolder('Audit');
        expect(folderList().keys, ['Audit', 'Audit (2)']);

        final suffixId = folderList()['Audit (2)']!;
        final renameButton = find.descendant(
          of: find.byKey(ValueKey(suffixId)),
          matching: find.byTooltip(l10n.commonRename),
        );
        await tester.tap(renameButton);
        await tester.pumpAndSettle();
        await enterName('Audit');
        expect(folderList()['Audit (2)'], suffixId);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();
        final folderId = folderList()['Audit']!;
        move(assetId, folderId);
        await tester.pumpAndSettle();
        final folderChip = find.widgetWithText(ChoiceChip, 'Audit');
        await tester.tap(folderChip);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(assetId)), findsOneWidget);
        expect(assetFolder(), folderId);

        await openFolders();
        final deleteButton = find.descendant(
          of: find.byKey(ValueKey(folderId)),
          matching: find.byTooltip(l10n.commonDelete),
        );
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.creativeFolderDeleteBody('Audit')),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
        await tester.pumpAndSettle();
        expect(folderList().containsKey('Audit'), isFalse);
        expect(assetFolder(), isNull);
        navigator.pop();
        await tester.pumpAndSettle();

        final all = find.widgetWithText(
          ChoiceChip,
          l10n.creativePanelFolderAllChip,
        );
        expect(tester.widget<ChoiceChip>(all).selected, isTrue);
        await tester.tap(find.widgetWithText(ChoiceChip, l10n.folderNone));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(assetId)), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Services read the same persisted data the next time the app starts.
        await tester.runAsync(() async {
          switch (kind) {
            case 'brush':
              final restored = BrushService();
              await restored.init();
              expect(
                restored.brushes.firstWhere((b) => b.id == assetId).folderId,
                isNull,
              );
              expect(restored.folders.map((f) => f.name), ['Audit (2)']);
              restored.dispose();
            case 'tone':
              final restored = ToneService();
              await restored.init();
              expect(
                restored.tones.firstWhere((t) => t.id == assetId).folderId,
                isNull,
              );
              expect(restored.folders.map((f) => f.name), ['Audit (2)']);
              restored.dispose();
            case 'stamp':
              final restored = StampService();
              await restored.init();
              expect(
                restored.stamps.firstWhere((s) => s.id == assetId).folderId,
                isNull,
              );
              expect(restored.folders.map((f) => f.name), ['Audit (2)']);
              restored.dispose();
          }
        });
      },
    );
  }
}
