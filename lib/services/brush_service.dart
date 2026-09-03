import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/brush_texture_cache.dart';
import '../models/asset_tags.dart';
import '../models/brush.dart';

/// ブラシ管理サービス。
/// SharedPreferencesへ永続化する（端末単位。プロジェクトファイルには含めない）。
/// お気に入り・並び替え・複製・削除・パラメータ編集の内容を保持する。
/// 自作ブラシ（画像からの新規作成）・フォルダ管理・読み込み/書き出しにも対応し、
/// カスタム画像はアプリ全体の`Brushes/`フォルダへコピーして保存する。
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
      id: 'Brush0001',
      name: 'ペン',
      size: 5,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 50,
      pixelMode: false,
      pressureMode: PressureMode.size,
      pressureStrength: 80,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
    ),
    const Brush(
      id: 'Brush0002',
      name: 'Gペン',
      size: 3,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 60,
      pixelMode: false,
      pressureMode: PressureMode.sizeAndOpacity,
      pressureStrength: 90,
      fadeMode: FadeMode.weak,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
    ),
    const Brush(
      id: 'Brush0003',
      name: 'エアブラシ',
      size: 30,
      opacity: 40,
      spacing: 3,
      blurRadius: 50,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureMode: PressureMode.opacity,
      pressureStrength: 70,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
    ),
    const Brush(
      id: 'Brush0004',
      name: '混色ブラシ',
      size: 15,
      opacity: 80,
      spacing: 8,
      blurRadius: 10,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureMode: PressureMode.size,
      pressureStrength: 60,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.simple,
      mixingRate: 50,
    ),
    // マーカーペン：チゼル（斜め切り）先端の太めの半透明ペン先
    // （重ね塗りで色が濃くなる）。calligraphyAngle: 0（ペン先の扁平な
    // 向きを水平に固定）により、横に引くと細く・縦に引くと太くなる
    // 実物のチゼルマーカー特有の見た目を再現する。あわせて、実物の
    // マーカーのようにインクがだんだん掠れて薄くなっていく様子を、
    // ストローク減衰機能（strokeDecay）で表現する。フェルトペンは
    // 筆圧の影響をほぼ受けないため、筆圧反映はOFFにする。
    const Brush(
      id: 'Brush0005',
      name: 'マーカーペン',
      size: 20,
      opacity: 65,
      spacing: 5,
      blurRadius: 0,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureMode: PressureMode.off,
      pressureStrength: 0,
      fadeMode: FadeMode.off,
      strokeDecay: true,
      mixingMode: BrushMixingMode.simple,
      mixingRate: 15,
      calligraphyAngle: 0.0,
      edgeJitter: true,
    ),
    // カリグラフィー：ペン先の角度を45度に固定した扁平ブラシ
    // （calligraphyAngle）。進行方向によって線の太さが変わる
    // カリグラフィーペン特有の見た目になる。
    const Brush(
      id: 'Brush0006',
      name: 'カリグラフィー',
      size: 14,
      opacity: 100,
      spacing: 4,
      blurRadius: 0,
      stabilization: true,
      stabilizationStrength: 40,
      pixelMode: false,
      pressureMode: PressureMode.size,
      pressureStrength: 50,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      calligraphyAngle: 45.0,
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
      _brushes.addAll(
        raw.map((s) => Brush.fromJson(jsonDecode(s) as Map<String, dynamic>)),
      );
      // 既存ユーザーにも新規追加した初期ブラシ（マーカーペン・カリグラフィー）を
      // 反映する（既に同じIDのブラシが存在する場合は追加しない）。
      final existingIds = _brushes.map((b) => b.id).toSet();
      final missing = _defaultBrushes().where(
        (b) => !existingIds.contains(b.id),
      );
      bool needsPersist = false;
      if (missing.isNotEmpty) {
        _brushes.addAll(missing);
        needsPersist = true;
      }
      // Brush0001/0002はプリインストールかつUI上編集不可。旧版の
      // 保存済み標準値はブラシ径より間隔が広く点線になっていたため、
      // 連続線の1px間隔へ安全に移行する。
      for (final id in const ['Brush0001', 'Brush0002']) {
        final index = _brushes.indexWhere((b) => b.id == id);
        if (index != -1 && _brushes[index].spacing != 1) {
          _brushes[index] = _brushes[index].copyWith(spacing: 1);
          needsPersist = true;
        }
      }
      // 「マーカーペン」（Brush0005）は後からcalligraphyAngle（チゼル先端の
      // 横太さ変化）を追加した。既にBrush0005を持つ既存ユーザーの端末には
      // 反映されないため、calligraphyAngle未設定のままなら一度だけ補う
      // （それ以外のユーザー編集済みパラメータ〔サイズ・不透明度等〕は
      // 変更しない）。calligraphyAngleはUI上編集不可のプリセット専用項目
      // のため、上書きしてもユーザーの意図的な設定を壊すことはない。
      final markerIndex = _brushes.indexWhere((b) => b.id == 'Brush0005');
      if (markerIndex != -1) {
        var m = _brushes[markerIndex];
        // calligraphyAngle未設定の旧データを補完
        if (m.calligraphyAngle == null) {
          m = m.copyWith(calligraphyAngle: 0.0);
          needsPersist = true;
        }
        // edgeJitter・混色設定未適用の旧データを補完
        if (!m.edgeJitter || m.mixingMode == BrushMixingMode.off) {
          m = m.copyWith(
            edgeJitter: true,
            mixingMode: BrushMixingMode.simple,
            mixingRate: m.mixingMode == BrushMixingMode.off ? 15 : m.mixingRate,
          );
          needsPersist = true;
        }
        _brushes[markerIndex] = m;
      }
      if (needsPersist) {
        await _persist();
      }
    }
    final foldersRaw = prefs.getStringList(_foldersKey);
    _folders.clear();
    if (foldersRaw != null) {
      _folders.addAll(
        foldersRaw.map(
          (s) => BrushFolder.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
    }
    final currentId = prefs.getString(_currentIdKey);
    _currentBrush =
        _brushes.where((b) => b.id == currentId).firstOrNull ??
        _brushes.firstOrNull;
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
    await prefs.setStringList(
      _prefsKey,
      _brushes.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _foldersKey,
      _folders.map((f) => jsonEncode(f.toJson())).toList(),
    );
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

  // プリインストールされている初期実装ブラシ（_defaultBrushes()の6件）は
  // 編集・削除の対象外とする（複製したものは対象外の複製元とは別IDになる
  // ため、複製後の編集・削除は可能）。
  static final Set<String> _builtInIds = _defaultBrushes()
      .map((b) => b.id)
      .toSet();

  bool isBuiltIn(String id) => _builtInIds.contains(id);

  void addBrush(Brush brush) {
    _brushes.add(brush);
    _preloadTextureIfNeeded(brush);
    notifyListeners();
    _persist();
  }

  /// [id]のブラシを削除する。プリインストール、またはお気に入り登録中の
  /// 場合は削除せずfalseを返す（呼び出し元でその旨のポップアップを表示する）。
  bool deleteBrush(String id) {
    if (isBuiltIn(id)) return false;
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx < 0) return false;
    if (_brushes[idx].isFavorite) return false;
    _brushes.removeAt(idx);
    notifyListeners();
    _persist();
    return true;
  }

  void duplicateBrush(String id) {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final newId = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    _brushes.add(brush.copyWith(id: newId, name: '${brush.name} (コピー)'));
    notifyListeners();
    _persist();
  }

  /// ブラシへ分類用タグを設定する（既存のタグ列を置き換える）。
  ///
  /// お気に入りと同様、**組み込みブラシにも付けられる**。編集・削除は
  /// できなくても「どう分類したいか」は利用者の都合であり、そこを縛ると
  /// タグ機能がほとんど使えなくなるため（`updateXxx`のような
  /// `isBuiltIn`ガードは意図的に置いていない）。
  void setTags(String id, List<String> tags) {
    final idx = _brushes.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _brushes[idx] = _brushes[idx].copyWith(tags: normalizeTags(tags));
    notifyListeners();
    _persist();
  }

  /// 登録されている全タグを、使われている件数の多い順（同数なら名前順）で
  /// 返す。タグ検索の候補チップに使う。表記ゆれで別タグ扱いにならないよう、
  /// 大文字小文字を無視して数え、代表表記は最初に見つかったものを使う。
  List<String> allTags() {
    final count = <String, int>{};
    final display = <String, String>{};
    for (final e in _brushes) {
      for (final tag in e.tags) {
        final key = tag.toLowerCase();
        count[key] = (count[key] ?? 0) + 1;
        display.putIfAbsent(key, () => tag);
      }
    }
    final keys = count.keys.toList()
      ..sort((a, b) {
        final c = count[b]!.compareTo(count[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final k in keys) display[k]!];
  }

  void toggleFavoriteBrush(String id) {
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _brushes[idx] = _brushes[idx].copyWith(
        isFavorite: !_brushes[idx].isFavorite,
      );
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
    if (isBuiltIn(brush.id)) return;
    final idx = _brushes.indexWhere((b) => b.id == brush.id);
    if (idx >= 0) {
      _brushes[idx] = brush;
      if (_currentBrush?.id == brush.id) _currentBrush = brush;
      _preloadTextureIfNeeded(brush);
      notifyListeners();
      _persist();
    }
  }

  // ─── フォルダ管理 ─────────────────────────────────────────────────────

  Future<BrushFolder> createFolder(String name) async {
    final folder = BrushFolder(
      id: 'BrushFolder${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
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
    _folders[idx] = _folders[idx].copyWith(
      isFavorite: !_folders[idx].isFavorite,
    );
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

  /// フォルダを削除する。中の素材はルート（フォルダなし）へ戻す。
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

  // ─── 自作ブラシ（画像からの新規作成） ────────────────────────────────────

  Future<Directory> _brushesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/Brushes');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// [sourcePath]の画像ファイルを取り込み、新規ブラシとして追加する。
  Future<Brush> createBrushFromImage(String sourcePath, {String? name}) async {
    final id = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourcePath.split('.').last;
    final dir = await _brushesDir();
    final destPath = '${dir.path}/$id.$ext';
    await File(sourcePath).copy(destPath);
    final brush = Brush(
      id: id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : '自作ブラシ',
      size: 10,
      opacity: 100,
      spacing: 10,
      blurRadius: 0,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureMode: PressureMode.size,
      pressureStrength: 80,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
      customImagePath: destPath,
    );
    addBrush(brush);
    return brush;
  }

  // ─── 読み込み・書き出し（個別ファイル単位） ──────────────────────────────

  static const _bundleDataFile = 'data.json';

  /// ブラシ1件を`.niabrush`ファイル（ZIP：data.json＋カスタム画像）として
  /// 書き出す。共有シートで送るためのFileを返す。
  Future<File> exportBrush(String id) async {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = brush.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${base.path}/$safeName.niabrush';
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(
      ArchiveFile(_bundleDataFile, 0, utf8.encode(jsonEncode(brush.toJson()))),
    );
    final imagePath = brush.customImagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      final bytes = await File(imagePath).readAsBytes();
      final ext = imagePath.split('.').last;
      encoder.addArchiveFile(ArchiveFile('image.$ext', bytes.length, bytes));
    }
    encoder.close();
    return File(filePath);
  }

  /// `.niabrush`ファイルを読み込み、新規ブラシとして追加する。
  Future<Brush> importBrushFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_bundleDataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final json =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    final imported = Brush.fromJson(json);
    final id = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = archive.files
        .where((f) => f.name.startsWith('image.'))
        .firstOrNull;
    String? newImagePath;
    if (imageFile != null) {
      final ext = imageFile.name.split('.').last;
      final dir = await _brushesDir();
      newImagePath = '${dir.path}/$id.$ext';
      await File(newImagePath).writeAsBytes(imageFile.content as List<int>);
    }
    // 元端末固有のID・フォルダ・画像パスだけ差し替え、それ以外の
    // rotation/density/scatter/fade/edgeJitter/pixelColor等は全て保持する。
    final restoredJson = Map<String, dynamic>.from(imported.toJson())
      ..['id'] = id
      ..['folderId'] = null
      ..['customImagePath'] = newImagePath;
    final brush = Brush.fromJson(restoredJson);
    addBrush(brush);
    return brush;
  }
}

class BrushFolder {
  final String id;
  final String name;
  final bool isFavorite;

  BrushFolder({required this.id, required this.name, this.isFavorite = false});

  BrushFolder copyWith({String? name, bool? isFavorite}) => BrushFolder(
    id: id,
    name: name ?? this.name,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isFavorite': isFavorite,
  };

  factory BrushFolder.fromJson(Map<String, dynamic> j) => BrushFolder(
    id: j['id'] as String,
    name: j['name'] as String,
    isFavorite: j['isFavorite'] as bool? ?? false,
  );
}
