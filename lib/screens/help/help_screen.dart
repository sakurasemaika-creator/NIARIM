import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<_HelpEntry> _entries = const [
    _HelpEntry('ブレンドモード', 'レイヤーの合成方法を変更します。乗算・スクリーン・オーバーレイなどがあります。', 'レイヤー'),
    _HelpEntry('クリッピング', '下のレイヤーの不透明ピクセル範囲内にのみ描画します。描画範囲の制御にはこちらを使用します。', 'レイヤー'),
    _HelpEntry('自動塗り', 'プリセットに基づいて線画から自動的に色を塗ります。', '描画'),
    _HelpEntry('オニオンスキン', '前後のフレームを半透明表示し、アニメーション制作を補助します。', 'アニメーション'),
    _HelpEntry('定規', '直線・円・楕円・透視図法など、描画補助のための定規を配置します。', '描画'),
    _HelpEntry('フェード', 'ストロークが進むにつれて不透明度・サイズが減少する効果です。', 'ブラシ'),
    _HelpEntry('ストローク減衰', '描き続けるほどインクが減るような表現です。', 'ブラシ'),
    _HelpEntry('混色', 'ブラシ直下の色と選択色を混ぜて描画します。', 'ブラシ'),
    _HelpEntry('共通レイヤー', '複数フレームで同一の描画内容を共有するレイヤーです。', 'レイヤー'),
    _HelpEntry('セーブツリー', '手動保存の履歴を管理し、任意の状態へ戻れます。', '保存'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_HelpEntry> get _filtered => _searchQuery.isEmpty
      ? _entries
      : _entries.where((e) => e.title.contains(_searchQuery) || e.description.contains(_searchQuery) || e.category.contains(_searchQuery)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ヘルプ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: '検索...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('該当する項目が見つかりません',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final entry = _filtered[index];
                return ExpansionTile(
                  leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                  title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(entry.category,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(entry.description))],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpEntry {
  final String title;
  final String description;
  final String category;
  const _HelpEntry(this.title, this.description, this.category);
}
