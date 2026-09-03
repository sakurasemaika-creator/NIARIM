import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ホーム画面ウィジェットの種類。
enum HomeWidgetKind {
  /// 好きな作品の、選んだフレーム1枚を表示し、タップでNIARIMを開く。
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

/// ホーム画面ウィジェットの設定（どのフレームを出すか・種類ごとの背景色）を
/// 保持する。
///
/// ## なぜ動画ではなく静止画なのか
///
/// Androidのホーム画面ウィジェットは`RemoteViews`で描画され、使えるのは
/// ImageView/TextView等の限られた部品だけで、**動画再生もWebViewも一切
/// できない**。したがってYouTube動画をウィジェット内で再生することは
/// 規約以前に技術的に不可能で、ローカルの自作作品の**選んだフレーム1枚**を
/// 静止画として出す形にしている。
///
/// `RemoteViews`の自動更新間隔の下限は30分（`updatePeriodMillis`）なので、
/// パラパラ動かすこともしない。
///
/// ## 色について
///
/// 色は**ウィジェットの種類ごとに独立**して持つ（`Map<HomeWidgetKind,
/// int>`）。3種類を並べて置いたときに色を変えて見分けたい、という使い方が
/// できるようにするため。背景色（[backgroundColorOf]）に加えて、アイコンと
/// 文字の色（[foregroundColorOf]）も指定できる。背景だけ変えられると、
/// 濃い背景に濃い文字といった読めない組み合わせになりうるため。
/// 任意のARGBを保存でき、既定は「アプリのテーマカラーに追従」
/// （その種類の色がnullのときがその状態）。
///
/// なお[HomeWidgetKind.artwork]の色は設定画面から変更する手段を設けて
/// いない（作品ウィジェットは「どのフレームを出すか」だけを選ぶ設計とした
/// ため）。データ構造自体は3種類共通のままにしてあるので、値は常に
/// 未設定＝テーマ追従になる。
class HomeWidgetService extends ChangeNotifier {
  static const _prefsKey = 'home_widget_config_v1';

  String? _projectId;
  String? _sceneId;
  int? _frameIndex;

  /// 種類ごとの背景色（ARGB）。値が無い種類は「テーマカラーに追従」。
  final Map<HomeWidgetKind, int> _backgroundColors = {};

  /// 種類ごとのアイコン・文字の色（ARGB）。値が無い種類はテーマ追従
  /// （＝テーマの「メニュー背景色」）。
  final Map<HomeWidgetKind, int> _foregroundColors = {};

  /// 作品ウィジェットに表示するプロジェクトのID。未選択ならnull。
  String? get projectId => _projectId;

  /// 表示するシーンのID。[projectId]がnullなら意味を持たない。
  /// projectIdはあるがsceneIdがnullの場合（種類ごとのフレーム選択を
  /// 導入する前の設定からの移行）は、そのプロジェクトの先頭シーンを表す。
  String? get sceneId => _sceneId;

  /// 表示するフレームのインデックス（0始まり）。[sceneId]と同様、
  /// nullは「先頭フレーム」を表す。
  int? get frameIndex => _frameIndex;

  /// [kind]の背景色（ARGB）。nullなら「アプリのテーマカラーに追従」。
  int? backgroundColorOf(HomeWidgetKind kind) => _backgroundColors[kind];

  /// [kind]のアイコン・文字の色（ARGB）。nullなら「テーマに追従」。
  int? foregroundColorOf(HomeWidgetKind kind) => _foregroundColors[kind];

  /// [kind]がテーマ追従かどうか。背景色を指定した時点で「色を指定する」
  /// 状態とみなす（文字色は、その状態のときだけ追加で選べる）。
  bool followsTheme(HomeWidgetKind kind) =>
      !_backgroundColors.containsKey(kind);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _projectId = json['projectId'] as String?;
      _sceneId = json['sceneId'] as String?;
      _frameIndex = json['frameIndex'] as int?;
      final foregrounds = json['foregroundColors'];
      if (foregrounds is Map) {
        for (final kind in HomeWidgetKind.values) {
          final value = foregrounds[kind.name];
          if (value is int) _foregroundColors[kind] = value;
        }
      }
      final colors = json['backgroundColors'];
      if (colors is Map) {
        for (final kind in HomeWidgetKind.values) {
          final value = colors[kind.name];
          if (value is int) _backgroundColors[kind] = value;
        }
      } else {
        // 種類ごとの色を持つ前は3種類で1つの色を共有していた。
        // 既に色を選んでいた人の設定が消えないよう、全種類へ引き継ぐ。
        final legacy = json['backgroundColor'];
        if (legacy is int) {
          for (final kind in HomeWidgetKind.values) {
            _backgroundColors[kind] = legacy;
          }
        }
      }
    } catch (_) {
      // 壊れた設定で起動できなくなるほうが害が大きいので、既定値へ倒す。
      _projectId = null;
      _sceneId = null;
      _frameIndex = null;
      _backgroundColors.clear();
      _foregroundColors.clear();
    }
  }

  /// 起動画面ウィジェットに表示するフレームを選ぶ。
  ///
  /// [projectId]がnull（または空文字）なら「作品を選んでいません」の
  /// 状態に戻す（[sceneId]・[frameIndex]も一緒にクリアする）。
  Future<void> selectArtwork({
    String? projectId,
    String? sceneId,
    int? frameIndex,
  }) async {
    if (projectId == null || projectId.isEmpty) {
      _projectId = null;
      _sceneId = null;
      _frameIndex = null;
    } else {
      _projectId = projectId;
      _sceneId = sceneId;
      _frameIndex = frameIndex;
    }
    notifyListeners();
    await _persist();
  }

  /// [kind]の背景色を指定する。nullを渡すと「テーマカラーに追従」へ戻す
  /// （文字色の指定も一緒に解除する。背景がテーマ追従に戻ったのに文字色
  /// だけ残っていると、意図しない組み合わせになるため）。
  Future<void> setBackgroundColor(HomeWidgetKind kind, int? argb) async {
    if (argb == null) {
      _backgroundColors.remove(kind);
      _foregroundColors.remove(kind);
    } else {
      _backgroundColors[kind] = argb;
    }
    notifyListeners();
    await _persist();
  }

  /// [kind]のアイコン・文字の色を指定する。nullでテーマ追従へ戻す。
  Future<void> setForegroundColor(HomeWidgetKind kind, int? argb) async {
    if (argb == null) {
      _foregroundColors.remove(kind);
    } else {
      _foregroundColors[kind] = argb;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'projectId': _projectId,
        'sceneId': _sceneId,
        'frameIndex': _frameIndex,
        'backgroundColors': {
          for (final e in _backgroundColors.entries) e.key.name: e.value,
        },
        'foregroundColors': {
          for (final e in _foregroundColors.entries) e.key.name: e.value,
        },
      }),
    );
  }

  /// ネイティブ側が読む設定値のキー（Kotlin側と一致させること）。
  static String backgroundColorKey(HomeWidgetKind kind) =>
      'backgroundColor_${kind.name}';

  /// ネイティブ側が読むアイコン・文字色のキー（Kotlin側と一致させること）。
  static String foregroundColorKey(HomeWidgetKind kind) =>
      'foregroundColor_${kind.name}';

  /// ショートカットウィジェット（作品をつくる／作品広場）の意匠を焼いた
  /// PNGのパスを渡すキー（Kotlin側と一致させること）。
  static String shortcutImageKey(HomeWidgetKind kind) =>
      'shortcutImage_${kind.name}';

  /// ネイティブ側へ渡す値をまとめる。
  ///
  /// [themeColor]はアプリの現在のテーマカラー。テーマ追従の種類はこれを
  /// そのまま背景色として使う。[themeForegroundColor]は同じくテーマ追従の
  /// ときのアイコン・文字色（テーマの「メニュー背景色」）。[thumbnailPath]は選んだフレームを実際に
  /// 描画したPNGのパス（呼び出し側で`frame_thumbnail_renderer.dart`を
  /// 使って用意する。このサービス自体はDartの`dart:ui`合成処理へ依存させ
  /// たくないため関与しない）。
  ///
  /// [shortcutImagePaths]は「作品をつくる」「作品広場」ウィジェットの意匠を
  /// 起動画面のボタンと同じデザインで焼いたPNGのパス
  /// （`shortcut_widget_renderer.dart`が用意する）。ネイティブ側はこれが
  /// あればそのまま表示し、無ければアイコン＋ラベルの簡易表示へ倒す。
  Map<String, Object?> widgetPayload({
    required int themeColor,
    required int themeForegroundColor,
    String? thumbnailPath,
    String? projectName,
    Map<HomeWidgetKind, String>? shortcutImagePaths,
  }) => {
    for (final kind in HomeWidgetKind.values)
      backgroundColorKey(kind): _backgroundColors[kind] ?? themeColor,
    for (final kind in HomeWidgetKind.values)
      foregroundColorKey(kind): _foregroundColors[kind] ?? themeForegroundColor,
    for (final kind in HomeWidgetKind.values)
      shortcutImageKey(kind): shortcutImagePaths?[kind] ?? '',
    'projectId': _projectId ?? '',
    'projectName': projectName ?? '',
    'thumbnailPath': thumbnailPath ?? '',
    'routeArtwork': homeWidgetRoute(HomeWidgetKind.artwork),
    'routeCreate': homeWidgetRoute(HomeWidgetKind.create),
    'routePlaza': homeWidgetRoute(HomeWidgetKind.plaza),
  };
}
