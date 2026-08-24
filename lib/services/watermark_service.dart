import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watermark_asset.dart';

/// ユーザーウォーターマーク管理サービス（プレミアム限定）。
/// ウォーターマークは専用機能ではなく画像素材と同じタイムライン素材として
/// 扱うが、登録・管理自体はプロジェクトをまたぐアプリ全体の設定として行う。
class WatermarkService extends ChangeNotifier {
  static const _prefsKey = 'watermark_assets';

  final List<WatermarkAsset> _assets = [];
  int _counter = 0;

  List<WatermarkAsset> get assets => List.unmodifiable(_assets);

  Future<Directory> _watermarksDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/watermarks');
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

  /// 入力した文字列をウォーターマークとして登録する（
  /// 「設定項目：画像選択 / 文字入力」の文字入力側）。ドロップシャドウ・
  /// 縁取りも登録時点で既定値として設定できる。
  Future<WatermarkAsset> addTextWatermark(
    String text, {
    required int color,
    String? fontFamily,
    bool shadowEnabled = false,
    int shadowColor = 0x99000000,
    double shadowOffsetX = 4,
    double shadowOffsetY = 4,
    double shadowBlur = 6,
    bool outlineEnabled = false,
    int outlineColor = 0xFFFFFFFF,
    double outlineWidth = 3,
  }) async {
    final id = 'wm_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final asset = WatermarkAsset(
      id: id,
      name: text.length > 12 ? '${text.substring(0, 12)}…' : text,
      type: WatermarkAssetType.text,
      text: text,
      textColor: color,
      fontFamily: fontFamily,
      shadowEnabled: shadowEnabled,
      shadowColor: shadowColor,
      shadowOffsetX: shadowOffsetX,
      shadowOffsetY: shadowOffsetY,
      shadowBlur: shadowBlur,
      outlineEnabled: outlineEnabled,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
    );
    _assets.add(asset);
    await _persist();
    notifyListeners();
    return asset;
  }

  /// 登録済みウォーターマークの内容を更新する。過去に作成した
  /// ウォーターマークの編集もタップで後からできるようにする。
  /// 画像そのものの差し替えは行わず、名前・文字/色/フォント・ドロップ
  /// シャドウ/縁取りの既定設定のみを更新する。
  Future<void> updateAsset(WatermarkAsset updated) async {
    final idx = _assets.indexWhere((a) => a.id == updated.id);
    if (idx < 0) return;
    _assets[idx] = updated;
    await _persist();
    notifyListeners();
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
