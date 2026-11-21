import 'dart:io';

/// AdMob・アプリ内課金のネイティブ実装が存在する実行環境かどうか。
bool get supportsMobilePluginRuntime => Platform.isAndroid || Platform.isIOS;
