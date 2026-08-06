import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/material_asset.dart';

/// 素材管理サービス（仕様書21：MaterialID方式）。
/// 画像・音声・動画をプロジェクト内`Materials/`フォルダへコピーし、
/// ファイル名ではなく素材ID（Material0001形式）で参照する。
/// 同一内容のファイルはプロジェクト内に1つだけ保存し、重複保存を防ぐ。
class MaterialService extends ChangeNotifier {
  final Map<String, List<MaterialAsset>> _materials = {}; // projectId -> assets
  final Map<String, int> _counters = {}; // projectId -> 次の連番

  List<MaterialAsset> materialsOf(String projectId) =>
      List.unmodifiable(_materials[projectId] ?? const []);

  Future<Directory> _materialsDir(String projectId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/miranima/projects/$projectId/Materials');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String _nextId(String projectId) {
    final n = (_counters[projectId] ?? 0) + 1;
    _counters[projectId] = n;
    return 'Material${n.toString().padLeft(4, '0')}';
  }

  /// [sourcePath]のファイルを素材として登録し、Materials/フォルダへコピーする。
  /// 同一種別・同一内容（バイト一致）の素材が既にある場合はそれを再利用し、
  /// 新規コピーは行わない（仕様書21：重複保存の防止）。
  Future<MaterialAsset> addMaterial({
    required String projectId,
    required String sourcePath,
    required MaterialType type,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final dir = await _materialsDir(projectId);

    final existing = _materials[projectId] ?? const [];
    for (final m in existing) {
      if (m.type != type || m.sizeBytes != bytes.length) continue;
      final candidate = File('${dir.path}/${m.storageName}');
      if (!candidate.existsSync()) continue;
      if (_bytesEqual(bytes, await candidate.readAsBytes())) return m;
    }

    final originalFileName = sourcePath.split(RegExp(r'[\\/]')).last;
    final asset = MaterialAsset(
      id: _nextId(projectId),
      originalFileName: originalFileName,
      type: type,
      sizeBytes: bytes.length,
      addedAt: DateTime.now(),
    );
    await File('${dir.path}/${asset.storageName}').writeAsBytes(bytes);
    _materials.putIfAbsent(projectId, () => []).add(asset);
    notifyListeners();
    return asset;
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 素材IDの実ファイルパスを解決する。ファイルが見つからない場合はnull
  /// を返す（仕様書21：不足素材の検出）。
  Future<String?> pathOf(String projectId, String materialId) async {
    final asset = assetOf(projectId, materialId);
    if (asset == null) return null;
    final dir = await _materialsDir(projectId);
    final file = File('${dir.path}/${asset.storageName}');
    return file.existsSync() ? file.path : null;
  }

  MaterialAsset? assetOf(String projectId, String materialId) =>
      (_materials[projectId] ?? const []).where((m) => m.id == materialId).firstOrNull;

  /// 使用中でない素材を削除する。[isUsed]がtrueを返す場合は削除しない
  /// （仕様書21：使用中の素材は削除できない）。
  Future<bool> removeMaterial({
    required String projectId,
    required String materialId,
    required bool Function(String materialId) isUsed,
  }) async {
    if (isUsed(materialId)) return false;
    final list = _materials[projectId];
    if (list == null) return false;
    final idx = list.indexWhere((m) => m.id == materialId);
    if (idx < 0) return false;
    final dir = await _materialsDir(projectId);
    final file = File('${dir.path}/${list[idx].storageName}');
    if (file.existsSync()) await file.delete();
    list.removeAt(idx);
    notifyListeners();
    return true;
  }

  /// 未使用の素材を一括削除する（仕様書21）。削除件数を返す。
  Future<int> removeUnused({
    required String projectId,
    required bool Function(String materialId) isUsed,
  }) async {
    final list = List<MaterialAsset>.from(_materials[projectId] ?? const []);
    int removed = 0;
    for (final m in list) {
      final ok = await removeMaterial(projectId: projectId, materialId: m.id, isUsed: isUsed);
      if (ok) removed++;
    }
    return removed;
  }

  /// 登録済み素材のうち、実ファイルが見つからないものを返す
  /// （仕様書21：プロジェクトを開いた際の不足素材検出）。
  Future<List<MaterialAsset>> detectMissing(String projectId) async {
    final dir = await _materialsDir(projectId);
    final missing = <MaterialAsset>[];
    for (final m in _materials[projectId] ?? const []) {
      if (!File('${dir.path}/${m.storageName}').existsSync()) missing.add(m);
    }
    return missing;
  }
}
