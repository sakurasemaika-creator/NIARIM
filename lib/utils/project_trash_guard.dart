import 'dart:convert';
import 'dart:io';

import '../models/project.dart';
import 'app_error_reporter.dart';

/// Retains a cleanup target when a recursive permanent deletion only partly
/// completes. Project archives and the existing trash preference stay compatible.
class ProjectTrashGuard {
  const ProjectTrashGuard(this.file, this.project, this.deletedAt);

  final File file;
  final Project project;
  final DateTime deletedAt;
  static const _prefix = '.niarim-delete-';

  static File fileFor(String basePath, String id) {
    if (id.isEmpty ||
        id == '.' ||
        id == '..' ||
        id.contains(RegExp(r'[/\\]'))) {
      throw const FormatException('Invalid project directory name');
    }
    return File('$basePath/$_prefix${Uri.encodeComponent(id)}.json');
  }

  static Future<ProjectTrashGuard> _read(File file, String basePath) async {
    final value = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (value['version'] != 1) {
      throw const FormatException('Unsupported trash cleanup record');
    }
    final saved = Map<String, dynamic>.from(value['project'] as Map);
    // Only cleanup-row metadata is needed here. Restoration always reads the
    // actual archive; it never creates project content from this record.
    final project = Project(
      id: saved['id'] as String,
      name: saved['name'] as String,
      fps: saved['fps'] as int,
      durationSeconds: saved['durationSeconds'] as int,
      backgroundColor: saved['backgroundColor'] as int,
      createdAt: DateTime.parse(saved['createdAt'] as String),
      updatedAt: DateTime.parse(saved['updatedAt'] as String),
      totalWorkSeconds: saved['totalWorkSeconds'] as int,
    );
    if (fileFor(basePath, project.id).path != file.path) {
      throw const FormatException('Trash cleanup target mismatch');
    }
    return ProjectTrashGuard(
      file,
      project,
      DateTime.parse(value['deletedAt'] as String),
    );
  }

  static Future<ProjectTrashGuard> write(
    String basePath,
    Project project,
    DateTime deletedAt,
  ) async {
    final file = fileFor(basePath, project.id);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.file) return _read(file, basePath);
    if (type != FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Trash cleanup record is not a file',
        file.path,
      );
    }
    final temporary = File(
      '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temporary.writeAsString(
        jsonEncode({
          'version': 1,
          'project': {
            'id': project.id,
            'name': project.name,
            'fps': project.fps,
            'durationSeconds': project.durationSeconds,
            'backgroundColor': project.backgroundColor,
            'createdAt': project.createdAt.toIso8601String(),
            'updatedAt': project.updatedAt.toIso8601String(),
            'totalWorkSeconds': project.totalWorkSeconds,
          },
          'deletedAt': deletedAt.toIso8601String(),
        }),
        flush: true,
      );
      await temporary.rename(file.path);
      return ProjectTrashGuard(file, project, deletedAt);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static Future<void> remove(String basePath, String id) async {
    final file = fileFor(basePath, id);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw FileSystemException(
        'Trash cleanup record is not a file',
        file.path,
      );
    }
    await file.delete();
  }

  static Future<List<ProjectTrashGuard>> pending(String basePath) async {
    final pending = <ProjectTrashGuard>[];
    await for (final entry in Directory(basePath).list(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.path.split(Platform.pathSeparator).last;
      if (name.startsWith(_prefix) &&
          RegExp(r'\.json\.tmp-\d+$').hasMatch(name)) {
        try {
          await entry.delete();
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
        }
        continue;
      }
      if (!name.startsWith(_prefix) || !name.endsWith('.json')) continue;
      try {
        final guard = await _read(entry, basePath);
        final type = await FileSystemEntity.type(
          '$basePath/${guard.project.id}',
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) {
          // The content was deleted; a leftover cleanup record cannot resurrect it.
          await entry.delete();
        } else {
          pending.add(guard);
        }
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
      }
    }
    return pending;
  }
}
