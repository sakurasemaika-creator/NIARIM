import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/services/project_service.dart';

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

  // .niashareインポート（importSharedProject）で追加したプロジェクトが
  // 「共有」タブ（ProjectService.shared）に現れ、プロジェクト一覧タブ側
  // では絞り込んで除外できることを検証する。
  test('.niashareインポートしたプロジェクトは共有タブに入り、通常一覧からは絞り込める', () async {
    final service = ProjectService();
    await service.init();
    final own = await service.createProject(
      name: '自作作品', fps: 12, durationSeconds: 5, backgroundColor: 0xFFFFFFFF,
    );

    final incoming = Project(
      id: 'ignored', // importSharedProjectが新規IDを採番するため無視される
      name: '受け取った作品',
      fps: 24,
      durationSeconds: 3,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      totalWorkSeconds: 0,
    );
    final imported = await service.importSharedProject(
      NiaproData(project: incoming, scenes: const [], tileData: const {}),
    );

    expect(imported.isSharedImport, isTrue);
    expect(service.shared.map((p) => p.id), contains(imported.id));
    expect(service.projects.map((p) => p.id), contains(imported.id));
    // 「共有」タブと「プロジェクト」タブは同じ_projectsから絞り込むため、
    // 自作プロジェクトは共有タブに現れず、逆に共有インポート分はプロジェクト
    // タブ側のフィルタ（!isSharedImport）で除外できる。
    expect(service.shared.map((p) => p.id), isNot(contains(own.id)));
    final projectsTabList = service.projects.where((p) => !p.isSharedImport);
    expect(projectsTabList.map((p) => p.id), isNot(contains(imported.id)));
    expect(projectsTabList.map((p) => p.id), contains(own.id));
  });

  test('共有タブ専用フォルダへの移動・削除は共有インポート分にのみ作用する', () async {
    final service = ProjectService();
    await service.init();
    final own = await service.createProject(
      name: '自作作品2', fps: 12, durationSeconds: 5, backgroundColor: 0xFFFFFFFF,
    );
    final incoming = Project(
      id: 'ignored',
      name: '受け取った作品2',
      fps: 24,
      durationSeconds: 3,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      totalWorkSeconds: 0,
    );
    final imported = await service.importSharedProject(
      NiaproData(project: incoming, scenes: const [], tileData: const {}),
    );
    final folder = await service.createSharedFolder('もらった動画');

    // 通常プロジェクト（isSharedImport=false）はプロジェクト一覧タブ専用の
    // フォルダしか対象にできないため、共有タブ用フォルダへの移動は無視される。
    await service.moveToSharedFolder(own.id, folder.id);
    expect(service.projects.firstWhere((p) => p.id == own.id).sharedFolderId, isNull);

    await service.moveToSharedFolder(imported.id, folder.id);
    expect(service.shared.firstWhere((p) => p.id == imported.id).sharedFolderId, folder.id);

    await service.deleteSharedFolder(folder.id);
    expect(service.sharedFolders.any((f) => f.id == folder.id), isFalse);
    expect(service.shared.firstWhere((p) => p.id == imported.id).sharedFolderId, isNull);
  });
}
