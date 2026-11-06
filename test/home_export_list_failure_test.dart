import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('failed export prefetch is nonfatal and works can retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
    });
    final directory = Directory.systemTemp.createTempSync(
      'export_list_failure_',
    );
    var failDocuments = true;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (failDocuments &&
              call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'a failed background prefetch must not escape',
    );
    await tester.tap(find.text('作品をつくる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品一覧'));
    await tester.pumpAndSettle();
    expect(find.text('作品一覧を読み込めませんでした'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    failDocuments = false;
    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();
    expect(find.text('書き出した作品がありません'), findsOneWidget);
    expect(find.text('作品一覧を読み込めませんでした'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 保存先を読めなかったとき、プロジェクトの一覧は空に見えるだけで何も
  // 知らされず、読み直すこともできなかった（作品が消えたように見えた）。
  testWidgets('projects that could not be loaded are reported and retried', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
    });
    final directory = Directory.systemTemp.createTempSync(
      'project_list_failure_',
    );
    var failDocuments = false;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (failDocuments &&
              call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    // 保存先が読めるうちに作品を1つ保存しておく。
    await tester.runAsync(() async {
      final service = ProjectService();
      await service.createProject(
        name: '残っている作品',
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      service.dispose();
    });
    failDocuments = true;
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品をつくる'));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトを読み込めませんでした'), findsOneWidget);
    expect(find.text('残っている作品'), findsNothing);

    failDocuments = false;
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('homeProjectsLoadFailed')),
        matching: find.text('再試行'),
      ),
    );
    // 読み直しは実際のファイルを読むので、実時間で待つ。
    for (var i = 0; i < 20 && find.text('残っている作品').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトを読み込めませんでした'), findsNothing);
    expect(find.text('残っている作品'), findsOneWidget);

    // 読み直しても同じ作品が二重にならない。
    final service = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    await tester.runAsync(service.retryLoadProjects);
    await tester.pumpAndSettle();
    expect(service.projects.where((p) => p.name == '残っている作品'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
