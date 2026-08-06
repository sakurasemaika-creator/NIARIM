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
  static const String _tilesDir = 'tiles';

  // ─── 保存 ─────────────────────────────────────────────────────────────

  static Future<File> save({
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
  }) async {
    final dir = await _projectDir(project.id);
    final filePath = '${dir.path}/${project.id}.mirapro';

    final encoder = ZipFileEncoder();
    encoder.create(filePath);

    encoder.addArchiveFile(ArchiveFile(
      _manifestFile,
      0,
      utf8.encode(jsonEncode(_serializeManifest(project))),
    ));

    for (final scene in scenes) {
      final scenePrefix = 'Scene/${scene.id}';

      encoder.addArchiveFile(ArchiveFile(
        '$scenePrefix/$_framesFile',
        0,
        utf8.encode(jsonEncode(_serializeFrames(scene.frames))),
      ));

      final allTiles = tileManager.exportAll();
      for (final layerEntry in allTiles.entries) {
        for (final tileEntry in layerEntry.value.entries) {
          encoder.addArchiveFile(ArchiveFile(
            '$scenePrefix/$_tilesDir/${layerEntry.key}_${tileEntry.key}.bin',
            0,
            tileEntry.value,
          ));
        }
      }
    }

    encoder.close();
    return File(filePath);
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
