import 'frame_thumbnail_renderer.dart';
import 'home_widget_bridge.dart';
import 'home_widget_service.dart';
import 'project_service.dart';
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
/// UI層（`widget_settings_screen.dart`・`widget_artwork_picker_screen.dart`）
/// の両方から呼ばれるため、それらのどちらにも依存しない独立ファイルに
/// してある（UI側どうしを互いにimportし合う循環を避けるため）。
Future<void> refreshHomeWidgets({
  required HomeWidgetService widgets,
  required ProjectService projects,
  required ThemeService theme,
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
  await HomeWidgetBridge().update(
    widgets,
    themeColor: theme.current.accentColor.toARGB32(),
    thumbnailPath: thumbnailPath,
    projectName: project?.name,
  );
}
