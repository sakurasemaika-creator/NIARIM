import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_theme_preset.dart';
import '../models/autofill_preset.dart';
import '../models/brush.dart';
import '../models/color_palette.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../services/autofill_preset_service.dart';
import '../services/brush_service.dart';
import '../services/palette_service.dart';
import '../services/pixel_art_palette_service.dart';
import '../services/project_service.dart';
import '../services/settings_service.dart';
import '../services/stamp_service.dart';
import '../services/theme_service.dart';
import '../services/tone_service.dart';
import 'archive_security.dart';
import 'niapro_serializer.dart' show NiaproSerializer;

/// .niatra（引き継ぎファイル、旧称.stutra）の書き出し・読み込み。
/// 引き継ぐ項目（設定/素材/ブラシ/プリセット/UIテーマ）をチェックボックスで選択できる。
/// 形式：ZIPアーカイブ内に data.json 一枚のみを持つシンプル構成。
class NiatraSerializer {
  static const _dataFile = 'data.json';

  /// 引き継ぎデータをZIPバイト列として書き出す（メモリ上でエンコードするため
  /// Web版でも動作する。旧実装はpath_providerでローカルファイルとして書き出
  /// していたが、Web版ではpath_providerのプラットフォーム実装が存在せず
  /// MissingPluginExceptionで失敗していたため、ファイルI/Oを介さない方式へ
  /// 変更した）。呼び出し側はこのバイト列をXFile.fromData等で共有する。
  static Future<Uint8List> export({
    required Map<String, bool> selectedItems,
    required SettingsService settings,
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
    required AutofillPresetService autofillPresets,
    required ThemeService theme,
    required PaletteService palette,
    required PixelArtPaletteService pixelArtPalette,
    // 制作中プロジェクトを丸ごと引き継ぐための追加データ。呼び出し側
    // （transfer_screen.dart）でユーザーが選択したプロジェクトごとに
    // NiaproSerializer.saveShare()で生成した.niashareバイト列を
    // 「ファイル名 → バイト列」のMapとして渡す。他カテゴリと異なりチェック
    // ボックスひとつでON/OFFする単純な項目ではなく、プロジェクトごとに個別
    // 選択できるようにするため、真偽値のselectedItemsではなくこの専用
    // パラメータで受け取る。
    Map<String, Uint8List>? projectFiles,
  }) async {
    final data = <String, dynamic>{'appVersion': '1.0.0'};

    if (selectedItems['設定'] ?? false) {
      data['settings'] = {
        'defaultFps': settings.defaultFps,
        'undoLimit': settings.undoLimit,
        'trashAutoDeleteDays': settings.trashAutoDeleteDays,
        'language': settings.language,
        'twoFingerTap': settings.twoFingerTap.name,
        'threeFingerTap': settings.threeFingerTap.name,
        'twoFingerSwipe': settings.twoFingerSwipe.name,
        'longPress': settings.longPress.name,
      };
    }

    if (selectedItems['ブラシ'] ?? false) {
      data['brushes'] = brush.brushes.map(_serializeBrush).toList();
    }

    if (selectedItems['素材'] ?? false) {
      data['tones'] = tone.tones.map(_serializeTone).toList();
      data['stamps'] = stamp.stamps.map(_serializeStamp).toList();
    }

    if (selectedItems['プリセット'] ?? false) {
      data['autofillPresets'] = autofillPresets.presets
          .map(_serializeAutofillPreset)
          .toList();
    }

    if (selectedItems['UIテーマ'] ?? false) {
      data['themePresets'] = theme.presets.map(_serializeThemePreset).toList();
      data['currentThemeId'] = theme.current.id;
    }

    if (selectedItems['パレット'] ?? false) {
      data['palettes'] = palette.palettes.map((p) => p.toJson()).toList();
      data['pixelArtPalettes'] = pixelArtPalette.palettes
          .map((p) => p.toJson())
          .toList();
    }

    final archive = Archive();

    // プロジェクトは.niashare形式（.niaproと同一形式）のバイト列そのままを
    // Projects/以下へ生ファイルとして埋め込む（JSON化・base64化するとサイズが
    // 大きく膨らむため、既存のpackage:archive基盤をそのまま流用する）。
    // どのファイルを埋め込んだかはdata.json側の'projectFiles'キーへ記録し、
    // 読み込み側（restoreProjects）がそのリストを頼りにアーカイブから
    // 個別のエントリを取り出す。
    if (projectFiles != null && projectFiles.isNotEmpty) {
      data['projectFiles'] = projectFiles.keys.toList();
      for (final entry in projectFiles.entries) {
        archive.addFile(
          ArchiveFile('Projects/${entry.key}', entry.value.length, entry.value),
        );
      }
    }

    final jsonBytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile(_dataFile, jsonBytes.length, jsonBytes));
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw const FormatException('ZIP encoding failed');
    return Uint8List.fromList(zipBytes);
  }

  /// バイト列から読み込む（Web版でファイル選択ダイアログがパスではなく
  /// バイト列のみを返す場合もこちらを使う）。
  static NiatraData loadFromBytes(List<int> bytes) {
    final archive = ArchiveSecurity.decodeZip(bytes);
    final dataFile = archive.findFile(_dataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final data =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    return NiatraData(data, archive);
  }

  /// ローカルファイルパスから読み込む（デスクトップ/モバイル用）。
  static Future<NiatraData> load(String filePath) async {
    final file = File(filePath);
    ArchiveSecurity.validateFileSize(await file.length());
    final bytes = await file.readAsBytes();
    return loadFromBytes(bytes);
  }

  /// 読み込んだデータを各サービスへ適用する。存在しない項目はスキップする。
  static void applyTo(
    NiatraData data, {
    required SettingsService settings,
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
    required AutofillPresetService autofillPresets,
    required ThemeService theme,
    required PaletteService palette,
    required PixelArtPaletteService pixelArtPalette,
  }) {
    final j = data.raw;

    final settingsJson = j['settings'] as Map<String, dynamic>?;
    if (settingsJson != null) {
      settings.setDefaultFps(
        settingsJson['defaultFps'] as int? ?? settings.defaultFps,
      );
      settings.setUndoLimit(
        settingsJson['undoLimit'] as int? ?? settings.undoLimit,
      );
      settings.setTrashAutoDelete(
        settingsJson['trashAutoDeleteDays'] as int? ??
            settings.trashAutoDeleteDays,
      );
    }

    final brushesJson = j['brushes'] as List<dynamic>?;
    if (brushesJson != null) {
      for (final bj in brushesJson) {
        brush.addBrush(_deserializeBrush(bj as Map<String, dynamic>));
      }
    }

    final tonesJson = j['tones'] as List<dynamic>?;
    if (tonesJson != null) {
      for (final tj in tonesJson) {
        tone.addTone(_deserializeTone(tj as Map<String, dynamic>));
      }
    }

    final stampsJson = j['stamps'] as List<dynamic>?;
    if (stampsJson != null) {
      for (final sj in stampsJson) {
        stamp.addStamp(_deserializeStamp(sj as Map<String, dynamic>));
      }
    }

    final presetsJson = j['autofillPresets'] as List<dynamic>?;
    if (presetsJson != null) {
      for (final pj in presetsJson) {
        autofillPresets.addPreset(
          _deserializeAutofillPreset(pj as Map<String, dynamic>),
        );
      }
    }

    final themePresetsJson = j['themePresets'] as List<dynamic>?;
    if (themePresetsJson != null) {
      for (final tpj in themePresetsJson) {
        theme.savePreset(_deserializeThemePreset(tpj as Map<String, dynamic>));
      }
    }

    // パレット・ドット絵専用パレットはIDが取り込み先の既存データと衝突
    // しないよう、それぞれのimportPalette()/addPalette()内で振り直される
    // （他カテゴリと異なり戻り値がFutureだが、他の追加系メソッドの
    // 内部永続化と同様、呼び出し元は完了を待たずfire-and-forgetでよい）。
    final palettesJson = j['palettes'] as List<dynamic>?;
    if (palettesJson != null) {
      for (final pj in palettesJson) {
        palette.importPalette(
          ColorPalette.fromJson(pj as Map<String, dynamic>),
        );
      }
    }

    final pixelArtPalettesJson = j['pixelArtPalettes'] as List<dynamic>?;
    if (pixelArtPalettesJson != null) {
      for (final pj in pixelArtPalettesJson) {
        final p = ColorPalette.fromJson(pj as Map<String, dynamic>);
        pixelArtPalette.addPalette(p.name, p.colors);
      }
    }
  }

  /// 埋め込まれた制作中プロジェクト（Projects/以下の.niashareエントリ）を
  /// 新規プロジェクトとして復元する。他カテゴリのapplyTo()と異なり
  /// プロジェクト取り込みはファイルI/O・タイル展開を伴う非同期処理
  /// （ProjectService.importSharedProject）のため、同期メソッドのapplyTo()
  /// とは別の非同期メソッドとして分離している。呼び出し側はawaitすること。
  ///
  /// 一時ファイルの書き出しにpath_providerを使うため、Web版では動作しない
  /// （プロジェクトデータ自体が既にdart:io/path_provider前提の.niapro形式で
  /// あり、この制約はniatra以前から存在する既存の制約に合わせたもの）。
  static Future<void> restoreProjects(
    NiatraData data,
    ProjectService projectService,
  ) async {
    final fileNames = (data.raw['projectFiles'] as List<dynamic>?)
        ?.cast<String>();
    if (fileNames == null || fileNames.isEmpty) return;
    final tempDir = await getTemporaryDirectory();
    for (final name in fileNames) {
      final entry = data.archive.findFile('Projects/$name');
      if (entry == null) continue;
      final tempPath =
          '${tempDir.path}/niatra_import_${DateTime.now().microsecondsSinceEpoch}_$name';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(entry.content as List<int>);
      try {
        final niaproData = await NiaproSerializer.loadShare(tempPath);
        // niatra経由の取り込みは自分自身の別端末データを戻しているだけであり、
        // 他人から共有された作品ではないため、ホーム画面の「共有」タブへは
        // 振り分けずisSharedImport: falseで通常プロジェクトとして追加する。
        await projectService.importSharedProject(
          niaproData,
          isSharedImport: false,
        );
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    }
  }

  // ─── Brush ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeBrush(Brush b) => b.toJson();

  static Brush _deserializeBrush(Map<String, dynamic> j) {
    final json = Map<String, dynamic>.from(j)
      ..['id'] = 'Brush${DateTime.now().microsecondsSinceEpoch}_${j['id']}'
      ..['folderId'] = null;
    return Brush.fromJson(json);
  }

  // ─── Tone / Stamp ─────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeTone(Tone t) => t.toJson();

  static Tone _deserializeTone(Map<String, dynamic> j) {
    final json = Map<String, dynamic>.from(j)
      ..['id'] = 'Tone${DateTime.now().microsecondsSinceEpoch}_${j['id']}'
      ..['folderId'] = null;
    return Tone.fromJson(json);
  }

  static Map<String, dynamic> _serializeStamp(Stamp s) => s.toJson();

  static Stamp _deserializeStamp(Map<String, dynamic> j) {
    final json = Map<String, dynamic>.from(j)
      ..['id'] = 'Stamp${DateTime.now().microsecondsSinceEpoch}_${j['id']}'
      ..['folderId'] = null;
    return Stamp.fromJson(json);
  }

  // ─── AutofillPreset ───────────────────────────────────────────────────

  // グラデーション・トーン・線画色・トレス調整など、パーツが持つ設定を
  // 一切欠かさず引き継げるよう、モデル自身のtoJson/fromJsonをそのまま使う。
  static Map<String, dynamic> _serializeAutofillPreset(AutofillPreset p) =>
      p.toJson();

  static AutofillPreset _deserializeAutofillPreset(Map<String, dynamic> j) {
    final base = AutofillPreset.fromJson(j);
    // IDは取り込み先で既存プリセットと衝突しないよう振り直す。
    final suffix = DateTime.now().microsecondsSinceEpoch;
    return base.copyWith(
      id: 'p_${suffix}_${base.id}',
      parts: base.parts
          .map((part) => part.copyWith(id: 'part_${suffix}_${part.id}'))
          .toList(),
    );
  }

  // ─── ThemePreset ──────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeThemePreset(AppThemePreset t) => {
    'id': t.id,
    'name': t.name,
    'accentColor': t.accentColor.toARGB32(),
    'textColor': t.textColor.toARGB32(),
    'panelBgColor': t.panelBgColor.toARGB32(),
    'menuBgColor': t.menuBgColor.toARGB32(),
    'selectionColor': t.selectionColor.toARGB32(),
    'updateMarkColor': t.updateMarkColor.toARGB32(),
    'isFavorite': t.isFavorite,
  };

  // 'baseTheme'キーは廃止済みだが、旧バージョンで書き出された.niatraファイル
  // に含まれている場合があるため、jにあっても単に無視する（読み込みエラー
  // にしない）。
  static AppThemePreset _deserializeThemePreset(Map<String, dynamic> j) =>
      AppThemePreset(
        id: 'theme_${DateTime.now().microsecondsSinceEpoch}_${j['id']}',
        name: j['name'] as String,
        accentColor: Color(j['accentColor'] as int),
        textColor: Color(j['textColor'] as int),
        panelBgColor: Color(j['panelBgColor'] as int),
        menuBgColor: Color(j['menuBgColor'] as int),
        selectionColor: Color(j['selectionColor'] as int),
        updateMarkColor: Color(j['updateMarkColor'] as int),
        isFavorite: j['isFavorite'] as bool? ?? false,
      );
}

class NiatraData {
  final Map<String, dynamic> raw;
  // Projects/以下に埋め込まれた.niashareエントリを取り出すための元アーカイブ。
  // restoreProjects()専用で、他カテゴリの復元はraw（data.json）のみで完結する。
  final Archive archive;
  const NiatraData(this.raw, this.archive);
}
