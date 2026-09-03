import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/font_fallback.dart';
import '../../l10n/app_localizations.dart';
import '../../services/home_widget_bridge.dart';
import '../../services/home_widget_service.dart';
import '../../services/project_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/responsive.dart';
import '../canvas/widgets/color_picker_panel.dart';

/// ホーム画面ウィジェットの設定画面。
///
/// 置けるウィジェットは3種類（起動画面／作品をつくる／作品広場）。この画面は
/// **ウィジェット1種類につき1節**という構成にしてある。3種を並べて置いたとき
/// 色を変えて見分けたい、という使い方ができるよう背景色は種類ごとに独立して
/// 持つ。起動画面ウィジェットだけは、加えて「どの作品のフレームを出すか」を
/// 選ぶ。
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
            _artworkPicker(context, widgets),
            _colorRow(context, widgets, HomeWidgetKind.artwork),
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

  /// 起動画面ウィジェットに出す作品を選ぶ一覧。
  Widget _artworkPicker(BuildContext context, HomeWidgetService widgets) {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.watch<ProjectService>().projects;
    final scheme = Theme.of(context).colorScheme;

    if (projects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          l10n.widgetNoProjects,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }

    // 選択状態と変更通知はRadioGroupがまとめて持つ
    // （groupValue/onChangedはFlutter 3.32で非推奨）。
    return RadioGroup<String?>(
      groupValue: widgets.projectId,
      onChanged: (id) async {
        await widgets.selectProject(id);
        if (context.mounted) await _push(context);
      },
      // 作品が増えても全行のWidgetを毎回作らないようbuilderを使う
      // （CLAUDE.mdの「ListView(children:)は半分しか遅延しない」）。
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // 先頭の1行は「選んでいない」状態へ戻すための選択肢。
        itemCount: projects.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return RadioListTile<String?>(
              value: null,
              title: Text(l10n.widgetArtworkNone),
              secondary: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.block_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final p = projects[index - 1];
          final path = p.thumbnailPath;
          return RadioListTile<String?>(
            value: p.id,
            title: Text(p.name),
            secondary: SizedBox(
              width: 44,
              height: 44,
              child: path == null
                  ? Icon(Icons.image_outlined, color: scheme.onSurfaceVariant)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        // 表示は44px。保存解像度のままデコードして
                        // 画像キャッシュへ載せない。
                        cacheWidth:
                            (44 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  /// 1種類ぶんの背景色設定（テーマ追従スイッチ＋任意色）。
  Widget _colorRow(
    BuildContext context,
    HomeWidgetService widgets,
    HomeWidgetKind kind,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final follows = widgets.followsTheme(kind);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: Text(l10n.widgetColorFollowTheme),
          value: follows,
          onChanged: (follow) async {
            await widgets.setBackgroundColor(
              kind,
              follow ? null : _themeColor(context),
            );
            if (context.mounted) await _push(context);
          },
        ),
        if (!follows)
          ListTile(
            title: Text(l10n.widgetColorCustom),
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(widgets.backgroundColorOf(kind)!),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
            onTap: () => _pickColor(context, widgets, kind),
          ),
      ],
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

/// テーマ変更にウィジェットを追従させるための共通処理。
///
/// `ThemeService`が変わったタイミングで呼ぶ想定。テーマ追従設定の種類だけ
/// 色が変わるが、追従していない種類でも作品名・サムネイルの更新は要るので
/// 常に書き出す。
Future<void> refreshHomeWidgets({
  required HomeWidgetService widgets,
  required ProjectService projects,
  required ThemeService theme,
}) async {
  final id = widgets.projectId;
  final project = id == null
      ? null
      : projects.projects.where((p) => p.id == id).firstOrNull;
  await HomeWidgetBridge().update(
    widgets,
    themeColor: theme.current.accentColor.toARGB32(),
    thumbnailPath: project?.thumbnailPath,
    projectName: project?.name,
  );
}
