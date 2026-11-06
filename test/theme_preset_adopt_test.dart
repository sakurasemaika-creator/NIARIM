// テーマ一覧の「タップ＝配色の取り込み」「三点メニューの編集＝編集対象化」を守る。
//
// 以前はカードのタップがそのテーマを編集対象にしていたため、見本のつもりで
// タップしたテーマが、その後のカラーカスタマイズで**勝手に上書きされて**
// いた。タップは配色を現在の色へ写すだけにし、テーマ自体の編集は三点
// メニューの「編集」からのみ行う。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ThemeService> newService() async {
    final service = ThemeService();
    await service.init();
    return service;
  }

  test('タップ（配色の取り込み）では、色を変えても元のテーマは変わらない', () async {
    final service = await newService();
    final target = service.presets.firstWhere(
      (p) => p.id != service.current.id,
    );
    final originalAccent = target.accentColor;

    service.adoptPresetColors(target.id);
    // 配色は現在の色へ入るが、テーマそのものになったわけではない。
    expect(service.current.accentColor, originalAccent);
    expect(service.current.id, ThemeService.customCurrentId);
    expect(
      service.isEditingPreset,
      isFalse,
      reason: '取り込み直後はどのテーマの編集でもない（＝一覧にチェックが付かない）',
    );
    expect(
      service.presets.map((p) => p.id),
      isNot(contains(ThemeService.customCurrentId)),
      reason: '取り込み用の現在色は一覧へ現れないこと',
    );

    // カラーカスタマイズで色を変えて確定しても、見本のテーマは無傷。
    const changed = Color(0xFF123456);
    service.previewCurrent(service.current.copyWith(accentColor: changed));
    service.commitCurrent();

    expect(service.current.accentColor, changed);
    expect(
      service.presets.firstWhere((p) => p.id == target.id).accentColor,
      originalAccent,
      reason: 'タップしただけのテーマがカラーカスタマイズで書き換わらないこと',
    );
    expect(
      service.presets.map((p) => p.id),
      isNot(contains(ThemeService.customCurrentId)),
      reason: '確定してもテーマ一覧へ新しい項目が増えないこと',
    );
  });

  test('三点メニューの編集（applyPreset）では、色の変更がそのテーマへ保存される', () async {
    final service = await newService();
    final target = service.presets.firstWhere(
      (p) => p.id != service.current.id,
    );

    service.applyPreset(target.id);
    expect(service.current.id, target.id);
    expect(service.isEditingPreset, isTrue, reason: '編集対象にしたテーマには一覧でチェックが付く');

    const changed = Color(0xFF654321);
    service.previewCurrent(service.current.copyWith(accentColor: changed));
    service.commitCurrent();

    expect(
      service.presets.firstWhere((p) => p.id == target.id).accentColor,
      changed,
      reason: '編集対象にしたテーマへは変更が保存されること',
    );
  });

  test('引き継ぎ用のrestoreCurrentは一覧へ足さずに現在の色だけ差し替える', () async {
    final service = await newService();
    final before = service.presets.length;
    final handed = service.presets.first.copyWith(
      id: 'theme_from_other_device',
      accentColor: const Color(0xFF00FF88),
    );

    service.restoreCurrent(handed);

    expect(service.current.accentColor, const Color(0xFF00FF88));
    expect(service.presets.length, before, reason: '引き継いだ現在の色でテーマ一覧が増えないこと');
  });

  test('取り込んだ現在の色は再起動後も復元される', () async {
    final service = await newService();
    final target = service.presets.firstWhere(
      (p) => p.id != service.current.id,
    );
    service.adoptPresetColors(target.id);
    const changed = Color(0xFF0A0B0C);
    service.previewCurrent(service.current.copyWith(accentColor: changed));
    service.commitCurrent();
    // _persistはawaitできないので、SharedPreferencesへの書き込みを待つ。
    await Future<void>.delayed(Duration.zero);

    final restored = await newService();
    expect(
      restored.current.accentColor,
      changed,
      reason: '一覧に無い「現在の色」もJSONとして保存・復元されること',
    );
  });
}
