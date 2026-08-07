import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/brush_texture_cache.dart';
import '../models/brush.dart';

/// ブラシ管理サービス（仕様書17・21）。
/// SharedPreferencesへ永続化する（端末単位。プロジェクトファイルには含めない）。
/// 従来はインメモリのみで、お気に入り・並び替え・複製・削除・パラメータ編集の
/// すべてがアプリ再起動のたびに失われていた（Task#83で修正）。
/// 自作ブラシ（画像からの新規作成）・フォルダ管理・読み込み/書き出しは
/// Task#84で追加した。カスタム画像はアプリ全体の`Brushes/`フォルダへ
/// コピーして保存する（仕様書21）。
class BrushService extends ChangeNotifier {
  static const _prefsKey = 'brushes';
  static const _currentIdKey = 'brushes_current_id';
  static const _foldersKey = 'brush_folders';

  final List<Brush> _brushes = [];
  final List<BrushFolder> _folders = [];
  Brush? _currentBrush;
  Color _currentColor = const Color(0xFF000000);

  List<Brush> get brushes => List.unmodifiable(_brushes);
  List<BrushFolder> get folders => List.unmodifiable(_folders);
  Brush? get currentBrush => _currentBrush;
  Color get currentColor => _currentColor;

  void setCurrentColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  static List<Brush> _defaultBrushes() => [
        const Brush(
          id: 'Brush0001', name: 'ペン', size: 5, opacity: 100, spacing: 10,
          blurRadius: 0, stabilization: true, stabilizationStrength: 50,
          dotPenMode: false, pressureMode: PressureMode.size, pressureStrength: 80,
          fadeMode: FadeMode.off, strokeDecay: false,
          mixingMode: BrushMixingMode.off, mixingRate: 0,
        ),
        const Brush(
          id: 'Brush0002', name: 'Gペン', size: 3, opacity: 100, spacing: 5,
          blurRadius: 0, stabilization: true, stabilizationStrength: 60,
          dotPenMode: false, pressureMode: PressureMode.sizeAndOpacity, pressureStrength: 90,
          fadeMode: FadeMode.weak, strokeDecay: false,
          mixingMode: BrushMixingMode.off, mixingRate: 0,
        ),
        const Brush(
          id: 'Brush0003', name: 'エアブラシ', size: 30, opacity: 40, spacing: 3,
          blurRadius: 50, stabilization: false, stabilizationStrength: 0,
          dotPenMode: false, pressureMode: PressureMode.opacity, pressureStrength: 70,
          fadeMode: FadeMode.off, strokeDecay: false,
          mixingMode: BrushMixingMode.off, mixingRate: 0,
        ),
        const Brush(
          id: 'Brush0004', name: '混色ブラシ', size: 15, opacity: 80, spacing: 8,
          blurRadius: 10, stabilization: false, stabilizationStrength: 0,
          dotPenMode: false, pressureMode: PressureMode.size, pressureStrength: 60,
          fadeMode: FadeMode.off, strokeDecay: false,
          mixingMode: BrushMixingMode.simple, mixingRate: 50,
        ),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _brushes.clear();
    if (raw == null) {
      // 初回起動：初期ブラシ一式を投入して即座に永続化する
      _brushes.addAll(_defaultBrushes());
      await _persist();
    } else {
      _brushes.addAll(raw.map((s) => Brush.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    final foldersRaw = prefs.getStringList(_foldersKey);
    _folders.clear();
    if (foldersRaw != null) {
      _folders.addAll(
          foldersRaw.map((s) => BrushFolder.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    final currentId = prefs.getString(_currentIdKey);
    _currentBrush = _brushes.where((b) => b.id == currentId).firstOrNull ?? _brushes.firstOrNull;
    _preloadTextureIfNeeded(_currentBrush);
  }

  /// 自作ブラシ画像（[Brush.customImagePath]）を事前デコードしてキャッシュへ
  /// 入れる。DrawingEngineの描画ホットパスは同期処理のため、実際に描画する
  /// 前（選択時・作成時・復元時）に済ませておく必要がある（失敗しても
  /// キャッシュが空のままフォールバックされるだけなので待たない）。
  void _preloadTextureIfNeeded(Brush? brush) {
    final path = brush?.customImagePath;
    if (path != null) {
      // ignore: unawaited_futures
      preloadBrushTexture(path);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _brushes.map((b) => jsonEncode(b.toJson())).toList());
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, _folders.map((f) => jsonEncode(f.toJson())).toList());
  }

  Future<void> _persistCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _currentBrush?.id;
    if (id == null) {
      await prefs.remove(_currentIdKey);
    } else {
      await prefs.setString(_currentIdKey, id);
    }
  }

  void selectBrush(String id) {
    _currentBrush = _brushes.firstWhere((b) => b.id == id);
    _preloadTextureIfNeeded(_currentBrush);
    notifyListeners();
    _persistCurrent();
  }

  void updateCurrentBrushSize(double size) {
    if (_currentBrush != null) {
      _currentBrush = _currentBrush!.copyWith(size: size);
      notifyListeners();
    }
  }

  void updateCurrentBrushOpacity(int opacity) {
    if (_currentBrush != null) {
      _currentBrush = _currentBrush!.copyWith(opacity: opacity);
      notifyListeners();
    }
  }

  void addBrush(Brush brush) {
    _brushes.add(brush);
    _preloadTextureIfNeeded(brush);
    notifyListeners();
    _persist();
  }

  void deleteBrush(String id) {
    _brushes.removeWhere((b) => b.id == id);
    notifyListeners();
    _persist();
  }

  void duplicateBrush(String id) {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final newId = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    _brushes.add(brush.copyWith(id: newId, name: '${brush.name} (コピー)'));
    notifyListeners();
    _persist();
  }

  void toggleFavoriteBrush(String id) {
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _brushes[idx] = _brushes[idx].copyWith(isFavorite: !_brushes[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  void reorderBrush(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final brush = _brushes.removeAt(oldIndex);
    _brushes.insert(newIndex, brush);
    notifyListeners();
    _persist();
  }

  void updateBrush(Brush brush) {
    final idx = _brushes.indexWhere((b) => b.id == brush.id);
    if (idx >= 0) {
      _brushes[idx] = brush;
      if (_currentBrush?.id == brush.id) _currentBrush = brush;
      _preloadTextureIfNeeded(brush);
      notifyListeners();
      _persist();
    }
  }

  // ─── フォルダ管理（仕様書17：ブラシ・トーン・スタンプすべてフォルダ管理対応） ──

  Future<BrushFolder> createFolder(String name) async {
    final folder = BrushFolder(id: 'BrushFolder${DateTime.now().millisecondsSinceEpoch}', name: name);
    _folders.add(folder);
    notifyListeners();
    await _persistFolders();
    return folder;
  }

  void renameFolder(String id, String name) {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(name: name);
    notifyListeners();
    _persistFolders();
  }

  void toggleFolderFavorite(String id) {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(isFavorite: !_folders[idx].isFavorite);
    notifyListeners();
    _persistFolders();
  }

  void reorderFolder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final folder = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, folder);
    notifyListeners();
    _persistFolders();
  }

  /// フォルダを削除する。中の素材はルート（フォルダなし）へ戻す（仕様書17）。
  void deleteFolder(String id) {
    _folders.removeWhere((f) => f.id == id);
    for (int i = 0; i < _brushes.length; i++) {
      if (_brushes[i].folderId == id) {
        _brushes[i] = _brushes[i].copyWith(folderId: null);
      }
    }
    notifyListeners();
    _persistFolders();
    _persist();
  }

  void moveToFolder(String brushId, String? folderId) {
    final idx = _brushes.indexWhere((b) => b.id == brushId);
    if (idx < 0) return;
    _brushes[idx] = _brushes[idx].copyWith(folderId: folderId);
    notifyListeners();
    _persist();
  }

  // ─── 自作ブラシ（画像からの新規作成、仕様書17） ──────────────────────────

  Future<Directory> _brushesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/miranima/Brushes');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// [sourcePath]の画像ファイルを取り込み、新規ブラシとして追加する
  /// （仕様書17：ブラシ画像からのブラシ作成）。
  Future<Brush> createBrushFromImage(String sourcePath, {String? name}) async {
    final id = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourcePath.split('.').last;
    final dir = await _brushesDir();
    final destPath = '${dir.path}/$id.$ext';
    await File(sourcePath).copy(destPath);
    final brush = Brush(
      id: id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : '自作ブラシ',
      size: 10, opacity: 100, spacing: 10, blurRadius: 0,
      stabilization: false, stabilizationStrength: 0, dotPenMode: false,
      pressureMode: PressureMode.size, pressureStrength: 80,
      fadeMode: FadeMode.off, strokeDecay: false,
      mixingMode: BrushMixingMode.off, mixingRate: 0,
      customImagePath: destPath,
    );
    addBrush(brush);
    return brush;
  }

  // ─── 読み込み・書き出し（仕様書17：個別ファイル単位） ───────────────────

  static const _bundleDataFile = 'data.json';

  /// ブラシ1件を`.mirabrush`ファイル（ZIP：data.json＋カスタム画像）として
  /// 書き出す。共有シートで送るためのFileを返す。
  Future<File> exportBrush(String id) async {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = brush.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${base.path}/$safeName.mirabrush';
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(
        ArchiveFile(_bundleDataFile, 0, utf8.encode(jsonEncode(brush.toJson()))));
    final imagePath = brush.customImagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      final bytes = await File(imagePath).readAsBytes();
      final ext = imagePath.split('.').last;
      encoder.addArchiveFile(ArchiveFile('image.$ext', bytes.length, bytes));
    }
    encoder.close();
    return File(filePath);
  }

  /// `.mirabrush`ファイルを読み込み、新規ブラシとして追加する。
  Future<Brush> importBrushFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_bundleDataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final json = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
    final imported = Brush.fromJson(json);
    final id = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = archive.files.where((f) => f.name.startsWith('image.')).firstOrNull;
    String? newImagePath;
    if (imageFile != null) {
      final ext = imageFile.name.split('.').last;
      final dir = await _brushesDir();
      newImagePath = '${dir.path}/$id.$ext';
      await File(newImagePath).writeAsBytes(imageFile.content as List<int>);
    }
    // customImagePathは元端末のパスをそのまま引き継げないため、copyWith
    // （??でnullを無視する実装）を使わず、常にnewImagePath（なければ未設定）で
    // 明示的に上書きする。
    final brush = Brush(
      id: id,
      name: imported.name, size: imported.size, opacity: imported.opacity,
      spacing: imported.spacing, blurRadius: imported.blurRadius,
      stabilization: imported.stabilization, stabilizationStrength: imported.stabilizationStrength,
      dotPenMode: imported.dotPenMode, pressureMode: imported.pressureMode,
      pressureStrength: imported.pressureStrength, fadeMode: imported.fadeMode,
      fadeCustom: imported.fadeCustom, strokeDecay: imported.strokeDecay,
      mixingMode: imported.mixingMode, mixingRate: imported.mixingRate,
      isFavorite: imported.isFavorite, customImagePath: newImagePath,
    );
    addBrush(brush);
    return brush;
  }
}

class BrushFolder {
  final String id;
  final String name;
  final bool isFavorite;

  BrushFolder({
    required this.id,
    required this.name,
    this.isFavorite = false,
  });

  BrushFolder copyWith({String? name, bool? isFavorite}) => BrushFolder(
        id: id,
        name: name ?? this.name,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isFavorite': isFavorite};

  factory BrushFolder.fromJson(Map<String, dynamic> j) => BrushFolder(
        id: j['id'] as String,
        name: j['name'] as String,
        isFavorite: j['isFavorite'] as bool? ?? false,
      );
}
