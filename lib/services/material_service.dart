import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/material_asset.dart';

/// 素材管理サービス（MaterialID方式）。
/// 画像・音声・動画をプロジェクト内`Materials/`フォルダへコピーし、
/// ファイル名ではなく素材ID（Material0001形式）で参照する。
/// 同一内容のファイルはプロジェクト内に1つだけ保存し、重複保存を防ぐ。
///
/// メタデータ（MaterialAssetのリスト）は`Materials/materials.json`へ永続化する。
/// 従来はインメモリのみで保持しており、アプリ再起動のたびに素材メタデータが
/// 失われ、素材一覧・不足素材検出・重複防止（addMaterial）・差し替えが
/// 機能しなくなっていた（実ファイルはMaterials/に残るが、それを指す
/// MaterialAssetの情報が消えるため）。各公開メソッドの先頭で
/// [_ensureLoaded] を呼び、初回アクセス時に自動でmaterials.jsonから復元する。
class MaterialService extends ChangeNotifier {
  final Map<String, List<MaterialAsset>> _materials = {}; // projectId -> assets
  final Map<String, int> _counters = {}; // projectId -> 次の連番
  final Map<String, Future<void>> _loading =
      {}; // projectId -> 読み込み中Future（同時読み込み防止）

  /// materialsOf()はUIのbuild内で同期的に呼ばれるため、事前に
  /// ensureLoaded()を呼んでおく必要がある（material_list_screen.dart等）。
  List<MaterialAsset> materialsOf(String projectId) =>
      List.unmodifiable(_materials[projectId] ?? const []);

  Future<Directory> _materialsDir(String projectId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/projects/$projectId/Materials');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// [projectId]の素材メタデータをmaterials.jsonから読み込む（初回のみ）。
  /// 既に読み込み済みの場合は何もしない。
  Future<void> ensureLoaded(String projectId) async {
    if (_materials.containsKey(projectId)) return;
    final inFlight = _loading[projectId];
    if (inFlight != null) return inFlight;
    final future = _loadFromDisk(projectId);
    _loading[projectId] = future;
    try {
      await future;
    } finally {
      _loading.remove(projectId);
    }
  }

  Future<void> _loadFromDisk(String projectId) async {
    final dir = await _materialsDir(projectId);
    final file = File('${dir.path}/materials.json');
    if (!file.existsSync()) {
      _materials[projectId] = [];
      _counters[projectId] = 0;
      return;
    }
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _counters[projectId] = json['nextCounter'] as int? ?? 0;
      _materials[projectId] = (json['materials'] as List<dynamic>? ?? [])
          .map((e) => _deserialize(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 破損している場合は空として扱う（実ファイルはMaterials/に残っているため
      // 完全な喪失ではないが、メタデータの復元はできない）。
      _materials[projectId] = [];
      _counters[projectId] = 0;
    }
    notifyListeners();
  }

  Future<void> _saveManifest(String projectId) async {
    final dir = await _materialsDir(projectId);
    final file = File('${dir.path}/materials.json');
    final list = _materials[projectId] ?? const [];
    final json = {
      'nextCounter': _counters[projectId] ?? 0,
      'materials': list.map(_serialize).toList(),
    };
    await file.writeAsString(jsonEncode(json));
  }

  Map<String, dynamic> _serialize(MaterialAsset m) => {
    'id': m.id,
    'originalFileName': m.originalFileName,
    'type': m.type.name,
    'sizeBytes': m.sizeBytes,
    'addedAt': m.addedAt.toIso8601String(),
    'width': m.width,
    'height': m.height,
    'durationMs': m.duration?.inMilliseconds,
  };

  MaterialAsset _deserialize(Map<String, dynamic> j) => MaterialAsset(
    id: j['id'] as String,
    originalFileName: j['originalFileName'] as String,
    type: MaterialType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => MaterialType.image,
    ),
    sizeBytes: j['sizeBytes'] as int,
    addedAt: DateTime.parse(j['addedAt'] as String),
    width: j['width'] as int?,
    height: j['height'] as int?,
    duration: j['durationMs'] != null
        ? Duration(milliseconds: j['durationMs'] as int)
        : null,
  );

  String _nextId(String projectId) {
    final n = (_counters[projectId] ?? 0) + 1;
    _counters[projectId] = n;
    return 'Material${n.toString().padLeft(4, '0')}';
  }

  /// [sourcePath]のファイルを素材として登録し、Materials/フォルダへコピーする。
  /// 同一種別・同一内容（バイト一致）の素材が既にある場合はそれを再利用し、
  /// 新規コピーは行わない（重複保存の防止）。
  Future<MaterialAsset> addMaterial({
    required String projectId,
    required String sourcePath,
    required MaterialType type,
  }) async {
    await ensureLoaded(projectId);
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
    await _saveManifest(projectId);
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
  /// を返す（不足素材の検出）。
  Future<String?> pathOf(String projectId, String materialId) async {
    await ensureLoaded(projectId);
    final asset = assetOf(projectId, materialId);
    if (asset == null) return null;
    final dir = await _materialsDir(projectId);
    final file = File('${dir.path}/${asset.storageName}');
    return file.existsSync() ? file.path : null;
  }

  MaterialAsset? assetOf(String projectId, String materialId) =>
      (_materials[projectId] ?? const [])
          .where((m) => m.id == materialId)
          .firstOrNull;

  /// 使用中でない素材を削除する。[isUsed]がtrueを返す場合は削除しない
  /// （使用中の素材は削除できない）。
  Future<bool> removeMaterial({
    required String projectId,
    required String materialId,
    required bool Function(String materialId) isUsed,
  }) async {
    await ensureLoaded(projectId);
    if (isUsed(materialId)) return false;
    final list = _materials[projectId];
    if (list == null) return false;
    final idx = list.indexWhere((m) => m.id == materialId);
    if (idx < 0) return false;
    final dir = await _materialsDir(projectId);
    final file = File('${dir.path}/${list[idx].storageName}');
    if (file.existsSync()) await file.delete();
    list.removeAt(idx);
    await _saveManifest(projectId);
    notifyListeners();
    return true;
  }

  /// 未使用の素材を一括削除する。削除件数を返す。
  Future<int> removeUnused({
    required String projectId,
    required bool Function(String materialId) isUsed,
  }) async {
    await ensureLoaded(projectId);
    final list = List<MaterialAsset>.from(_materials[projectId] ?? const []);
    int removed = 0;
    for (final m in list) {
      final ok = await removeMaterial(
        projectId: projectId,
        materialId: m.id,
        isUsed: isUsed,
      );
      if (ok) removed++;
    }
    return removed;
  }

  /// 登録済み素材のうち、実ファイルが見つからないものを返す
  /// （プロジェクトを開いた際の不足素材検出）。
  Future<List<MaterialAsset>> detectMissing(String projectId) async {
    await ensureLoaded(projectId);
    final dir = await _materialsDir(projectId);
    final missing = <MaterialAsset>[];
    for (final m in _materials[projectId] ?? const []) {
      if (!File('${dir.path}/${m.storageName}').existsSync()) missing.add(m);
    }
    return missing;
  }

  /// 指定した種類の素材のみを対象に、.niashare同梱用のファイルbyte列と
  /// マニフェストJSONを作成する（共有時の素材同梱チェックボックス用）。
  /// [includeTypes]が空、または対象素材が実ファイルとして見つからない場合は
  /// filesが空・manifestがnullの結果を返す。
  Future<({Map<String, Uint8List> files, String? manifest})> buildShareBundle(
    String projectId,
    Set<MaterialType> includeTypes,
  ) async {
    await ensureLoaded(projectId);
    if (includeTypes.isEmpty) {
      return (files: <String, Uint8List>{}, manifest: null);
    }
    final selected = (_materials[projectId] ?? const []).where(
      (m) => includeTypes.contains(m.type),
    );
    final dir = await _materialsDir(projectId);
    final files = <String, Uint8List>{};
    final included = <MaterialAsset>[];
    for (final m in selected) {
      final f = File('${dir.path}/${m.storageName}');
      if (!f.existsSync()) continue;
      files[m.storageName] = await f.readAsBytes();
      included.add(m);
    }
    if (files.isEmpty) return (files: <String, Uint8List>{}, manifest: null);
    final manifest = jsonEncode({
      'nextCounter': _counters[projectId] ?? 0,
      'materials': included.map(_serialize).toList(),
    });
    return (files: files, manifest: manifest);
  }
}
