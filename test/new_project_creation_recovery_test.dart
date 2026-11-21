import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingCreation extends ProjectService {
  var pending = Completer<Project>();
  var calls = 0;

  @override
  Future<Project> createProject({
    required String name,
    required int fps,
    required int durationSeconds,
    required int backgroundColor,
    int exportWidth = 1920,
    int exportHeight = 1080,
    double drawingAreaScale = 1.0,
    List<String>? enabledAutofillPresetIds,
  }) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'creation prevents double submission and retains input after failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
      });
      final directory = Directory.systemTemp.createTempSync(
        'creation_recovery_',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final service = _PendingCreation();
      addTearDown(service.dispose);
      final providers = await tester.runAsync(buildAppProviders);
      appRouter.go('/new-project');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...providers!,
            ChangeNotifierProvider<ProjectService>.value(value: service),
          ],
          child: const NiarimApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Keep this name');
      await tester.ensureVisible(find.text('作成'));
      await tester.tap(find.text('作成'));
      await tester.tap(find.text('作成'));
      await tester.pump();
      expect(service.calls, 1);
      final busy = find.text('作成しています…');
      expect(busy, findsOneWidget);
      final button = find.ancestor(
        of: busy,
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      service.pending.completeError(
        const FileSystemException('storage unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('プロジェクトを保存できませんでした'), findsOneWidget);
      expect(find.text('Keep this name'), findsOneWidget);
      expect(tester.takeException(), isNull);
      service.pending = Completer<Project>();
      await tester.ensureVisible(find.text('作成'));
      await tester.tap(find.text('作成'));
      await tester.pump();
      expect(service.calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      service.pending.complete(
        Project(
          id: 'completed-after-leaving',
          name: 'Keep this name',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          totalWorkSeconds: 0,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
