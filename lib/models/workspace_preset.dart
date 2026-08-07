import 'toolbar_item.dart';

/// 名前を付けて保存するワークスペース設定（仕様書08・24）。
/// UIテーマとは独立して、左利きモード・PC/DeXモードに加え、ツールバーの
/// 表示ツール・並び順・ツール早替え登録内容までをまとめて保存する
/// （仕様書08：「切り替えると表示ツール・早替えツール・パネル配置が
/// 一括で変わる」）。
class WorkspacePreset {
  final String id;
  final String name;
  final bool isLeftHanded;
  final bool? forcePcMode; // null=自動
  // ツールバー編集の並び順・非表示項目（空リストは「保存時点の全項目デフォルト」）
  final List<String> toolbarOrder;
  final List<String> hiddenToolbarItems;
  // ツール早替え登録内容（QuickToolEntry.toJson()のリスト）
  final List<Map<String, dynamic>> quickToolEntries;

  const WorkspacePreset({
    required this.id,
    required this.name,
    required this.isLeftHanded,
    this.forcePcMode,
    this.toolbarOrder = const [],
    this.hiddenToolbarItems = const [],
    this.quickToolEntries = const [],
  });

  List<ToolbarItemId> get toolbarOrderIds {
    final map = ToolbarItemId.values.asNameMap();
    return toolbarOrder.map((n) => map[n]).whereType<ToolbarItemId>().toList();
  }

  Set<ToolbarItemId> get hiddenToolbarItemIds {
    final map = ToolbarItemId.values.asNameMap();
    return hiddenToolbarItems.map((n) => map[n]).whereType<ToolbarItemId>().toSet();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isLeftHanded': isLeftHanded,
        'forcePcMode': forcePcMode,
        'toolbarOrder': toolbarOrder,
        'hiddenToolbarItems': hiddenToolbarItems,
        'quickToolEntries': quickToolEntries,
      };

  factory WorkspacePreset.fromJson(Map<String, dynamic> json) => WorkspacePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        isLeftHanded: json['isLeftHanded'] as bool? ?? false,
        forcePcMode: json['forcePcMode'] as bool?,
        toolbarOrder: (json['toolbarOrder'] as List?)?.cast<String>() ?? const [],
        hiddenToolbarItems: (json['hiddenToolbarItems'] as List?)?.cast<String>() ?? const [],
        quickToolEntries: (json['quickToolEntries'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
      );
}
