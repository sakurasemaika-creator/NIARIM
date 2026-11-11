import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/app_theme_preset.dart';
import '../models/autofill_preset.dart';
import '../models/brush.dart';
import '../models/color_palette.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../services/autofill_preset_service.dart';
import '../services/brush_service.dart';
import '../services/custom_automation_service.dart';
import '../services/filter_service.dart';
import '../services/first_use_tooltip_service.dart';
import '../services/palette_service.dart';
import '../services/pixel_art_palette_service.dart';
import '../services/project_service.dart';
import '../services/quick_tool_service.dart';
import '../services/settings_service.dart';
import '../services/shortcut_service.dart';
import '../services/stamp_service.dart';
import '../services/theme_service.dart';
import '../services/tone_service.dart';
import '../services/watermark_service.dart';
import '../services/workspace_preset_service.dart';
import '../utils/app_error_reporter.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';
import 'archive_security.dart';
import 'niapro_serializer.dart' show NiaproData, NiaproSerializer;

/// .niatra（引き継ぎファイル、旧称.stutra）の書き出し・読み込み。
/// 引き継ぐ項目（設定/素材/ブラシ/プリセット/UIテーマ）をチェックボックスで選択できる。
/// 形式：ZIPアーカイブ内に data.json 一枚のみを持つシンプル構成。
class NiatraSerializer {
  static const _dataFile = 'data.json';
  static const _brushFoldersKey = 'brushFolders';
  static const _brushRememberedKey = 'brushRememberedBuiltInValues';
  static const _toneFoldersKey = 'toneFolders';
  static const _stampFoldersKey = 'stampFolders';
  static const _recentColorsKey = 'recentColors';
  static const _brushCurrentKey = 'brushCurrentId';
  static const _paletteActiveKey = 'paletteActiveId';
  static const _projectFoldersKey = 'projectFolders';

  // Never migrate access credentials or device-installation identifiers.
  static bool _portablePreference(String key) {
    final lower = key.toLowerCase();
    const sensitive = [
      'token',
      'oauth',
      'secret',
      'password',
      'credential',
      'session',
      'cookie',
      'api_key',
      'private_key',
      'google',
      'login',
      'device_id',
      'installation_id',
      'refresh',
      'authorization',
    ];
    return !sensitive.any(lower.contains);
  }

  /// 各項目（ブラシ・素材・自動塗り設定・テーマ・パレット）が一覧と突き
  /// 合わせて取り込む保存。「端末保存データ」では書き出さず、古いファイルに
  /// 入っていても書かない。動いているサービスは一覧を覚えているので、保存を
  /// 直接書き換えると次の保存で読み込んだ内容が戻り、起動し直すとこの端末に
  /// しか無い項目が消える。
  static final Set<String> _keysOwnedByItems = {
    ...BrushService.savedPreferenceKeys,
    ...ToneService.savedPreferenceKeys,
    ...StampService.savedPreferenceKeys,
    ...AutofillPresetService.savedPreferenceKeys,
    ...ThemeService.savedPreferenceKeys,
    ...PaletteService.savedPreferenceKeys,
    ...PixelArtPaletteService.savedPreferenceKeys,
  };

  /// この端末の作品・ゴミ箱・フォルダ・書き出した作品・フォント・
  /// ホーム画面のウィジェット・購入・アカウント・自動保存・端末の性能の
  /// 判定・初回の使い方の記録。記録が指す作品・ファイル・購入は端末保存
  /// データでは移らない（作品はプロジェクトの項目で移す）ので、記録も
  /// 書き出さず、古いファイルに入っていても書かない（書くと、この端末の
  /// 作品のフォルダ分けやゴミ箱の中身・購入日・性能の判定が、もう1台の記録で
  /// 置き換わる）。書き出した共有ファイルのお気に入りと、書き出した作品の
  /// サムネイルの選び方は、この端末のファイルの場所で覚えている。
  static const Set<String> deviceRecordKeys = {
    'project_folders',
    'trashed_projects',
    'trashed_project_folders',
    'shared_folders',
    'work_folders',
    'work_file_folder_map',
    'work_file_thumbnail_covers',
    'exported_work_thumbnail_overrides_v1',
    'niarim_outgoing_share_favorites',
    'user_fonts',
    'home_widget_config_v1',
    'custom_automation_offered_builtins_v1',
    'is_premium',
    'premium_purchase_product_id',
    'premium_purchase_date',
    'default_preset',
    'first_launch',
  };

  /// [deviceRecordKeys]と同じ記録で、キーの頭が決まっているもの（自動保存・
  /// 投稿の途中・アカウントごとの記録。作品広場の節目の知らせ・制作時間の
  /// 未確認分もアカウントごとにこの端末で数えている。引き継ぎでこの端末に
  /// 足した複製の記録〔[TransferCopyRecord]〕は、この端末の一覧のIDを指す）。
  static const List<String> deviceRecordPrefixes = [
    TransferCopyRecord.keyPrefix,
    'autosave_',
    'community.pendingUpload.',
    'community.ownerByAccount.',
    'community.savedSearches.v1',
    'community.searchHistory.v1',
    'community.milestone.v1.',
    'creator_edit_pending_v1_',
    'creator_edit_unverified_seconds_v1_',
    'pending_coin_redemption_',
  ];

  /// 利用者が作った物の一覧（動いているサービスが覚えている）。端末保存
  /// データでは生のまま書かず、[TransferredSavedLists]のサービスがこの端末の
  /// 一覧へ足す（項目と同じ決まりで、この端末の物は書き換えない）。透かしの
  /// 画像は`NiatraAssetBundle.enrichExport`がファイルへ入れる
  /// （[watermarkImagesKey]）。
  static const Set<String> mergedListKeys = {
    'workspace_presets',
    'custom_automations_v1',
    'custom_automation_favorites_v1',
    'quick_tool_entries',
    'shortcut_bindings',
    'custom_size_presets',
    'draw_filters',
    'first_use_tooltips_seen',
    'watermark_assets',
  };

  /// 透かしの画像（透かしのID → ファイルの中の画像の場所）。
  static const watermarkImagesKey = 'watermarkImages';

  /// 1件ずつの文字列の一覧（作品広場のミュート）。この端末に無いものだけを
  /// 足す（呼び出し側が読み直させる）。作品のミュートと「いつも表示」は、
  /// この端末でどちらかに入れた作品をもう片方へ足さない（この端末で決めた
  /// 方を使う）。
  static const Set<String> unionListKeys = {
    'community.mutedWords',
    'community.mutedTags',
    'community.mutedAuthors',
    'community.mutedWorks.v1',
    'community.alwaysVisibleWorks.v1',
  };

  /// 1つの設定の値として、ほかの設定と同じくそのまま移す一覧（並び順・
  /// 表示する部品など）。ここにも上の一覧にも無い一覧は書かない（この端末の
  /// 一覧のまま。新しい一覧を足したら、どれかに入れること）。
  static const Set<String> settingListKeys = {
    'toolbar_order',
    'toolbar_hidden',
    'tool_option_dock_order',
    'right_dock_order',
    'default_docked_panels',
    'desktop_collapsed_docks',
    'pen_pressure_custom_points',
  };

  /// 1つの値の設定として、そのまま移す保存。ここに無い1つの値（この端末の
  /// 記録・新しく足した保存）は書き出さず、読み込んでも書かない（新しい保存を
  /// 足したら、どれかの一覧へ入れること。`niatra_transfer_saved_keys_test`が
  /// 見張る）。
  static const Set<String> settingKeys = {
    'language',
    'default_fps',
    'undo_limit',
    'trash_auto_delete',
    'is_left_handed',
    'force_pc_mode',
    'toolbar_size_level',
    'timeline_track_height_level',
    'timeline_preview_height_fraction',
    'desktop_panel_width',
    'desktop_tool_panel_width',
    'desktop_dock_heights',
    'desktop_dock_auto_collapse_enabled',
    'desktop_dock_layout_customized',
    'default_drawing_area_enabled',
    'default_drawing_area_scale',
    'endcard_default_hidden_for_premium',
    'gesture_two_finger_tap',
    'gesture_three_finger_tap',
    'gesture_four_or_more_finger_tap',
    'gesture_two_finger_swipe',
    'gesture_long_press',
    'pen_button_1',
    'pen_button_2',
    'pen_pressure_enabled',
    'pen_pressure_curve',
    'pen_pressure_custom_exponent',
    'palm_rejection_enabled',
    'hold_eyedropper_enabled',
    'hold_eyedropper_seconds',
    'bucket_tolerance',
    'bucket_expand_px',
    'bucket_fill_under_line',
    'lasso_snap_to_lines',
    'lasso_gap_tolerance_px',
    'selection_reference_all_visible',
    'quality_level',
    'custom_saved',
    'custom_tilt',
    'custom_show_prev',
    'custom_show_next',
    'custom_onion_prev',
    'custom_onion_next',
    'custom_save_mode',
    'custom_slot_count',
    'home.projectViewMode.v1',
    'community.hideGenerativeAiImageVideo',
    'community.rankingLayout.v1',
    'community.tileMinWidth.v1',
    'community_vertical_video_end_behavior',
  };

  /// 動いているサービスが一覧と一緒に持つ設定で、この端末のまま残すもの
  /// （描画フィルターのカラーノイズの設定。描画フィルターの取り込みは、
  /// ノイズの種類ごとの設定〔フィルムグレイン・VHSの隠れたフィルター〕を
  /// この端末のままにするので、同じく移さない。生のまま書くと、フィルターを
  /// 変えたかどうかで次の保存に上書きされたりされなかったりする）。書き出さず、
  /// 読み込んでも書かない。
  static const Set<String> keptSettingKeys = {
    'draw_filter_noise_color_profile',
  };

  static bool _isDeviceRecord(String key) =>
      deviceRecordKeys.contains(key) ||
      deviceRecordPrefixes.any(key.startsWith);

  static bool _transfersAsLocalPreference(String key) =>
      _portablePreference(key) &&
      !_keysOwnedByItems.contains(key) &&
      !_isDeviceRecord(key) &&
      (settingKeys.contains(key) ||
          settingListKeys.contains(key) ||
          mergedListKeys.contains(key) ||
          unionListKeys.contains(key));

  /// どちらか一方にだけ入る一覧の組（作品のミュートと「いつも表示」。アプリの
  /// 操作は片方へ入れるともう片方から外す）。
  static const Map<String, String> _exclusiveListKeys = {
    'community.mutedWorks.v1': 'community.alwaysVisibleWorks.v1',
    'community.alwaysVisibleWorks.v1': 'community.mutedWorks.v1',
  };

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

    if (selectedItems['端末保存データ'] ?? false) {
      final prefs = await SharedPreferences.getInstance();
      final local = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (!_transfersAsLocalPreference(key)) continue;
        final value = prefs.get(key);
        if (value is String ||
            value is bool ||
            value is int ||
            value is double ||
            value is List<String>) {
          local[key] = value;
        }
      }
      data['localPreferences'] = local;
    }

    if (selectedItems['ブラシ'] ?? false) {
      data['brushes'] = brush.brushes.map(_serializeBrush).toList();
      data[_brushFoldersKey] = brush.folders.map((f) => f.toJson()).toList();
      data[_brushRememberedKey] = brush.rememberedBuiltInValuesForTransfer();
      data[_brushCurrentKey] = brush.currentBrush?.id;
    }

    if (selectedItems['素材'] ?? false) {
      data['tones'] = tone.tones.map(_serializeTone).toList();
      data[_toneFoldersKey] = tone.folders.map((f) => f.toJson()).toList();
      data['stamps'] = stamp.stamps.map(_serializeStamp).toList();
      data[_stampFoldersKey] = stamp.folders.map((f) => f.toJson()).toList();
    }

    if (selectedItems['プリセット'] ?? false) {
      data['autofillPresets'] = autofillPresets.presets
          .map(_serializeAutofillPreset)
          .toList();
    }

    if (selectedItems['UIテーマ'] ?? false) {
      data['themePresets'] = theme.presets.map(_serializeThemePreset).toList();
      data['currentThemeId'] = theme.current.id;
      // 現在の色は一覧のどれかとは限らない（テーマ一覧から配色だけ取り込んで
      // 手直しした状態）ので、IDではなく配色そのものも持たせる。
      data['currentTheme'] = _serializeThemePreset(theme.current);
    }

    if (selectedItems['パレット'] ?? false) {
      data['palettes'] = palette.palettes.map((p) => p.toJson()).toList();
      data['pixelArtPalettes'] = pixelArtPalette.palettes
          .map((p) => p.toJson())
          .toList();
      data[_recentColorsKey] = palette.recentColors;
      data[_paletteActiveKey] = palette.activePaletteId;
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
      // 作品が入っているフォルダ（この端末のフォルダの一覧。読み込み側は
      // 移した作品が入っているフォルダと、その上のフォルダだけを足す）。
      // フォルダの一覧そのものは端末の記録なので端末保存データでは移さない。
      data[_projectFoldersKey] = await _savedProjectFolders();
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
  ///
  /// 一覧の項目はIDで突き合わせ、この端末の内容を黙って失わない（同じIDで
  /// 中身が違えば、この端末の項目を残して受け取った項目を「名前 (コピー)」と
  /// して足す。組み込みは足さず整理だけ。同じファイルを何度読んでも増えない。
  /// 詳しくは`mergeTransferredItems`と各サービスの`mergeTransferred`）。
  /// 複製の名前は[l10n]の言語で付ける。新しいキーの無い古いファイルは、
  /// 端末保存データ（`localPreferences`）の中の同じ内容の保存から読む。
  /// どのサービスの一覧もこの中で変わり終え、保存し終えたら返る。
  static Future<void> applyTo(
    NiatraData data, {
    required SettingsService settings,
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
    required AutofillPresetService autofillPresets,
    required ThemeService theme,
    required PaletteService palette,
    required PixelArtPaletteService pixelArtPalette,
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) async {
    final j = data.raw;
    final copyNames = _copyNames(l10n, report);
    final pending = <Future<void>>[];

    final settingsJson = j['settings'] as Map<String, dynamic>?;
    if (settingsJson != null) {
      pending.add(
        settings.setDefaultFps(
          settingsJson['defaultFps'] as int? ?? settings.defaultFps,
        ),
      );
      pending.add(
        settings.setUndoLimit(
          settingsJson['undoLimit'] as int? ?? settings.undoLimit,
        ),
      );
      pending.add(
        settings.setTrashAutoDelete(
          settingsJson['trashAutoDeleteDays'] as int? ??
              settings.trashAutoDeleteDays,
        ),
      );
    }

    final brushesJson = _items(data, 'brushes', 'brushes');
    if (brushesJson != null ||
        _legacy(data, 'brush_folders') != null ||
        _legacy(data, 'brushes_current_id') != null) {
      pending.add(
        mergeBrushes(
          data,
          brush,
          [
            for (var i = 0; i < (brushesJson?.length ?? 0); i++)
              _deserializeBrush(brushesJson![i], i),
          ],
          l10n: l10n,
          report: report,
        ),
      );
    }

    final tonesJson = _items(data, 'tones', 'tones');
    // 自動塗りのパーツが使うトーンは、トーンを合わせ終えてから合わせる。
    var tonesMerged = Future<void>.value();
    if (tonesJson != null || _legacy(data, 'tone_folders') != null) {
      tonesMerged = mergeTones(
        data,
        tone,
        [
          for (var i = 0; i < (tonesJson?.length ?? 0); i++)
            _deserializeTone(tonesJson![i], i),
        ],
        l10n: l10n,
        report: report,
      );
      pending.add(tonesMerged);
    }

    final stampsJson = _items(data, 'stamps', 'stamps');
    if (stampsJson != null || _legacy(data, 'stamp_folders') != null) {
      pending.add(
        mergeStamps(
          data,
          stamp,
          [
            for (var i = 0; i < (stampsJson?.length ?? 0); i++)
              _deserializeStamp(stampsJson![i], i),
          ],
          l10n: l10n,
          report: report,
        ),
      );
    }

    final presetsJson = _items(data, 'autofillPresets', 'autofill_presets');
    if (presetsJson != null) {
      final presets = [
        for (final pj in presetsJson) AutofillPreset.fromJson(pj),
      ];
      pending.add(
        tonesMerged.then(
          (_) => mergeAutofillPresets(
            data,
            autofillPresets,
            presets,
            l10n: l10n,
            report: report,
          ),
        ),
      );
    }

    final themePresetsJson = _items(data, 'themePresets', 'theme_presets');
    // 現在の色は一覧へ足さずに差し替える（一覧に無い配色のこともあるため）。
    final currentThemeJson =
        j['currentTheme'] as Map<String, dynamic>? ??
        _legacyJson(_legacy(data, 'theme_current_json'));
    if (themePresetsJson != null || currentThemeJson != null) {
      pending.add(
        theme.mergeTransferred(
          [
            for (final tpj in themePresetsJson ?? const [])
              _deserializeThemePreset(tpj),
          ],
          copyNames: copyNames,
          current: currentThemeJson == null
              ? null
              : _deserializeThemePreset(currentThemeJson),
        ),
      );
    }

    // パレット・ドット絵専用パレットは自分の別の端末の内容なので、IDは
    // そのまま（他の人から受け取るときのimportPalette()と違う）。
    final palettesJson = _items(data, 'palettes', 'color_palettes');
    final recent =
        (j[_recentColorsKey] as List<dynamic>?) ??
        (_legacy(data, 'palette_recent_colors') as List<dynamic>?);
    final activePaletteId =
        j[_paletteActiveKey] ?? _legacy(data, 'color_palette_active_id');
    if (palettesJson != null || recent != null || activePaletteId != null) {
      pending.add(
        palette.mergeTransferred(
          [
            for (final pj in palettesJson ?? const [])
              ColorPalette.fromJson(pj),
          ],
          copyNames: copyNames,
          recentColors: [
            for (final c in recent ?? const [])
              if (c is int)
                c
              else if (c is String && int.tryParse(c) != null)
                int.parse(c),
          ],
          activePaletteId: activePaletteId is String ? activePaletteId : null,
        ),
      );
    }

    final pixelArtPalettesJson = _items(
      data,
      'pixelArtPalettes',
      'pixel_art_palettes',
    );
    if (pixelArtPalettesJson != null) {
      pending.add(
        pixelArtPalette.mergeTransferred([
          for (final pj in pixelArtPalettesJson) ColorPalette.fromJson(pj),
        ], copyNames: copyNames),
      );
    }

    await Future.wait(pending);
  }

  static TransferCopyNames _copyNames(
    AppLocalizations? l10n, [
    TransferImportReport? report,
  ]) => TransferCopyNames(
    l10n ?? lookupAppLocalizations(const Locale('ja')),
    report: report,
  );

  /// 古いファイルの端末保存データ（`localPreferences`）の中の[key]。
  static Object? _legacy(NiatraData data, String key) {
    final local = data.raw['localPreferences'];
    return local is Map ? local[key] : null;
  }

  /// 項目を合わせ終えたら、古いファイルの端末保存データにある同じ内容を
  /// 除く（画像を展開した後の[applyTo]が、古い形でもう一度合わせない）。
  static void _dropLegacy(NiatraData data, List<String> keys) {
    final local = data.raw['localPreferences'];
    if (local is Map) keys.forEach(local.remove);
  }

  /// 保存と同じ形（JSONの文字列）を読む。読めなければnull。
  static Map<String, dynamic>? _legacyJson(Object? value) {
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// [key]の一覧。無い古いファイルは、端末保存データの[legacyKey]（保存と
  /// 同じ、1件ずつのJSONの文字列）から読む。読めない1件は飛ばす。
  static List<Map<String, dynamic>>? _items(
    NiatraData data,
    String key,
    String legacyKey,
  ) {
    final value = data.raw[key];
    if (value is List) {
      return [for (final item in value) item as Map<String, dynamic>];
    }
    final legacy = _legacy(data, legacyKey);
    if (legacy is! List) return null;
    return [for (final entry in legacy) ?_legacyJson(entry)];
  }

  /// ブラシの項目をこの端末の一覧へ合わせる（`NiatraAssetBundle`が画像を
  /// 展開した新しい形式と、画像を持たない古い形式の両方から呼ぶ）。合わせた
  /// 項目（ブラシ・フォルダ・覚えた太さ・使っていたブラシ）は[data]から除き、
  /// 受け取ったブラシの行き先を[NiatraData.placedBrushIds]へ書く。
  static Future<void> mergeBrushes(
    NiatraData data,
    BrushService brush,
    List<Brush> brushes, {
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) {
    final folders = _folderJson(data, _brushFoldersKey, 'brush_folders');
    data.raw.remove('brushes');
    final remembered =
        data.raw.remove(_brushRememberedKey) ??
        _legacyJson(_legacy(data, 'brush_builtin_working_values'));
    final current =
        data.raw.remove(_brushCurrentKey) ??
        _legacy(data, 'brushes_current_id');
    _dropLegacy(data, const [
      'brushes',
      'brush_folders',
      'brush_builtin_working_values',
      'brushes_current_id',
    ]);
    return brush.mergeTransferred(
      brushes,
      copyNames: _copyNames(l10n, report),
      folders: [for (final f in folders) BrushFolder.fromJson(f)],
      rememberedBuiltInValues: remembered,
      currentBrushId: current is String ? current : null,
      placed: data.placedBrushIds,
    );
  }

  /// トーンの項目をこの端末の一覧へ合わせる（[mergeBrushes]と同じ）。
  static Future<void> mergeTones(
    NiatraData data,
    ToneService tone,
    List<Tone> tones, {
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) {
    final folders = _folderJson(data, _toneFoldersKey, 'tone_folders');
    data.raw.remove('tones');
    _dropLegacy(data, const ['tones', 'tone_folders']);
    return tone.mergeTransferred(
      tones,
      copyNames: _copyNames(l10n, report),
      folders: [for (final f in folders) ToneFolder.fromJson(f)],
      placed: data.placedToneIds,
    );
  }

  /// 自動塗りのプリセットをこの端末の一覧へ合わせる（`NiatraAssetBundle`が
  /// サムネイルの画像を展開した新しい形式と、画像を持たない古い形式の両方
  /// から呼ぶ。トーンを合わせ終えてから呼ぶ）。合わせたプリセットは[data]から
  /// 除き、受け取ったプリセットとパーツの行き先を
  /// [NiatraData.placedAutofillPresetIds]・[NiatraData.placedAutofillPartIds]へ
  /// 書く。パーツが使うトーンは[NiatraData.placedToneIds]で合わせる。
  static Future<void> mergeAutofillPresets(
    NiatraData data,
    AutofillPresetService autofillPresets,
    List<AutofillPreset> presets, {
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) {
    data.raw.remove('autofillPresets');
    _dropLegacy(data, const ['autofill_presets']);
    return autofillPresets.mergeTransferred(
      presets,
      copyNames: _copyNames(l10n, report),
      toneIds: data.placedToneIds,
      placed: data.placedAutofillPresetIds,
      placedParts: data.placedAutofillPartIds,
    );
  }

  /// スタンプの項目をこの端末の一覧へ合わせる（[mergeBrushes]と同じ）。
  static Future<void> mergeStamps(
    NiatraData data,
    StampService stamp,
    List<Stamp> stamps, {
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) {
    final folders = _folderJson(data, _stampFoldersKey, 'stamp_folders');
    data.raw.remove('stamps');
    _dropLegacy(data, const ['stamps', 'stamp_folders']);
    return stamp.mergeTransferred(
      stamps,
      copyNames: _copyNames(l10n, report),
      folders: [for (final f in folders) StampFolder.fromJson(f)],
    );
  }

  /// フォルダの一覧。新しいキーが無い古いファイルは端末保存データの
  /// [legacyKey]から読む。読めない1件は飛ばす。
  static List<Map<String, dynamic>> _folderJson(
    NiatraData data,
    String key,
    String legacyKey,
  ) {
    final value = data.raw.remove(key);
    final items = value is List
        ? value
        : [
            for (final entry in _legacy(data, legacyKey) as List? ?? const [])
              ?_legacyJson(entry),
          ];
    return [
      for (final item in items)
        if (item is Map<String, dynamic> &&
            item['id'] is String &&
            item['name'] is String)
          item,
    ];
  }

  /// 受け取った項目のID。自分の別の端末の内容なのでそのまま使う（同じ
  /// ファイルを読み直しても増えないように）。IDの無い壊れた項目だけ新しく
  /// 付ける。
  static String transferredId(Object? id, String prefix, int index) =>
      id is String && id.isNotEmpty
      ? id
      : '$prefix${DateTime.now().microsecondsSinceEpoch}_$index';

  /// 端末保存データを戻す。ログインの情報・各項目が一覧と突き合わせて
  /// 取り込む保存・この端末の記録（[deviceRecordKeys]）は書かない。
  ///
  /// 設定（[settingKeys]の1つの値と[settingListKeys]の一覧）はもう1台の値に
  /// する（[keptSettingKeys]はこの端末のまま）。利用者が
  /// 作った物の一覧（[mergedListKeys]）は、[lists]の動いているサービスが
  /// この端末の一覧へ足し（渡されなかった一覧は書かない）、[unionListKeys]は
  /// この端末に無いものだけを足す。どれにも当たらない一覧は書かない
  /// （生のまま書くと、動いている一覧の次の保存で戻り、起動し直すと
  /// この端末にしか無い物が消える）。複製の名前は[l10n]の言語で付け、
  /// [report]へ書き留める。
  static Future<void> restoreLocalPreferences(
    NiatraData data, {
    TransferredSavedLists lists = const TransferredSavedLists(),
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) async {
    final values = data.raw['localPreferences'];
    if (values is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    List<String>? strings(Object? value) =>
        value is List && value.every((item) => item is String)
        ? List<String>.from(value)
        : null;
    // どちらか一方にだけ入る一覧で、どちらかに入っている作品（この端末の分を
    // 書き換える前に、この端末と受け取った両方から集める）。
    final decided = {
      for (final key in _exclusiveListKeys.keys)
        key: {...?prefs.readStringList(key), ...?strings(values[key])},
    };
    final merged = <String, List<String>>{};
    for (final entry in values.entries) {
      final key = entry.key;
      if (key is! String || !_transfersAsLocalPreference(key)) continue;
      final value = entry.value;
      if (value is List) {
        final list = strings(value);
        if (list == null) continue;
        if (mergedListKeys.contains(key)) {
          merged[key] = list;
        } else if (unionListKeys.contains(key)) {
          await _addMissing(
            prefs,
            key,
            list,
            exclude: decided[_exclusiveListKeys[key]] ?? const {},
          );
        } else if (settingListKeys.contains(key)) {
          await prefs.setStringList(key, list);
        }
      } else if (!settingKeys.contains(key)) {
        continue;
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    }
    if (merged.isNotEmpty) {
      await lists._merge(
        merged,
        _copyNames(l10n, report),
        brushIds: data.placedBrushIds,
        watermarkImages: _watermarkImages(data),
        placedWatermarks: data.placedWatermarkIds,
      );
    }
  }

  /// ファイルに入っている透かしの画像（透かしのID → 画像のバイト列）。
  /// 見つからない画像は飛ばす。
  static Map<String, List<int>> _watermarkImages(NiatraData data) {
    final places = data.raw[watermarkImagesKey];
    if (places is! Map) return const {};
    return {
      for (final entry in places.entries)
        if (entry.key is String && entry.value is String)
          if (data.archive.findFile(entry.value as String) case final file?)
            entry.key as String: file.content as List<int>,
    };
  }

  /// 文字列の一覧[key]へ、[incoming]のうちこの端末に無いものを足す
  /// （[exclude]は足さない）。読めない値（型の違う値）が入っているときは
  /// 書かない。
  static Future<void> _addMissing(
    SharedPreferences prefs,
    String key,
    List<String> incoming, {
    Set<String> exclude = const {},
  }) async {
    if (prefs.holdsUnreadableStringList(key)) return;
    final local = prefs.readStringList(key);
    final next = [...?local];
    for (final item in incoming) {
      if (!next.contains(item) && !exclude.contains(item)) next.add(item);
    }
    if (local != null && next.length == local.length) return;
    await prefs.setStringList(key, next);
  }

  /// 埋め込まれた制作中プロジェクト（Projects/以下の.niashareエントリ）を
  /// 新規プロジェクトとして復元する。他カテゴリのapplyTo()と異なり
  /// プロジェクト取り込みはファイルI/O・タイル展開を伴う非同期処理
  /// （ProjectService.importSharedProject）のため、同期メソッドのapplyTo()
  /// とは別の非同期メソッドとして分離している。呼び出し側はawaitすること。
  ///
  /// 一覧の項目と同じく、この端末の作品を黙って失わず、同じファイルを何度
  /// 読んでも増えない：同じ中身（作品の設定・シーン・絵）で、名前が同じか
  /// 複製どうしの作品が読み込む前からこの端末の作品の一覧にあれば足さない
  /// （同じファイルの読み直し・もう1台を行き来して戻ってきた作品）。同じ
  /// ファイルの別の作品（もう1台で複製した作品）と、「共有」のタブの作品
  /// （.niashareで取り込んだ物）とは比べない。足さなかった作品には、
  /// もう1台での整理を合わせる（お気に入りはどちらかで付けていれば付け、
  /// タグは大文字・小文字を区別せず両方、フォルダはこの端末で入れていれば
  /// そのまま・無ければもう1台のフォルダ。変わるときだけ保存する）。
  ///
  /// 同じ中身の作品が何組もあるとき（アプリで複製して別のフォルダへ入れた
  /// 作品など）は、ファイルの作品1つにこの端末の作品を1つだけ、取り違えない
  /// ように決める（[_matchProjects]：名前が同じ作品、次にフォルダと
  /// お気に入りも同じ作品を先に。決められなければ整理を合わせない）。足すかは
  /// 数で決め、この端末の同じ作品がファイルの同じ作品より少ない分だけ足す
  /// （この端末で消した作品。この端末で同じ名前の作品を同じフォルダへ
  /// まとめても、読み直しで足さない）。
  ///
  /// 読み込む前からこの端末にあった別の中身の作品と名前が同じなら、この
  /// 端末の作品を残して「名前 (コピー)」として足し、[report]へ書き留める
  /// （複製の名前は[l10n]の言語）。同じファイルの作品どうしの名前が同じ
  /// だけなら、もう1台と同じ名前のまま足す。
  ///
  /// 足す作品が使う自動塗りのプリセット・線画のパーツ・透かしは、合わせた
  /// 後でもう1台の中身を持つこの端末の項目にする（この端末の版を残して
  /// 足した複製なら複製、同じ中身の項目が別のIDで既にあればその項目。
  /// [applyTo]・[restoreLocalPreferences]の後で呼ぶ）。この端末の作品と
  /// 比べるときは、合わせたIDでも、ファイルのままのIDでも比べ（この端末の
  /// 古いバックアップを読み直したときも、作品を二重にしない）、もう1台の
  /// 項目と、引き継ぎでその版を足したこの端末の複製を同じ項目とみなす
  /// （[TransferCopyRecord.origin]。足した複製の名前を変えた・消した、
  /// もう1台が項目をこの端末と同じ版にした後でも、同じ作品を足さない）。
  ///
  /// 作品はもう1台と同じフォルダに入れる。そのフォルダ（と上のフォルダ）が
  /// この端末に無ければ、ファイルにあるフォルダを同じIDで足す（同じ階層に
  /// 同じ名前のフォルダがあれば番号を付ける。この端末のフォルダの名前・場所は
  /// 変えない）。この端末でゴミ箱へ移したフォルダは戻さず、足せなかった
  /// フォルダの作品は一番上に置く。
  ///
  /// 一時ファイルの書き出しにpath_providerを使うため、Web版では動作しない
  /// （プロジェクトデータ自体が既にdart:io/path_provider前提の.niapro形式で
  /// あり、この制約はniatra以前から存在する既存の制約に合わせたもの）。
  static Future<void> restoreProjects(
    NiatraData data,
    ProjectService projectService, {
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) async {
    final fileNames = (data.raw['projectFiles'] as List<dynamic>?)
        ?.cast<String>();
    if (fileNames == null || fileNames.isEmpty) return;
    final copyNames = _copyNames(l10n, report);
    // ファイルにある作品のフォルダ（読めない1件は飛ばす）。
    final folders = <String, ProjectFolder>{};
    final records = data.raw[_projectFoldersKey];
    for (final json in records is List ? records : const []) {
      final folder = json is Map<String, dynamic> ? _projectFolder(json) : null;
      if (folder != null) folders[folder.id] = folder;
    }
    // 読み込む前からこの端末の作品の一覧にあった作品。
    final mine = [
      for (final p in projectService.projects)
        if (!p.isSharedImport) p,
    ];
    // もう1台の項目と、引き継ぎでその版を足したこの端末の複製を同じ項目と
    // みなして比べる。
    final presets = await TransferCopyRecord.read(
      TransferCopyRecord.autofillPresets,
    );
    final parts = await TransferCopyRecord.read(
      TransferCopyRecord.autofillParts,
    );
    final marks = await TransferCopyRecord.read(TransferCopyRecord.watermarks);
    NiaproData origins(NiaproData d) => _withReferences(
      d,
      preset: presets.origin,
      part: parts.origin,
      mark: marks.origin,
    );
    final tempDir = await getTemporaryDirectory();

    /// [same]は、この端末の同じ中身の作品（名前が同じでも複製の名前に
    /// しない。この端末で消した作品が戻る）。
    Future<void> add(
      NiaproData niaproData, {
      List<Project> same = const [],
    }) async {
      final incoming = niaproData.project;
      final clashes = mine.any(
        (p) => p.name == incoming.name && !same.any((s) => s.id == p.id),
      );
      final taken = {
        for (final p in projectService.projects)
          if (!p.isSharedImport) p.name,
      };
      final folderId = await _transferredFolder(
        projectService,
        incoming.folderId,
        folders,
      );
      // niatra経由の取り込みは自分自身の別端末データを戻しているだけであり、
      // 他人から共有された作品ではないため、ホーム画面の「共有」タブへは
      // 振り分けずisSharedImport: falseで通常プロジェクトとして追加する。
      await projectService.importSharedProject(
        NiaproData(
          project: incoming.copyWith(
            name: clashes
                ? copyNames.next(incoming.name, taken)
                : incoming.name,
            folderId: folderId,
          ),
          scenes: niaproData.scenes,
          tileData: niaproData.tileData,
          materialFiles: niaproData.materialFiles,
          materialsManifest: niaproData.materialsManifest,
          fontFiles: niaproData.fontFiles,
          fontsManifest: niaproData.fontsManifest,
        ),
        isSharedImport: false,
      );
    }

    // この端末に同じ作品があるかもしれない、ファイルの作品（足すかどうかは
    // すべての作品を見てから決める）。
    final pendingNames = <String>[];
    final pending = <Project>[];
    final candidates = <List<Project>>[];
    for (final name in fileNames) {
      final entry = data.archive.findFile('Projects/$name');
      if (entry == null) continue;
      final asSaved = await _loadProject(tempDir, name, entry);
      // 作品が使う自動塗りのプリセット・パーツと透かしを、合わせた後で
      // もう1台の中身を持つこの端末の項目にする。
      final niaproData = _withTransferredReferences(asSaved, data);
      final incoming = niaproData.project;
      final related = [
        for (final p in mine)
          if (TransferCopyNames.related(p.name, incoming.name)) p,
      ];
      final same = <Project>[];
      if (related.isNotEmpty) {
        // この端末の同じ作品（ファイルのままのIDで同じ＝この端末のバック
        // アップの読み直し、合わせたIDで同じ＝読み直し・持ち帰り）。
        final placedHere = origins(niaproData);
        final savedHere = identical(niaproData, asSaved)
            ? null
            : origins(asSaved);
        for (final p in related) {
          final local = origins(
            NiaproData(
              project: p,
              scenes: projectService.scenesOf(p.id),
              tileData: projectService.tileManagerOf(p.id).exportAll(),
            ),
          );
          if (NiaproSerializer.sameContent(local, placedHere) ||
              (savedHere != null &&
                  NiaproSerializer.sameContent(local, savedHere))) {
            same.add(p);
          }
        }
      }
      if (same.isEmpty) {
        await add(niaproData);
        continue;
      }
      pendingNames.add(name);
      pending.add(incoming);
      candidates.add(same);
    }

    final matched = _matchProjects(pending, candidates);
    for (var i = 0; i < pending.length; i++) {
      final id = matched.organize[i];
      // 決められなかった作品は、整理を合わせない（取り違えて別の作品の整理を
      // 変えない）。
      if (id != null) {
        await _adoptProjectOrganization(
          projectService,
          id,
          pending[i],
          folders,
        );
      }
      if (!matched.add.contains(i)) continue;
      // この端末の同じ作品が、ファイルの同じ作品より少ない（この端末で
      // 消したもう1つの作品）。
      final name = pendingNames[i];
      final entry = data.archive.findFile('Projects/$name');
      if (entry == null) continue;
      await add(
        _withTransferredReferences(
          await _loadProject(tempDir, name, entry),
          data,
        ),
        same: candidates[i],
      );
    }
  }

  /// ファイルの作品[entry]を読む（一時ファイルを経て読む）。
  static Future<NiaproData> _loadProject(
    Directory tempDir,
    String name,
    ArchiveFile entry,
  ) async {
    final tempFile = File(
      '${tempDir.path}/niatra_import_${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    await tempFile.writeAsBytes(entry.content as List<int>);
    try {
      return await NiaproSerializer.loadShare(tempFile.path);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  /// ファイルの作品[incoming]（i番目。[candidates]のi番目がこの端末の同じ
  /// 中身の作品）のうち、整理を合わせるこの端末の作品（`organize`）と、足す
  /// 作品（`add`）。
  ///
  /// 整理は、この端末の作品1つにファイルの作品を1つだけ決める。名前が同じ組、
  /// フォルダとお気に入りも同じ組を先に決め、同じ段で1対1に決まらない作品は
  /// 取り違えないよう合わせない（その段の候補のこの端末の作品もほかの作品の
  /// 整理に選ばせない）。足すのは、ファイルの作品とこの端末の同じ作品を
  /// 1対1でできるだけ多く組んでも組めない作品だけ（この端末で消した作品）で、
  /// 名前・フォルダとお気に入り・タグが同じこの端末の作品の足りない方を
  /// 足す（ファイルの中の順によらない）。整理を決めた組はそのまま組む（その
  /// 作品は足さず、そのこの端末の作品をほかの作品の分には数えない）。見分け
  /// られない作品が候補を取って、ほかの作品を足させることは無い。
  static ({Map<int, String> organize, Set<int> add}) _matchProjects(
    List<Project> incoming,
    List<List<Project>> candidates,
  ) {
    int score(Project theirs, Project mine) =>
        (mine.name == theirs.name ? 2 : 0) +
        (mine.folderId == theirs.folderId &&
                mine.isFavorite == theirs.isFavorite
            ? 1
            : 0);
    // 整理を合わせる組：名前が同じ組、フォルダとお気に入りも同じ組を先に、
    // その段で1対1に決まる組だけを決める。決まらない作品は整理を合わせず、
    // その段の候補のこの端末の作品もほかの作品の整理に選ばせない。
    final organize = <int, String>{};
    final settled = <int>{};
    final taken = <String>{};
    for (var level = 3; level >= 0; level--) {
      final pairs = <int, List<String>>{};
      final byLocal = <String, List<int>>{};
      for (var i = 0; i < incoming.length; i++) {
        if (settled.contains(i)) continue;
        for (final local in candidates[i]) {
          if (taken.contains(local.id) || score(incoming[i], local) != level) {
            continue;
          }
          pairs.putIfAbsent(i, () => []).add(local.id);
          byLocal.putIfAbsent(local.id, () => []).add(i);
        }
      }
      for (final entry in pairs.entries) {
        final locals = entry.value;
        if (locals.length == 1 && byLocal[locals.single]!.length == 1) {
          organize[entry.key] = locals.single;
        }
      }
      for (final entry in pairs.entries) {
        settled.add(entry.key);
        taken.addAll(entry.value);
      }
    }
    // 足すかどうかは数で決める：ファイルの作品とこの端末の同じ作品を1対1で
    // できるだけ多く組み（最大マッチング）、組めなかった作品だけを足す
    // （この端末の同じ作品がファイルより少ない＝この端末で消した）。見分け
    // られない作品も、組めるこの端末の作品を数に入れ、ほかの作品を足させ
    // ない。整理を合わせる組はそのまま（整理を合わせた作品を、ほかの
    // ファイルの作品の分として数えない）、ほかの組は組み替えて増やす。
    //
    // 組めずに足すのは、この端末に同じ名前・整理の作品が足りない方（この端末
    // で消した作品）にする。似た組から段を下げて組む：名前、フォルダと
    // お気に入り、タグ（大文字・小文字は区別しない）の順に一致の多い組だけで
    // まだ組めていない作品を組み、次の段で一致の少ない組も使う（前の段で
    // 組んだ作品は組んだまま、相手は組み替えてよい）。ファイルの順で決めると、
    // 同じ名前・整理の作品がファイルの先にある方が組み、消した作品とは別の
    // フォルダ・名前・タグの作品を足していた。
    final tagsOf = [for (final p in incoming) _tagsKey(p)];
    final localTags = <String, String>{};
    // candidates[i]と同じ並びの、組の近さ。
    final closeness = [
      for (var i = 0; i < incoming.length; i++)
        [
          for (final local in candidates[i])
            score(incoming[i], local) * 2 +
                (localTags.putIfAbsent(local.id, () => _tagsKey(local)) ==
                        tagsOf[i]
                    ? 1
                    : 0),
        ],
    ];
    final ownerOf = <String, int>{
      for (final entry in organize.entries) entry.value: entry.key,
    };
    bool pairUp(int i, int level, Set<String> seen) {
      final locals = candidates[i];
      for (var k = 0; k < locals.length; k++) {
        final local = locals[k];
        if (closeness[i][k] < level || !seen.add(local.id)) continue;
        final owner = ownerOf[local.id];
        if (owner == null ||
            (!organize.containsKey(owner) && pairUp(owner, level, seen))) {
          ownerOf[local.id] = i;
          return true;
        }
      }
      return false;
    }

    // 組の近さとして実際にある段だけを、近い方から（使える組が増えない段は、
    // 組めなかった作品をもう一度試しても組めない）。組めなかった作品が
    // たどったこの端末の作品は、次に1組増えるまで、ほかの作品からたどっても
    // 組めないので、たどり直さない（同じ作品が数百あっても時間がかからない）。
    final levels = {for (final row in closeness) ...row}.toList()
      ..sort((a, b) => b - a);
    final paired = {...organize.keys};
    for (final level in levels) {
      var seen = <String>{};
      for (var i = 0; i < incoming.length; i++) {
        if (paired.contains(i) || !pairUp(i, level, seen)) continue;
        paired.add(i);
        seen = <String>{};
      }
    }
    final add = <int>{
      for (var i = 0; i < incoming.length; i++)
        if (!paired.contains(i)) i,
    };
    return (organize: organize, add: add);
  }

  /// [project]のタグを比べる形（大文字・小文字と並びは区別しない）。
  static String _tagsKey(Project project) => jsonEncode(
    {for (final tag in project.tags) tag.toLowerCase()}.toList()..sort(),
  );

  /// [saved]（ファイルの作品）が使う自動塗りのプリセット・線画のパーツ・
  /// 透かしを、合わせた後でもう1台の中身を持つこの端末の項目
  /// （[NiatraData.placedAutofillPresetIds]・
  /// [NiatraData.placedAutofillPartIds]・[NiatraData.placedWatermarkIds]）に
  /// した作品。変えるところが無ければ[saved]のまま。
  static NiaproData _withTransferredReferences(
    NiaproData saved,
    NiatraData data,
  ) => _withReferences(
    saved,
    preset: (id) => transferredItemId(id, data.placedAutofillPresetIds)!,
    part: (id) => transferredItemId(id, data.placedAutofillPartIds)!,
    mark: (id) => transferredItemId(id, data.placedWatermarkIds)!,
  );

  /// [saved]が使う自動塗りのプリセット・線画のパーツ・透かしのIDを、
  /// [preset]・[part]・[mark]で置き換えた作品（同じプリセットが2つになれば
  /// 1つにする）。変えるところが無ければ[saved]のまま。
  static NiaproData _withReferences(
    NiaproData saved, {
    required String Function(String id) preset,
    required String Function(String id) part,
    required String Function(String id) mark,
  }) {
    var changed = false;
    Layer layerOf(Layer layer) {
      final partId = layer.partId == null ? null : part(layer.partId!);
      final markId = layer.watermarkAssetId == null
          ? null
          : mark(layer.watermarkAssetId!);
      if (partId == layer.partId && markId == layer.watermarkAssetId) {
        return layer;
      }
      changed = true;
      return layer.copyWith(partId: partId, watermarkAssetId: markId);
    }

    final scenes = [
      for (final scene in saved.scenes)
        scene.copyWith(
          frames: [
            for (final frame in scene.frames)
              frame.copyWith(
                layers: [for (final l in frame.layers) layerOf(l)],
              ),
          ],
        ),
    ];
    final enabled = saved.project.enabledAutofillPresetIds;
    final enabledHere = enabled == null
        ? null
        : <String>{for (final id in enabled) preset(id)}.toList();
    if (enabled != null && jsonEncode(enabled) != jsonEncode(enabledHere)) {
      changed = true;
    }
    if (!changed) return saved;
    return NiaproData(
      project: saved.project.copyWith(enabledAutofillPresetIds: enabledHere),
      scenes: scenes,
      tileData: saved.tileData,
      materialFiles: saved.materialFiles,
      materialsManifest: saved.materialsManifest,
      fontFiles: saved.fontFiles,
      fontsManifest: saved.fontsManifest,
    );
  }

  /// 足さなかった作品（この端末の[id]）へ、もう1台での整理（[incoming]の
  /// お気に入り・タグ・フォルダ）を合わせる（[restoreProjects]）。変わる
  /// ところだけを保存する（同じファイルを読み直しても何も書かない）。
  /// 保存できなかった整理は記録して、読み込みは続ける。
  static Future<void> _adoptProjectOrganization(
    ProjectService service,
    String id,
    Project incoming,
    Map<String, ProjectFolder> folders,
  ) async {
    Project? mine() => service.projects.where((p) => p.id == id).firstOrNull;
    try {
      if (incoming.isFavorite && !(mine()?.isFavorite ?? true)) {
        await service.setFavorite(id, true);
      }
      final tags = mine()?.tags ?? const <String>[];
      final known = {for (final tag in tags) tag.toLowerCase()};
      final added = [
        for (final tag in incoming.tags)
          if (known.add(tag.toLowerCase())) tag,
      ];
      if (added.isNotEmpty) {
        await service.setProjectTags(id, [...tags, ...added]);
      }
      final current = mine();
      if (current != null &&
          current.folderId == null &&
          incoming.folderId != null) {
        final folderId = await _transferredFolder(
          service,
          incoming.folderId,
          folders,
        );
        if (folderId != null) await service.moveToFolder(id, folderId);
      }
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
  }

  /// この端末の作品のフォルダの一覧（保存の形のまま。読めなければ空）。
  static Future<List<Map<String, dynamic>>> _savedProjectFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.readString('project_folders');
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map<String, dynamic> && _projectFolder(item) != null)
            item,
      ];
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      return const [];
    }
  }

  /// 読めるフォルダの記録（読めなければnull）。
  static ProjectFolder? _projectFolder(Map<String, dynamic> json) {
    if (json['id'] is! String || json['name'] is! String) return null;
    try {
      return ProjectFolder.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 移した作品を入れる、この端末のフォルダのID（[id]はもう1台のフォルダ）。
  /// この端末に同じIDのフォルダがあればそれ、無ければ[records]から足す
  /// （上のフォルダから順に。足せない・ゴミ箱へ移したフォルダはnull）。
  static Future<String?> _transferredFolder(
    ProjectService service,
    String? id,
    Map<String, ProjectFolder> records, [
    Set<String>? visiting,
  ]) async {
    if (id == null) return null;
    if (service.folders.any((f) => f.id == id)) return id;
    if (service.isFolderInTrash(id)) return null;
    final record = records[id];
    final seen = visiting ?? <String>{};
    // 親をたどって同じフォルダへ戻る壊れた記録は足さない。
    if (record == null || !seen.add(id)) return null;
    final parent = await _transferredFolder(
      service,
      record.parentFolderId,
      records,
      seen,
    );
    try {
      return (await service.addTransferredFolder(
        record,
        parentFolderId: parent,
      )).id;
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      return null;
    }
  }

  // ─── Brush ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeBrush(Brush b) => b.toJson();

  static Brush _deserializeBrush(Map<String, dynamic> j, int index) =>
      Brush.fromJson({...j, 'id': transferredId(j['id'], 'Brush', index)});

  // ─── Tone / Stamp ─────────────────────────────────────────────────────

  static Map<String, dynamic> _serializeTone(Tone t) => t.toJson();

  static Tone _deserializeTone(Map<String, dynamic> j, int index) =>
      Tone.fromJson({...j, 'id': transferredId(j['id'], 'Tone', index)});

  static Map<String, dynamic> _serializeStamp(Stamp s) => s.toJson();

  static Stamp _deserializeStamp(Map<String, dynamic> j, int index) =>
      Stamp.fromJson({...j, 'id': transferredId(j['id'], 'Stamp', index)});

  // ─── AutofillPreset ───────────────────────────────────────────────────

  // グラデーション・トーン・線画色・トレス調整など、パーツが持つ設定を
  // 一切欠かさず引き継げるよう、モデル自身のtoJson/fromJsonをそのまま使う。
  static Map<String, dynamic> _serializeAutofillPreset(AutofillPreset p) =>
      p.toJson();

  // ─── ThemePreset ──────────────────────────────────────────────────────

  // Export/import the current mandatory theme schema as a single unit.
  // All body/button/menu/selection foregrounds must survive transfer.
  // We intentionally do not convert prerelease obsolete schemas.
  static Map<String, dynamic> _serializeThemePreset(AppThemePreset theme) =>
      theme.toJson();

  // IDは元のまま（同じテーマの読み直しで増えず、編集中のテーマも保つ）。
  static AppThemePreset _deserializeThemePreset(Map<String, dynamic> json) =>
      AppThemePreset.fromJson(json);
}

class NiatraData {
  final Map<String, dynamic> raw;
  // Projects/以下に埋め込まれた.niashareエントリを取り出すための元アーカイブ。
  // restoreProjects()専用で、他カテゴリの復元はraw（data.json）のみで完結する。
  final Archive archive;

  /// ブラシを合わせた後の、受け取ったブラシのIDごとの、その中身を持つ
  /// この端末のブラシのID（[NiatraSerializer.mergeBrushes]が書き、
  /// [NiatraSerializer.restoreLocalPreferences]が早替えツール・
  /// ショートカット・ワークスペースのブラシを合わせるのに使う）。
  final Map<String, String> placedBrushIds = {};

  /// トーンを合わせた後の、受け取ったトーンのIDごとの、その中身を持つ
  /// この端末のトーンのID（[NiatraSerializer.mergeTones]が書き、
  /// 自動塗りのプリセットを合わせるときにパーツが使うトーンを合わせる）。
  final Map<String, String> placedToneIds = {};

  /// 自動塗りのプリセットを合わせた後の、受け取ったプリセットとパーツの
  /// IDごとの、その中身を持つこの端末のプリセットとパーツのID
  /// （[NiatraSerializer.mergeAutofillPresets]が書き、
  /// [NiatraSerializer.restoreProjects]が移した作品の使うプリセットと
  /// 線画のパーツを合わせる）。
  final Map<String, String> placedAutofillPresetIds = {};
  final Map<String, String> placedAutofillPartIds = {};

  /// 透かしを合わせた後の、受け取った透かしのIDごとの、その中身を持つ
  /// この端末の透かしのID（[NiatraSerializer.restoreLocalPreferences]が
  /// 書き、[NiatraSerializer.restoreProjects]が移した作品の透かしの
  /// レイヤーを合わせる）。
  final Map<String, String> placedWatermarkIds = {};

  NiatraData(this.raw, this.archive);
}

/// 端末保存データの中の、利用者が作った物の一覧を持つ、動いているサービス
/// （引き継ぎ画面が渡す）。どのサービスも一覧の保存を生のまま書き換えず、
/// 受け取った物をこの端末の一覧へ足す。
class TransferredSavedLists {
  const TransferredSavedLists({
    this.workspacePresets,
    this.customAutomations,
    this.quickTools,
    this.shortcuts,
    this.settings,
    this.filters,
    this.firstUseTooltips,
    this.watermarks,
  });

  final WorkspacePresetService? workspacePresets;
  final CustomAutomationService? customAutomations;
  final QuickToolService? quickTools;
  final ShortcutService? shortcuts;
  final SettingsService? settings;
  final FilterService? filters;
  final FirstUseTooltipService? firstUseTooltips;
  final WatermarkService? watermarks;

  /// [brushIds]：早替えツール・ショートカット・ワークスペースの早替え
  /// ツールが使うブラシの、合わせた後の行き先（[transferredBrushId]）。
  /// [watermarkImages]：ファイルに入っていた透かしの画像（透かしのID →
  /// バイト列）。受け取った透かしの行き先は[placedWatermarks]へ書く。
  /// ショートカットが使う自動操作は、自動操作を合わせた後の行き先にする。
  /// 足さなかったショートカットは[TransferCopyNames.report]へ書く。
  Future<void> _merge(
    Map<String, List<String>> saved,
    TransferCopyNames copyNames, {
    Map<String, String> brushIds = const {},
    Map<String, List<int>> watermarkImages = const {},
    Map<String, String>? placedWatermarks,
  }) async {
    final automationIds = <String, String>{};
    final workspace = saved['workspace_presets'];
    if (workspace != null) {
      await workspacePresets?.mergeTransferred(
        workspace,
        copyNames: copyNames,
        brushIds: brushIds,
      );
    }
    final automations = saved['custom_automations_v1'];
    final favorites = saved['custom_automation_favorites_v1'];
    if (automations != null || favorites != null) {
      await customAutomations?.mergeTransferred(
        automations ?? const [],
        favoriteIds: favorites ?? const [],
        copyNames: copyNames,
        placed: automationIds,
      );
    }
    final quick = saved['quick_tool_entries'];
    if (quick != null) {
      await quickTools?.mergeTransferred(
        quick,
        copyNames: copyNames,
        brushIds: brushIds,
      );
    }
    final bindings = saved['shortcut_bindings'];
    if (bindings != null) {
      await shortcuts?.mergeTransferred(
        bindings,
        brushIds: brushIds,
        automationIds: automationIds,
        report: copyNames.report,
      );
    }
    final sizes = saved['custom_size_presets'];
    if (sizes != null) {
      await settings?.mergeTransferredCanvasSizes(sizes, copyNames: copyNames);
    }
    final drawFilters = saved['draw_filters'];
    if (drawFilters != null) {
      await filters?.mergeTransferred(drawFilters, copyNames: copyNames);
    }
    final seen = saved['first_use_tooltips_seen'];
    if (seen != null) await firstUseTooltips?.mergeTransferred(seen);
    final marks = saved['watermark_assets'];
    if (marks != null) {
      await watermarks?.mergeTransferred(
        marks,
        copyNames: copyNames,
        images: watermarkImages,
        placed: placedWatermarks,
      );
    }
  }
}
