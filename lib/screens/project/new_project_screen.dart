import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/autofill_preset_selection_sheet.dart';
import '../../widgets/background_color_picker.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import 'canvas_size_preset_manage_screen.dart';
import '../../config/font_fallback.dart';

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _nameController = TextEditingController();
  // プロジェクト名の初期値はローカライズが必要なため、didChangeDependencies内で
  // 一度だけ設定する（initStateの時点ではAppLocalizationsの参照が確定しない）。
  bool _nameInitialized = false;
  int _fps = 12;
  int _durationSeconds = 10;
  Color _backgroundColor = Colors.white;
  // 書き出しサイズ（1920×1080/1280×720/3840×2160等から選択、
  // またはカスタムサイズを指定できる）。
  int _exportWidth = 1920;
  int _exportHeight = 1080;
  bool _customSize = false;
  late final TextEditingController _customWidthController;
  late final TextEditingController _customHeightController;
  // 描画領域設定（ホーム画面設定の初期値を引き継ぎ）
  bool _drawingAreaEnabled = false;
  double _drawingAreaScale = 2.0;
  // このプロジェクトで使う自動塗りプリセット。nullは
  // 「すべて使用する」を意味する。
  List<String>? _enabledPresetIds;
  // 長さ（秒）の数字入力欄（スライダーだけでなく
  // 数字入力でも指定できるようにする）。
  late final TextEditingController _durationController;

  // 30fpsは手描きアニメーションでは中割りの負担が大きく現実的でないため
  // 選択肢から除外している（基本設定画面のデフォルトFPS選択肢とも統一）。
  static const List<int> fpsOptions = [8, 12, 24];

  // 書き出しサイズプリセット（上限はFull HD相当。1:1・
  // アナログ放送比率・公開先メディアの比率別に用意する）。
  // 3つ目の要素は表示文言の内部キー（_presetLabelでl10nの文言に変換する）。
  static const List<(int, int, String)> sizePresets = [
    (1920, 1080, 'fullHd'),
    (1280, 720, 'hd'),
    (1080, 1080, 'square'),
    (1080, 1920, 'vertical'),
    (1080, 1350, 'portrait'),
    (1440, 1080, 'analog'),
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    // 基本設定側の保存値が旧仕様（廃止した30fps等）の場合に備え、選択肢に
    // 存在しない値は最も近い許容値へフォールバックする。
    _fps = fpsOptions.contains(settings.defaultFps)
        ? settings.defaultFps
        : fpsOptions.reduce(
            (a, b) =>
                (a - settings.defaultFps).abs() <
                    (b - settings.defaultFps).abs()
                ? a
                : b,
          );
    _drawingAreaEnabled = settings.defaultDrawingAreaEnabled;
    _drawingAreaScale = settings.defaultDrawingAreaScale;
    _customWidthController = TextEditingController(text: '$_exportWidth');
    _customHeightController = TextEditingController(text: '$_exportHeight');
    _durationController = TextEditingController(text: '$_durationSeconds');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInitialized) {
      _nameController.text = AppLocalizations.of(context)!
          .newProjectDefaultName;
      _nameInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customWidthController.dispose();
    _customHeightController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // サイズプリセットの表示文言をロケールに応じて取得する。
  String _presetLabel(AppLocalizations l10n, int width, int height) {
    for (final preset in sizePresets) {
      if (preset.$1 == width && preset.$2 == height) {
        switch (preset.$3) {
          case 'fullHd':
            return l10n.newProjectPresetFullHd;
          case 'hd':
            return l10n.newProjectPresetHd;
          case 'square':
            return l10n.newProjectPresetSquare;
          case 'vertical':
            return l10n.newProjectPresetVertical;
          case 'portrait':
            return l10n.newProjectPresetPortrait;
          case 'analog':
            return l10n.newProjectPresetAnalog;
        }
      }
    }
    return '';
  }

  void _selectPreset(int width, int height) {
    setState(() {
      _customSize = false;
      _exportWidth = width;
      _exportHeight = height;
    });
    // カスタムのテキスト欄・スライダーもプリセットの値へ同期しておく。
    // これをしないと、プリセット選択後に「カスタム」へ切り替えた際に
    // 直前の古い値が一瞬表示されてしまう（数値変更時の連動不備）。
    _customWidthController.text = '$width';
    _customHeightController.text = '$height';
  }

  // 長さ（秒）の表示用フォーマット。プレミアム会員は最大2時間まで
  // 選択できるため、60秒を超える場合は分/時間表記へ切り替える。
  static String _formatDuration(AppLocalizations l10n, int seconds) {
    if (seconds < 60) return l10n.newProjectDurationSeconds(seconds);
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      if (s > 0) return l10n.newProjectDurationHms(h, m, s);
      return m > 0
          ? l10n.newProjectDurationHm(h, m)
          : l10n.newProjectDurationH(h);
    }
    return s > 0
        ? l10n.newProjectDurationMs(m, s)
        : l10n.newProjectDurationM(m);
  }

  // 上限はFull HD相当（長辺1920px）とする。
  static const int _maxCustomEdge = 1920;

  /// カスタムサイズをスライダー・テキスト欄両方から一元的に反映する。
  /// テキスト欄の表示もここで同期し、スライダー操作とテキスト直接入力の
  /// どちらでも比率プレビューへ即座に反映されるようにする。
  void _setCustomSize({int? width, int? height}) {
    final w = (width ?? _exportWidth).clamp(64, _maxCustomEdge);
    final h = (height ?? _exportHeight).clamp(64, _maxCustomEdge);
    setState(() {
      _exportWidth = w;
      _exportHeight = h;
    });
    _customWidthController.text = '$w';
    _customHeightController.text = '$h';
  }

  void _applyCustomSize() {
    final w = int.tryParse(_customWidthController.text);
    final h = int.tryParse(_customHeightController.text);
    if (w == null || h == null) return;
    setState(() {
      _exportWidth = w.clamp(64, _maxCustomEdge);
      _exportHeight = h.clamp(64, _maxCustomEdge);
    });
  }

  /// 現在のカスタムサイズに名前を付けて保存し、以降はサイズ一覧の
  /// プリセットとして選択できるようにする。
  void _showSaveCustomSizeDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newProjectSaveCustomSizeDialogTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.newProjectSaveCustomSizeNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<SettingsService>().addCustomSizePreset(
                  nameCtrl.text,
                  _exportWidth,
                  _exportHeight,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.newProjectSaveCustomSizeSavedSnackbar),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ).then(
      (_) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => nameCtrl.dispose(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newProjectScreenTitle),
        actions: const [HelpButton(topic: '新規プロジェクト作成')],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.newProjectNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'FPS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: fpsOptions
                    .map(
                      (fps) => ChoiceChip(
                        label: Text('$fps'),
                        selected: _fps == fps,
                        onSelected: (selected) {
                          if (selected) setState(() => _fps = fps);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    l10n.newProjectSizeLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      adMockMaterialPageRoute(
                        builder: (_) => const CanvasSizePresetManageScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(l10n.newProjectSizePresetManageButton),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer<SettingsService>(
                builder: (context, settings, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    // ChoiceChipはWrap内で自身の自然幅を要求するため、長い
                    // ローカライズ文言（特に9:16縦型）が狭いスマホ幅より長いと
                    // 例外を出さず画面端で文字だけ不自然に切れる。各チップを
                    // 親幅以下へ制約し、最大2行+ellipsisで情報を保ちながら収める。
                    final maxChipWidth = constraints.maxWidth;

                    Widget sizeChip({
                      required String text,
                      required bool selected,
                      required VoidCallback onSelected,
                    }) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxChipWidth),
                        child: ChoiceChip(
                          label: Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          selected: selected,
                          onSelected: (s) {
                            if (s) onSelected();
                          },
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...sizePresets.map((preset) {
                          final (w, h, _) = preset;
                          final label = _presetLabel(l10n, w, h);
                          final selected =
                              !_customSize &&
                              _exportWidth == w &&
                              _exportHeight == h;
                          return sizeChip(
                            text: '$label ($w×$h)',
                            selected: selected,
                            onSelected: () => _selectPreset(w, h),
                          );
                        }),
                        ...settings.customSizePresets.map((preset) {
                          final selected =
                              !_customSize &&
                              _exportWidth == preset.width &&
                              _exportHeight == preset.height;
                          return sizeChip(
                            text:
                                '${preset.name} (${preset.width}×${preset.height})',
                            selected: selected,
                            onSelected: () =>
                                _selectPreset(preset.width, preset.height),
                          );
                        }),
                        ChoiceChip(
                          label: Text(l10n.newProjectCustomSize),
                          selected: _customSize,
                          onSelected: (s) => setState(() => _customSize = s),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_customSize) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.newProjectMaxEdgeHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customWidthController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.newProjectWidthLabel,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => _applyCustomSize(),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('×'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _customHeightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.newProjectHeightLabel,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => _applyCustomSize(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        l10n.newProjectWidthShort,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: SteppedSlider(
                        min: 64,
                        max: _maxCustomEdge.toDouble(),
                        value: _exportWidth
                            .clamp(64, _maxCustomEdge)
                            .toDouble(),
                        label: '${_exportWidth}px',
                        onChanged: (v) => _setCustomSize(width: v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: EditableSliderValue(
                        text: '${_exportWidth}px',
                        textAlign: TextAlign.center,
                        value: _exportWidth,
                        min: 64,
                        max: _maxCustomEdge,
                        onChanged: (v) => _setCustomSize(width: v.round()),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        l10n.newProjectHeightShort,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: SteppedSlider(
                        min: 64,
                        max: _maxCustomEdge.toDouble(),
                        value: _exportHeight
                            .clamp(64, _maxCustomEdge)
                            .toDouble(),
                        label: '${_exportHeight}px',
                        onChanged: (v) => _setCustomSize(height: v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: EditableSliderValue(
                        text: '${_exportHeight}px',
                        textAlign: TextAlign.center,
                        value: _exportHeight,
                        min: 64,
                        max: _maxCustomEdge,
                        onChanged: (v) => _setCustomSize(height: v.round()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _showSaveCustomSizeDialog,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.newProjectSaveCustomSizeButton),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 比率プレビュー：プリセットタップ・カスタム数値変更のどちらでも
              // 即座に連動する。
              Center(
                child: SizedBox(
                  height: 90,
                  child: AspectRatio(
                    aspectRatio: _exportWidth / _exportHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '$_exportWidth×$_exportHeight',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  // 長さの上限：無料会員は最大90秒、プレミアム会員は
                  // 最大2時間（7200秒）。
                  final isPremium = context.watch<PremiumService>().isPremium;
                  final maxDuration = isPremium ? 7200 : 90;
                  if (_durationSeconds > maxDuration) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _durationSeconds = maxDuration);
                        _durationController.text = '$maxDuration';
                      }
                    });
                  }
                  final maxDurationText = _formatDuration(l10n, maxDuration);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium
                            ? l10n.newProjectDurationLabel(maxDurationText)
                            : l10n.newProjectDurationLabelWithPremiumHint(
                                maxDurationText,
                              ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SteppedSlider(
                              min: 1,
                              max: maxDuration.toDouble(),
                              value: _durationSeconds
                                  .clamp(1, maxDuration)
                                  .toDouble(),
                              divisions: maxDuration - 1,
                              label: _formatDuration(l10n, _durationSeconds),
                              onChanged: (v) => setState(() {
                                _durationSeconds = v.round();
                                _durationController.text = '$_durationSeconds';
                              }),
                            ),
                          ),
                          // 数字入力欄（秒単位。スライダーだけでなく
                          // 数字入力でも長さを指定できるようにする）。プレミアム会員は
                          // 最大7200（4桁）まで入力できるため、幅は「秒」の
                          // 接尾辞込みで4桁の数字がすべて見える広さを確保する
                          // （以前は64pxで、4桁の数字が入ると欄内で見切れて
                          // 実際の値と表示が食い違って見えることがあった）。
                          SizedBox(
                            width: 88,
                            child: TextField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                isDense: true,
                                suffixText: '秒',
                              ),
                              onChanged: (v) {
                                final parsed = int.tryParse(v);
                                if (parsed == null) return;
                                setState(
                                  () => _durationSeconds = parsed.clamp(
                                    1,
                                    maxDuration,
                                  ),
                                );
                              },
                              onSubmitted: (_) => setState(
                                () => _durationController.text =
                                    '$_durationSeconds',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(l10n, _durationSeconds),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                l10n.newProjectBackgroundColorLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              const SizedBox(height: 8),
              BackgroundColorSwatchPicker(
                selectedColor: _backgroundColor,
                onChanged: (color) => setState(() => _backgroundColor = color),
              ),
              const SizedBox(height: 24),
              // 描画領域設定
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.newProjectDrawingAreaTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                subtitle: Text(l10n.newProjectDrawingAreaSubtitle),
                value: _drawingAreaEnabled,
                onChanged: (v) => setState(() => _drawingAreaEnabled = v),
              ),
              if (_drawingAreaEnabled) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      l10n.newProjectScaleLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SteppedSlider(
                        min: 1.0,
                        max: 10.0,
                        value: _drawingAreaScale,
                        divisions: 18, // 0.5刻み
                        step: 0.5,
                        label: l10n.newProjectScaleValue(
                          _drawingAreaScale.toStringAsFixed(1),
                        ),
                        onChanged: (v) => setState(() => _drawingAreaScale = v),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: EditableSliderValue(
                        text: l10n.newProjectScaleValue(
                          _drawingAreaScale.toStringAsFixed(1),
                        ),
                        textAlign: TextAlign.center,
                        value: _drawingAreaScale,
                        min: 1.0,
                        max: 10.0,
                        isInt: false,
                        onChanged: (v) =>
                            setState(() => _drawingAreaScale = v.toDouble()),
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.newProjectDrawableAreaInfo(
                    '$_exportWidth',
                    l10n.newProjectScaleValue(
                      _drawingAreaScale.toStringAsFixed(1),
                    ),
                    '${(_exportWidth * _drawingAreaScale).round()}×${(_exportHeight * _drawingAreaScale).round()}',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // このプロジェクトで使う自動塗りプリセットの選択。
              // 新規作成時にも選べるようにする。
              OutlinedButton.icon(
                onPressed: () async {
                  final allPresets = context
                      .read<AutofillPresetService>()
                      .presets;
                  final result = await showAutofillPresetSelectionSheet(
                    context,
                    allPresets: allPresets,
                    initiallyEnabledIds: _enabledPresetIds?.toSet(),
                  );
                  if (!result.cancelled) {
                    setState(() => _enabledPresetIds = result.ids);
                  }
                },
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text(
                  _enabledPresetIds == null
                      ? l10n.autofillPresetSelectionButton
                      : l10n.autofillPresetSelectionCountLabel(
                          _enabledPresetIds!.length,
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.newProjectTotalFrames(_fps * _durationSeconds)),
                      Text(
                        l10n.newProjectExportSizeInfo(
                          '$_exportWidth×$_exportHeight',
                        ),
                      ),
                      if (_drawingAreaEnabled)
                        Text(
                          l10n.newProjectDrawingAreaInfo(
                            '${(_exportWidth * _drawingAreaScale).round()}×${(_exportHeight * _drawingAreaScale).round()}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _createProject,
                icon: const Icon(Icons.add),
                label: Text(l10n.commonCreate),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    final projectService = context.read<ProjectService>();
    final defaultName = AppLocalizations.of(context)!.newProjectDefaultName;
    final project = await projectService.createProject(
      name: _nameController.text.trim().isEmpty
          ? defaultName
          : _nameController.text.trim(),
      fps: _fps,
      durationSeconds: _durationSeconds,
      backgroundColor: _backgroundColor.toARGB32(),
      exportWidth: _exportWidth,
      exportHeight: _exportHeight,
      drawingAreaScale: _drawingAreaEnabled ? _drawingAreaScale : 1.0,
      enabledAutofillPresetIds: _enabledPresetIds,
    );
    if (mounted) context.go('/canvas/${project.id}');
  }
}
