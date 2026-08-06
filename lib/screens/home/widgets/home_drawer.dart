import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF16213E)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('MIRANIMA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('手書きアニメ制作アプリ', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('お気に入り'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('自動塗りプリセット'),
            onTap: () {
              Navigator.pop(context);
              context.push('/autofill-presets');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('設定'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('ヘルプ'),
            onTap: () {
              Navigator.pop(context);
              context.push('/help');
            },
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('プレミアム'),
            onTap: () {
              Navigator.pop(context);
              context.push('/premium');
            },
          ),
        ],
      ),
    );
  }
}
