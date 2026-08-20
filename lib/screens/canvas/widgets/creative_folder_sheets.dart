import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/confirm_delete.dart';

/// ブラシ・トーン・スタンプで共通のフォルダ管理UI（仕様書17：フォルダ管理）。
/// 各サービス（BrushService/ToneService/StampService）の型が異なるため、
/// レコード型でフォルダ情報を受け取り、操作はコールバックで委譲する。

/// フォルダ管理シート（新規作成・名前変更・並び替え・お気に入り登録・削除）。
void showFolderManagementSheet(
  BuildContext context, {
  required List<({String id, String name, bool isFavorite})> Function() getFolders,
  required Future<void> Function(String name) onCreate,
  required void Function(String id, String name) onRename,
  required void Function(String id) onToggleFavorite,
  required void Function(int oldIndex, int newIndex) onReorder,
  required void Function(String id) onDelete,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final folders = getFolders();
        final l10n = AppLocalizations.of(ctx)!;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(l10n.folderManagementTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.create_new_folder, size: 18),
                      label: Text(l10n.folderManagementCreateNew),
                      onPressed: () async {
                        final name = await _promptFolderName(ctx, title: l10n.homeAddSheetNewFolder);
                        if (name == null || name.trim().isEmpty) return;
                        await onCreate(name.trim());
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.folderManagementEmpty, style: const TextStyle(color: Colors.grey)),
                ),
              Expanded(
                child: ReorderableListView.builder(
                  // ドラッグハンドルを明示アイコンとして置く（既定のままだと
                  // 行の長押しでしか並べ替えを開始できず、可視の目印が無い
                  // ままだった）。
                  buildDefaultDragHandles: false,
                  scrollController: controller,
                  itemCount: folders.length,
                  onReorder: (oldIndex, newIndex) {
                    onReorder(oldIndex, newIndex);
                    setSheetState(() {});
                  },
                  itemBuilder: (context, index) {
                    final f = folders[index];
                    return ListTile(
                      key: ValueKey(f.id),
                      leading: const Icon(Icons.folder),
                      title: Text(f.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(f.isFavorite ? Icons.star : Icons.star_outline,
                                color: f.isFavorite ? Colors.amber : null, size: 18),
                            tooltip: l10n.commonFavoriteToggle,
                            onPressed: () {
                              onToggleFavorite(f.id);
                              setSheetState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: l10n.commonRename,
                            onPressed: () async {
                              final name = await _promptFolderName(ctx, title: l10n.commonRename, initial: f.name);
                              if (name == null || name.trim().isEmpty) return;
                              onRename(f.id, name.trim());
                              setSheetState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: l10n.commonDelete,
                            // お気に入り登録中は削除できない。
                            onPressed: () async {
                              if (f.isFavorite) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
                                return;
                              }
                              if (!await confirmDelete(ctx, itemName: f.name)) return;
                              onDelete(f.id);
                              setSheetState(() {});
                            },
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle, size: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<String?> _promptFolderName(BuildContext context, {required String title, String? initial}) {
  final controller = TextEditingController(text: initial);
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.folderNameLabel, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('OK')),
      ],
    ),
  ).then((v) { controller.dispose(); return v; });
}

/// 素材を指定フォルダへ移動するシート（「フォルダなし」も選択可能）。
void showMoveToCreativeFolderSheet(
  BuildContext context, {
  required List<({String id, String name})> folders,
  required void Function(String? folderId) onSelect,
}) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.folderMoveToTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(l10n.folderNone),
            onTap: () {
              onSelect(null);
              Navigator.pop(ctx);
            },
          ),
          ...folders.map((f) => ListTile(
                leading: const Icon(Icons.folder),
                title: Text(f.name),
                onTap: () {
                  onSelect(f.id);
                  Navigator.pop(ctx);
                },
              )),
        ],
      ),
      );
    },
  );
}

/// 新規名を入力するダイアログ（自作ブラシ/トーン/スタンプ作成時の名前入力）。
Future<String?> promptCreativeAssetName(BuildContext context, {required String title, String initial = ''}) {
  final controller = TextEditingController(text: initial);
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.creativeAssetNameLabel, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l10n.commonCreate)),
      ],
    ),
  ).then((v) { controller.dispose(); return v; });
}
