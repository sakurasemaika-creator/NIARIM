import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class MakingSnapshot {
  const MakingSnapshot({
    required this.path,
    required this.capturedAt,
    required this.sceneId,
    required this.frameIndex,
    required this.sizeBytes,
  });

  final String path;
  final DateTime capturedAt;
  final String sceneId;
  final int frameIndex;
  final int sizeBytes;
}

class MakingHistory {
  const MakingHistory({
    required this.snapshots,
    required this.sizeBytes,
    required this.limitReached,
  });

  final List<MakingSnapshot> snapshots;
  final int sizeBytes;
  final bool limitReached;
}

/// Optional per-project canvas snapshots. These files are stored separately
/// from the editable .niapro archive and have a hard storage cap.
abstract final class MakingService {
  static const int maxBytesPerProject = 64 * 1024 * 1024;

  static Future<Directory> _directory(String projectId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(projectId)) {
      throw ArgumentError.value(projectId, 'projectId');
    }
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory(
      documents.path + '/niarim/projects/' + projectId + '/Making',
    );
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _manifest(String projectId) async {
    final dir = await _directory(projectId);
    return File(dir.path + '/making.json');
  }

  static Future<Map<String, dynamic>> _readManifest(String projectId) async {
    final file = await _manifest(projectId);
    if (!await file.exists()) {
      return {
        'version': 1,
        'sizeBytes': 0,
        'limitReached': false,
        'snapshots': <dynamic>[],
      };
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic> && decoded['version'] == 1) {
        decoded['snapshots'] = decoded['snapshots'] is List
            ? decoded['snapshots']
            : <dynamic>[];
        decoded['sizeBytes'] =
            decoded['sizeBytes'] is int ? decoded['sizeBytes'] : 0;
        decoded['limitReached'] = decoded['limitReached'] == true;
        return decoded;
      }
    } catch (_) {
      // Keep existing image files rather than deleting them on index damage.
    }
    return {
      'version': 1,
      'sizeBytes': 0,
      'limitReached': false,
      'snapshots': <dynamic>[],
    };
  }

  static Future<void> _writeManifest(
    String projectId,
    Map<String, dynamic> manifest,
  ) async {
    final file = await _manifest(projectId);
    final temporary = File(file.path + '.tmp');
    await temporary.writeAsString(jsonEncode(manifest), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  static Future<bool> recordSnapshot({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty || frameIndex < 0) return false;
    final dir = await _directory(projectId);
    final manifest = await _readManifest(projectId);
    if (manifest['limitReached'] == true) return false;
    final currentBytes = manifest['sizeBytes'] as int;
    if (currentBytes + bytes.length > maxBytesPerProject) {
      manifest['limitReached'] = true;
      await _writeManifest(projectId, manifest);
      return false;
    }
    final snapshots = List<dynamic>.from(manifest['snapshots'] as List);
    final number = snapshots.length + 1;
    final name = 'making_' + number.toString().padLeft(6, '0') + '.jpg';
    final target = File(dir.path + '/' + name);
    final staging = File(target.path + '.tmp');
    await staging.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await staging.rename(target.path);
    snapshots.add({
      'file': name,
      'capturedAt': DateTime.now().toIso8601String(),
      'sceneId': sceneId,
      'frameIndex': frameIndex,
      'sizeBytes': bytes.length,
    });
    manifest['snapshots'] = snapshots;
    manifest['sizeBytes'] = currentBytes + bytes.length;
    await _writeManifest(projectId, manifest);
    return true;
  }

  static Future<MakingHistory> history(String projectId) async {
    final dir = await _directory(projectId);
    final manifest = await _readManifest(projectId);
    final snapshots = <MakingSnapshot>[];
    for (final raw in manifest['snapshots'] as List) {
      if (raw is! Map) continue;
      final name = raw['file'];
      if (name is! String ||
          !RegExp(r'^making_[0-9]{6}\.jpg$').hasMatch(name)) {
        continue;
      }
      final file = File(dir.path + '/' + name);
      if (!await file.exists()) continue;
      final capturedAt =
          DateTime.tryParse(raw['capturedAt'] as String? ?? '');
      snapshots.add(
        MakingSnapshot(
          path: file.path,
          capturedAt:
              capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          sceneId: raw['sceneId'] as String? ?? '',
          frameIndex: raw['frameIndex'] as int? ?? 0,
          sizeBytes: raw['sizeBytes'] as int? ?? await file.length(),
        ),
      );
    }
    return MakingHistory(
      snapshots: List.unmodifiable(snapshots),
      sizeBytes: manifest['sizeBytes'] as int,
      limitReached: manifest['limitReached'] == true,
    );
  }

  static Future<void> deleteHistory(String projectId) async {
    final dir = await _directory(projectId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
