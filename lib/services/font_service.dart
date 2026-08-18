import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/downloadable_font.dart';
import '../models/font_asset.dart';

/// フォント管理サービス（仕様書15・21：ユーザーフォント追加）。
/// アプリ全体で共有するFonts/フォルダにTTF/OTFを保存し、FontLoaderで
/// Flutterへ登録することでテキストツールのフォント選択に利用可能にする。
/// プロジェクトとは独立して管理する（引き継ぎ・フォント共有の対象）。
class FontService extends ChangeNotifier {
  final List<FontAsset> _fonts = [];
  int _counter = 0;
  List<DownloadableFontEntry> _catalog = [];

  List<FontAsset> get fonts => List.unmodifiable(_fonts);

  /// 追加フリーフォントカタログ（オンデマンドダウンロード対象、約2000書体。
  /// assets/font_catalog/font_catalog.jsonから読み込む）。
  List<DownloadableFontEntry> get catalog => List.unmodifiable(_catalog);

  /// [displayName]からFontLoaderへ登録したファミリー名を得る（IDベースで一意）。
  String familyNameOf(FontAsset asset) => 'UserFont_${asset.id}';

  static const _prefsKey = 'user_fonts';

  Future<Directory> _fontsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/Fonts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> init() async {
    try {
      _catalog = await loadDownloadableFontCatalog();
    } catch (_) {
      // カタログ読み込み失敗時も既存フォントの初期化は継続する
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _fonts.addAll(list.map((e) => FontAsset.fromJson(e as Map<String, dynamic>)));
        for (final f in _fonts) {
          final n = int.tryParse(f.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (n >= _counter) _counter = n + 1;
        }
      }
      // 起動のたびにFontLoaderへ再登録する（登録状態はプロセス単位で消えるため）。
      // 1件が破損していても他のフォントの登録は継続する。
      final dir = await _fontsDir();
      for (final font in _fonts) {
        final file = File('${dir.path}/${font.fileName}');
        if (!file.existsSync()) continue;
        try {
          await _registerFont(font, file);
        } catch (_) {
          // 破損フォント：このフォントの登録のみスキップして続行
        }
      }
    } catch (_) {
      // 読み込み失敗時はフォントなしとして続行
    }
  }

  Future<void> _registerFont(FontAsset asset, File file) async {
    final bytes = await file.readAsBytes();
    final loader = FontLoader(familyNameOf(asset))
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_fonts.map((f) => f.toJson()).toList()));
    } catch (_) {
      // 保存失敗時も続行
    }
  }

  /// TTF/OTFファイルを追加する。対応形式以外はnullを返す（仕様書15：
  /// 「このフォントは読み込めません。」）。読み込みはできても登録（パース）に
  /// 失敗した場合は[FontCorruptedException]を投げる（仕様書15：
  /// 「フォントが破損しています。」）。
  Future<FontAsset?> addFont(String sourcePath, String displayName) async {
    final ext = sourcePath.split('.').last.toLowerCase();
    if (ext != 'ttf' && ext != 'otf') return null;
    final dir = await _fontsDir();
    final id = 'Font${(_counter++).toString().padLeft(4, '0')}';
    final fileName = '$id.$ext';
    final destFile = File('${dir.path}/$fileName');
    try {
      await File(sourcePath).copy(destFile.path);
    } catch (_) {
      return null;
    }
    final asset = FontAsset(
      id: id,
      displayName: displayName,
      fileName: fileName,
      sizeBytes: await destFile.length(),
      addedAt: DateTime.now(),
    );
    try {
      await _registerFont(asset, destFile);
    } catch (_) {
      // 破損フォント：コピーしたファイルを片付けてから通知する
      try {
        if (destFile.existsSync()) await destFile.delete();
      } catch (_) {}
      throw FontCorruptedException();
    }
    _fonts.add(asset);
    await _persist();
    notifyListeners();
    return asset;
  }

  /// フォントファイルの生データを取得する（仕様書15：プロジェクト共有時の
  /// フォント同梱に使用）。
  Future<Uint8List?> readFontBytes(FontAsset asset) async {
    final dir = await _fontsDir();
    final file = File('${dir.path}/${asset.fileName}');
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// 共有ファイル（.niashare）に同梱されたフォントを取り込む（仕様書15：
  /// 「「フォントを含める」を選択した場合のみフォントを同梱」）。
  /// [id]・[fileName]を送信元と同じものに保つことで、familyNameOf()が
  /// 生成するファミリー名（インポートしたテキストレイヤーのfontFamilyが
  /// 参照する値）が送信元と一致し、正しくフォントが解決されるようにする。
  /// 既に同じIDのフォントが登録済みの場合は何もしない（重複防止）。
  Future<void> importBundledFont({
    required String id,
    required String displayName,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (_fonts.any((f) => f.id == id)) return;
    final dir = await _fontsDir();
    final destFile = File('${dir.path}/$fileName');
    try {
      await destFile.writeAsBytes(bytes);
    } catch (_) {
      return;
    }
    final asset = FontAsset(
      id: id,
      displayName: displayName,
      fileName: fileName,
      sizeBytes: bytes.length,
      addedAt: DateTime.now(),
    );
    try {
      await _registerFont(asset, destFile);
    } catch (_) {
      try {
        if (destFile.existsSync()) await destFile.delete();
      } catch (_) {}
      return;
    }
    _fonts.add(asset);
    final n = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (n >= _counter) _counter = n + 1;
    await _persist();
    notifyListeners();
  }

  /// [entry]が既にダウンロード・登録済みかどうか（追加フリーフォント一覧の
  /// ダウンロードボタン表示に使用）。
  bool isCatalogFontDownloaded(DownloadableFontEntry entry) =>
      _fonts.any((f) => f.id == entry.id);

  /// カタログの追加フリーフォント（[DownloadableFontEntry]）をネットワーク
  /// 経由で取得し、[importBundledFont]と同じ仕組みで端末内に保存・登録する。
  /// 一度ダウンロードすれば以降はオフラインでも利用できる。
  /// 失敗時は[FontDownloadException]を投げる。
  Future<void> downloadCatalogFont(DownloadableFontEntry entry) async {
    if (isCatalogFontDownloaded(entry)) return;
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse(entry.sourceUrl))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw FontDownloadException('ネットワークに接続できません。');
    }
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw FontDownloadException('このフォントは読み込めません。');
    }
    try {
      await importBundledFont(
        id: entry.id,
        displayName: entry.displayName,
        fileName: entry.fileName,
        bytes: response.bodyBytes,
      );
    } catch (_) {
      throw FontDownloadException('フォントが破損しています。');
    }
    if (!isCatalogFontDownloaded(entry)) {
      // importBundledFont内部でパース失敗した場合は例外を投げず静かに
      // スキップされるため、登録できたかどうかをここで確認する。
      throw FontDownloadException('フォントが破損しています。');
    }
  }

  Future<void> renameFont(String id, String newName) async {
    final idx = _fonts.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _fonts[idx] = _fonts[idx].copyWith(displayName: newName);
    await _persist();
    notifyListeners();
  }

  /// お気に入り登録／解除を切り替える（フォント選択画面「ダウンロード済み」
  /// タブでの絞り込みに使用）。
  Future<void> toggleFavorite(String id) async {
    final idx = _fonts.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _fonts[idx] = _fonts[idx].copyWith(isFavorite: !_fonts[idx].isFavorite);
    await _persist();
    notifyListeners();
  }

  /// ピクセルモードのON/OFFを切り替える（フォント選択画面「ダウンロード済み」
  /// タブのトグルボタンから呼ぶ）。
  Future<void> togglePixelMode(String id) async {
    final idx = _fonts.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _fonts[idx] = _fonts[idx].copyWith(pixelMode: !_fonts[idx].pixelMode);
    await _persist();
    notifyListeners();
  }

  /// [family]（TextObject.fontFamilyの値。familyNameOf()の戻り値と同じ表現）
  /// に該当するFontAssetのピクセルモードがONかどうかを返す。テキスト
  /// ラスタライズ時（text_render.dart呼び出し元）にこの結果を渡すことで、
  /// フォント側の設定だけでピクセルモードを反映できるようにする
  /// （テキストレイヤーごとに個別設定を持たせない設計。DL済のフォント
  /// 一覧画面で各フォントにそれぞれピクセルモードをon/offする）。
  /// built-in同梱フォント（familyNameOf()を経由しない
  /// ものはFontAssetが無いためfalseを返す。
  bool pixelModeForFamily(String family) =>
      _fonts.any((f) => familyNameOf(f) == family && f.pixelMode);

  Future<void> removeFont(String id) async {
    final idx = _fonts.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    final font = _fonts.removeAt(idx);
    try {
      final dir = await _fontsDir();
      final file = File('${dir.path}/${font.fileName}');
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // ファイル削除失敗時も一覧からは除去する
    }
    await _persist();
    notifyListeners();
    // 注：FlutterのFontLoaderには登録解除APIが無いため、削除後もプロセス内では
    // 引き続き描画可能（既存テキストが壊れて表示されることを防ぐ副次的な効果）。
  }
}

/// フォントファイルの読み込み（パース）に失敗した場合の例外（仕様書15：
/// 「フォントが破損しています。」）。拡張子は正しいが内容が壊れているケースを表す。
class FontCorruptedException implements Exception {}

/// 追加フリーフォントのダウンロードに失敗した場合の例外（[FontService.
/// downloadCatalogFont]用）。[message]はそのままユーザーへ表示できる文言。
class FontDownloadException implements Exception {
  final String message;
  const FontDownloadException(this.message);
}
