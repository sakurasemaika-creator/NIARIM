import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'home_widget_service.dart';

/// ホーム画面ウィジェットとアプリの橋渡し。
///
/// - ウィジェットへ表示内容（背景色・作品名・サムネイルのパス・タップ先の
///   ルート）を書き出し、再描画を要求する
/// - ウィジェットのタップで指定されたルートを受け取る
///
/// ネイティブ側の実装は`NiarimWidgetProviders.kt`。
class HomeWidgetBridge {
  static const _channel = MethodChannel('com.niarim.niarim/home_widget_route');

  /// 各ウィジェットのプロバイダークラス名（ネイティブと一致させること）。
  static const _providers = [
    'NiarimArtworkWidgetProvider',
    'NiarimCreateWidgetProvider',
    'NiarimPlazaWidgetProvider',
  ];

  /// ウィジェットのタップで開くルートが届いたときに呼ばれる。
  ValueChanged<String>? onRoute;

  /// 起動時に一度だけ呼ぶ。
  ///
  /// アプリが起動しきる前にウィジェットのIntentが届くため、
  /// 「起動時に溜まっていたルート」を取りに行くのと、
  /// 「起動後に届くルート」を待ち受けるのの両方が要る。
  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetRoute') {
        final route = call.arguments;
        if (route is String && route.isNotEmpty) onRoute?.call(route);
      }
      return null;
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialRoute');
      if (initial != null && initial.isNotEmpty) onRoute?.call(initial);
    } on MissingPluginException {
      // Android以外・テスト環境ではチャンネルが無い。ウィジェットが無い
      // だけでアプリは動くので、握りつぶして続行する。
    }
  }

  /// ウィジェットの表示内容を更新する。
  ///
  /// [themeColor]はアプリの現在のテーマカラー。
  /// [HomeWidgetService]が「テーマ追従」設定のときはこれが背景色になる。
  Future<void> update(
    HomeWidgetService service, {
    required int themeColor,
    required int themeForegroundColor,
    String? thumbnailPath,
    String? projectName,
    Map<HomeWidgetKind, Map<ShortcutWidgetShape, String>>? shortcutImagePaths,
  }) async {
    final payload = service.widgetPayload(
      themeColor: themeColor,
      themeForegroundColor: themeForegroundColor,
      thumbnailPath: thumbnailPath,
      projectName: projectName,
      shortcutImagePaths: shortcutImagePaths,
    );
    try {
      for (final entry in payload.entries) {
        await HomeWidget.saveWidgetData(entry.key, entry.value);
      }
      for (final provider in _providers) {
        await HomeWidget.updateWidget(name: provider, androidName: provider);
      }
    } on PlatformException catch (e) {
      // ウィジェットが1つも置かれていない端末では更新要求が失敗しうる。
      // 失敗してもアプリ本体の動作には影響しないので落とさない。
      debugPrint('ホーム画面ウィジェットの更新に失敗: ${e.message}');
    } on MissingPluginException {
      // 同上（テスト環境など）。
    }
  }
}
