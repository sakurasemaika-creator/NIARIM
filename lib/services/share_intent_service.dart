import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/archive_security.dart';
import '../utils/app_error_reporter.dart';

/// The largest file opened from another app: as large as a received work may
/// be on this device ([ArchiveLimits.receivedWork], tied to its memory).
int maxShareIntentBytes() => ArchiveLimits.receivedWork.compressedBytes;

enum SharedFileReadFailure { tooLarge, noSpace, unreadable }

/// A file opened from another app that could not be taken in.
class SharedFileReadException implements Exception {
  const SharedFileReadException(this.failure, {this.bytes});

  final SharedFileReadFailure failure;

  /// [SharedFileReadFailure.tooLarge]: the largest file this device opens.
  /// [SharedFileReadFailure.noSpace]: how much more free space it needs.
  final int? bytes;

  @override
  String toString() => 'SharedFileReadException($failure, $bytes)';
}

/// .niashare のOSレベル受信（他アプリ/ファイラーからのタップで開く）を扱うサービス。
/// ネイティブ側（MainActivity.kt）とMethodChannelで連携する。
class ShareIntentService {
  static const MethodChannel _channel = MethodChannel(
    'com.niarim.niarim/share_intent',
  );

  /// The folder in the app's cache that holds the copies of opened files
  /// while they are read ("全データを削除" empties the cache with it).
  static const intakeFolderName = 'shared_intake';

  /// チャンネルのハンドラーを今持っているインスタンス。チャンネルは
  /// アプリで1つなので、後から作ったインスタンスのハンドラーを古い
  /// インスタンスのdisposeで外さないようにする。
  static ShareIntentService? _handlerOwner;

  static int _copySerial = 0;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Removing the copies a previous run left behind (the app was closed
  /// while one was read); a new copy waits for it.
  Future<void>? _sweep;

  /// アプリ起動中（ウォームスタート）に共有ファイルが開かれた際に発火する。
  Stream<String> get onFileReceived => _controller.stream;

  /// コールドスタート時（アプリが共有ファイルのタップで起動された場合）のURI。
  /// init()完了後に一度だけ消費すること。
  String? pendingInitialUri;

  Future<void> init() async {
    _handlerOwner = this;
    _channel.setMethodCallHandler(_handleMethodCall);
    // Not awaited: starting the app does not wait for the clean-up.
    _sweep = _removeLeftCopies();
    try {
      pendingInitialUri = await _channel.invokeMethod<String>('getInitialUri');
    } on PlatformException {
      pendingInitialUri = null;
    } on MissingPluginException {
      // Android実機以外（Web/デスクトップ開発時）はネイティブ実装が存在しないため無視する
      pendingInitialUri = null;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSharedFile') {
      final uri = call.arguments as String?;
      if (uri != null) _controller.add(uri);
    }
    return null;
  }

  static Future<Directory> _intakeFolder() async => Directory(
    '${(await getApplicationCacheDirectory()).path}/'
    '$intakeFolderName',
  );

  Future<void> _removeLeftCopies() async {
    try {
      final folder = await _intakeFolder();
      if (await folder.exists()) await folder.delete(recursive: true);
    } on MissingPluginException {
      // No app folders on this platform (tests): nothing was copied.
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
  }

  /// Copies the file at the content:// [uri] into the app's cache a chunk at
  /// a time (neither side holds the whole file in memory) and returns the
  /// copy. The caller reads the work from it and deletes it with
  /// [discardCopy]. A file over [maxShareIntentBytes], or one the free space
  /// cannot hold, throws [SharedFileReadException] and leaves no copy.
  Future<File> copyUriToCache(String uri) async {
    await _sweep;
    final File copy;
    try {
      final folder = await _intakeFolder();
      await folder.create(recursive: true);
      copy = File(
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}-'
        '${_copySerial++}.niashare',
      );
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      throw const SharedFileReadException(SharedFileReadFailure.unreadable);
    }
    final limit = maxShareIntentBytes();
    try {
      final copied = await _channel.invokeMethod<int>('copyUri', {
        'uri': uri,
        'path': copy.path,
        'maxBytes': limit,
      });
      // What is read is the copy on disk, whatever the platform reported.
      final length = await copy.length();
      if (length > limit) {
        throw SharedFileReadException(
          SharedFileReadFailure.tooLarge,
          bytes: limit,
        );
      }
      if (copied == null || length == 0) {
        throw const SharedFileReadException(SharedFileReadFailure.unreadable);
      }
      return copy;
    } catch (error) {
      await discardCopy(copy);
      if (error is SharedFileReadException) rethrow;
      if (error is PlatformException) {
        throw switch (error.code) {
          'FILE_TOO_LARGE' => SharedFileReadException(
            SharedFileReadFailure.tooLarge,
            bytes: limit,
          ),
          'NO_SPACE' => SharedFileReadException(
            SharedFileReadFailure.noSpace,
            bytes: (error.details as num?)?.toInt(),
          ),
          _ => const SharedFileReadException(SharedFileReadFailure.unreadable),
        };
      }
      // MissingPluginException (no native side), or the copy vanished.
      throw const SharedFileReadException(SharedFileReadFailure.unreadable);
    }
  }

  /// Deletes a copy made by [copyUriToCache] (nothing when it is gone).
  static Future<void> discardCopy(File copy) async {
    try {
      if (await copy.exists()) await copy.delete();
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
  }

  /// Waits for the clean-up started by [init] (tests).
  @visibleForTesting
  Future<void> get leftCopiesRemoved => _sweep ?? Future<void>.value();

  void dispose() {
    if (identical(_handlerOwner, this)) {
      _handlerOwner = null;
      _channel.setMethodCallHandler(null);
    }
    _controller.close();
  }
}
