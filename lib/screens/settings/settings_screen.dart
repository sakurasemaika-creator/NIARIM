import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumService>().isPremium;
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(controller: _searchController, autofocus: true, decoration: const InputDecoration(hintText: '設定を検索...', border: InputBorder.none))
            : const Text('設定'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) _searchController.clear(); }),
          ),
        ],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _item(Icons.settings, '基本', 'FPS・背景色・言語', _showBasicSettings, const Color(0xFFFF5C7A)),
            _item(Icons.tune, '詳細', 'Undo回数・自動保存・ゴミ箱', _showDetailSettings, const Color(0xFF3AA6FF)),
            _item(Icons.speed, 'パフォーマンス', '品質設定・タイルキャッシュ', () => context.push('/settings/performance'), const Color(0xFF3DDC97)),
            _item(Icons.touch_app, 'ジェスチャー', '2本指タップ・長押し', () => context.push('/settings/gestures'), const Color(0xFFFFB020)),
            _item(Icons.edit, 'ペン入力', '筆圧・傾き・ペンボタン', () => context.push('/settings/pen'), const Color(0xFFB15CFF)),
            _item(Icons.desktop_windows, 'ワークスペース', 'ツールバー編集・パネル配置', () => context.push('/settings/workspace'), const Color(0xFF3AA6FF)),
            _item(Icons.palette, 'UI・テーマ', 'テーマ設定・ワークスペース', () => context.push('/settings/theme'), const Color(0xFFFF5C7A)),
            // 無料会員のみ🔒マーク付きで表示（仕様書08）
            _item(Icons.water, isPremium ? 'ウォーターマーク' : 'ウォーターマーク 🔒', 'ユーザーウォーターマーク（Premium）', _showWatermarkSetting, const Color(0xFFB15CFF)),
            _item(Icons.import_export, '引き継ぎ', '設定・素材・ブラシを他端末へ書き出し/読み込み', () => context.push('/settings/transfer'), const Color(0xFF3DDC97)),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, String subtitle, VoidCallback onTap, Color accent) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showWatermarkSetting() {
    if (!context.read<PremiumService>().isPremium) {
      showPremiumBanner(context);
      return;
    }
    context.push('/settings/watermark');
  }

  void _showBasicSettings() {
    final settings = context.read<SettingsService>();
    var enabled = settings.defaultDrawingAreaEnabled;
    var scale = settings.defaultDrawingAreaScale;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                const Text('基本設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(title: const Text('デフォルトFPS'), trailing: Text('${settings.defaultFps}')),
                ListTile(title: const Text('言語'), trailing: Text(settings.language == 'ja' ? '日本語' : 'English')),
                const Divider(),
                // 描画領域初期値（仕様書26）
                const Text('描画領域初期値', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('新規プロジェクト作成時の初期値となります。',
                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('描画領域を広くする'),
                  value: enabled,
                  onChanged: (v) {
                    setS(() => enabled = v);
                    settings.setDefaultDrawingArea(enabled: v, scale: scale);
                  },
                ),
                if (enabled) ...[
                  Row(
                    children: [
                      const Text('倍率'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          min: 1.0, max: 10.0,
                          value: scale,
                          divisions: 18,
                          label: '${scale.toStringAsFixed(1)}倍',
                          onChanged: (v) {
                            setS(() => scale = v);
                            settings.setDefaultDrawingArea(enabled: enabled, scale: v);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${scale.toStringAsFixed(1)}倍', textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDetailSettings() {
    final settings = context.read<SettingsService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('詳細設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(title: const Text('Undo回数'), trailing: Text('${settings.undoLimit}')),
            const ListTile(title: Text('自動保存スロット数'), trailing: Text('3（固定）')),
            ListTile(title: const Text('ゴミ箱の自動削除'), trailing: Text(settings.trashAutoDeleteDays == 0 ? 'OFF' : '${settings.trashAutoDeleteDays}日')),
          ],
        ),
      ),
    );
  }
}
