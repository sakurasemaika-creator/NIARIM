import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ホーム画面ウィジェットの種類。
enum HomeWidgetKind {
  /// 好きな作品のフレーム1枚を表示し、タップでその作品を開く。
  artwork,

  /// ワンタップで「作品をつくる」（新規プロジェクト）へ。
  create,

  /// ワンタップで「作品広場」へ。
  plaza,
}

/// ウィジェットのタップで開くアプリ内のルート。
///
/// ネイティブ側（AppWidgetProvider）はこの文字列をPendingIntentのextraへ
/// 載せてMainActivityを起動し、Flutter側がgo_routerのpushへ橋渡しする。
/// ネイティブとDartで文字列を二重管理すると片方の変更に気付けないため、
/// 生成もここへ集約する。
String homeWidgetRoute(HomeWidgetKind kind) => switch (kind) {
  // 作品ウィジェットは「作品を眺めるための飾り」で、タップは
  // 「NIARIMを開く」という意味にする。表示している作品の編集画面へ
  // いきなり飛ばさない（ホーム画面から不意に編集画面へ入るより、
  // 通常の起動と同じ入口に着地するほうが迷わないため）。
  HomeWidgetKind.artwork => '/',
  HomeWidgetKind.create => '/new-project',
  HomeWidgetKind.plaza => '/community',
};

/// ホーム画面ウィジェットの設定（どの作品を出すか・背景色）を保持する。
///
/// ## なぜ動画ではなく静止画なのか
///
/// Androidのホーム画面ウィジェットは`RemoteViews`で描画され、使えるのは
/// ImageView/TextView等の限られた部品だけで、**動画再生もWebViewも一切
/// できない**。したがってYouTube動画をウィジェット内で再生することは
/// 規約以前に技術的に不可能で、ローカルの自作作品のフレーム1枚を静止画
/// として出す形にしている。
///
/// `RemoteViews`の自動更新間隔の下限は30分（`updatePeriodMillis`）なので、
/// パラパラ動かすこともしない。
///
/// ## 色について
///
/// 背景色は任意のARGBを保存できる（`RemoteViews.setInt`は任意の色を
/// 受け取れるため、プリセットに限定する必要がない）。既定は「アプリの
/// テーマカラーに追従」で、[backgroundColor]がnullのときがその状態。
class HomeWidgetService extends ChangeNotifier {
  static const _prefsKey = 'home_widget_config_v1';

  String? _projectId;
  int? _backgroundColor;

  /// 作品ウィジェットに表示するプロジェクトのID。未選択ならnull。
  String? get projectId => _projectId;

  /// ウィジェットの背景色（ARGB）。nullなら「アプリのテーマカラーに追従」。
  int? get backgroundColor => _backgroundColor;

  /// テーマ追従かどうか。
  bool get followsTheme => _backgroundColor == null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _projectId = json['projectId'] as String?;
      _backgroundColor = json['backgroundColor'] as int?;
    } catch (_) {
      // 壊れた設定で起動できなくなるほうが害が大きいので、既定値へ倒す。
      _projectId = null;
      _backgroundColor = null;
    }
  }

  Future<void> selectProject(String? projectId) async {
    _projectId = (projectId != null && projectId.isEmpty) ? null : projectId;
    notifyListeners();
    await _persist();
  }

  /// 背景色を指定する。nullを渡すと「アプリのテーマカラーに追従」へ戻す。
  Future<void> setBackgroundColor(int? argb) async {
    _backgroundColor = argb;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'projectId': _projectId,
        'backgroundColor': _backgroundColor,
      }),
    );
  }

  /// ネイティブ側へ渡す値をまとめる。
  ///
  /// [themeColor]はアプリの現在のテーマカラー。テーマ追従のときはこれを
  /// そのまま背景色として使う。
  Map<String, Object?> widgetPayload({
    required int themeColor,
    String? thumbnailPath,
    String? projectName,
  }) => {
    'backgroundColor': _backgroundColor ?? themeColor,
    'projectId': _projectId ?? '',
    'projectName': projectName ?? '',
    'thumbnailPath': thumbnailPath ?? '',
    'routeArtwork': homeWidgetRoute(HomeWidgetKind.artwork),
    'routeCreate': homeWidgetRoute(HomeWidgetKind.create),
    'routePlaza': homeWidgetRoute(HomeWidgetKind.plaza),
  };
}
