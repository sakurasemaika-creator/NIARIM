import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _nameController = TextEditingController(text: '新規プロジェクト');
  int _fps = 12;
  int _durationSeconds = 10;
  Color _backgroundColor = Colors.white;
  // 書き出しサイズ（仕様書07・26：1920×1080/1280×720/3840×2160等から選択、
  // またはカスタムサイズを指定できる）。
  int _exportWidth = 1920;
  int _exportHeight = 1080;
  bool _customSize = false;
  late final TextEditingController _customWidthController;
  late final TextEditingController _customHeightController;
  // 描画領域設定（ホーム画面設定の初期値を引き継ぎ）
  bool _drawingAreaEnabled = false;
  double _drawingAreaScale = 2.0;

  static const List<int> fpsOptions = [8, 12, 24, 30];

  // 書き出しサイズプリセット（仕様書07・26：上限はFull HD相当。1:1・
  // アナログ放送比率・公開先メディアの比率別に用意する）。
  static const List<(int, int, String)> sizePresets = [
    (1920, 1080, 'Full HD (16:9・YouTube等横動画向け)'),
    (1280, 720, 'HD (16:9・軽量版)'),
    (1080, 1080, '1:1 スクエア (Twitter/Instagram投稿向け)'),
    (1080, 1920, '9:16 縦型 (YouTubeショート/リール・ストーリーズ向け)'),
    (1080, 1350, '4:5 縦長 (Instagramフィード投稿向け)'),
    (1440, 1080, '4:3 (アナログ放送比率)'),
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _fps = settings.defaultFps;
    _drawingAreaEnabled = settings.defaultDrawingAreaEnabled;
    _drawingAreaScale = settings.defaultDrawingAreaScale;
    _customWidthController = TextEditingController(text: '$_exportWidth');
    _customHeightController = TextEditingController(text: '$_exportHeight');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customWidthController.dispose();
    _customHeightController.dispose();
    super.dispose();
  }

  void _selectPreset(int width, int height) {
    setState(() {
      _customSize = false;
      _exportWidth = width;
      _exportHeight = height;
    });
  }

  // 上限はFull HD相当（長辺1920px）とする。
  static const int _maxCustomEdge = 1920;

  void _applyCustomSize() {
    final w = int.tryParse(_customWidthController.text);
    final h = int.tryParse(_customHeightController.text);
    if (w == null || h == null) return;
    setState(() {
      _exportWidth = w.clamp(64, _maxCustomEdge);
      _exportHeight = h.clamp(64, _maxCustomEdge);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規プロジェクト')),
      body: desktopCentered(
        context,
        SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'プロジェクト名', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            const Text('FPS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: fpsOptions.map((fps) => ChoiceChip(
                label: Text('$fps'),
                selected: _fps == fps,
                onSelected: (selected) { if (selected) setState(() => _fps = fps); },
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Text('サイズ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...sizePresets.map((preset) {
                  final (w, h, label) = preset;
                  final selected = !_customSize && _exportWidth == w && _exportHeight == h;
                  return ChoiceChip(
                    label: Text('$label ($w×$h)'),
                    selected: selected,
                    onSelected: (s) { if (s) _selectPreset(w, h); },
                  );
                }),
                ChoiceChip(
                  label: const Text('カスタム'),
                  selected: _customSize,
                  onSelected: (s) => setState(() => _customSize = s),
                ),
              ],
            ),
            if (_customSize) ...[
              const SizedBox(height: 8),
              Text('長辺は最大1920pxまで指定できます',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customWidthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '幅(px)', border: OutlineInputBorder()),
                      onChanged: (_) => _applyCustomSize(),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('×')),
                  Expanded(
                    child: TextField(
                      controller: _customHeightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '高さ(px)', border: OutlineInputBorder()),
                      onChanged: (_) => _applyCustomSize(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Text('長さ（秒）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 1, max: 60,
                    value: _durationSeconds.toDouble(),
                    divisions: 59,
                    label: '$_durationSeconds秒',
                    onChanged: (v) => setState(() => _durationSeconds = v.round()),
                  ),
                ),
                SizedBox(width: 60, child: Text('$_durationSeconds秒', textAlign: TextAlign.center)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('背景色', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [Colors.white, Colors.black, Colors.transparent, const Color(0xFFF5F5DC)].map((color) {
                final isSelected = _backgroundColor == color;
                final isLight = color == Colors.white ||
                    color == Colors.transparent ||
                    color == const Color(0xFFF5F5DC);
                return GestureDetector(
                  onTap: () => setState(() => _backgroundColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (color == Colors.transparent)
                          CustomPaint(size: const Size(40, 40), painter: _CheckerboardPainter())
                        else
                          Container(color: color),
                        if (isSelected)
                          Icon(Icons.check, size: 18, color: isLight ? Colors.black87 : Colors.white),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // 描画領域設定（仕様書26）
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('描画領域を広くする', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('書き出し範囲外にも描画できる領域を追加します'),
              value: _drawingAreaEnabled,
              onChanged: (v) => setState(() => _drawingAreaEnabled = v),
            ),
            if (_drawingAreaEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('倍率', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      min: 1.0, max: 10.0,
                      value: _drawingAreaScale,
                      divisions: 18, // 0.5刻み
                      label: '${_drawingAreaScale.toStringAsFixed(1)}倍',
                      onChanged: (v) => setState(() => _drawingAreaScale = v),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${_drawingAreaScale.toStringAsFixed(1)}倍', textAlign: TextAlign.center),
                  ),
                ],
              ),
              Text(
                '描画可能範囲: $_exportWidth×${_drawingAreaScale.toStringAsFixed(1)}倍 = ${(_exportWidth * _drawingAreaScale).round()}×${(_exportHeight * _drawingAreaScale).round()}',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('総フレーム数: ${_fps * _durationSeconds}'),
                    Text('書き出しサイズ: $_exportWidth×$_exportHeight'),
                    if (_drawingAreaEnabled)
                      Text('描画領域: ${(_exportWidth * _drawingAreaScale).round()}×${(_exportHeight * _drawingAreaScale).round()}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _createProject,
              icon: const Icon(Icons.add),
              label: const Text('作成'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _createProject() async {
    final projectService = context.read<ProjectService>();
    final project = await projectService.createProject(
      name: _nameController.text.trim().isEmpty ? '新規プロジェクト' : _nameController.text.trim(),
      fps: _fps,
      durationSeconds: _durationSeconds,
      backgroundColor: _backgroundColor.toARGB32(),
      exportWidth: _exportWidth,
      exportHeight: _exportHeight,
      drawingAreaScale: _drawingAreaEnabled ? _drawingAreaScale : 1.0,
    );
    if (mounted) context.go('/canvas/${project.id}');
  }
}

/// 「透明」背景色スウォッチ用の市松模様を描画する。
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 8.0;
    final light = Paint()..color = Colors.grey[300]!;
    final dark = Paint()..color = Colors.grey[400]!;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final isDark = ((x / cell).round() + (y / cell).round()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), isDark ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
