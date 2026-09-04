import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'frame_thumbnail_renderer.dart';
import 'home_widget_bridge.dart';
import 'home_widget_service.dart';
import 'project_service.dart';
import 'shortcut_widget_renderer.dart';
import 'theme_service.dart';

/// テーマ変更・作品選択変更・フレーム選択変更のいずれでも、ホーム画面
/// ウィジェットの表示内容を実際に書き出し直すための共通処理。
///
/// `ThemeService`が変わったタイミングでも呼ぶ想定（テーマ追従設定の種類
/// だけ色が変わるが、追従していない種類でも作品名・サムネイルの更新は
/// 要るので常に書き出す）。起動画面ウィジェットの
/// [HomeWidgetService.projectId]が選ばれていれば、選んだフレームを実際に
/// 合成したPNGを都度焼き直して渡す（`saveArtworkWidgetThumbnail`。
/// プロジェクトの既定サムネイルではなく、ユーザーが選んだそのフレームを
/// 出すため）。
///
/// あわせて「作品をつくる」「作品広場」ウィジェットの意匠も、起動画面の
/// 2つの導線ボタンと同じデザインでPNGへ焼き直す
/// （`shortcut_widget_renderer.dart`。正方形・横長・縦長の3通り）。文言・アイコン・配色は
/// `splash_screen.dart`の`_SplashActionButton`の呼び出し側と1対1で
/// 対応させてあるので、片方を変えたらもう片方も変えること。
///
/// UI層（`widget_settings_screen.dart`・`widget_artwork_picker_screen.dart`）
/// の両方から呼ばれるため、それらのどちらにも依存しない独立ファイルに
/// してある（UI側どうしを互いにimportし合う循環を避けるため）。
Future<void> refreshHomeWidgets({
  required HomeWidgetService widgets,
  required ProjectService projects,
  required ThemeService theme,
  required AppLocalizations l10n,
}) async {
  final id = widgets.projectId;
  final project = id == null
      ? null
      : projects.projects.where((p) => p.id == id).firstOrNull;
  final thumbnailPath = id == null
      ? null
      : await saveArtworkWidgetThumbnail(
          projects,
          projectId: id,
          sceneId: widgets.sceneId,
          frameIndex: widgets.frameIndex,
        );

  // 置かれたマスの縦横比はユーザーが自由に変えられるので、3通りを焼いて
  // 渡し、ネイティブ側に選ばせる（`NiarimWidgetProviders.kt`）。
  final shortcutImagePaths =
      <HomeWidgetKind, Map<ShortcutWidgetShape, String>>{};
  for (final kind in const [HomeWidgetKind.create, HomeWidgetKind.plaza]) {
    for (final shape in ShortcutWidgetShape.values) {
      final path = await saveShortcutWidgetImage(
        kind: kind,
        icon: shortcutWidgetIcon(kind),
        label: shortcutWidgetLabel(l10n, kind),
        subLabel: shortcutWidgetSubLabel(l10n, kind),
        colors: shortcutWidgetColors(widgets, kind),
        foreground: shortcutWidgetForeground(widgets, theme, kind),
        shape: shape,
      );
      if (path != null) (shortcutImagePaths[kind] ??= {})[shape] = path;
    }
  }

  await HomeWidgetBridge().update(
    widgets,
    themeColor: theme.current.accentColor.toARGB32(),
    themeForegroundColor: theme.current.menuBgColor.toARGB32(),
    thumbnailPath: thumbnailPath,
    projectName: project?.name,
    shortcutImagePaths: shortcutImagePaths,
  );
}

/// ショートカットウィジェットのアイコン（起動画面のボタンと同じもの）。
IconData shortcutWidgetIcon(HomeWidgetKind kind) => switch (kind) {
  HomeWidgetKind.create => Icons.brush_outlined,
  HomeWidgetKind.plaza => Icons.movie_filter_outlined,
  HomeWidgetKind.artwork => Icons.image_outlined,
};

/// ショートカットウィジェットの1行目（起動画面のボタンと同じ文言）。
String shortcutWidgetLabel(AppLocalizations l10n, HomeWidgetKind kind) =>
    switch (kind) {
      HomeWidgetKind.create => l10n.splashCreateButton,
      HomeWidgetKind.plaza => l10n.splashCommunityButtonTitle,
      HomeWidgetKind.artwork => l10n.widgetSectionArtwork,
    };

/// ショートカットウィジェットの2行目。起動画面と同じく、作品広場だけが
/// 2行構成（「作品広場」＋「投稿作品をみる」）になる。
String? shortcutWidgetSubLabel(AppLocalizations l10n, HomeWidgetKind kind) =>
    kind == HomeWidgetKind.plaza ? l10n.splashCommunityButtonSubtitle : null;

/// ショートカットウィジェットのグラデーション2色。
///
/// 「テーマに合わせる」ときは起動画面のボタンとまったく同じ組み合わせ
/// （作品をつくる＝primary→primaryContainer、作品広場＝secondary→
/// secondaryContainer）。ユーザーが色を指定しているときは、その色を起点に
/// 白へ寄せた色を終点にして、同じグラデーションの見え方を保つ。
List<Color> shortcutWidgetColors(
  HomeWidgetService widgets,
  HomeWidgetKind kind,
) {
  final custom = widgets.backgroundColorOf(kind);
  if (custom != null) {
    final base = Color(custom);
    return [base, Color.lerp(base, Colors.white, 0.35)!];
  }
  final scheme = ThemeService.activeColorScheme;
  return kind == HomeWidgetKind.plaza
      ? [scheme.secondary, scheme.secondaryContainer]
      : [scheme.primary, scheme.primaryContainer];
}

/// ショートカットウィジェットのアイコン・文字の色。
///
/// 既定はテーマの「メニュー背景色」（起動画面の導線ボタンと同じ）。
/// 背景色を自分で選んだ種類では、文字色も個別に指定できる
/// （濃い背景に濃い文字、という読めない組み合わせを避けるため）。
Color shortcutWidgetForeground(
  HomeWidgetService widgets,
  ThemeService theme,
  HomeWidgetKind kind,
) {
  final custom = widgets.foregroundColorOf(kind);
  return custom != null ? Color(custom) : theme.current.menuBgColor;
}
