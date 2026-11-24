import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/accent_text_theme.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/canvas_size_preset.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/autofill_preset_selection_sheet.dart';
import '../../widgets/background_color_picker.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/frame_preview_background.dart';
import '../../widgets/name_entry_dialog.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import 'canvas_size_preset_manage_screen.dart';
import 'widgets/canvas_size_fields.dart';
import '../canvas/widgets/canvas_icon_button.dart';
import '../../config/font_fallback.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/grouped_sheet.dart';
import '../../widgets/icon_notice.dart';
import 'widgets/canvas_size_choice_label.dart';
import '../../widgets/keep_together_text.dart';

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
  bool _creating = false;
  bool _creationFailed = false;
  int _fps = 12;
  int _durationSeconds = 10;
  Color _backgroundColor = Colors.white;
  // 書き出しサイズ（1920×1080/1280×720/3840×2160等から選択、
  // またはカスタムサイズを指定できる）。
  int _exportWidth = 1920;
  int _exportHeight = 1080;
  bool _customSize = false;
  // 選んでいるサイズのチップ（組み込みは「builtin:種類」、保存したサイズは
  // 「custom:ID」）。大きさで比べると、組み込みと同じ大きさで保存したサイズの
  // チップも一緒に選ばれた表示になった。
  String? _selectedPresetKey = 'builtin:fullHd';
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
  // 数字の欄から出たら、実際に使う値（範囲に収めた値）を欄へ書き戻す。
  // 書き戻さないと、5000と打った欄が1920で作られるのに5000のまま見えた。
  final _widthFocus = FocusNode();
  final _heightFocus = FocusNode();
  final _durationFocus = FocusNode();

  /// 数字の欄に打てるのは4桁までの数字だけ。
  static final _numberInput = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

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
    for (final focus in [_widthFocus, _heightFocus, _durationFocus]) {
      focus.addListener(() {
        if (!focus.hasFocus) _commitNumberFields();
      });
    }
  }

  /// 数字の欄の表示を、実際に使う幅・高さ・長さにそろえる。
  void _commitNumberFields() {
    if (!mounted) return;
    setState(() {
      _customWidthController.text = '$_exportWidth';
      _customHeightController.text = '$_exportHeight';
      _durationController.text = '$_durationSeconds';
    });
  }

  /// 欄の数字が[min]〜[max]に収まっていなければ、その旨の文。
  String? _rangeError(
    AppLocalizations l10n,
    TextEditingController controller,
    int min,
    int max,
  ) {
    final value = int.tryParse(controller.text);
    if (value != null && value >= min && value <= max) return null;
    return l10n.newProjectNumberRangeError(min, max);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInitialized) {
      _nameController.text = AppLocalizations.of(
        context,
      )!.newProjectDefaultName;
      _nameInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customWidthController.dispose();
    _customHeightController.dispose();
    _durationController.dispose();
    _widthFocus.dispose();
    _heightFocus.dispose();
    _durationFocus.dispose();
    super.dispose();
  }

  /// 「項目名（説明）」の文を、見出しの項目名と、下に小さく出す説明に分けて
  /// 描く（括弧の無い文はそのまま見出し）。
  Widget _headingWithNote(BuildContext context, String text) {
    final parts = RegExp(r'^(.*?)\s*[（(](.*)[）)]$').firstMatch(text);
    final heading = localizedHeadingStyle(
      context,
      const TextStyle(fontWeight: FontWeight.bold),
    );
    if (parts == null) return Text(text, style: heading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(parts.group(1)!, style: heading),
        const SizedBox(height: 2),
        messageText(
          parts.group(2)!,
          keepLineStarts: true,
          keepLastPhrase: true,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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

  void _selectPreset(int width, int height, String key) {
    // 以前の版で範囲外のサイズを保存できたので、選んだときも範囲に収める。
    width = clampCanvasEdge(width);
    height = clampCanvasEdge(height);
    setState(() {
      _customSize = false;
      _selectedPresetKey = key;
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

  /// 選んでいる保存したサイズが「サイズ設定」で変わった・消えたときに追う。
  /// 変わったらその大きさにし、消えたら今の大きさのままカスタムにする
  /// （チップの表示と作る大きさを食い違わせない）。
  void _followChosenPreset(SettingsService settings) {
    final key = _selectedPresetKey;
    if (_customSize || key == null || !key.startsWith('custom:')) return;
    final chosen = settings.customSizePresets
        .where((p) => key == 'custom:${p.id}')
        .firstOrNull;
    if (chosen != null &&
        clampCanvasEdge(chosen.width) == _exportWidth &&
        clampCanvasEdge(chosen.height) == _exportHeight) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedPresetKey != key) return;
      if (chosen != null) {
        _selectPreset(chosen.width, chosen.height, key);
      } else {
        setState(() {
          _customSize = true;
          _selectedPresetKey = null;
          _customWidthController.text = '$_exportWidth';
          _customHeightController.text = '$_exportHeight';
        });
      }
    });
  }

  /// カスタムサイズをスライダー・テキスト欄両方から一元的に反映する。
  /// テキスト欄の表示もここで同期し、スライダー操作とテキスト直接入力の
  /// どちらでも比率プレビューへ即座に反映されるようにする。
  void _setCustomSize({int? width, int? height}) {
    final w = (width ?? _exportWidth).clamp(kMinCanvasEdge, kMaxCanvasEdge);
    final h = (height ?? _exportHeight).clamp(kMinCanvasEdge, kMaxCanvasEdge);
    setState(() {
      _exportWidth = w;
      _exportHeight = h;
    });
    _customWidthController.text = '$w';
    _customHeightController.text = '$h';
  }

  /// 打った数字を範囲に収めて使う（数字が無ければ前の値のまま）。欄の
  /// 表示は打ったままにして範囲の文を出し、欄から出たときにそろえる。
  void _applyCustomSize() {
    final w = int.tryParse(_customWidthController.text);
    final h = int.tryParse(_customHeightController.text);
    setState(() {
      if (w != null) _exportWidth = w.clamp(kMinCanvasEdge, kMaxCanvasEdge);
      if (h != null) _exportHeight = h.clamp(kMinCanvasEdge, kMaxCanvasEdge);
    });
  }

  /// 現在のカスタムサイズに名前を付けて保存し、以降はサイズ一覧の
  /// プリセットとして選択できるようにする。空白だけの名前では保存しない。
  void _showSaveCustomSizeDialog() {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsService>();
    final messenger = ScaffoldMessenger.of(context);
    final width = _exportWidth;
    final height = _exportHeight;
    showDialog(
      context: context,
      builder: (ctx) => NameEntryDialog(
        title: l10n.newProjectSaveCustomSizeDialogTitle,
        labelText: l10n.newProjectSaveCustomSizeNameLabel,
        confirmLabel: l10n.commonSave,
        cancelLabel: l10n.commonCancel,
        onSubmit: (name) async {
          await settings.addCustomSizePreset(name, width, height);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.newProjectSaveCustomSizeSavedSnackbar)),
          );
        },
      ),
    );
  }

  Widget _customDimensionField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required FocusNode focus,
  }) {
    final error = _rangeError(
      AppLocalizations.of(context)!,
      controller,
      kMinCanvasEdge,
      kMaxCanvasEdge,
    );
    return TextField(
      controller: controller,
      focusNode: focus,
      keyboardType: TextInputType.number,
      inputFormatters: _numberInput,
      decoration: InputDecoration(
        label: Text(label),
        border: const OutlineInputBorder(),
        error: error == null ? null : Text(error),
      ),
      onChanged: (_) => _applyCustomSize(),
      onSubmitted: (_) => _commitNumberFields(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Narrow phones benefit from slightly tighter section rhythm without
    // changing the established spacing on regular phones, tablets, or desktop.
    final sectionSpacing = MediaQuery.sizeOf(context).width < 360 ? 20.0 : 24.0;
    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.newProjectScreenTitle),
        actions: const [HelpButton(topic: '新規プロジェクト作成')],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
              SizedBox(
                key: const ValueKey('new-project-section-gap-1'),
                height: sectionSpacing,
              ),
              Text(
                'FPS',
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
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
              // 上のFPSのチップの押せる所（48px）の下の空き（8px）と、
              // 「サイズ設定」のボタンの高さ（48px）に合わせて見出しの上に
              // できる空きのぶん詰める。詰めないと、見えている間がほかの
              // 区切り（名前の欄→FPS）の約2倍（51px）に開いた。
              SizedBox(
                key: const ValueKey('new-project-section-gap-2'),
                height: sectionSpacing - 16,
              ),
              // 見出しと「サイズ設定」が1行に入らなければ、ボタンを次の行へ
              // （Rowに並べていた頃は、英・西・仏語の大きな文字ではみ出した）。
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.newProjectSizeLabel,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      adMockMaterialPageRoute(
                        builder: (_) => const CanvasSizePresetManageScreen(),
                      ),
                    ),
                    icon: Icon(
                      Icons.tune,
                      size: 18,
                      shadows: CanvasIconButton.actionShadows(
                        AccentTextTheme.of(context),
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).colorScheme,
                      ),
                    ),
                    label: Text(
                      l10n.newProjectSizePresetManageButton,
                      style: TextStyle(
                        shadows: CanvasIconButton.actionShadows(
                          AccentTextTheme.of(context),
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 大きさは1枚の面に行を並べ、選んでいる行は先頭の丸い印
              // （選択の色）で示す。以前は選んだ行を差し色で塗りつぶした
              // ピルにし、ほかの行も1つずつ浮いたカードだったので、画面で
              // いちばん強い色の塊になり、行どうしのまとまりも読めなかった。
              // 名前が欄に入らないときは行を増やして全部出す（「…」で
              // 切らない）。
              Consumer<SettingsService>(
                builder: (context, settings, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    // 行の左右の余白・印・印と名前の間を引いた名前の欄の幅。
                    final labelMaxWidth = math.max(
                      0.0,
                      constraints.maxWidth -
                          CanvasSizeOptionRow.leadingWidth -
                          GroupedSheet.rowInset,
                    );

                    Widget sizeRow({
                      required String text,
                      required int width,
                      required int height,
                      required bool selected,
                      required VoidCallback onSelected,
                    }) => CanvasSizeOptionRow(
                      selected: selected,
                      onSelected: onSelected,
                      child: CanvasSizeChoiceLabel(
                        text: text,
                        canvasWidth: width,
                        canvasHeight: height,
                        width: labelMaxWidth,
                      ),
                    );

                    _followChosenPreset(settings);
                    return GroupedSheet(
                      children: [
                        ...sizePresets.map((preset) {
                          final (w, h, kind) = preset;
                          final label = _presetLabel(l10n, w, h);
                          final key = 'builtin:$kind';
                          return sizeRow(
                            text: label,
                            width: w,
                            height: h,
                            selected: !_customSize && _selectedPresetKey == key,
                            onSelected: () => _selectPreset(w, h, key),
                          );
                        }),
                        ...settings.customSizePresets.map((preset) {
                          final key = 'custom:${preset.id}';
                          return sizeRow(
                            text: preset.name,
                            width: preset.width,
                            height: preset.height,
                            selected: !_customSize && _selectedPresetKey == key,
                            onSelected: () =>
                                _selectPreset(preset.width, preset.height, key),
                          );
                        }),
                        CanvasSizeOptionRow(
                          selected: _customSize,
                          onSelected: () => setState(() {
                            if (_customSize) return;
                            _customSize = true;
                            // 欄とスライダーは今の大きさから始める。
                            _selectedPresetKey = null;
                            _customWidthController.text = '$_exportWidth';
                            _customHeightController.text = '$_exportHeight';
                          }),
                          child: SizedBox(
                            width: labelMaxWidth,
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 22,
                                  child: Icon(Icons.aspect_ratio, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    l10n.newProjectCustomSize,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) => CanvasSizeFields(
                    availableWidth: constraints.maxWidth,
                    separator: const Padding(
                      padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
                      child: Text('×'),
                    ),
                    widthField: _customDimensionField(
                      context,
                      label: l10n.newProjectWidthLabel,
                      controller: _customWidthController,
                      focus: _widthFocus,
                    ),
                    heightField: _customDimensionField(
                      context,
                      label: l10n.newProjectHeightLabel,
                      controller: _customHeightController,
                      focus: _heightFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledSlider(
                  label: l10n.newProjectWidthShort,
                  min: kMinCanvasEdge.toDouble(),
                  max: kMaxCanvasEdge.toDouble(),
                  value: _exportWidth
                      .clamp(kMinCanvasEdge, kMaxCanvasEdge)
                      .toDouble(),
                  sliderLabel: '${_exportWidth}px',
                  valueText: '${_exportWidth}px',
                  onChanged: (v) => _setCustomSize(width: v.round()),
                ),
                LabeledSlider(
                  label: l10n.newProjectHeightShort,
                  min: kMinCanvasEdge.toDouble(),
                  max: kMaxCanvasEdge.toDouble(),
                  value: _exportHeight
                      .clamp(kMinCanvasEdge, kMaxCanvasEdge)
                      .toDouble(),
                  sliderLabel: '${_exportHeight}px',
                  valueText: '${_exportHeight}px',
                  onChanged: (v) => _setCustomSize(height: v.round()),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _showSaveCustomSizeDialog,
                    icon: Icon(
                      Icons.save_outlined,
                      size: 18,
                      shadows: CanvasIconButton.actionShadows(
                        AccentTextTheme.of(context),
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).colorScheme,
                      ),
                    ),
                    label: Text(
                      l10n.newProjectSaveCustomSizeButton,
                      style: TextStyle(
                        shadows: CanvasIconButton.actionShadows(
                          AccentTextTheme.of(context),
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 比率プレビュー：プリセットタップ・カスタム数値変更のどちらでも
              // 即座に連動する。
              SizedBox(
                height: 112,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _exportWidth / _exportHeight,
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: FramePreviewBackground(
                        backgroundColor: _backgroundColor.toARGB32(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                label: l10n.newProjectExportSizeInfo(
                  '$_exportWidth×$_exportHeight',
                ),
                excludeSemantics: true,
                child: Text(
                  '$_exportWidth×$_exportHeight',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              SizedBox(
                key: const ValueKey('new-project-section-gap-3'),
                height: sectionSpacing,
              ),
              Builder(
                builder: (context) {
                  // 長さの上限：無料会員は最大90秒、プレミアム会員は
                  // 最大2時間（7200秒）。
                  final premium = context.watch<PremiumService>();
                  final hasLongDuration = premium.isFeatureAvailable(
                    PremiumFeature.unlimitedDuration,
                  );
                  final maxDuration = premium.maxProjectDurationSeconds;
                  if (_durationSeconds > maxDuration) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _durationSeconds = maxDuration);
                        _durationController.text = '$maxDuration';
                      }
                    });
                  }
                  final maxDurationText = _formatDuration(l10n, maxDuration);
                  final durationError = _rangeError(
                    l10n,
                    _durationController,
                    1,
                    maxDuration,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1行目：項目名と数字入力欄、2行目：スライダーだけで
                      // 横幅いっぱいを使う。
                      Row(
                        children: [
                          // 項目名は見出し、括弧の中の上限の説明は下に小さく
                          // （1つの見出しのまま太字で2行に折れ、項目名と説明の
                          // 区別が付かなかった）。
                          Expanded(
                            child: _headingWithNote(
                              context,
                              hasLongDuration
                                  ? l10n.newProjectDurationLabel(
                                      maxDurationText,
                                    )
                                  : l10n.newProjectDurationLabelWithPremiumHint(
                                      maxDurationText,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              focusNode: _durationFocus,
                              keyboardType: TextInputType.number,
                              inputFormatters: _numberInput,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                suffixText: l10n.newProjectDurationUnit,
                                // 欄が狭いので、範囲の文は欄の下の行に出す。
                                error: durationError == null
                                    ? null
                                    : const SizedBox.shrink(),
                              ),
                              onChanged: (v) {
                                final parsed = int.tryParse(v);
                                setState(() {
                                  if (parsed != null) {
                                    _durationSeconds = parsed.clamp(
                                      1,
                                      maxDuration,
                                    );
                                  }
                                });
                              },
                              onSubmitted: (_) => _commitNumberFields(),
                            ),
                          ),
                        ],
                      ),
                      if (durationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconNotice(durationError, fontSize: 12),
                        ),
                      const SizedBox(height: 4),
                      SteppedSlider(
                        min: 1,
                        max: maxDuration.toDouble(),
                        value: _durationSeconds
                            .clamp(1, maxDuration)
                            .toDouble(),
                        divisions: maxDuration - 1,
                        compact: true,
                        label: _formatDuration(l10n, _durationSeconds),
                        onChanged: (v) => setState(() {
                          _durationSeconds = v.round();
                          _durationController.text = '$_durationSeconds';
                        }),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(l10n, _durationSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(
                key: const ValueKey('new-project-section-gap-4'),
                height: sectionSpacing,
              ),
              Text(
                l10n.newProjectBackgroundColorLabel,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              BackgroundColorSwatchPicker(
                selectedColor: _backgroundColor,
                onChanged: (color) => setState(() => _backgroundColor = color),
              ),
              SizedBox(
                key: const ValueKey('new-project-section-gap-5'),
                height: sectionSpacing,
              ),
              // 描画領域と自動塗りは、作る前に決められる追加の設定として
              // 1枚の面にまとめる（以前は切り替えが用紙の上に、自動塗りが
              // 全幅の枠のボタンとして別々に置かれ、「作成」と同じ重さの
              // ボタンが続いていた）。
              GroupedSheet(
                children: [
                  // 描画領域設定
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: GroupedSheet.rowInset,
                      vertical: 4,
                    ),
                    title: Text(
                      l10n.newProjectDrawingAreaTitle,
                      style: localizedHeadingStyle(
                        context,
                        const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    subtitle: Text(l10n.newProjectDrawingAreaSubtitle),
                    value: _drawingAreaEnabled,
                    onChanged: (v) => setState(() => _drawingAreaEnabled = v),
                  ),
                  if (_drawingAreaEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        GroupedSheet.rowInset,
                        8,
                        GroupedSheet.rowInset,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LabeledSlider(
                            label: l10n.newProjectScaleLabel,
                            labelStyle: localizedHeadingStyle(
                              context,
                              const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            min: 1.0,
                            max: 10.0,
                            value: _drawingAreaScale,
                            divisions: 18, // 0.5刻み
                            step: 0.5,
                            isInt: false,
                            sliderLabel: l10n.newProjectScaleValue(
                              _drawingAreaScale.toStringAsFixed(1),
                            ),
                            valueText: l10n.newProjectScaleValue(
                              _drawingAreaScale.toStringAsFixed(1),
                            ),
                            onChanged: (v) =>
                                setState(() => _drawingAreaScale = v),
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
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // このプロジェクトで使う自動塗りプリセットの選択。
                  // 新規作成時にも選べるようにする。
                  SheetRow(
                    key: const Key('newProjectAutofillRow'),
                    icon: Icons.auto_fix_high_outlined,
                    title: _enabledPresetIds == null
                        ? l10n.autofillPresetSelectionButton
                        : l10n.autofillPresetSelectionCountLabel(
                            _enabledPresetIds!.length,
                          ),
                    onTap: () async {
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
                  ),
                ],
              ),
              SizedBox(
                key: const ValueKey('new-project-section-gap-6'),
                height: sectionSpacing,
              ),
              // 作る作品のまとめ。上の設定と同じ面（上下のボタンと同じ幅）。
              GroupedSheet(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.newProjectTotalFrames(_fps * _durationSeconds),
                        ),
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
                ],
              ),
              const SizedBox(height: 32),
              if (_creationFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconNotice(
                    l10n.newProjectCreateFailed,
                    liveRegion: true,
                  ),
                ),
              FilledButton.icon(
                onPressed: _creating ? null : _createProject,
                icon: _creating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _creating ? l10n.newProjectCreating : l10n.commonCreate,
                ),
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
    if (_creating) return;
    // 作るのは欄に見えている値（範囲に収めた値）にそろえてから。
    final maxDuration = context
        .read<PremiumService>()
        .maxProjectDurationSeconds;
    _durationSeconds = _durationSeconds.clamp(1, maxDuration);
    _commitNumberFields();
    setState(() {
      _creating = true;
      _creationFailed = false;
    });
    final projectService = context.read<ProjectService>();
    final l10n = AppLocalizations.of(context)!;
    final defaultName = l10n.newProjectDefaultName;
    try {
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
      // 作れたら作成中のまま（押せない）にしておく。戻すと、キャンバスを
      // 描く前に届いたダブルクリックの2回目で、もう1つ作品ができた。
      if (mounted) context.go('/canvas/${project.id}');
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _creating = false;
        _creationFailed = true;
      });
    }
  }
}
