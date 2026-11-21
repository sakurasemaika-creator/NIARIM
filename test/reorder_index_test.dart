import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/reorder_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// このアプリの各サービスの並び替えメソッドが共通して持っている実装。
/// newIndexは「移動元をまだ取り除いていない」添字である前提。
List<T> reorderAsService<T>(List<T> src, int oldIndex, int newIndexPre) {
  final list = List<T>.from(src);
  if (newIndexPre > oldIndex) newIndexPre -= 1;
  final item = list.removeAt(oldIndex);
  list.insert(newIndexPre, item);
  return list;
}

/// `ReorderableListView.onReorderItem`が意図する結果。newIndexは
/// 「移動元を取り除いた後」のリスト上の最終位置。
List<T> reorderAsOnReorderItem<T>(List<T> src, int oldIndex, int newIndexPost) {
  final list = List<T>.from(src);
  final item = list.removeAt(oldIndex);
  list.insert(newIndexPost, item);
  return list;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // onReorderからonReorderItemへ移行するにあたり、サービス側の添字規約
  // （ドラッグ以外の呼び出し元も依存しているため変えられない）を保ったまま
  // UI側で変換している。その変換が全パターンで正しいことを機械的に確かめる。
  test('preRemovalIndexはonReorderItemの意図する並びを厳密に再現する', () {
    for (var n = 1; n <= 8; n++) {
      final src = List<int>.generate(n, (i) => i);
      for (var oldIndex = 0; oldIndex < n; oldIndex++) {
        // onReorderItemのnewIndexは、移動元を取り除いた後のリスト
        // （長さ n-1）の添字なので 0..n-1 の範囲を取る。
        for (var newPost = 0; newPost < n; newPost++) {
          expect(
            reorderAsService(src, oldIndex, preRemovalIndex(oldIndex, newPost)),
            reorderAsOnReorderItem(src, oldIndex, newPost),
            reason: 'n=$n old=$oldIndex newPost=$newPost',
          );
        }
      }
    }
  });

  test('同じ位置へ戻す操作は並びを変えない', () {
    for (var n = 1; n <= 6; n++) {
      final src = List<int>.generate(n, (i) => i);
      for (var i = 0; i < n; i++) {
        expect(reorderAsService(src, i, preRemovalIndex(i, i)), src);
      }
    }
  });

  // 上のreorderAsServiceは実サービスの写しなので、写しが実物とずれて
  // いないことを、実際のサービス2つで端から端まで動かして確かめる。
  test('実サービス（QuickToolService）でも変換後の並びが一致する', () async {
    SharedPreferences.setMockInitialValues({});
    final service = QuickToolService();
    await service.init();
    final original = service.entries.map((e) => e.id).toList();
    final n = original.length;
    expect(n, greaterThan(2));

    for (var oldIndex = 0; oldIndex < n; oldIndex++) {
      for (var newPost = 0; newPost < n; newPost++) {
        SharedPreferences.setMockInitialValues({});
        final s = QuickToolService();
        await s.init();
        s.reorder(oldIndex, preRemovalIndex(oldIndex, newPost));
        expect(
          s.entries.map((e) => e.id).toList(),
          reorderAsOnReorderItem(original, oldIndex, newPost),
          reason: 'old=$oldIndex newPost=$newPost',
        );
      }
    }
  });

  test('実サービス（ThemeService）でも変換後の並びが一致する', () async {
    SharedPreferences.setMockInitialValues({});
    final probe = ThemeService();
    await probe.init();
    final original = probe.presets.map((p) => p.id).toList();
    final n = original.length;
    expect(n, greaterThan(2));

    for (var oldIndex = 0; oldIndex < n; oldIndex++) {
      for (var newPost = 0; newPost < n; newPost++) {
        SharedPreferences.setMockInitialValues({});
        final s = ThemeService();
        await s.init();
        s.reorder(oldIndex, preRemovalIndex(oldIndex, newPost));
        expect(
          s.presets.map((p) => p.id).toList(),
          reorderAsOnReorderItem(original, oldIndex, newPost),
          reason: 'old=$oldIndex newPost=$newPost',
        );
      }
    }
  });
}
