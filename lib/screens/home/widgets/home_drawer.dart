import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // テーマの差し色を使ったグラデーションヘッダー（固定の濃紺ではなく
          // 選択中テーマに追従する）。
          Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.movie_creation_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 12),
                const Text('MIRANIMA',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('手書きアニメ制作アプリ',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('自動塗りプリセット'),
            onTap: () {
              Navigator.pop(context);
              context.push('/autofill-presets');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
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
            leading: Icon(Icons.workspace_premium_outlined, color: scheme.primary),
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
