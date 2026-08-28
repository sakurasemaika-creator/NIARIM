import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/workspace_preset_service.dart';

/// WorkspacePresetService の単体テスト。
/// 注意：exportPreset()はpath_providerのgetApplicationDocumentsDirectory()に
/// 依存しており、単体テスト環境ではMissingPluginExceptionになるため、
/// ファイルI/Oを伴わないimportPresetJson()のみを対象にする。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('初回起動時はプリセットが0件', () async {
    final service = WorkspacePresetService();
    await service.init();
    expect(service.presets, isEmpty);
  });

  test('save/delete/renameで保存内容が反映される', () async {
    final service = WorkspacePresetService();
    await service.init();

    await service.save('線画用', isLeftHanded: true, forcePcMode: null);
    expect(service.presets, hasLength(1));
    final id = service.presets.first.id;

    await service.rename(id, '線画用改');
    expect(service.presets.first.name, '線画用改');

    await service.delete(id);
    expect(service.presets, isEmpty);
  });

  group('共有（Task#142：個別書き出し・QRコード共有）', () {
    test('importPresetJsonはexportPresetと同じJSON形式から復元でき、IDは振り直される', () async {
      final service = WorkspacePresetService();
      await service.init();

      final json = jsonEncode({
        'id': 'other-device-id',
        'name': '共有ワークスペース',
        'isLeftHanded': true,
        'forcePcMode': null,
        'toolbarOrder': <String>[],
        'hiddenToolbarItems': <String>[],
        'quickToolEntries': <Map<String, dynamic>>[],
        'defaultDockedPanels': <String>[],
        'toolOptionDockOrder': <String>[],
        'rightDockOrder': <String>[],
      });

      final imported = await service.importPresetJson(json);

      expect(service.presets, hasLength(1));
      expect(imported.id, isNot('other-device-id'), reason: 'ID衝突を避けるため振り直すはず');
      expect(imported.name, '共有ワークスペース');
      expect(imported.isLeftHanded, isTrue);
    });
  });
}
