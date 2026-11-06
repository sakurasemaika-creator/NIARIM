import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../services/project_service.dart';
import 'name_collation.dart';

/// 移動先のフォルダを選ぶ一覧の並び。親のすぐ下に子を名前順で並べ、
/// 階層の深さを添える（平らに並べると、どのフォルダの中か分からず、
/// 別のシリーズの同じ名前のフォルダを見分けられなかった）。
///
/// [excluding]を渡すと、そのフォルダと中のフォルダは出さない（フォルダを
/// 自分自身やその中へは移せず、選んでも何も起きなかった）。親が見つからない
/// フォルダや、壊れたデータで親子が輪になったフォルダは一番上の階層に置く。
List<({ProjectFolder folder, int depth})> folderTree(
  List<ProjectFolder> folders, {
  String? excluding,
}) {
  final ids = {for (final f in folders) f.id};
  final children = <String?, List<ProjectFolder>>{};
  for (final f in folders) {
    final parent = ids.contains(f.parentFolderId) ? f.parentFolderId : null;
    (children[parent] ??= []).add(f);
  }
  for (final list in children.values) {
    list.sort((a, b) => compareNames(a.name, b.name));
  }

  final seen = <String>{};
  void skip(String id) {
    if (!seen.add(id)) return;
    for (final child in children[id] ?? const <ProjectFolder>[]) {
      skip(child.id);
    }
  }

  if (excluding != null) skip(excluding);

  final result = <({ProjectFolder folder, int depth})>[];
  void visit(ProjectFolder folder, int depth) {
    if (!seen.add(folder.id)) return;
    result.add((folder: folder, depth: depth));
    for (final child in children[folder.id] ?? const <ProjectFolder>[]) {
      visit(child, depth + 1);
    }
  }

  for (final root in children[null] ?? const <ProjectFolder>[]) {
    visit(root, 0);
  }
  final rest = folders.where((f) => !seen.contains(f.id)).toList()
    ..sort((a, b) => compareNames(a.name, b.name));
  for (final folder in rest) {
    visit(folder, 0);
  }
  return result;
}

/// [folderTree]の一覧の行の余白。中のフォルダほど字下げする（深い階層でも
/// 名前が残るよう5段まで）。右はListTileの既定のまま。
EdgeInsetsDirectional folderTreeTilePadding(int depth) =>
    EdgeInsetsDirectional.only(start: 16.0 + 20 * math.min(depth, 5), end: 24);
