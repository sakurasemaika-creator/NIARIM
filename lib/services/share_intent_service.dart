import 'dart:async';

import 'package:flutter/services.dart';

// Match maxSharedFileBytes in MainActivity's share-intent reader.
const maxShareIntentBytes = 128 * 1024 * 1024;

enum SharedFileReadFailure implements Exception { tooLarge, unreadable }

/// .niashare のOSレベル受信（他アプリ/ファイラーからのタップで開く）を扱うサービス。
/// ネイティブ側（MainActivity.kt）とMethodChannelで連携する。
class ShareIntentService {
  static const MethodChannel _channel = MethodChannel(
    'com.niarim.niarim/share_intent',
  );

  /// チャンネルのハンドラーを今持っているインスタンス。チャンネルは
  /// アプリで1つなので、後から作ったインスタンスのハンドラーを古い
  /// インスタンスのdisposeで外さないようにする。
  static ShareIntentService? _handlerOwner;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// アプリ起動中（ウォームスタート）に共有ファイルが開かれた際に発火する。
  Stream<String> get onFileReceived => _controller.stream;

  /// コールドスタート時（アプリが共有ファイルのタップで起動された場合）のURI。
  /// init()完了後に一度だけ消費すること。
  String? pendingInitialUri;

  Future<void> init() async {
    _handlerOwner = this;
    _channel.setMethodCallHandler(_handleMethodCall);
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

  /// content:// スキームのURIからバイト列を読み出す（ContentResolver経由）。
  Future<Uint8List> readUriBytes(String uri) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('readUri', {
        'uri': uri,
      });
      if (bytes == null || bytes.isEmpty) {
        throw SharedFileReadFailure.unreadable;
      }
      if (bytes.length > maxShareIntentBytes) {
        throw SharedFileReadFailure.tooLarge;
      }
      return bytes;
    } on PlatformException catch (error) {
      throw error.code == 'FILE_TOO_LARGE'
          ? SharedFileReadFailure.tooLarge
          : SharedFileReadFailure.unreadable;
    } on MissingPluginException {
      throw SharedFileReadFailure.unreadable;
    }
  }

  void dispose() {
    if (identical(_handlerOwner, this)) {
      _handlerOwner = null;
      _channel.setMethodCallHandler(null);
    }
    _controller.close();
  }
}
