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
  final int _exportWidth = 1920;
  final int _exportHeight = 1080;
  // 描画領域設定（ホーム画面設定の初期値を引き継ぎ）
  bool _drawingAreaEnabled = false;
  double _drawingAreaScale = 2.0;

  static const List<int> fpsOptions = [8, 12, 24, 30];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _fps = settings.defaultFps;
    _drawingAreaEnabled = settings.defaultDrawingAreaEnabled;
    _drawingAreaScale = settings.defaultDrawingAreaScale;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
              spacing: 8,
              children: [Colors.white, Colors.black, Colors.transparent, const Color(0xFFF5F5DC)].map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _backgroundColor = color),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: _backgroundColor == color ? Theme.of(context).colorScheme.primary : Colors.grey,
                        width: _backgroundColor == color ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
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
                style: const TextStyle(fontSize: 11, color: Colors.grey),
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
