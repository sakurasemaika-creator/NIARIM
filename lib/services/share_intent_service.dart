import 'dart:async';
import 'package:flutter/services.dart';

/// .niashare のOSレベル受信（他アプリ/ファイラーからのタップで開く）を扱うサービス。
/// ネイティブ側（MainActivity.kt）とMethodChannelで連携する。
class ShareIntentService {
  static const MethodChannel _channel =
      MethodChannel('com.niarim.niarim/share_intent');

  final StreamController<String> _controller = StreamController<String>.broadcast();

  /// アプリ起動中（ウォームスタート）に共有ファイルが開かれた際に発火する。
  Stream<String> get onFileReceived => _controller.stream;

  /// コールドスタート時（アプリが共有ファイルのタップで起動された場合）のURI。
  /// init()完了後に一度だけ消費すること。
  String? pendingInitialUri;

  Future<void> init() async {
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
  Future<Uint8List?> readUriBytes(String uri) async {
    try {
      return await _channel.invokeMethod<Uint8List>('readUri', {'uri': uri});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  void dispose() => _controller.close();
}
