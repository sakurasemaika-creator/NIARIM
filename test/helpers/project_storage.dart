import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gives service and canvas tests a real, isolated location for initial saves.
/// Call before registering tests; tests that exercise storage failures supply
/// their own path-provider handler instead.
void useTemporaryProjectStorage() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('niarim-project-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    // Existing mutations may have queued background saves. Allow an in-flight
    // filesystem operation to finish if it races directory cleanup.
    for (var attempt = 0; directory.existsSync(); attempt++) {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 39 || attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });
}
