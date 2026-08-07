import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/font_asset.dart';

/// フォント管理サービス（仕様書15・21：ユーザーフォント追加）。
/// アプリ全体で共有するFonts/フォルダにTTF/OTFを保存し、FontLoaderで
/// Flutterへ登録することでテキストツールのフォント選択に利用可能にする。
/// プロジェクトとは独立して管理する（引き継ぎ・フォント共有の対象）。
class FontService extends ChangeNotifier {
  final List<FontAsset> _fonts = [];
  int _counter = 0;

  List<FontAsset> get fonts => List.unmodifiable(_fonts);

  /// [displayName]からFontLoaderへ登録したファミリー名を得る（IDベースで一意）。
  String familyNameOf(FontAsset asset) => 'UserFont_${asset.id}';

  static const _prefsKey = 'user_fonts';

  Future<Directory> _fontsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/miranima/Fonts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> init() async {
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

  Future<void> renameFont(String id, String newName) async {
    final idx = _fonts.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _fonts[idx] = _fonts[idx].copyWith(displayName: newName);
    await _persist();
    notifyListeners();
  }

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
