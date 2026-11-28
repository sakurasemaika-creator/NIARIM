// A file opened from another app's share menu is copied into the app's cache
// by the platform side a chunk at a time (no byte array crosses the channel),
// up to what a received work may be on this device, and the copy is removed
// whatever happens to it.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/archive_security.dart';
import 'package:niarim/services/share_intent_service.dart';

const _shareChannel = MethodChannel('com.niarim.niarim/share_intent');
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _mib = 1024 * 1024;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory cache;
  late Directory intake;

  /// What the platform side is asked: the arguments of each `copyUri`.
  late List<Map<Object?, Object?>> calls;

  /// How the platform side answers a copy (writes the file, or throws).
  late Object? Function(String path, int maxBytes) platform;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('share-intake-');
    intake = Directory('${cache.path}/${ShareIntentService.intakeFolderName}');
    calls = [];
    platform = (path, maxBytes) => throw StateError('no answer');
    messenger.setMockMethodCallHandler(
      _pathChannel,
      (call) async => cache.path,
    );
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      switch (call.method) {
        case 'getInitialUri':
          return null;
        case 'copyUri':
          final args = call.arguments as Map<Object?, Object?>;
          calls.add(args);
          return platform(args['path']! as String, args['maxBytes']! as int);
      }
      throw MissingPluginException();
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pathChannel, null);
    messenger.setMockMethodCallHandler(_shareChannel, null);
    ArchiveSecurity.debugReceivedWorkBudget = null;
    if (cache.existsSync()) cache.deleteSync(recursive: true);
  });

  /// A file of [length] bytes at [path] without writing its bytes (sparse).
  void writeSparse(String path, int length) {
    File(path).openSync(mode: FileMode.write)
      ..truncateSync(length)
      ..closeSync();
  }

  Future<SharedFileReadException> refusal(Future<File> copy) async {
    try {
      await copy;
    } on SharedFileReadException catch (error) {
      return error;
    }
    fail('the copy was not refused');
  }

  test('the limit follows the received-work budget of this device', () {
    ArchiveSecurity.debugReceivedWorkBudget = 1536 * _mib;
    expect(maxShareIntentBytes(), 1536 * _mib);
    expect(maxShareIntentBytes(), ArchiveLimits.receivedWork.compressedBytes);
    // Never below the fixed limit of received archives.
    ArchiveSecurity.debugReceivedWorkBudget = 16 * _mib;
    expect(maxShareIntentBytes(), ArchiveLimits.received.compressedBytes);
  });

  test(
    'a file over 128 MB is copied into the cache and read from there',
    () async {
      ArchiveSecurity.debugReceivedWorkBudget = 1024 * _mib;
      final service = ShareIntentService();
      await service.init();
      const length = 300 * _mib;
      platform = (path, maxBytes) {
        expect(maxBytes, 1024 * _mib);
        writeSparse(path, length);
        // Only the number of bytes written comes back, never the bytes.
        return length;
      };
      final copy = await service.copyUriToCache('content://files/big.niashare');
      expect(calls.single['uri'], 'content://files/big.niashare');
      expect(copy.path, startsWith('${intake.path}/'));
      expect(copy.path, endsWith('.niashare'));
      expect(copy.lengthSync(), length);

      // Two shares in a row get copies of their own.
      final second = await service.copyUriToCache('content://files/b.niashare');
      expect(second.path, isNot(copy.path));

      await ShareIntentService.discardCopy(copy);
      await ShareIntentService.discardCopy(second);
      expect(intake.listSync(), isEmpty);
      // Deleting a copy that is already gone is not an error.
      await ShareIntentService.discardCopy(copy);
      service.dispose();
    },
  );

  test(
    'a file over the budget is refused with the limit and leaves no copy',
    () async {
      ArchiveSecurity.debugReceivedWorkBudget = 512 * _mib;
      final service = ShareIntentService();
      await service.init();

      // The platform side stops copying past the limit.
      platform = (path, maxBytes) {
        writeSparse(path, 8 * _mib);
        throw PlatformException(code: 'FILE_TOO_LARGE');
      };
      var error = await refusal(service.copyUriToCache('content://x/a'));
      expect(error.failure, SharedFileReadFailure.tooLarge);
      expect(error.bytes, 512 * _mib);
      expect(intake.listSync(), isEmpty);

      // A copy larger than the limit is refused whatever the platform reported.
      platform = (path, maxBytes) {
        writeSparse(path, maxBytes + 1);
        return 1;
      };
      error = await refusal(service.copyUriToCache('content://x/b'));
      expect(error.failure, SharedFileReadFailure.tooLarge);
      expect(error.bytes, 512 * _mib);
      expect(intake.listSync(), isEmpty);
      service.dispose();
    },
  );

  test(
    'too little free space, unreadable and empty files leave no copy',
    () async {
      final service = ShareIntentService();
      await service.init();

      platform = (path, maxBytes) {
        writeSparse(path, _mib);
        throw PlatformException(code: 'NO_SPACE', details: 700 * _mib);
      };
      var error = await refusal(service.copyUriToCache('content://x/a'));
      expect(error.failure, SharedFileReadFailure.noSpace);
      expect(error.bytes, 700 * _mib);
      expect(intake.listSync(), isEmpty);

      platform = (path, maxBytes) =>
          throw PlatformException(code: 'READ_FAILED');
      error = await refusal(service.copyUriToCache('content://x/b'));
      expect(error.failure, SharedFileReadFailure.unreadable);

      platform = (path, maxBytes) {
        writeSparse(path, 0);
        return 0;
      };
      error = await refusal(service.copyUriToCache('content://x/c'));
      expect(error.failure, SharedFileReadFailure.unreadable);
      expect(intake.listSync(), isEmpty);

      // The platform side said it copied but left nothing.
      platform = (path, maxBytes) => 10;
      error = await refusal(service.copyUriToCache('content://x/d'));
      expect(error.failure, SharedFileReadFailure.unreadable);

      // No platform side (not Android).
      messenger.setMockMethodCallHandler(_shareChannel, null);
      error = await refusal(service.copyUriToCache('content://x/e'));
      expect(error.failure, SharedFileReadFailure.unreadable);
      expect(intake.listSync(), isEmpty);
      service.dispose();
    },
  );

  test('copies a previous run left behind are removed on start', () async {
    intake.createSync(recursive: true);
    final left = File('${intake.path}/1-0.niashare')..writeAsBytesSync([1, 2]);
    final other = File('${cache.path}/thumb.bin')..writeAsBytesSync([3]);
    platform = (path, maxBytes) {
      File(path).writeAsBytesSync([1, 2, 3]);
      return 3;
    };
    final service = ShareIntentService();
    await service.init();
    // A share opened right away waits for the clean-up, so its copy stays.
    final copy = await service.copyUriToCache('content://x/a');
    expect(left.existsSync(), isFalse);
    expect(copy.existsSync(), isTrue);
    expect(intake.listSync().single.path, copy.path);
    // Nothing else in the cache is touched.
    expect(other.existsSync(), isTrue);
    await ShareIntentService.discardCopy(copy);
    service.dispose();

    // Starting again with nothing left behind is quiet.
    final again = ShareIntentService();
    await again.init();
    await again.leftCopiesRemoved;
    expect(intake.existsSync(), isFalse);
    again.dispose();
  });
}
