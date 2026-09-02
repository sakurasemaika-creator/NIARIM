import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../services/brush_service.dart';
import '../services/stamp_service.dart';
import '../services/tone_service.dart';
import 'archive_security.dart';
import 'niatra_serializer.dart';

/// `.niatra` に端末固有パスだけでなく、カスタムブラシ／トーン／スタンプの
/// 画像本体も同梱するための補助レイヤー。
///
/// 旧 `.niatra` は [NiatraSerializer] がそのまま読めるよう一切変更せず、
/// このクラスが付与する `creativeAssetsVersion` が存在する新形式だけを
/// フルモデル＋埋め込み画像として復元する。
class NiatraAssetBundle {
  static const _dataFile = 'data.json';
  static const _versionKey = 'creativeAssetsVersion';
  static const _version = 1;
  static const _embeddedImageKey = 'embeddedImagePath';

  /// 既存 [NiatraSerializer.export] が作ったZIPへカスタム画像を追加し、
  /// ブラシ／トーン／スタンプのJSONを各モデルの完全なtoJson()へ置き換える。
  /// これにより、画像だけでなくfolderId・fadeCustom・edgeJitter等も欠落しない。
  static Future<Uint8List> enrichExport(
    Uint8List original, {
    required Map<String, bool> selectedItems,
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
  }) async {
    final sourceArchive = ArchiveSecurity.decodeZip(original);
    final dataFile = sourceArchive.findFile(_dataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final data = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
    data[_versionKey] = _version;

    final output = Archive();
    for (final file in sourceArchive.files) {
      if (file.name == _dataFile) continue;
      output.addFile(ArchiveFile(file.name, file.size, file.content));
    }

    if (selectedItems['ブラシ'] ?? false) {
      final items = <Map<String, dynamic>>[];
      for (int i = 0; i < brush.brushes.length; i++) {
        final model = brush.brushes[i];
        final json = Map<String, dynamic>.from(model.toJson());
        await _embedImage(
          output,
          json,
          sourcePath: model.customImagePath,
          category: 'Brushes',
          index: i,
          pathKey: 'customImagePath',
        );
        items.add(json);
      }
      data['brushes'] = items;
    }

    if (selectedItems['素材'] ?? false) {
      final tones = <Map<String, dynamic>>[];
      for (int i = 0; i < tone.tones.length; i++) {
        final model = tone.tones[i];
        final json = Map<String, dynamic>.from(model.toJson());
        await _embedImage(
          output,
          json,
          sourcePath: model.texturePath,
          category: 'Tones',
          index: i,
          pathKey: 'texturePath',
        );
        tones.add(json);
      }
      data['tones'] = tones;

      final stamps = <Map<String, dynamic>>[];
      for (int i = 0; i < stamp.stamps.length; i++) {
        final model = stamp.stamps[i];
        final json = Map<String, dynamic>.from(model.toJson());
        await _embedImage(
          output,
          json,
          sourcePath: model.imagePath,
          category: 'Stamps',
          index: i,
          pathKey: 'imagePath',
        );
        stamps.add(json);
      }
      data['stamps'] = stamps;
    }

    final jsonBytes = utf8.encode(jsonEncode(data));
    output.addFile(ArchiveFile(_dataFile, jsonBytes.length, jsonBytes));
    final encoded = ZipEncoder().encode(output);
    if (encoded == null) throw const FormatException('ZIP encoding failed');
    return Uint8List.fromList(encoded);
  }

  /// 新形式の埋め込み画像を取り込み先端末のアプリ領域へ展開し、対応する
  /// Brush/Tone/Stampを新しいIDで追加する。処理したカテゴリはrawから除去し、
  /// 後続のNiatraSerializer.applyTo()による二重追加を防ぐ。
  ///
  /// 旧形式（creativeAssetsVersionなし）は何もせず、従来のapplyTo()へ委ねる。
  /// Webでは永続ファイルパスを作れないため画像だけ未復元になるが、完全な
  /// モデルJSON自体は同じ経路で復元し、旧Serializerによる項目欠落を防ぐ。
  static Future<void> restoreEmbeddedAssets(
    NiatraData data, {
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
  }) async {
    if (data.raw[_versionKey] != _version) return;

    final String? basePath =
        kIsWeb ? null : (await getApplicationDocumentsDirectory()).path;
    final importNonce = DateTime.now().microsecondsSinceEpoch;

    final brushesJson = data.raw['brushes'] as List<dynamic>?;
    if (brushesJson != null) {
      for (int i = 0; i < brushesJson.length; i++) {
        final json = Map<String, dynamic>.from(brushesJson[i] as Map<String, dynamic>);
        final id = 'Brush${importNonce}_$i';
        json['id'] = id;
        json['folderId'] = null;
        json['customImagePath'] = await _restoreImage(
          data,
          json,
          basePath: basePath,
          category: 'Brushes',
          id: id,
          pathKey: 'customImagePath',
        );
        brush.addBrush(Brush.fromJson(json));
      }
      data.raw.remove('brushes');
    }

    final tonesJson = data.raw['tones'] as List<dynamic>?;
    if (tonesJson != null) {
      for (int i = 0; i < tonesJson.length; i++) {
        final json = Map<String, dynamic>.from(tonesJson[i] as Map<String, dynamic>);
        final id = 'Tone${importNonce}_$i';
        json['id'] = id;
        json['folderId'] = null;
        json['texturePath'] = await _restoreImage(
          data,
          json,
          basePath: basePath,
          category: 'Tones',
          id: id,
          pathKey: 'texturePath',
        );
        tone.addTone(Tone.fromJson(json));
      }
      data.raw.remove('tones');
    }

    final stampsJson = data.raw['stamps'] as List<dynamic>?;
    if (stampsJson != null) {
      for (int i = 0; i < stampsJson.length; i++) {
        final json = Map<String, dynamic>.from(stampsJson[i] as Map<String, dynamic>);
        final id = 'Stamp${importNonce}_$i';
        json['id'] = id;
        json['folderId'] = null;
        json['imagePath'] = await _restoreImage(
          data,
          json,
          basePath: basePath,
          category: 'Stamps',
          id: id,
          pathKey: 'imagePath',
        );
        stamp.addStamp(Stamp.fromJson(json));
      }
      data.raw.remove('stamps');
    }
  }

  static Future<void> _embedImage(
    Archive archive,
    Map<String, dynamic> json, {
    required String? sourcePath,
    required String category,
    required int index,
    required String pathKey,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) return;
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return;
      final bytes = await source.readAsBytes();
      final ext = _safeExtension(sourcePath);
      final archivePath = 'CreativeAssets/$category/$index.$ext';
      archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      json[_embeddedImageKey] = archivePath;
      // 元端末の絶対パスを別端末へ持ち越さない。
      json[pathKey] = null;
    } on UnsupportedError {
      // dart:ioが利用できない環境では従来形式相当へフォールバックする。
    } on FileSystemException {
      // 読めない画像1件のために引き継ぎ全体を失敗させない。
    }
  }

  static Future<String?> _restoreImage(
    NiatraData data,
    Map<String, dynamic> json, {
    required String? basePath,
    required String category,
    required String id,
    required String pathKey,
  }) async {
    final embeddedPath = json[_embeddedImageKey] as String?;
    if (embeddedPath != null) {
      if (basePath == null) return null;
      final entry = data.archive.findFile(embeddedPath);
      if (entry == null) return null;
      final ext = _safeExtension(embeddedPath);
      final dir = Directory('$basePath/niarim/$category');
      if (!await dir.exists()) await dir.create(recursive: true);
      final destination = File('${dir.path}/$id.$ext');
      await destination.writeAsBytes(entry.content as List<int>, flush: true);
      return destination.path;
    }

    // 新形式なのに画像が埋め込まれていない場合でも、同一端末内で元パスが
    // まだ有効なら利用できる。別端末で存在しない絶対パスはnullへ落とす。
    if (basePath == null) return null;
    final legacyPath = json[pathKey] as String?;
    if (legacyPath == null || legacyPath.isEmpty) return null;
    try {
      return await File(legacyPath).exists() ? legacyPath : null;
    } on UnsupportedError {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static String _safeExtension(String path) {
    final fileName = path.replaceAll('\\', '/').split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'png';
    final ext = fileName.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : 'png';
  }
}
