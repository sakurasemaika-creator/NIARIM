import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/project.dart';
import '../../../services/project_service.dart';

/// A saved work which can be used as a folder cover.
class FolderThumbnailChoice {
  final String id;
  final String name;
  final String imagePath;
  final DateTime updatedAt;

  const FolderThumbnailChoice({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.updatedAt,
  });
}

/// Includes direct works as well as works in any nested child folder.
/// A visited set prevents malformed cycles from hanging the home screen.
List<FolderThumbnailChoice> projectFolderThumbnailChoices(
  List<ProjectFolder> folders,
  List<Project> projects,
  String rootId,
) {
  final children = <String, List<String>>{};
  for (final folder in folders) {
    if (folder.parentFolderId != null) {
      children.putIfAbsent(folder.parentFolderId!, () => []).add(folder.id);
    }
  }
  final descendants = <String>{rootId};
  final queue = <String>[rootId];
  for (var i = 0; i < queue.length; i++) {
    for (final id in children[queue[i]] ?? const <String>[]) {
      if (descendants.add(id)) queue.add(id);
    }
  }
  return [
    for (final project in projects)
      if (project.folderId != null &&
          descendants.contains(project.folderId) &&
          project.thumbnailPath?.isNotEmpty == true)
        FolderThumbnailChoice(
          id: project.id,
          name: project.name,
          imagePath: project.thumbnailPath!,
          updatedAt: project.updatedAt,
        ),
  ];
}

String? folderThumbnailPath(
  ProjectFolder folder,
  List<FolderThumbnailChoice> choices,
) {
  switch (folder.thumbnailMode) {
    case 'none':
      return null;
    case 'custom':
      return folder.thumbnailImagePath;
    case 'item':
      for (final choice in choices) {
        if (choice.id == folder.thumbnailSourceId) return choice.imagePath;
      }
      return null;
    default:
      FolderThumbnailChoice? latest;
      for (final choice in choices) {
        if (latest == null || choice.updatedAt.isAfter(latest.updatedAt)) {
          latest = choice;
        }
      }
      return latest?.imagePath;
  }
}

/// Creates a small preview for exported video files only when the UI
/// actually needs one. This is Android-only; desktop widget tests do not
/// invoke native codecs and simply retain the folder icon fallback.
class FolderCoverMedia extends StatelessWidget {
  const FolderCoverMedia({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth = 320,
  });

  final String path;
  final BoxFit fit;
  final int cacheWidth;

  static final Map<String, Future<String?>> _videoPreviews = {};

  static bool _isVideo(String path) {
    final suffix = path.split('.').last.toLowerCase();
    return const {'mp4', 'webm', 'mov', 'mkv', 'avi'}.contains(suffix);
  }

  static String _ffmpegQuote(String path) =>
      '"${path.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  static Future<String?> _resolveVideo(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      final source = File(path);
      if (!source.existsSync()) return null;
      final modified = source.lastModifiedSync().millisecondsSinceEpoch;
      var hash = 0x811c9dc5;
      for (final code in path.codeUnits) {
        hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
      }
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/folder_cover_previews',
      );
      await directory.create(recursive: true);
      final poster = File(
        '${directory.path}/${hash.toRadixString(16)}_$modified.jpg',
      );
      if (await poster.exists() && await poster.length() > 0) {
        return poster.path;
      }
      final session = await FFmpegKit.execute(
        '-hide_banner -loglevel error -y -ss 0.2 '
        '-i ${_ffmpegQuote(path)} -frames:v 1 -vf scale=320:-2 '
        '${_ffmpegQuote(poster.path)}',
      );
      final code = await session.getReturnCode();
      return ReturnCode.isSuccess(code) &&
              await poster.exists() &&
              await poster.length() > 0
          ? poster.path
          : null;
    } catch (_) {
      // A corrupt or unsupported export should not break folder browsing.
      return null;
    }
  }

  static Future<String?> _videoFuture(String path) {
    // The last modified timestamp forms part of the key so regenerated video
    // content gets a new preview instead of reusing an outdated cached one.
    int modified;
    try {
      modified = File(path).lastModifiedSync().millisecondsSinceEpoch;
    } on FileSystemException {
      return Future<String?>.value(null);
    }
    return _videoPreviews.putIfAbsent(
      '$path:$modified',
      () => _resolveVideo(path),
    );
  }

  Widget _image(String filePath) => Image.file(
    File(filePath),
    key: ValueKey('folderCoverMedia_$filePath'),
    fit: fit,
    cacheWidth: cacheWidth,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    if (!_isVideo(path)) return _image(path);
    return FutureBuilder<String?>(
      future: _videoFuture(path),
      builder: (context, snapshot) =>
          snapshot.data == null
              ? const SizedBox.shrink()
              : _image(snapshot.data!),
    );
  }
}

/// Same sized preview surface as a work card. The actual image is clipped
/// to the BODY of the folder symbol rather than covering the folder outline.
class FolderThumbnail extends StatelessWidget {
  const FolderThumbnail({
    super.key,
    required this.folder,
    required this.choices,
  });
  final ProjectFolder folder;
  final List<FolderThumbnailChoice> choices;

  @override
  Widget build(BuildContext context) {
    final color = folder.color == null
        ? Theme.of(context).colorScheme.primary
        : Color(folder.color!);
    final imagePath = folderThumbnailPath(folder, choices);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 56.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 56.0;
        final size = math.max(1.0, math.min(w, h) * 0.87);
        final left = (w - size) / 2;
        final top = (h - size) / 2;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: color.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: size,
              height: size,
              child: Icon(Icons.folder_rounded, size: size, color: color),
            ),
            if (imagePath != null)
              Positioned(
                left: left + size * 0.17,
                top: top + size * 0.36,
                width: size * 0.68,
                height: size * 0.43,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.05),
                  child: FolderCoverMedia(
                    key: ValueKey('folderCover_${folder.id}_$imagePath'),
                    path: imagePath,
                    cacheWidth: 320,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _folderCoverText(BuildContext context, String key) {
  final ja = Localizations.localeOf(context).languageCode == 'ja';
  switch (key) {
    case 'title':
      return ja ? 'サムネイル変更' : 'Change thumbnail';
    case 'auto':
      return ja ? 'デフォルト（最新の作品）' : 'Default (most recently updated work)';
    case 'none':
      return ja ? 'サムネイル表示しない' : 'Do not show a thumbnail';
    case 'item':
      return ja ? 'サムネイルにする作品を選ぶ' : 'Choose a work';
    case 'custom':
      return ja ? '端末内から画像を読み込む' : 'Choose an image from device';
    case 'select':
      return ja ? '作品を選択' : 'Select a work';
    case 'load':
      return ja ? '画像を選択' : 'Choose image';
    case 'apply':
      return ja ? '適用' : 'Apply';
    case 'cancel':
      return ja ? 'キャンセル' : 'Cancel';
    default:
      return ja ? '画像を読み込めませんでした' : 'Could not open image';
  }
}

typedef SaveFolderThumbnail = Future<void> Function({
  required String mode,
  String? sourceId,
  String? imagePath,
});

/// Four mutually exclusive radio choices. The custom image is copied into
/// app-owned storage only after Apply, so Cancel does not mutate metadata.
Future<void> showFolderThumbnailDialog(
  BuildContext context, {
  required ProjectFolder folder,
  required List<FolderThumbnailChoice> choices,
  required SaveFolderThumbnail onSave,
}) async {
  String mode = folder.thumbnailMode;
  String? selectedId = folder.thumbnailSourceId;
  String? customPath = folder.thumbnailImagePath;
  Uint8List? pickedBytes;
  String? pickedExtension;
  String? pickedName;
  bool saving = false;
  String? failure;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        scrollable: true,
        title: Text(_folderCoverText(ctx, 'title')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<String>(
                groupValue: mode,
                onChanged: (value) {
                  if (value != null) setState(() => mode = value);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      key: const Key('folderCoverAuto'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(_folderCoverText(ctx, 'auto')),
                      value: 'auto',
                    ),
                    RadioListTile<String>(
                      key: const Key('folderCoverNone'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(_folderCoverText(ctx, 'none')),
                      value: 'none',
                    ),
                    RadioListTile<String>(
                      key: const Key('folderCoverItem'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(_folderCoverText(ctx, 'item')),
                      value: 'item',
                    ),
                    RadioListTile<String>(
                      key: const Key('folderCoverCustom'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(_folderCoverText(ctx, 'custom')),
                      value: 'custom',
                    ),
                  ],
                ),
              ),
              // The panel below the four radios is the only changing part.
              // The Cancel/Apply actions stay at the bottom of the dialog.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: switch (mode) {
                  'item' => Padding(
                    key: const Key('folderCoverItemPanel'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          key: const Key('folderCoverItemChoice'),
                          initialValue: choices.any((c) => c.id == selectedId)
                              ? selectedId
                              : null,
                          isExpanded: true,
                          hint: Text(_folderCoverText(ctx, 'select')),
                          items: [
                            for (final choice in choices)
                              DropdownMenuItem(
                                value: choice.id,
                                child: Text(
                                  choice.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => selectedId = value),
                        ),
                        if (choices.any((c) => c.id == selectedId)) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 112,
                              height: 72,
                              child: FolderCoverMedia(
                                key: const Key('folderCoverWorkPreview'),
                                path: choices.firstWhere(
                                  (c) => c.id == selectedId,
                                ).imagePath,
                                cacheWidth: 224,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  'custom' => Padding(
                    key: const Key('folderCoverCustomPanel'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('folderCoverChooseImage'),
                          onPressed: saving
                              ? null
                              : () async {
                                  try {
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                    );
                                    if (result == null || result.files.isEmpty) return;
                                    final picked = result.files.first;
                                    final bytes = picked.bytes ??
                                        (picked.path != null
                                            ? await File(picked.path!).readAsBytes()
                                            : null);
                                    if (bytes == null || bytes.isEmpty ||
                                        bytes.lengthInBytes > 10 * 1024 * 1024) {
                                      throw const FormatException('Invalid image size');
                                    }
                                    final ext = picked.extension?.toLowerCase() ?? 'png';
                                    if (!const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}
                                        .contains(ext)) {
                                      throw const FormatException('Unsupported image');
                                    }
                                    setState(() {
                                      pickedBytes = bytes;
                                      pickedName = picked.name;
                                      pickedExtension = ext;
                                      failure = null;
                                    });
                                  } catch (_) {
                                    if (ctx.mounted) {
                                      setState(() => failure =
                                          _folderCoverText(ctx, 'error'));
                                    }
                                  }
                                },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(_folderCoverText(ctx, 'load')),
                        ),
                        if (pickedName != null) ...[
                          Text(pickedName!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ] else if (customPath != null) ...[
                          Text(
                            customPath!.split(Platform.pathSeparator).last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (pickedBytes != null || customPath != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: pickedBytes != null
                                ? Image.memory(
                                    pickedBytes!,
                                    key: const Key('folderCoverImagePreview'),
                                    width: 112,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    cacheWidth: 224,
                                  )
                                : Image.file(
                                    File(customPath!),
                                    key: const Key('folderCoverImagePreview'),
                                    width: 112,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    cacheWidth: 224,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              if (failure != null)
                Text(failure!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx),
            child: Text(_folderCoverText(ctx, 'cancel')),
          ),
          FilledButton(
            key: const Key('folderCoverApply'),
            onPressed: saving ||
                    (mode == 'item' && !choices.any((c) => c.id == selectedId)) ||
                    (mode == 'custom' && pickedBytes == null && customPath == null)
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      String? path = mode == 'custom' ? customPath : null;
                      if (mode == 'custom' && pickedBytes != null) {
                        final dir = Directory(
                          '${(await getApplicationSupportDirectory()).path}/folder_thumbnails',
                        );
                        await dir.create(recursive: true);
                        final safeId = folder.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                        final file = File(
                          '${dir.path}/${safeId}_${DateTime.now().microsecondsSinceEpoch}.${pickedExtension ?? 'png'}',
                        );
                        await file.writeAsBytes(pickedBytes!, flush: true);
                        path = file.path;
                      }
                      await onSave(
                        mode: mode,
                        sourceId: mode == 'item' ? selectedId : null,
                        imagePath: path,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (_) {
                      if (ctx.mounted) {
                        setState(() {
                          saving = false;
                          failure = _folderCoverText(ctx, 'error');
                        });
                      }
                    }
                  },
            child: Text(_folderCoverText(ctx, 'apply')),
          ),
        ],
      ),
    ),
  );
}
