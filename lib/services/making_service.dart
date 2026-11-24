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

/// Optional per-project canvas snapshots. Files are stored outside the
/// editable project archive and capped at 64 MB. Existing snapshots are never
/// removed automatically when the cap is reached.
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

  static String _snapshotName(int number) =>
      'making_' + number.toString().padLeft(6, '0') + '.jpg';

  static bool _isSnapshotName(String name) =>
      RegExp(r'^making_[0-9]{6}\.jpg$').hasMatch(name);

  static Future<Map<String, dynamic>> _emptyManifest(
    Directory dir,
  ) async {
    final recovered = <dynamic>[];
    var recoveredBytes = 0;
    final files = <File>[];
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is File && _isSnapshotName(entry.uri.pathSegments.last)) {
        files.add(entry);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final stat = await file.stat();
      recoveredBytes += stat.size;
      recovered.add({
        'file': file.uri.pathSegments.last,
        'capturedAt': stat.modified.toIso8601String(),
        'sceneId': '',
        'frameIndex': 0,
        'sizeBytes': stat.size,
      });
    }
    return {
      'version': 1,
      'sizeBytes': recoveredBytes,
      'limitReached': recoveredBytes >= maxBytesPerProject,
      'snapshots': recovered,
    };
  }

  static Future<Map<String, dynamic>> _readManifest(
    String projectId,
  ) async {
    final dir = await _directory(projectId);
    final file = File(dir.path + '/making.json');
    if (!await file.exists()) return _emptyManifest(dir);

    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is Map<String, dynamic> && value['version'] == 1) {
        decoded = value;
      }
    } catch (_) {
      // Rebuild the index from files below; do not discard any JPEG snapshots.
    }
    if (decoded == null) return _emptyManifest(dir);

    final metadataByName = <String, Map>{};
    final rawSnapshots = decoded['snapshots'] is List
        ? decoded['snapshots'] as List
        : const <dynamic>[];
    for (final raw in rawSnapshots) {
      if (raw is! Map) continue;
      final name = raw['file'];
      if (name is String && _isSnapshotName(name)) {
        metadataByName[name] = raw;
      }
    }

    // Recalculate the exact on-disk size instead of trusting a possibly stale
    // manifest. This keeps the cap effective after interrupted writes or file
    // loss, and it also recovers snapshots saved just before a crash.
    final files = <File>[];
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is File &&
          _isSnapshotName(entry.uri.pathSegments.last)) {
        files.add(entry);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    final snapshots = <dynamic>[];
    var sizeBytes = 0;
    for (final imageFile in files) {
      final name = imageFile.uri.pathSegments.last;
      final stat = await imageFile.stat();
      sizeBytes += stat.size;
      final metadata = metadataByName[name];
      final capturedAt = metadata?['capturedAt'] as String?;
      snapshots.add({
        'file': name,
        'capturedAt': DateTime.tryParse(capturedAt ?? '')?.toIso8601String() ??
            stat.modified.toIso8601String(),
        'sceneId': metadata?['sceneId'] as String? ?? '',
        'frameIndex': metadata?['frameIndex'] as int? ?? 0,
        'sizeBytes': stat.size,
      });
    }
    return {
      'version': 1,
      'sizeBytes': sizeBytes,
      'limitReached': decoded['limitReached'] == true ||
          sizeBytes >= maxBytesPerProject,
      'snapshots': snapshots,
    };
  }

  static Future<void> _writeManifest(
    String projectId,
    Map<String, dynamic> manifest,
  ) async {
    final dir = await _directory(projectId);
    final file = File(dir.path + '/making.json');
    final temporary = File(file.path + '.tmp');
    await temporary.writeAsString(jsonEncode(manifest), flush: true);
    // On Android this is an atomic rename over the old index.
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
    final currentBytes = manifest['sizeBytes'] as int;
    if (manifest['limitReached'] == true ||
        currentBytes + bytes.length > maxBytesPerProject) {
      manifest['limitReached'] = true;
      await _writeManifest(projectId, manifest);
      return false;
    }

    final snapshots = List<dynamic>.from(manifest['snapshots'] as List);
    final usedNames = snapshots
        .whereType<Map>()
        .map((entry) => entry['file'])
        .whereType<String>()
        .toSet();
    var number = snapshots.length + 1;
    while (usedNames.contains(_snapshotName(number)) ||
        await File(dir.path + '/' + _snapshotName(number)).exists()) {
      number++;
    }
    final name = _snapshotName(number);
    final target = File(dir.path + '/' + name);
    final staging = File(target.path + '.tmp');
    await staging.writeAsBytes(bytes, flush: true);
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
      if (name is! String || !_isSnapshotName(name)) continue;
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
