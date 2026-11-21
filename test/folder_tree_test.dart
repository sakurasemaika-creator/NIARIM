import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/folder_tree.dart';

ProjectFolder _folder(String id, String name, [String? parent]) =>
    ProjectFolder(id: id, name: name, parentFolderId: parent);

List<String> _rows(List<({ProjectFolder folder, int depth})> tree) => [
  for (final (:folder, :depth) in tree) '${'  ' * depth}${folder.name}',
];

/// 移動先のフォルダの一覧：親のすぐ下に子を名前順、深さつき。
void main() {
  final folders = [
    _folder('b', 'シリーズB'),
    _folder('a1', '第1話', 'a'),
    _folder('a', 'シリーズA'),
    _folder('a1x', 'カット素材', 'a1'),
    _folder('b1', '第1話', 'b'),
    _folder('a2', '第2話', 'a'),
    _folder('a10', '第10話', 'a'),
  ];

  test('children follow their parent, in name order, with depth', () {
    expect(_rows(folderTree(folders)), [
      'シリーズA',
      '  第1話',
      '    カット素材',
      '  第2話',
      '  第10話',
      'シリーズB',
      '  第1話',
    ]);
  });

  test('a folder being moved leaves out itself and everything inside', () {
    expect(_rows(folderTree(folders, excluding: 'a1')), [
      'シリーズA',
      '  第2話',
      '  第10話',
      'シリーズB',
      '  第1話',
    ]);
  });

  test('a missing parent or a broken loop still lists every folder once', () {
    final broken = [
      _folder('o', '迷子', 'gone'),
      _folder('x', 'X', 'y'),
      _folder('y', 'Y', 'x'),
    ];
    final tree = folderTree(broken);
    expect(tree.map((e) => e.folder.id).toSet(), {'o', 'x', 'y'});
    expect(tree, hasLength(3));
    expect(tree.firstWhere((e) => e.folder.id == 'o').depth, 0);
  });

  test('indentation grows with depth and stops at five levels', () {
    double start(int depth) =>
        folderTreeTilePadding(depth).resolve(TextDirection.ltr).left;
    expect(start(0), 16);
    expect(start(1), greaterThan(start(0)));
    expect(start(5), greaterThan(start(4)));
    expect(start(9), start(5));
  });
}
