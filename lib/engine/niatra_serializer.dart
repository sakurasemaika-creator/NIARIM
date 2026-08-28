import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:archive/archive.dart';
import '../models/app_theme_preset.dart';
import '../models/autofill_preset.dart';
import '../models/brush.dart';
import '../models/pixel_color_mode.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../services/autofill_preset_service.dart';
import '../services/brush_service.dart';
import '../services/settings_service.dart';
import '../services/stamp_service.dart';
import '../services/theme_service.dart';
import '../services/tone_service.dart';

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
      data['autofillPresets'] = autofillPresets.presets.map(_serializeAutofillPreset).toList();
    }

    if (selectedItems['UIテーマ'] ?? false) {
      data['themePresets'] = theme.presets.map(_serializeThemePreset).toList();
      data['currentThemeId'] = theme.current.id;
    }

    final jsonBytes = utf8.encode(jsonEncode(data));
    final archive = Archive()..addFile(ArchiveFile(_dataFile, jsonBytes.length, jsonBytes));
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw const FormatException('ZIP encoding failed');
    return Uint8List.fromList(zipBytes);
  }

  /// バイト列から読み込む（Web版でファイル選択ダイアログがパスではなく
  /// バイト列のみを返す場合もこちらを使う）。
  static NiatraData loadFromBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_dataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final data = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
    return NiatraData(data);
  }

  /// ローカルファイルパスから読み込む（デスクトップ/モバイル用）。
  static Future<NiatraData> load(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
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
  }) {
    final j = data.raw;

    final settingsJson = j['settings'] as Map<String, dynamic>?;
    if (settingsJson != null) {
      settings.setDefaultFps(settingsJson['defaultFps'] as int? ?? settings.defaultFps);
      settings.setUndoLimit(settingsJson['undoLimit'] as int? ?? settings.undoLimit);
      settings.setTrashAutoDelete(
          settingsJson['trashAutoDeleteDays'] as int? ?? settings.trashAutoDeleteDays);
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
        autofillPresets.addPreset(_deserializeAutofillPreset(pj as Map<String, dynamic>));
      }
    }

    final themePresetsJson = j['themePresets'] as List<dynamic>?;
    if (themePresetsJson != null) {
      for (final tpj in themePresetsJson) {
        theme.savePreset(_deserializeThemePreset(tpj as Map<String, dynamic>));
      }
    }
  }

  // ─── Brush ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeBrush(Brush b) => {
        'id': b.id, 'name': b.name, 'size': b.size, 'opacity': b.opacity,
        'spacing': b.spacing, 'blurRadius': b.blurRadius,
        'stabilization': b.stabilization, 'stabilizationStrength': b.stabilizationStrength,
        'pixelMode': b.pixelMode, 'pressureMode': b.pressureMode.name,
        'pressureStrength': b.pressureStrength, 'fadeMode': b.fadeMode.name,
        'strokeDecay': b.strokeDecay, 'mixingMode': b.mixingMode.name,
        'mixingRate': b.mixingRate, 'isFavorite': b.isFavorite,
        'calligraphyAngle': b.calligraphyAngle,
        'pixelColorMode': b.pixelColorMode.name,
        'pixelColorLevels': b.pixelColorLevels,
        'pixelExplicitColors': b.pixelExplicitColors,
      };

  static Brush _deserializeBrush(Map<String, dynamic> j) => Brush(
        id: 'Brush${DateTime.now().microsecondsSinceEpoch}_${j['id']}',
        name: j['name'] as String,
        size: (j['size'] as num).toDouble(),
        opacity: j['opacity'] as int,
        spacing: j['spacing'] as int,
        blurRadius: j['blurRadius'] as int,
        stabilization: j['stabilization'] as bool,
        stabilizationStrength: j['stabilizationStrength'] as int,
        // pixelModeは旧称dotPenModeからの改称。旧バージョンで書き出された
        // .niatraファイルも引き続き読み込めるよう旧キーへフォールバックする。
        pixelMode: (j['pixelMode'] ?? j['dotPenMode']) as bool? ?? false,
        pressureMode: PressureMode.values.firstWhere((e) => e.name == j['pressureMode'],
            orElse: () => PressureMode.off),
        pressureStrength: j['pressureStrength'] as int,
        fadeMode: FadeMode.values
            .firstWhere((e) => e.name == j['fadeMode'], orElse: () => FadeMode.off),
        strokeDecay: j['strokeDecay'] as bool,
        mixingMode: BrushMixingMode.values.firstWhere((e) => e.name == j['mixingMode'],
            orElse: () => BrushMixingMode.off),
        mixingRate: j['mixingRate'] as int,
        isFavorite: j['isFavorite'] as bool? ?? false,
        calligraphyAngle: (j['calligraphyAngle'] as num?)?.toDouble(),
        pixelColorMode: PixelColorMode.values.firstWhere(
            (e) => e.name == j['pixelColorMode'], orElse: () => PixelColorMode.none),
        pixelColorLevels: j['pixelColorLevels'] as int? ?? 8,
        pixelExplicitColors: (j['pixelExplicitColors'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [0xFF000000],
      );

  // ─── Tone / Stamp ─────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeTone(Tone t) =>
      {'id': t.id, 'name': t.name, 'texturePath': t.texturePath, 'isFavorite': t.isFavorite};

  static Tone _deserializeTone(Map<String, dynamic> j) => Tone(
        id: 'Tone${DateTime.now().microsecondsSinceEpoch}_${j['id']}',
        name: j['name'] as String,
        texturePath: j['texturePath'] as String?,
        isFavorite: j['isFavorite'] as bool? ?? false,
      );

  static Map<String, dynamic> _serializeStamp(Stamp s) => {
        'id': s.id, 'name': s.name, 'imagePath': s.imagePath, 'isFavorite': s.isFavorite,
        'rotation': s.rotation, 'density': s.density, 'scatter': s.scatter,
        'pixelMode': s.pixelMode,
      };

  static Stamp _deserializeStamp(Map<String, dynamic> j) => Stamp(
        id: 'Stamp${DateTime.now().microsecondsSinceEpoch}_${j['id']}',
        name: j['name'] as String,
        imagePath: j['imagePath'] as String?,
        isFavorite: j['isFavorite'] as bool? ?? false,
        rotation: j['rotation'] as bool? ?? false,
        density: (j['density'] as num?)?.toDouble() ?? 1.0,
        scatter: (j['scatter'] as num?)?.toDouble() ?? 0.0,
        pixelMode: j['pixelMode'] as bool? ?? false,
      );

  // ─── AutofillPreset ───────────────────────────────────────────────────

  // グラデーション・トーン・線画色・トレス調整など、パーツが持つ設定を
  // 一切欠かさず引き継げるよう、モデル自身のtoJson/fromJsonをそのまま使う。
  static Map<String, dynamic> _serializeAutofillPreset(AutofillPreset p) => p.toJson();

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
        'id': t.id, 'name': t.name,
        'accentColor': t.accentColor.toARGB32(), 'textColor': t.textColor.toARGB32(),
        'panelBgColor': t.panelBgColor.toARGB32(), 'menuBgColor': t.menuBgColor.toARGB32(),
        'selectionColor': t.selectionColor.toARGB32(), 'updateMarkColor': t.updateMarkColor.toARGB32(),
        'isFavorite': t.isFavorite,
      };

  // 'baseTheme'キーは廃止済みだが、旧バージョンで書き出された.niatraファイル
  // に含まれている場合があるため、jにあっても単に無視する（読み込みエラー
  // にしない）。
  static AppThemePreset _deserializeThemePreset(Map<String, dynamic> j) => AppThemePreset(
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
  const NiatraData(this.raw);
}
