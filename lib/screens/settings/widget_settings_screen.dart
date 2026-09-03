import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/font_fallback.dart';
import '../../l10n/app_localizations.dart';
import '../../services/home_widget_refresh.dart';
import '../../services/home_widget_service.dart';
import '../../services/project_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/responsive.dart';
import '../canvas/widgets/color_picker_panel.dart';
import 'widget_artwork_picker_screen.dart';

/// 背景色の選び方（テーマに合わせる／色を指定する）の2択。
enum _ColorMode { theme, custom }

/// ホーム画面ウィジェットの設定画面。
///
/// 置けるウィジェットは3種類（起動画面／作品をつくる／作品広場）。この画面は
/// **ウィジェット1種類につき1節**という構成にしてある。
///
/// - 起動画面ウィジェットは「どのフレームを表示するか」だけを選ぶ
///   （タップで`WidgetArtworkPickerScreen`→`WidgetArtworkFramePickerScreen`
///   の2画面フローへ進む。背景色の指定はここには無い＝常にテーマに追従）。
/// - 作品をつくる／作品広場ウィジェットは、背景色を「テーマに合わせる」
///   「色を指定する」の2択のラジオボタンで選ぶ。
///
/// 背景色は種類ごとに独立して持つ。3種を並べて置いたとき色を変えて
/// 見分けたい、という使い方ができるようにするため。
///
/// ウィジェットの追加そのものはホーム画面の長押しから行う（アプリからは
/// 追加できない）ため、その旨を画面上に書いてある。
class WidgetSettingsScreen extends StatelessWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final widgets = context.watch<HomeWidgetService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.widgetSettingsTitle)),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.widgetSettingsDescription,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.widgetSettingsNote,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            _sectionTitle(context, l10n.widgetSectionArtwork),
            _sectionNote(context, l10n.widgetSectionArtworkDesc),
            _subLabel(context, l10n.widgetArtworkSection),
            _artworkSummaryTile(context, widgets),
            const SizedBox(height: 20),

            _sectionTitle(context, l10n.widgetSectionCreate),
            _sectionNote(context, l10n.widgetSectionCreateDesc),
            _colorRow(context, widgets, HomeWidgetKind.create),
            const SizedBox(height: 20),

            _sectionTitle(context, l10n.widgetSectionPlaza),
            _sectionNote(context, l10n.widgetSectionPlazaDesc),
            _colorRow(context, widgets, HomeWidgetKind.plaza),
          ],
        ),
      ),
    );
  }

  /// 起動画面ウィジェットの「作品を選ぶ」行。
  ///
  /// 未選択なら[l10n.widgetArtworkPickButton]（「作品を選ぶ」）をタイトルに
  /// 出す。選択済みなら選んだフレームのプレビュー・作品名・フレーム番号を
  /// 出す。どちらもタップで作品→フレームの選択フローへ進む。
  Widget _artworkSummaryTile(BuildContext context, HomeWidgetService widgets) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final projectId = widgets.projectId;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: projectId == null
              ? Icon(Icons.add_photo_alternate_outlined, color: scheme.primary)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ArtworkFrameThumbnail(
                    projectId: projectId,
                    sceneId: widgets.sceneId,
                    frameIndex: widgets.frameIndex,
                  ),
                ),
        ),
        title: Text(
          projectId == null
              ? l10n.widgetArtworkPickButton
              : (context
                        .watch<ProjectService>()
                        .projects
                        .where((p) => p.id == projectId)
                        .firstOrNull
                        ?.name ??
                    l10n.widgetArtworkPickButton),
        ),
        subtitle: projectId == null
            ? null
            : Text(
                l10n.widgetArtworkFrameNumberLabel(
                  (widgets.frameIndex ?? 0) + 1,
                ),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/widget/artwork'),
      ),
    );
  }

  /// 1種類ぶんの背景色設定（テーマに合わせる／色を指定するのラジオボタン）。
  Widget _colorRow(
    BuildContext context,
    HomeWidgetService widgets,
    HomeWidgetKind kind,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final mode = widgets.followsTheme(kind)
        ? _ColorMode.theme
        : _ColorMode.custom;

    return RadioGroup<_ColorMode>(
      groupValue: mode,
      onChanged: (value) async {
        if (value == _ColorMode.theme) {
          await widgets.setBackgroundColor(kind, null);
          if (context.mounted) await _push(context);
        } else if (context.mounted) {
          // 「色を指定する」は選ぶたび（既に選んでいる状態からの再タップも
          // 含め）色選択ダイアログを開く。まだ指定していなければ現在の
          // テーマカラーを初期値にする。ダイアログをそのまま閉じた場合は
          // 何も変更されず、選択はテーマ追従のまま（＝ラジオも戻る）。
          _pickColor(context, widgets, kind);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<_ColorMode>(
            value: _ColorMode.theme,
            title: Text(l10n.widgetColorFollowTheme),
          ),
          RadioListTile<_ColorMode>(
            value: _ColorMode.custom,
            title: Text(l10n.widgetColorCustom),
            secondary: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(
                  widgets.backgroundColorOf(kind) ?? _themeColor(context),
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Kuramubon',
        fontFamilyFallback: kHeadingFontFallback,
      ),
    ),
  );

  /// 節の中の小見出し（「表示する作品」等）。
  Widget _subLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _sectionNote(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  static int _themeColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary.toARGB32();

  /// 設定変更のたびにウィジェットへ反映する。
  static Future<void> _push(BuildContext context) async {
    await refreshHomeWidgets(
      widgets: context.read<HomeWidgetService>(),
      projects: context.read<ProjectService>(),
      theme: context.read<ThemeService>(),
    );
  }

  void _pickColor(
    BuildContext context,
    HomeWidgetService widgets,
    HomeWidgetKind kind,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ColorPickerPanel(
          currentColor: Color(
            widgets.backgroundColorOf(kind) ?? _themeColor(context),
          ),
          onColorChanged: (c) => widgets.setBackgroundColor(kind, c.toARGB32()),
          onClose: () async {
            Navigator.pop(ctx);
            if (context.mounted) await _push(context);
          },
        ),
      ),
    );
  }
}
