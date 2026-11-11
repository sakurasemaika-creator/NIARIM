import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace_preset.dart';
import '../utils/saved_list_reader.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';

/// ワークスペース（左利き設定・PC/DeXモード）を名前を付けて保存・読込・削除する
/// （ワークスペース保存・読込。例：アニメ用／線画用／背景用）。
class WorkspacePresetService extends ChangeNotifier {
  static const _prefsKey = 'workspace_presets';
  final List<WorkspacePreset> _presets = [];

  List<WorkspacePreset> get presets => List.unmodifiable(_presets);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.readStringList(_prefsKey) ?? const [];
    _presets
      ..clear()
      ..addAll(readSavedJsonList(raw, WorkspacePreset.fromJson));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _presets.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  /// 引き継ぎ（.niatra）の端末保存データで受け取ったワークスペース
  /// （保存と同じ1件ずつのJSON）を、この端末の一覧へ足す。この端末の
  /// ワークスペースは書き換えない（同じIDで中身か名前が違えば、受け取った方を
  /// 「名前 (コピー)」として足す。決まりは[mergeTransferredItems]）。
  /// 早替えツールの使うブラシは、合わせた後でそのブラシの中身を持つ
  /// この端末のブラシにする（[brushIds]、[transferredBrushId]）。比べる
  /// ときは、もう1台のブラシと、引き継ぎでその版を足したこの端末の複製を
  /// 同じブラシとみなす（[TransferCopyRecord.origin]）。
  Future<void> mergeTransferred(
    List<String> saved, {
    required TransferCopyNames copyNames,
    Map<String, String> brushIds = const {},
  }) async {
    final brushes = await TransferCopyRecord.read(TransferCopyRecord.brushes);
    // 前の読み込みでもう1台の版を足した複製（名前を変えていても見つける）。
    final copies = await TransferCopyRecord.read(TransferCopyRecord.workspaces);
    final changed = mergeTransferredItems(
      _presets,
      [
        for (final preset in readSavedJsonList(saved, WorkspacePreset.fromJson))
          WorkspacePreset.fromJson({
            ...preset.toJson(),
            'quickToolEntries': [
              for (final entry in preset.quickToolEntries)
                entry['brushId'] is String
                    ? {
                        ...entry,
                        'brushId': transferredBrushId(
                          entry['brushId'] as String,
                          brushIds,
                        ),
                      }
                    : entry,
            ],
          }),
      ],
      TransferMergeRules<WorkspacePreset>(
        idOf: (p) => p.id,
        nameOf: (p) => p.name,
        contentOf: (p) => p.toJson()
          ..remove('id')
          ..remove('name')
          ..['quickToolEntries'] = [
            for (final entry in p.quickToolEntries)
              entry['brushId'] is String
                  ? {
                      ...entry,
                      'brushId': brushes.origin(entry['brushId'] as String),
                    }
                  : entry,
          ],
        organizationOf: (_) =>
            (favorite: false, tags: const [], folderId: null),
        withOrganization: (p, _) => p,
        asCopy: (p, id, name) =>
            WorkspacePreset.fromJson({...p.toJson(), 'id': id, 'name': name}),
        newId: (attempt) =>
            'ws_${DateTime.now().microsecondsSinceEpoch}_$attempt',
        copyNames: copyNames,
      ),
      copies: copies,
    );
    await copies.save();
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  /// 現在の操作環境を[name]で保存する。同名の既存プリセットは上書きする。
  /// 表示ツール・並び順・ツール早替え登録内容も併せて保存する。
  Future<void> save(
    String name, {
    required bool isLeftHanded,
    required bool? forcePcMode,
    List<String> toolbarOrder = const [],
    List<String> hiddenToolbarItems = const [],
    List<Map<String, dynamic>> quickToolEntries = const [],
    List<String> defaultDockedPanels = const [],
    double? desktopPanelWidth,
    double? desktopToolPanelWidth,
    List<String> toolOptionDockOrder = const [],
    List<String> rightDockOrder = const [],
  }) async {
    _presets.removeWhere((p) => p.name == name);
    _presets.add(
      WorkspacePreset(
        id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        isLeftHanded: isLeftHanded,
        forcePcMode: forcePcMode,
        toolbarOrder: toolbarOrder,
        hiddenToolbarItems: hiddenToolbarItems,
        quickToolEntries: quickToolEntries,
        defaultDockedPanels: defaultDockedPanels,
        desktopPanelWidth: desktopPanelWidth,
        desktopToolPanelWidth: desktopToolPanelWidth,
        toolOptionDockOrder: toolOptionDockOrder,
        rightDockOrder: rightDockOrder,
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _presets.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  /// 保存済みワークスペースの名前だけを変更する（保存内容は変更しない）。
  Future<void> rename(String id, String newName) async {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx < 0 || newName.trim().isEmpty) return;
    final p = _presets[idx];
    _presets[idx] = WorkspacePreset(
      id: p.id,
      name: newName.trim(),
      isLeftHanded: p.isLeftHanded,
      forcePcMode: p.forcePcMode,
      toolbarOrder: p.toolbarOrder,
      hiddenToolbarItems: p.hiddenToolbarItems,
      quickToolEntries: p.quickToolEntries,
      defaultDockedPanels: p.defaultDockedPanels,
      desktopPanelWidth: p.desktopPanelWidth,
      desktopToolPanelWidth: p.desktopToolPanelWidth,
      toolOptionDockOrder: p.toolOptionDockOrder,
      rightDockOrder: p.rightDockOrder,
    );
    await _persist();
    notifyListeners();
  }

  /// [id]のワークスペースを現在の設定で上書きする。[newName]を指定しない
  /// （null）場合は既存の名前をそのまま使う。IDは変えない。
  Future<void> overwrite(
    String id, {
    String? newName,
    required bool isLeftHanded,
    required bool? forcePcMode,
    List<String> toolbarOrder = const [],
    List<String> hiddenToolbarItems = const [],
    List<Map<String, dynamic>> quickToolEntries = const [],
    List<String> defaultDockedPanels = const [],
    double? desktopPanelWidth,
    double? desktopToolPanelWidth,
    List<String> toolOptionDockOrder = const [],
    List<String> rightDockOrder = const [],
  }) async {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final current = _presets[idx];
    _presets[idx] = WorkspacePreset(
      id: current.id,
      name: (newName != null && newName.trim().isNotEmpty)
          ? newName.trim()
          : current.name,
      isLeftHanded: isLeftHanded,
      forcePcMode: forcePcMode,
      toolbarOrder: toolbarOrder,
      hiddenToolbarItems: hiddenToolbarItems,
      quickToolEntries: quickToolEntries,
      defaultDockedPanels: defaultDockedPanels,
      desktopPanelWidth: desktopPanelWidth,
      desktopToolPanelWidth: desktopToolPanelWidth,
      toolOptionDockOrder: toolOptionDockOrder,
      rightDockOrder: rightDockOrder,
    );
    await _persist();
    notifyListeners();
  }

  // ─── 共有（.niaworkspace）：バイナリ資産を持たない単純な
  // JSON設定のため、トーン・ブラシ等と異なりzip化はせずJSONそのまま
  // 書き出す。 ─────────────────────────────────────────────────────

  Future<File> exportPreset(String id) async {
    final preset = _presets.firstWhere((p) => p.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = preset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${base.path}/$safeName.niaworkspace');
    await file.writeAsString(jsonEncode(preset.toJson()));
    return file;
  }

  Future<WorkspacePreset> importPresetFile(String filePath) async {
    final content = await File(filePath).readAsString();
    return importPresetJson(content);
  }

  /// JSON文字列（`exportPreset`が書き出す形式と同じ）からワークスペース
  /// 設定を取り込む。QRコード共有で読み取ったテキストの取り込みにも使う。
  Future<WorkspacePreset> importPresetJson(String content) async {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final imported = WorkspacePreset.fromJson(json);
    // IDは取り込み先で既存プリセットと衝突しないよう振り直す。
    final preset = WorkspacePreset(
      id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
      name: imported.name,
      isLeftHanded: imported.isLeftHanded,
      forcePcMode: imported.forcePcMode,
      toolbarOrder: imported.toolbarOrder,
      hiddenToolbarItems: imported.hiddenToolbarItems,
      quickToolEntries: imported.quickToolEntries,
      defaultDockedPanels: imported.defaultDockedPanels,
      desktopPanelWidth: imported.desktopPanelWidth,
      desktopToolPanelWidth: imported.desktopToolPanelWidth,
      toolOptionDockOrder: imported.toolOptionDockOrder,
      rightDockOrder: imported.rightDockOrder,
    );
    _presets.add(preset);
    await _persist();
    notifyListeners();
    return preset;
  }
}
