import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watermark_asset.dart';

/// ユーザーウォーターマーク管理サービス（プレミアム限定、仕様書08・13）。
/// ウォーターマークは専用機能ではなく画像素材と同じタイムライン素材として
/// 扱うが、登録・管理自体はプロジェクトをまたぐアプリ全体の設定として行う。
class WatermarkService extends ChangeNotifier {
  static const _prefsKey = 'watermark_assets';

  final List<WatermarkAsset> _assets = [];
  int _counter = 0;

  List<WatermarkAsset> get assets => List.unmodifiable(_assets);

  Future<Directory> _watermarksDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/miranima/watermarks');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    _assets.addAll(raw.map((s) => WatermarkAsset.fromJson(jsonDecode(s) as Map<String, dynamic>)));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _assets.map((a) => jsonEncode(a.toJson())).toList());
  }

  /// [sourcePath]の画像をウォーターマークとして登録する。
  Future<WatermarkAsset> addWatermark(String sourcePath) async {
    final dir = await _watermarksDir();
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'png';
    final id = 'wm_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final fileName = '$id.$ext';
    await File(sourcePath).copy('${dir.path}/$fileName');
    final name = sourcePath.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.[^.]+$'), '');
    final asset = WatermarkAsset(id: id, name: name, type: WatermarkAssetType.image, fileName: fileName);
    _assets.add(asset);
    await _persist();
    notifyListeners();
    return asset;
  }

  /// 入力した文字列をウォーターマークとして登録する（仕様書01・13：
  /// 「設定項目：画像選択 / 文字入力」の文字入力側）。
  Future<WatermarkAsset> addTextWatermark(String text, {required int color}) async {
    final id = 'wm_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final asset = WatermarkAsset(
      id: id,
      name: text.length > 12 ? '${text.substring(0, 12)}…' : text,
      type: WatermarkAssetType.text,
      text: text,
      textColor: color,
    );
    _assets.add(asset);
    await _persist();
    notifyListeners();
    return asset;
  }

  Future<void> removeWatermark(String id) async {
    final idx = _assets.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final fileName = _assets[idx].fileName;
    if (fileName != null) {
      final dir = await _watermarksDir();
      final file = File('${dir.path}/$fileName');
      if (file.existsSync()) await file.delete();
    }
    _assets.removeAt(idx);
    await _persist();
    notifyListeners();
  }

  /// ウォーターマークIDの実ファイルパスを解決する（画像タイプのみ・
  /// 見つからない場合や文字タイプの場合はnull）。
  Future<String?> pathOf(String id) async {
    final asset = _assets.where((a) => a.id == id).firstOrNull;
    if (asset == null || asset.fileName == null) return null;
    final dir = await _watermarksDir();
    final file = File('${dir.path}/${asset.fileName}');
    return file.existsSync() ? file.path : null;
  }
}
