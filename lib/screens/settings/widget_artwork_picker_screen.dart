import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/frame_thumbnail_renderer.dart';
import '../../services/home_widget_refresh.dart';
import '../../services/home_widget_service.dart';
import '../../services/project_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/responsive.dart';

/// 起動画面ウィジェットに表示するフレームを選ぶフロー（2画面構成）。
///
/// 1. [WidgetArtworkPickerScreen]：作品を一覧から選ぶ（サムネイル＋タイトル）
/// 2. [WidgetArtworkFramePickerScreen]：その作品の中からフレームを選ぶ
///    （シーンが複数あればシーンも選べる。プレビューつき）
///
/// フレームをタップした時点で確定・保存し、両画面を一気に閉じて設定画面
/// （呼び出し元）へ戻る。

/// 手順1：作品を選ぶ一覧画面。
class WidgetArtworkPickerScreen extends StatelessWidget {
  const WidgetArtworkPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.watch<ProjectService>().projects;
    final widgets = context.watch<HomeWidgetService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.widgetArtworkPickButton)),
      body: desktopCentered(
        context,
        projects.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.widgetNoProjects,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : ListView.builder(
                // 先頭の1行は「選ばない」状態へ戻すための選択肢。
                itemCount: projects.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          Icons.block_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(l10n.widgetArtworkNone),
                      selected: widgets.projectId == null,
                      onTap: () async {
                        await widgets.selectArtwork();
                        if (context.mounted) {
                          await refreshHomeWidgets(
                            widgets: widgets,
                            projects: context.read<ProjectService>(),
                            theme: context.read<ThemeService>(),
                          );
                        }
                        if (context.mounted) context.pop();
                      },
                    );
                  }
                  final p = projects[index - 1];
                  final path = p.thumbnailPath;
                  return ListTile(
                    leading: SizedBox(
                      width: 56,
                      height: 56,
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
                                // 表示は56px。保存解像度のままデコードして
                                // 画像キャッシュへ載せない。
                                cacheWidth:
                                    (56 *
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
                    title: Text(p.name),
                    trailing: const Icon(Icons.chevron_right),
                    selected: widgets.projectId == p.id,
                    onTap: () =>
                        context.push('/settings/widget/artwork/${p.id}'),
                  );
                },
              ),
      ),
    );
  }
}

/// 手順2：作品内のフレームを選ぶ画面。
class WidgetArtworkFramePickerScreen extends StatefulWidget {
  final String projectId;
  const WidgetArtworkFramePickerScreen({super.key, required this.projectId});

  @override
  State<WidgetArtworkFramePickerScreen> createState() =>
      _WidgetArtworkFramePickerScreenState();
}

class _WidgetArtworkFramePickerScreenState
    extends State<WidgetArtworkFramePickerScreen> {
  String? _sceneId;

  @override
  void initState() {
    super.initState();
    // 同じ作品を選び直す場合は、前回選んでいたシーンを初期選択にする。
    final widgets = context.read<HomeWidgetService>();
    if (widgets.projectId == widget.projectId) _sceneId = widgets.sceneId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final widgets = context.watch<HomeWidgetService>();
    final scheme = Theme.of(context).colorScheme;
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final scenes = ps.scenesOf(widget.projectId);
    final sceneId = (_sceneId != null && scenes.any((s) => s.id == _sceneId))
        ? _sceneId!
        : (scenes.isEmpty ? null : scenes.first.id);
    final scene = scenes.where((s) => s.id == sceneId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(project?.name ?? '')),
      body: desktopCentered(
        context,
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                l10n.widgetArtworkFramePickerHint,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            if (scenes.length > 1)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: scenes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = scenes[i];
                    return ChoiceChip(
                      label: Text(s.displayName),
                      selected: s.id == sceneId,
                      onSelected: (_) => setState(() => _sceneId = s.id),
                    );
                  },
                ),
              ),
            if (scenes.length > 1) const SizedBox(height: 8),
            Expanded(
              child: (scene == null || scene.frames.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.widgetArtworkNoFrames,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 120,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: scene.frames.length,
                      itemBuilder: (context, index) {
                        final selected =
                            widgets.projectId == widget.projectId &&
                            widgets.sceneId == scene.id &&
                            (widgets.frameIndex ?? 0) == index;
                        return _FrameCell(
                          projectId: widget.projectId,
                          sceneId: scene.id,
                          frameIndex: index,
                          number: index + 1,
                          selected: selected,
                          onTap: () => _select(context, scene.id, index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _select(BuildContext context, String sceneId, int index) async {
    final widgets = context.read<HomeWidgetService>();
    await widgets.selectArtwork(
      projectId: widget.projectId,
      sceneId: sceneId,
      frameIndex: index,
    );
    if (context.mounted) {
      await refreshHomeWidgets(
        widgets: widgets,
        projects: context.read<ProjectService>(),
        theme: context.read<ThemeService>(),
      );
    }
    if (context.mounted) {
      // 作品一覧・フレーム選択の2画面ぶん一気に戻り、呼び出し元の
      // 設定画面へ着地する。
      final router = GoRouter.of(context);
      router.pop();
      router.pop();
    }
  }
}

class _FrameCell extends StatelessWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _FrameCell({
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
                color: scheme.surfaceContainerHigh,
              ),
              clipBehavior: Clip.antiAlias,
              child: ArtworkFrameThumbnail(
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$number',
            style: TextStyle(
              fontSize: 11,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// フレーム1枚を実際に合成してサムネイル表示するウィジェット。
///
/// ホーム画面ウィジェット設定の要約行（[projectId]のみ指定）と、
/// フレーム選択グリッドの各セル（[sceneId]・[frameIndex]も指定）の
/// 両方で共有する。[compositeFrameThumbnail]と同じ既定（先頭シーン・
/// 先頭フレーム）を使うため、[sceneId]・[frameIndex]は省略できる。
class ArtworkFrameThumbnail extends StatefulWidget {
  final String projectId;
  final String? sceneId;
  final int? frameIndex;

  const ArtworkFrameThumbnail({
    super.key,
    required this.projectId,
    this.sceneId,
    this.frameIndex,
  });

  @override
  State<ArtworkFrameThumbnail> createState() => _ArtworkFrameThumbnailState();
}

class _ArtworkFrameThumbnailState extends State<ArtworkFrameThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void didUpdateWidget(covariant ArtworkFrameThumbnail old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId ||
        old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex) {
      _generate();
    }
  }

  Future<void> _generate() async {
    final ps = context.read<ProjectService>();
    final image = await compositeFrameThumbnail(
      ps,
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      maxSize: 200,
    );
    if (!mounted) {
      image?.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = image);
    old?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return RawImage(image: image, fit: BoxFit.cover);
  }
}
