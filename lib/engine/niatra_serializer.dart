import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_theme_preset.dart';
import '../models/autofill_preset.dart';
import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../services/autofill_preset_service.dart';
import '../services/brush_service.dart';
import '../services/settings_service.dart';
import '../services/stamp_service.dart';
import '../services/theme_service.dart';
import '../services/tone_service.dart';

/// .niatra（引き継ぎファイル、旧称.stutra）の書き出し・読み込み（仕様書06）。
/// 引き継ぐ項目（設定/素材/ブラシ/プリセット/UIテーマ）をチェックボックスで選択できる。
/// 形式：ZIPアーカイブ内に data.json 一枚のみを持つシンプル構成。
class NiatraSerializer {
  static const _dataFile = 'data.json';

  static Future<File> export({
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

    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/niarim_${DateTime.now().millisecondsSinceEpoch}.niatra';
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(ArchiveFile(_dataFile, 0, utf8.encode(jsonEncode(data))));
    encoder.close();
    return File(filePath);
  }

  static Future<NiatraData> load(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_dataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final data = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
    return NiatraData(data);
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
        'dotPenMode': b.dotPenMode, 'pressureMode': b.pressureMode.name,
        'pressureStrength': b.pressureStrength, 'fadeMode': b.fadeMode.name,
        'strokeDecay': b.strokeDecay, 'mixingMode': b.mixingMode.name,
        'mixingRate': b.mixingRate, 'isFavorite': b.isFavorite,
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
        dotPenMode: j['dotPenMode'] as bool,
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
      };

  static Stamp _deserializeStamp(Map<String, dynamic> j) => Stamp(
        id: 'Stamp${DateTime.now().microsecondsSinceEpoch}_${j['id']}',
        name: j['name'] as String,
        imagePath: j['imagePath'] as String?,
        isFavorite: j['isFavorite'] as bool? ?? false,
        rotation: j['rotation'] as bool? ?? false,
        density: (j['density'] as num?)?.toDouble() ?? 1.0,
        scatter: (j['scatter'] as num?)?.toDouble() ?? 0.0,
      );

  // ─── AutofillPreset ───────────────────────────────────────────────────

  static Map<String, dynamic> _serializeAutofillPreset(AutofillPreset p) => {
        'id': p.id, 'name': p.name, 'thumbnailPath': p.thumbnailPath, 'isFavorite': p.isFavorite,
        'parts': p.parts.map((part) => {'id': part.id, 'name': part.name, 'color': part.color}).toList(),
      };

  static AutofillPreset _deserializeAutofillPreset(Map<String, dynamic> j) => AutofillPreset(
        id: 'p_${DateTime.now().microsecondsSinceEpoch}_${j['id']}',
        name: j['name'] as String,
        thumbnailPath: j['thumbnailPath'] as String?,
        isFavorite: j['isFavorite'] as bool? ?? false,
        parts: (j['parts'] as List<dynamic>)
            .map((pj) => AutofillPart(
                  id: 'part_${DateTime.now().microsecondsSinceEpoch}_${pj['id']}',
                  name: pj['name'] as String,
                  color: pj['color'] as int,
                ))
            .toList(),
      );

  // ─── ThemePreset ──────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeThemePreset(AppThemePreset t) => {
        'id': t.id, 'name': t.name, 'baseTheme': t.baseTheme.name,
        'accentColor': t.accentColor.toARGB32(), 'textColor': t.textColor.toARGB32(),
        'panelBgColor': t.panelBgColor.toARGB32(), 'menuBgColor': t.menuBgColor.toARGB32(),
        'selectionColor': t.selectionColor.toARGB32(), 'updateMarkColor': t.updateMarkColor.toARGB32(),
        'isFavorite': t.isFavorite,
      };

  static AppThemePreset _deserializeThemePreset(Map<String, dynamic> j) => AppThemePreset(
        id: 'theme_${DateTime.now().microsecondsSinceEpoch}_${j['id']}',
        name: j['name'] as String,
        baseTheme: BaseTheme.values
            .firstWhere((e) => e.name == j['baseTheme'], orElse: () => BaseTheme.dark),
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
