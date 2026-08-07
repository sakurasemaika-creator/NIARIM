import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miranima/services/project_service.dart';

/// 仕様書19：プロジェクト管理仕様「フォルダ管理」を検証する。
/// フォルダの永続化・複数階層対応・お気に入り・移動時の循環防止・
/// 削除時の子フォルダ/プロジェクトのルートへの復帰を確認する。
/// ProjectService.init()はストレージアクセス失敗時に空状態でも安全に
/// 起動する設計（try/catchで全体を包む）ため、path_providerのプラット
/// フォームチャンネルが無いテスト環境でも、SharedPreferencesベースの
/// フォルダ読み込み（_loadFolders）は正常に完了する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('フォルダの作成・複数階層のネストができる', () async {
    final service = ProjectService();
    await service.init();
    final root = await service.createFolder('アニメ用');
    final child = await service.createFolder('線画用', parentFolderId: root.id);
    expect(service.folders.length, 2);
    expect(child.parentFolderId, root.id);
  });

  test('お気に入り登録を切り替えられる', () async {
    final service = ProjectService();
    await service.init();
    final folder = await service.createFolder('背景用');
    expect(folder.isFavorite, isFalse);
    await service.toggleFolderFavorite(folder.id);
    expect(service.folders.first.isFavorite, isTrue);
    await service.toggleFolderFavorite(folder.id);
    expect(service.folders.first.isFavorite, isFalse);
  });

  test('自分自身または子孫フォルダへの移動は無視される（循環防止）', () async {
    final service = ProjectService();
    await service.init();
    final root = await service.createFolder('親');
    final child = await service.createFolder('子', parentFolderId: root.id);
    final grandchild = await service.createFolder('孫', parentFolderId: child.id);

    // 自分自身の子（孫）へは移動できない
    await service.moveFolderTo(root.id, grandchild.id);
    expect(service.folders.firstWhere((f) => f.id == root.id).parentFolderId, isNull);

    // 通常の移動は成功する
    await service.moveFolderTo(grandchild.id, root.id);
    expect(service.folders.firstWhere((f) => f.id == grandchild.id).parentFolderId, root.id);
  });

  test('フォルダ削除時、中の子フォルダ・プロジェクトはルートへ戻る', () async {
    final service = ProjectService();
    await service.init();
    final root = await service.createFolder('削除予定');
    final child = await service.createFolder('中身フォルダ', parentFolderId: root.id);
    final project = await service.createProject(
      name: 'テスト作品', fps: 12, durationSeconds: 5, backgroundColor: 0xFFFFFFFF,
    );
    await service.moveToFolder(project.id, root.id);

    await service.deleteFolder(root.id);

    expect(service.folders.any((f) => f.id == root.id), isFalse);
    expect(service.folders.firstWhere((f) => f.id == child.id).parentFolderId, isNull);
    expect(service.projects.firstWhere((p) => p.id == project.id).folderId, isNull);
  });

  test('保存内容（名前・色・親・お気に入り）は再起動後も復元される', () async {
    final service = ProjectService();
    await service.init();
    final root = await service.createFolder('保存確認');
    final child = await service.createFolder('子フォルダ', parentFolderId: root.id);
    await service.setFolderColor(root.id, 0xFFFF5C7A);
    await service.toggleFolderFavorite(root.id);

    // アプリ再起動をシミュレート：新しいインスタンスを作り直す
    final restarted = ProjectService();
    await restarted.init();

    final restoredRoot = restarted.folders.firstWhere((f) => f.id == root.id);
    expect(restoredRoot.color, 0xFFFF5C7A);
    expect(restoredRoot.isFavorite, isTrue);
    expect(restarted.folders.firstWhere((f) => f.id == child.id).parentFolderId, root.id);
  });
}
