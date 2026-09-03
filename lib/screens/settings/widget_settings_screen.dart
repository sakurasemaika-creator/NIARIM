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
/// 置けるウィジェットは3種類（作品／作品をつくる／作品広場）で、ここで
/// 設定するのは「作品ウィジェットに出す作品」と「3種共通の背景色」。
/// ウィジェットの追加そのものはホーム画面の長押しから行う（アプリからは
/// 追加できない）ため、その旨を画面上に書いてある。
class WidgetSettingsScreen extends StatelessWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final widgets = context.watch<HomeWidgetService>();
    final projects = context.watch<ProjectService>().projects;
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
            _sectionTitle(context, l10n.widgetArtworkSection),
            if (projects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.widgetNoProjects,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              // 選択状態と変更通知はRadioGroupがまとめて持つ
              // （groupValue/onChangedはFlutter 3.32で非推奨）。
              RadioGroup<String?>(
                groupValue: widgets.projectId,
                onChanged: (id) async {
                  await widgets.selectProject(id);
                  if (context.mounted) await _push(context);
                },
                child:
                    // 作品が増えても全行のWidgetを毎回作らないようbuilderを使う
                    // （CLAUDE.mdの「ListView(children:)は半分しか遅延しない」）。
                    ListView.builder(
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
                                ? Icon(
                                    Icons.image_outlined,
                                    color: scheme.onSurfaceVariant,
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      // 表示は44px。保存解像度のままデコードして
                                      // 画像キャッシュへ載せない。
                                      cacheWidth:
                                          (44 *
                                                  MediaQuery.devicePixelRatioOf(
                                                    context,
                                                  ))
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
              ),
            const SizedBox(height: 20),
            _sectionTitle(context, l10n.widgetColorSection),
            SwitchListTile(
              title: Text(l10n.widgetColorFollowTheme),
              value: widgets.followsTheme,
              onChanged: (follow) async {
                await widgets.setBackgroundColor(
                  follow ? null : _themeColor(context),
                );
                if (context.mounted) await _push(context);
              },
            ),
            if (!widgets.followsTheme)
              ListTile(
                title: Text(l10n.widgetColorCustom),
                trailing: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(widgets.backgroundColor!),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
                onTap: () => _pickColor(context, widgets),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Kuramubon',
        fontFamilyFallback: kHeadingFontFallback,
      ),
    ),
  );

  static int _themeColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary.toARGB32();

  /// 設定変更のたびにウィジェットへ反映する。
  static Future<void> _push(BuildContext context) async {
    final widgets = context.read<HomeWidgetService>();
    final projects = context.read<ProjectService>().projects;
    final themeColor = _themeColor(context);
    final id = widgets.projectId;
    final project = id == null
        ? null
        : projects.where((p) => p.id == id).firstOrNull;
    await HomeWidgetBridge().update(
      widgets,
      themeColor: themeColor,
      thumbnailPath: project?.thumbnailPath,
      projectName: project?.name,
    );
  }

  void _pickColor(BuildContext context, HomeWidgetService widgets) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ColorPickerPanel(
          currentColor: Color(widgets.backgroundColor ?? _themeColor(context)),
          onColorChanged: (c) => widgets.setBackgroundColor(c.toARGB32()),
          onClose: () async {
            Navigator.pop(ctx);
            if (context.mounted) await _push(context);
          },
        ),
      ),
    );
  }
}

/// テーマ変更にウィジェットを追従させるための拡張。
///
/// `ThemeService`が変わったタイミングで呼ぶ想定。テーマ追従設定のときだけ
/// 意味があるが、追従していない場合でも作品名・サムネイルの更新は要るので
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
