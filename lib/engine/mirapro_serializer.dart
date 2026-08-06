import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, TextAlign;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../models/scene.dart';
import '../models/text_object.dart';
import 'tile_manager.dart';

/// .mirapro ファイルの保存・読み込み（仕様書06・07）
/// 形式：ZIP アーカイブ
///   manifest.json
///   Scene/Scene0001/frames.json
///   Scene/Scene0001/tiles/Layer0001_0,0.bin
class MiraproSerializer {
  static const String _manifestFile = 'manifest.json';
  static const String _framesFile = 'frames.json';
  static const String _tilesDir = 'tiles'; // 旧形式（Scene毎重複保存）の読み込み互換用
  static const String _rootTilesDir = 'Tiles'; // 新形式：プロジェクト全体で1箇所のみ保存

  // ─── 保存 ─────────────────────────────────────────────────────────────

  /// プロジェクトを保存する。既存の.miraproがある場合は差分保存（変更されたタイルのみ
  /// 再書き込みし、未変更タイルは前回保存分をそのまま引き継ぐ）を行う（仕様書09：差分保存）。
  static Future<File> save({
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
  }) async {
    final dir = await _projectDir(project.id);
    final filePath = '${dir.path}/${project.id}.mirapro';
    final exists = await File(filePath).exists();
    final result = exists
        ? await _writeArchiveDiff(filePath, project, scenes, tileManager)
        : await _writeArchive(filePath, project, scenes, tileManager);
    // 保存完了時点を基準に、次回保存までの変更差分を追跡し直す
    tileManager.consumeDirtyTiles();
    return result;
  }

  /// .mirashare として保存する（内容は.miraproと同一形式、拡張子のみ異なる）。
  /// 仕様書06：共有用ファイル。受信側で複製して通常プロジェクトとして追加する。
  static Future<File> saveShare({
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    String? outputDir,
  }) async {
    final dir = outputDir ?? (await _projectDir(project.id)).path;
    final safeName = project.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '$dir/$safeName.mirashare';
    return _writeArchive(filePath, project, scenes, tileManager);
  }

  /// .mirashare を読み込む（.miraproと同一形式なので load() をそのまま利用できる）。
  static Future<MiraproData> loadShare(String filePath) => load(filePath);

  // ─── 自動保存（クラッシュ復元専用・最大3件固定、仕様書06・09） ────────

  static Future<String> _autosaveDir(String projectId) async {
    final dir = await _projectDir(projectId);
    final autosaveDir = Directory('${dir.path}/autosave');
    if (!autosaveDir.existsSync()) autosaveDir.createSync(recursive: true);
    return autosaveDir.path;
  }

  static Future<File> saveAutosave({
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    required int slotIndex,
  }) async {
    final dir = await _autosaveDir(project.id);
    return _writeArchive('$dir/slot_$slotIndex.mirapro', project, scenes, tileManager);
  }

  static Future<MiraproData> loadAutosave(String projectId, int slotIndex) async {
    final dir = await _autosaveDir(projectId);
    return load('$dir/slot_$slotIndex.mirapro');
  }

  /// フル書き出し：manifest・全シーンのframes.json・全タイルを新規に書き込む。
  /// タイルはプロジェクト全体で1箇所（$_rootTilesDir/）にのみ保存する。
  static Future<File> _writeArchive(
    String filePath,
    Project project,
    List<Scene> scenes,
    TileManager tileManager,
  ) async {
    final encoder = ZipFileEncoder();
    encoder.create(filePath);

    encoder.addArchiveFile(ArchiveFile(
      _manifestFile,
      0,
      utf8.encode(jsonEncode(_serializeManifest(project))),
    ));

    for (final scene in scenes) {
      encoder.addArchiveFile(ArchiveFile(
        'Scene/${scene.id}/$_framesFile',
        0,
        utf8.encode(jsonEncode(_serializeFrames(scene.frames))),
      ));
    }

    final allTiles = tileManager.exportAll();
    for (final layerEntry in allTiles.entries) {
      for (final tileEntry in layerEntry.value.entries) {
        encoder.addArchiveFile(ArchiveFile(
          '$_rootTilesDir/${layerEntry.key}_${tileEntry.key}.bin',
          0,
          tileEntry.value,
        ));
      }
    }

    encoder.close();
    return File(filePath);
  }

  /// 差分書き出し：manifest・frames.jsonは毎回書き直す（軽量なため）が、
  /// タイルは前回保存（dirtyでないもの）から流用し、変更されたタイルのみ新規に書き込む。
  static Future<File> _writeArchiveDiff(
    String filePath,
    Project project,
    List<Scene> scenes,
    TileManager tileManager,
  ) async {
    final oldBytes = await File(filePath).readAsBytes();
    final oldArchive = ZipDecoder().decodeBytes(oldBytes);
    final oldFilesByName = {for (final f in oldArchive.files) f.name: f};

    final tmpPath = '$filePath.tmp';
    final encoder = ZipFileEncoder();
    encoder.create(tmpPath);

    encoder.addArchiveFile(ArchiveFile(
      _manifestFile,
      0,
      utf8.encode(jsonEncode(_serializeManifest(project))),
    ));

    for (final scene in scenes) {
      encoder.addArchiveFile(ArchiveFile(
        'Scene/${scene.id}/$_framesFile',
        0,
        utf8.encode(jsonEncode(_serializeFrames(scene.frames))),
      ));
    }

    final allTiles = tileManager.exportAll();
    for (final layerEntry in allTiles.entries) {
      final layerId = layerEntry.key;
      // 変更されたタイルキー（非破壊：グローバルなdirty集合は消費しない）
      final dirtyTiles = tileManager.getDirtyTilesForLayer(layerId);
      for (final tileEntry in layerEntry.value.entries) {
        final tileKey = tileEntry.key;
        final entryName = '$_rootTilesDir/${layerId}_$tileKey.bin';
        final oldEntry = oldFilesByName[entryName];
        if (dirtyTiles.containsKey(tileKey) || oldEntry == null) {
          // 変更あり、または旧ファイルに存在しない（新規タイル・旧形式からの移行）→再書き込み
          encoder.addArchiveFile(ArchiveFile(entryName, 0, tileEntry.value));
        } else {
          // 未変更タイル：前回保存分をそのまま引き継ぐ
          encoder.addArchiveFile(ArchiveFile(entryName, 0, oldEntry.content as List<int>));
        }
      }
    }

    encoder.close();

    final tmpFile = File(tmpPath);
    final targetFile = File(filePath);
    if (await targetFile.exists()) await targetFile.delete();
    await tmpFile.rename(filePath);
    return targetFile;
  }

  // ─── 読み込み ─────────────────────────────────────────────────────────

  static Future<MiraproData> load(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    late Project project;
    final scenes = <Scene>[];
    final tileData = <String, Map<String, Uint8List>>{};

    final manifestFile = archive.findFile(_manifestFile);
    if (manifestFile == null) throw const FormatException('manifest.json not found');
    project = _deserializeManifest(
      jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>,
    );

    final sceneIds = archive.files
        .map((f) => f.name)
        .where((n) => n.startsWith('Scene/') && n.endsWith('/$_framesFile'))
        .map((n) => n.split('/')[1])
        .toSet();

    for (final sceneId in sceneIds) {
      final framesFile = archive.findFile('Scene/$sceneId/$_framesFile');
      if (framesFile == null) continue;
      final frames = _deserializeFrames(
        jsonDecode(utf8.decode(framesFile.content as List<int>)) as List<dynamic>,
      );
      final sceneIndex = int.tryParse(sceneId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      scenes.add(Scene(id: sceneId, index: sceneIndex - 1, frames: frames));

      for (final file in archive.files) {
        if (!file.name.startsWith('Scene/$sceneId/$_tilesDir/')) continue;
        final fileName = file.name.split('/').last;
        final withoutExt = fileName.replaceAll('.bin', '');
        final underscoreIdx = withoutExt.indexOf('_');
        if (underscoreIdx < 0) continue;
        final layerId = withoutExt.substring(0, underscoreIdx);
        final tileKey = withoutExt.substring(underscoreIdx + 1);
        tileData.putIfAbsent(layerId, () => {})[tileKey] =
            Uint8List.fromList(file.content as List<int>);
      }
    }

    // 新形式：プロジェクト全体で1箇所に保存されたタイル（$_rootTilesDir/）
    for (final file in archive.files) {
      if (!file.name.startsWith('$_rootTilesDir/')) continue;
      final fileName = file.name.split('/').last;
      final withoutExt = fileName.replaceAll('.bin', '');
      final underscoreIdx = withoutExt.indexOf('_');
      if (underscoreIdx < 0) continue;
      final layerId = withoutExt.substring(0, underscoreIdx);
      final tileKey = withoutExt.substring(underscoreIdx + 1);
      tileData.putIfAbsent(layerId, () => {})[tileKey] =
          Uint8List.fromList(file.content as List<int>);
    }

    scenes.sort((a, b) => a.index.compareTo(b.index));
    return MiraproData(project: project, scenes: scenes, tileData: tileData);
  }

  // ─── シリアライズ ─────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeManifest(Project p) => {
        'id': p.id,
        'name': p.name,
        'fps': p.fps,
        'durationSeconds': p.durationSeconds,
        'backgroundColor': p.backgroundColor,
        'exportWidth': p.exportWidth,
        'exportHeight': p.exportHeight,
        'drawingAreaScale': p.drawingAreaScale,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'totalWorkSeconds': p.totalWorkSeconds,
        'appVersion': '1.0.0',
      };

  static List<dynamic> _serializeFrames(List<Frame> frames) =>
      frames.map((f) => {
            'index': f.index,
            'layers': f.layers.map(_serializeLayer).toList(),
          }).toList();

  static Map<String, dynamic> _serializeLayer(Layer l) => {
        'id': l.id,
        'name': l.name,
        'type': l.type.name,
        'opacity': l.opacity,
        'blendMode': l.blendMode.name,
        'isVisible': l.isVisible,
        'isLocked': l.isLocked,
        'opacityLocked': l.opacityLocked,
        'hasClipping': l.hasClipping,
        'hasMask': l.hasMask,
        'parentFolderId': l.parentFolderId,
        'needsAutofillUpdate': l.needsAutofillUpdate,
        'partId': l.partId,
        'rangeMode': l.rangeMode.name,
        'rangeStart': l.rangeStart,
        'rangeEnd': l.rangeEnd,
        'isExpanded': l.isExpanded,
        if (l.textObject != null) 'textObject': _serializeTextObject(l.textObject!),
      };

  static Map<String, dynamic> _serializeTextObject(TextObject t) => {
        'id': t.id,
        'text': t.text,
        'fontFamily': t.fontFamily,
        'fontSize': t.fontSize,
        'color': t.color.toARGB32(),
        'isBold': t.isBold,
        'isItalic': t.isItalic,
        'lineHeight': t.lineHeight,
        'letterSpacing': t.letterSpacing,
        'direction': t.direction.name,
        'align': t.align.name,
        'positionX': t.position.dx,
        'positionY': t.position.dy,
        'rotation': t.rotation,
        'scale': t.scale,
        'opacity': t.opacity,
        if (t.outline != null) 'outline': {
          'enabled': t.outline!.enabled,
          'color': t.outline!.color.toARGB32(),
          'width': t.outline!.width,
        },
      };

  // ─── デシリアライズ ───────────────────────────────────────────────────

  static Project _deserializeManifest(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        fps: j['fps'] as int,
        durationSeconds: j['durationSeconds'] as int,
        backgroundColor: j['backgroundColor'] as int,
        exportWidth: j['exportWidth'] as int? ?? 1920,
        exportHeight: j['exportHeight'] as int? ?? 1080,
        drawingAreaScale: (j['drawingAreaScale'] as num?)?.toDouble() ?? 1.0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        totalWorkSeconds: j['totalWorkSeconds'] as int? ?? 0,
      );

  static List<Frame> _deserializeFrames(List<dynamic> json) =>
      json.map((f) {
        final map = f as Map<String, dynamic>;
        return Frame(
          index: map['index'] as int,
          layers: (map['layers'] as List<dynamic>)
              .map((l) => _deserializeLayer(l as Map<String, dynamic>))
              .toList(),
        );
      }).toList();

  static Layer _deserializeLayer(Map<String, dynamic> j) => Layer(
        id: j['id'] as String,
        name: j['name'] as String,
        type: LayerType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => LayerType.normal),
        opacity: j['opacity'] as int? ?? 100,
        blendMode: LayerBlendMode.values.firstWhere(
            (e) => e.name == j['blendMode'],
            orElse: () => LayerBlendMode.normal),
        isVisible: j['isVisible'] as bool? ?? true,
        isLocked: j['isLocked'] as bool? ?? false,
        opacityLocked: j['opacityLocked'] as bool? ?? false,
        hasClipping: j['hasClipping'] as bool? ?? false,
        hasMask: j['hasMask'] as bool? ?? false,
        parentFolderId: j['parentFolderId'] as String?,
        needsAutofillUpdate: j['needsAutofillUpdate'] as bool? ?? false,
        partId: j['partId'] as String?,
        rangeMode: LayerRangeMode.values.firstWhere(
            (e) => e.name == j['rangeMode'],
            orElse: () => LayerRangeMode.allFrames),
        rangeStart: j['rangeStart'] as int?,
        rangeEnd: j['rangeEnd'] as int?,
        isExpanded: j['isExpanded'] as bool? ?? true,
        textObject: j['textObject'] != null
            ? _deserializeTextObject(j['textObject'] as Map<String, dynamic>)
            : null,
      );

  static TextObject _deserializeTextObject(Map<String, dynamic> j) {
    final outlineMap = j['outline'] as Map<String, dynamic>?;
    return TextObject(
      id: j['id'] as String,
      text: j['text'] as String,
      fontFamily: j['fontFamily'] as String? ?? 'Roboto',
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 24,
      color: Color(j['color'] as int),
      isBold: j['isBold'] as bool? ?? false,
      isItalic: j['isItalic'] as bool? ?? false,
      lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? 1.2,
      letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0,
      direction: TextWritingDirection.values.firstWhere(
          (e) => e.name == j['direction'],
          orElse: () => TextWritingDirection.horizontal),
      align: TextAlign.values.firstWhere(
          (e) => e.name == j['align'],
          orElse: () => TextAlign.left),
      position: Offset(
        (j['positionX'] as num?)?.toDouble() ?? 0,
        (j['positionY'] as num?)?.toDouble() ?? 0,
      ),
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
      scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
      opacity: (j['opacity'] as num?)?.toDouble() ?? 1.0,
      outline: outlineMap != null
          ? TextOutline(
              enabled: outlineMap['enabled'] as bool? ?? false,
              color: Color(outlineMap['color'] as int),
              width: (outlineMap['width'] as num?)?.toDouble() ?? 3,
            )
          : null,
    );
  }

  // ─── ヘルパー ─────────────────────────────────────────────────────────

  static Future<Directory> _projectDir(String projectId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/miranima/projects/$projectId');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> projectsBasePath() async {
    final base = await getApplicationDocumentsDirectory();
    return '${base.path}/miranima/projects';
  }
}

class MiraproData {
  final Project project;
  final List<Scene> scenes;
  final Map<String, Map<String, Uint8List>> tileData;

  const MiraproData({
    required this.project,
    required this.scenes,
    required this.tileData,
  });
}
