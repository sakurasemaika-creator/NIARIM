import 'package:niarim/services/theme_service.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/material_service.dart';
import '../../services/project_service.dart';
import '../../services/storage_info_service.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import '../../widgets/project_trash_dialog.dart';
import '../../config/font_fallback.dart';

/// 容量削減画面（ホーム画面ハンバーガーメニューから遷移）。
/// 端末容量に対するNIARIMの使用量・NIARIM内部のデータ内訳を2つの円
/// グラフで可視化し、キャッシュ削除・未使用素材の一括削除（全プロジェクト
/// 横断）・ゴミ箱を空にする・プロジェクト整理（作品一覧への案内）・
/// 全データ削除（初期化）の各操作を提供する。
/// テーマから、6分類ぶんの**互いに区別できる**色を作る。
///
/// 以前は`Theme.of(context).colorScheme`と`ThemeService.activeColorScheme`
/// の両方から色を取っていたが、この2つは同じインスタンス（`themeData`の
/// getterが代入している）なので、6色のうち2組が**まったく同じ色**に
/// なっていた。実際に「プロジェクトデータ」と「キャッシュ」が同じ色で
/// 描かれ、円グラフも凡例もどちらがどちらか分からなかった
/// （`build/all-route-screenshots/32_storage.png`で発覚）。
///
/// さらにこのアプリのテーマは**primaryとsecondaryが同じ色**で、
/// `ColorScheme`の役割をそのまま並べても区別できる6色にはならない。
/// アクセント色の**色相と彩度を固定**し、明るい固定明度6色を作る。
/// 旧4〜6色目を先頭3色とし、さらに明るい3色を加える。
/// 旧明度の0.085刻みをそのまま9色目まで延長するとL>1になるため、
/// 後半3段階だけ幅を緩め、明度100%超過・真っ白への潰れを防ぐ。
/// `test/storage_chart_colors_test.dart`が組み込み28テーマ全てで検証する。
/// 各カテゴリの明度はテーマの明度から独立した固定値（HSLのL）。
/// 色相と彩度だけを現在のアクセントから取得する。
const storageChartLightnessLevels = <double>[
  0.615, // former 4th tone
  0.70, // former 5th tone
  0.785, // former 6th tone
  0.85, // new 7th tone
  0.915, // new 8th tone
  0.98, // new 9th tone: below pure white
];

List<Color> sliceColorsOf(ColorScheme scheme) {
  final accent = HSLColor.fromColor(scheme.primary);
  return [
    for (final lightness in storageChartLightnessLevels)
      accent.withLightness(lightness).toColor(),
  ];
}

/// Device chart uses the same accent saturation and fixed lightness levels
/// as NIARIM's six categories. Only the hue is rotated slightly so the two
/// charts are visually related without being identical.
const double storageDeviceHueShiftDegrees = 18.0;

List<Color> storageDeviceSliceColorsOf(ColorScheme scheme) {
  final accent = HSLColor.fromColor(scheme.primary);
  final deviceHue = (accent.hue + storageDeviceHueShiftDegrees) % 360;
  return [
    for (final lightness in storageChartLightnessLevels.take(3))
      accent.withHue(deviceHue).withLightness(lightness).toColor(),
  ];
}

/// 端末・NIARIMとも同じ1行34px＋上下4pxの棒グラフだけを使う。
/// 再取得中も行領域を確保し、操作の位置が不用意に跳ねないようにする。
const double _barRowExtent = 42;

/// 端末の容量のグラフに並ぶ棒の本数（NIARIM・ほかのアプリ・空き）。
const int _deviceBarCount = 3;

/// 棒のみ表示する領域。widthは既存のレイアウト呼び元と互換にする。
double _breakdownChartHeight(int bars, double width) => bars * _barRowExtent;

/// 端末の容量の問い合わせを待つ長さ。過ぎても答えが無ければ、その欄だけ
/// 「取得できませんでした」にして、やり直せるようにする（内訳と操作は
/// 待たせない）。
@visibleForTesting
const storageDeviceSpaceTimeout = Duration(seconds: 4);

/// 画面は「端末の容量」「NIARIMの内訳」「整理する」の3つの欄からなり、
/// 欄ごとに別々に読み込む・失敗する。操作の欄は読み込みを待たずにいつも出す。
/// 以前は1つの読み込み中フラグで本文全体を隠していたので、集計が遅い・
/// 失敗した・端末の容量の問い合わせが返らないと、操作まで使えなかった。
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key, this.service});

  /// 集計の進み方をテストで決めるための差し替え口。
  @visibleForTesting
  final StorageInfoService? service;

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late final StorageInfoService _service =
      widget.service ?? StorageInfoService();

  // ── NIARIMの内訳 ──
  /// 直近に集計できた内訳。
  StorageBreakdown? _breakdown;
  bool _scanning = false;

  /// 直近に終わった集計が失敗した。やり直している間も、結果が届くまで
  /// そのままにする（知らせとやり直しのボタンを、その場に残すため）。
  bool _breakdownFailed = false;

  /// 走っている集計が終わるか、待つのをやめる（[_scanOverdue]）と完了する。
  /// 引っぱって更新がこれを待つ。
  Completer<void>? _scanWait;

  /// 走っている集計が[storageScanShareLimit]を過ぎても終わっていない。
  /// 引っぱって更新を待たせ続けず、次の取り直しでは新しい集計を始める。
  /// 始め直さなければ、遅れて届いた結果はそのまま使う。
  bool _scanOverdue = false;
  Timer? _scanOverdueTimer;

  /// 集計を始めるたびに進める。古い集計の結果は捨てる。
  int _scanGeneration = 0;

  /// 走っている集計が待ち切れになり、「再試行」を出している。結果が届くまで
  /// そのままにする（押した後も、ボタンをその場に残す）。
  bool _scanRetryOffered = false;

  /// 大きさを変える操作の後、新しい集計が終わるまでtrue。その間、
  /// 持っている内訳は操作の前のものなので、グラフにも操作の行にも出さない。
  bool _sizesOutdated = false;

  /// この画面を開いている間、内訳の欄に取っておく棒の本数。出した・見込んだ
  /// うちの最大で、途中では減らさない（最初の結果が届いても、操作の後で棒が
  /// 減っても、下の操作の行が指の下で動かないように）。
  late int _reservedBars;

  // ── 端末の容量 ──
  DeviceSpaceInfo? _deviceSpace;
  bool _deviceWaiting = false;

  /// 直近の問い合わせが待ち切れになった。やり直している間も、答えが届くか
  /// もう一度待ち切れになるまでそのままにする（[_breakdownFailed]と同じ）。
  bool _deviceTimedOut = false;

  /// 直近の答えが「この端末では取得できない」だった。次の問い合わせを
  /// 待つ間は欄を出さない（出してすぐ消すと、下の操作の行が上下に動く）。
  bool _deviceUnavailable = false;
  int _deviceGeneration = 0;
  Timer? _deviceTimeout;

  // ── 整理する ──
  /// 操作が1つ進んでいる間（確かめるダイアログが開いている間も含む）true。
  /// 二度押しを止めるだけの印で、画面は作り直さない：ダイアログを開くのと
  /// 同じフレームで行を押せなくすると、キーボードで押した行がフォーカスを
  /// 手放し、その処理がダイアログのフォーカスの要求を上書きする（Escapeで
  /// 閉じられず、Enterが下の画面のボタンを押した）。
  bool _actionBusy = false;

  /// 確かめた後の処理（消している最中）の間だけtrue。見出しに印を出す。
  bool _working = false;

  // ── キーボードのフォーカス ──
  /// 大きさで押せなくなる行と、結果が届くと消える「再試行」。フォーカスを
  /// 持ったまま押せなくなる・消えると、Flutterはフォーカスを前にいた所
  /// （アプリバーのヘルプ）へ戻し、次のEnterがヘルプを開く。そうなる前に、
  /// その欄の見出しへ移す（[_keepFocusInItsSection]）。
  final _cacheRowFocus = FocusNode(debugLabel: 'storageClearCacheRow');
  final _trashRowFocus = FocusNode(debugLabel: 'storageEmptyTrashRow');
  final _deviceRetryFocus = FocusNode(debugLabel: 'storageDeviceRetry');
  final _breakdownRetryFocus = FocusNode(debugLabel: 'storageBreakdownRetry');

  /// 欄の見出し。Tabでは止まらず、フォーカスの置き場にだけ使う（Enterでは
  /// 何も起きず、次のTabはその欄の最初の操作へ進む）。
  final _deviceHeadingFocus = FocusNode(
    debugLabel: 'storageDeviceHeading',
    skipTraversal: true,
  );
  final _breakdownHeadingFocus = FocusNode(
    debugLabel: 'storageBreakdownHeading',
    skipTraversal: true,
  );
  final _actionsHeadingFocus = FocusNode(
    debugLabel: 'storageActionsHeading',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    // 開き直したときは、新しい集計が終わるまで前回の値を出しておく。ただし
    // ゴミ箱の中身がそのときと違えば（作品をゴミ箱へ移した・戻した）、前回の
    // 値はゴミ箱の大きさも作品データの大きさも合っていないので出さない。
    _breakdown = _service.lastBreakdownFor(_trashedProjectIds());
    _deviceSpace = _service.lastDeviceSpace;
    // 棒が何本になるか分からない間は、分類の数だけ（いちばん高い場合）を
    // 取っておく。少なく見込むと、結果が届いたときに操作の行が下へ動く。
    _reservedBars =
        _breakdown?.nonEmptyCategoryCount ??
        _service.lastNonEmptyCategoryCount ??
        StorageCategory.values.length;
    _reload();
  }

  @override
  void dispose() {
    _deviceTimeout?.cancel();
    _scanOverdueTimer?.cancel();
    for (final node in [
      _cacheRowFocus,
      _trashRowFocus,
      _deviceRetryFocus,
      _breakdownRetryFocus,
      _deviceHeadingFocus,
      _breakdownHeadingFocus,
      _actionsHeadingFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  Set<String> _trashedProjectIds() =>
      context.read<ProjectService>().trash.map((p) => p.id).toSet();

  /// 内訳と端末の容量を取り直す。投げず、必ず終わる（引っぱって更新が
  /// これを待つ）。[restart]は大きさを変える操作の後に渡す：走っている
  /// 集計・問い合わせは操作の前のディスクを見ているので、捨てて始め直す。
  Future<void> _reload({bool restart = false}) {
    _loadDeviceSpace(restart: restart);
    return _loadBreakdown(restart: restart);
  }

  Future<void> _loadBreakdown({bool restart = false}) {
    final waiting = _scanWait;
    final overdue = _scanOverdue;
    if (_scanning && waiting != null && !restart && !overdue) {
      return waiting.future;
    }
    final generation = ++_scanGeneration;
    final trashedIds = _trashedProjectIds();
    // 前の集計を待っている更新があれば放す（その結果はもう使わない）。
    _releaseScanWait();
    final done = _scanWait = Completer<void>();
    _scanOverdue = false;
    _scanOverdueTimer?.cancel();
    _scanOverdueTimer = Timer(storageScanShareLimit, () {
      if (!mounted || generation != _scanGeneration) return;
      // まだ走っているかもしれないが、待ち続けるかやり直すかを選べるように
      // 「再試行」を出す（キーボードだけでも押せる）。
      setState(() {
        _scanOverdue = true;
        _scanRetryOffered = true;
      });
      _releaseScanWait();
    });
    setState(() {
      _scanning = true;
      if (restart) _sizesOutdated = true;
    });
    // 待ち切れになった集計はサービスの側でも走ったままなので、分け合わずに
    // 新しく始めさせる。
    unawaited(_runScan(generation, trashedIds, fresh: overdue));
    return done.future;
  }

  void _releaseScanWait() {
    final waiting = _scanWait;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  Future<void> _runScan(
    int generation,
    Set<String> trashedIds, {
    required bool fresh,
  }) async {
    StorageBreakdown? result;
    try {
      result = await _service.computeBreakdown(trashedIds, fresh: fresh);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
    if (!mounted || generation != _scanGeneration) return;
    _scanOverdueTimer?.cancel();
    _scanOverdue = false;
    final scanned = result;
    setState(() {
      _scanning = false;
      _scanRetryOffered = false;
      if (scanned == null || scanned.isUnreadable) {
        _breakdownFailed = true;
        // 操作の前の内訳はもう合っていないので、残さない。
        if (_sizesOutdated) _breakdown = null;
      } else {
        _breakdownFailed = false;
        _breakdown = scanned;
        _sizesOutdated = false;
        _reservedBars = math.max(_reservedBars, scanned.nonEmptyCategoryCount);
      }
    });
    _releaseScanWait();
  }

  void _loadDeviceSpace({bool restart = false}) {
    if (_deviceWaiting && !restart) return;
    final generation = ++_deviceGeneration;
    _deviceTimeout?.cancel();
    // 待ちの長さは自分のタイマーで計る（`Future.timeout`は止められない
    // タイマーを残し、画面を閉じた後も動く）。
    _deviceTimeout = Timer(storageDeviceSpaceTimeout, () {
      if (!mounted || generation != _deviceGeneration) return;
      setState(() {
        _deviceWaiting = false;
        _deviceTimedOut = true;
      });
    });
    setState(() {
      _deviceWaiting = true;
      // 操作の前に聞いた空き容量は、もう合っていない。
      if (restart) _deviceSpace = null;
    });
    Future<DeviceSpaceInfo?>.sync(_service.deviceSpace).then<void>(
      (info) => _deviceAnswered(generation, info),
      onError: (Object error, StackTrace stack) {
        AppErrorReporter.record(error, stack);
        _deviceAnswered(generation, null);
      },
    );
  }

  /// 待ちが切れた後に届いた答えも、問い合わせ直していなければ使う。
  /// nullは「この端末では取得できない」で、欄ごと出さない。
  void _deviceAnswered(int generation, DeviceSpaceInfo? info) {
    if (!mounted || generation != _deviceGeneration) return;
    _deviceTimeout?.cancel();
    setState(() {
      _deviceWaiting = false;
      _deviceTimedOut = false;
      _deviceUnavailable = info == null;
      _deviceSpace = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cache = _sizedAction(l10n, StorageCategory.cache);
    final trash = _sizedAction(l10n, StorageCategory.trash);
    _keepFocusInItsSection(
      cacheEnabled: cache.enabled,
      trashEnabled: trash.enabled,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageScreenTitle),
        actions: const [HelpButton(topic: '容量削減')],
      ),
      body: desktopCentered(
        context,
        RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            // 欄は出入りしても、一覧の同じ位置の子のままにする（中身が空に
            // なるだけ）。位置がずれると後ろの子がすべて作り直され、
            // キーボードで選んでいた操作の行がフォーカスを失う。
            children: [
              _deviceSection(l10n),
              _breakdownSection(l10n),
              _sectionTitle(
                l10n.storageActionsTitle,
                busyLabel: _working ? l10n.homeTrashWorking : null,
                focusNode: _actionsHeadingFocus,
              ),
              const SizedBox(height: 8),
              _buildActions(l10n, cache: cache, trash: trash),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 欄 ───────────────────────────────────────────────────────────────

  /// 欄の見出し。[busyLabel]があれば横に小さな進行中の印を出す（値を出した
  /// まま裏で取り直している・操作の処理が進んでいる）。文は読み上げ用。
  /// [focusNode]は、その欄の操作が消える・押せなくなるときのフォーカスの
  /// 置き場（[_keepFocusInItsSection]）。
  Widget _sectionTitle(
    String text, {
    String? busyLabel,
    required FocusNode focusNode,
  }) {
    final title = Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Kuramubon',
        fontFamilyFallback: kHeadingFontFallback,
      ),
    );
    return Focus(
      focusNode: focusNode,
      skipTraversal: true,
      includeSemantics: false,
      child: busyLabel == null
          ? title
          : Row(
              children: [
                Flexible(child: title),
                const SizedBox(width: 8),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: busyLabel,
                  ),
                ),
              ],
            ),
    );
  }

  /// キーボードのフォーカスを持っている行がこのビルドで押せなくなる・
  /// 「再試行」が消えるなら、先にフォーカスをその欄の見出しへ移す。移して
  /// おかないと、Flutterはフォーカスを前にいた所（たいていアプリバーの
  /// ヘルプ）へ戻し、続けて押したEnterがヘルプを開く。
  void _keepFocusInItsSection({
    required bool cacheEnabled,
    required bool trashEnabled,
  }) {
    if ((!cacheEnabled && _cacheRowFocus.hasPrimaryFocus) ||
        (!trashEnabled && _trashRowFocus.hasPrimaryFocus)) {
      _actionsHeadingFocus.requestFocus();
    } else if (!_breakdownNoticed && _breakdownRetryFocus.hasPrimaryFocus) {
      _breakdownHeadingFocus.requestFocus();
    } else if (!_deviceTimedOut && _deviceRetryFocus.hasPrimaryFocus) {
      // 端末の容量の欄ごと消える場合（取得できない端末）は、次の欄の見出しへ。
      (_deviceSectionShown ? _deviceHeadingFocus : _breakdownHeadingFocus)
          .requestFocus();
    }
  }

  /// 欄の中身を、決めた高さ以上の場所に上から並べる。中身が集計中・グラフ・
  /// 知らせと入れ替わっても欄の高さが変わらず、下の操作の行が動かない。
  Widget _reservedBlock({required int bars, required List<Widget> children}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _breakdownChartHeight(bars, 0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// まだ出せる値が無い欄の中身。
  Widget _calculating(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.storageCalculating)),
        ],
      ),
    );
  }

  /// 集計できない状態では前の数値を表示しない。高さは_reservedBlockで維持。
  Widget _noChart() => const SizedBox.shrink();

  /// いま出してよい内訳。大きさを変える操作の後は、集計し直すまで無い。
  StorageBreakdown? get _currentBreakdown => _sizesOutdated ? null : _breakdown;

  /// 端末の容量の欄を出すか。取得できない端末（答えがnull）では、これまで
  /// どおり欄ごと出さない。答えを持っている間は、内訳を集計できなかった
  /// ときも場所を取ったままにする（やり直すたびに欄が出入りして、下の欄と
  /// 操作の行が上下に動いていた）。
  bool get _deviceSectionShown =>
      _deviceSpace != null ||
      _deviceTimedOut ||
      (_deviceWaiting && !_deviceUnavailable);

  Widget _deviceSection(AppLocalizations l10n) {
    final device = _deviceSpace;
    final breakdown = _currentBreakdown;
    // グラフはNIARIMの分を内訳の合計から出すので、内訳も要る。
    final hasChart = device != null && breakdown != null;
    return Column(
      key: const ValueKey('storageDeviceSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_deviceSectionShown) ...[
          _sectionTitle(
            l10n.storageDeviceChartTitle,
            busyLabel: _deviceWaiting && !_deviceTimedOut && hasChart
                ? l10n.storageCalculating
                : null,
            focusNode: _deviceHeadingFocus,
          ),
          const SizedBox(height: 8),
          _reservedBlock(
            bars: _deviceBarCount,
            children: [
              if (hasChart)
                _buildDeviceChart(l10n, device, breakdown)
              else if (_deviceTimedOut)
                // 知らせが状況を伝える（下）。
                const SizedBox.shrink()
              else if (_deviceWaiting || _scanning)
                _calculating(l10n)
              else
                // 内訳を集計できなかった：端末の容量だけではグラフにできない。
                _noChart(),
              if (_deviceTimedOut)
                _StorageNotice(
                  key: const ValueKey('storageDeviceNotice'),
                  // やり直している間も知らせとボタンはその場に残し、文だけ
                  // 替える。
                  message: _deviceWaiting
                      ? l10n.storageCalculating
                      : l10n.storageDeviceSpaceUnavailable,
                  busy: _deviceWaiting,
                  retryKey: const ValueKey('storageDeviceRetry'),
                  retryFocusNode: _deviceRetryFocus,
                  onRetry: _loadDeviceSpace,
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// 出ている内訳に、読めなかった分類がある。
  bool get _breakdownIncomplete =>
      _currentBreakdown?.incomplete.isNotEmpty ?? false;

  /// 内訳の欄に、知らせと「再試行」を出すか。
  bool get _breakdownNoticed =>
      _breakdownFailed || _breakdownIncomplete || _scanRetryOffered;

  /// 内訳の欄に出す知らせの文。
  /// - 集計できなかった：やり直している間は「集計中…」に替える。
  /// - 一部を読めなかった：出ている値の話なので、やり直している間も残す。
  /// - 集計が待ち切れになった：まだ走っているので「集計中…」のまま、
  ///   「再試行」だけを足す（集計できなかったとは言わない）。
  String _breakdownNoticeText(AppLocalizations l10n) {
    if (_breakdownFailed) {
      return _scanning
          ? l10n.storageCalculating
          : l10n.storageBreakdownLoadFailed;
    }
    return _breakdownIncomplete
        ? l10n.storageBreakdownIncomplete
        : l10n.storageCalculating;
  }

  Widget _breakdownSection(AppLocalizations l10n) {
    final breakdown = _currentBreakdown;
    final notice = _breakdownNoticed ? _breakdownNoticeText(l10n) : null;
    return Column(
      key: const ValueKey('storageBreakdownSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          l10n.storageBreakdownChartTitle,
          // 知らせを出しているときは、進行中の印は知らせの側に出す。
          busyLabel: _scanning && breakdown != null && notice == null
              ? l10n.storageCalculating
              : null,
          focusNode: _breakdownHeadingFocus,
        ),
        const SizedBox(height: 8),
        _reservedBlock(
          bars: _reservedBars,
          children: [
            if (breakdown != null)
              _buildBreakdownChart(l10n, breakdown)
            else if (_scanning && notice == null)
              _calculating(l10n),
            if (notice != null)
              _StorageNotice(
                key: const ValueKey('storageBreakdownNotice'),
                // やり直している間も知らせとボタンはその場に残す（消すと、
                // キーボードで押したボタンがフォーカスごと無くなる）。
                message: notice,
                busy: _scanning,
                retryKey: const ValueKey('storageBreakdownRetry'),
                retryFocusNode: _breakdownRetryFocus,
                onRetry: _reload,
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── 容量別の棒グラフ ─────────────────────────────────────────────────────────

  Widget _buildDeviceChart(
    AppLocalizations l10n,
    DeviceSpaceInfo device,
    StorageBreakdown breakdown,
  ) {
    final niarimBytes = breakdown.totalBytes;
    final others = (device.usedByOthersBytes - niarimBytes).clamp(
      0,
      device.totalBytes,
    );
    final free = device.freeBytes;
    final scheme = Theme.of(context).colorScheme;
    final deviceColors = storageDeviceSliceColorsOf(scheme);
    final slices = [
      _StorageAmount(
        niarimBytes.toDouble(),
        deviceColors[0],
        l10n.storageCategoryNiarimTotal,
      ),
      _StorageAmount(
        others.toDouble(),
        deviceColors[1],
        l10n.storageCategoryOtherApps,
      ),
      _StorageAmount(
        free.toDouble(),
        deviceColors[2],
        l10n.storageCategoryFree,
      ),
    ];
    return _barsWithLabels(slices, barKeyPrefix: 'storageDeviceBar');
  }

  Widget _buildBreakdownChart(
    AppLocalizations l10n,
    StorageBreakdown breakdown,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // アクセント色の色相・彩度を変えず、明度だけ6段階にした濃淡を使う。
    final colors = sliceColorsOf(scheme);
    final entries = [
      (StorageCategory.materials, l10n.storageCategoryMaterials),
      (StorageCategory.projectData, l10n.storageCategoryProjectData),
      (StorageCategory.exports, l10n.storageCategoryExports),
      (StorageCategory.customAssets, l10n.storageCategoryCustomAssets),
      (StorageCategory.cache, l10n.storageCategoryCache),
      (StorageCategory.trash, l10n.storageCategoryTrash),
    ];
    final slices = [
      for (int i = 0; i < entries.length; i++)
        _StorageAmount(
          breakdown.bytesOf(entries[i].$1).toDouble(),
          colors[i % colors.length],
          entries[i].$2,
        ),
    ];
    return _barsWithLabels(slices, barKeyPrefix: 'storageBreakdownBar');
  }

  /// Both groups have identical bars: category and bytes inside each bar.
  /// A full-width row gives long translated labels more space than the former
  /// pie + narrow side column. Each value is relative to the group's largest.
  Widget _barsWithLabels(
    List<_StorageAmount> slices, {
    required String barKeyPrefix,
  }) {
    final largest = slices.fold<double>(
      0,
      (max, slice) => math.max(max, slice.value),
    );
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slice in slices)
          if (slice.value > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _storageAmountBar(
                key: Key('${barKeyPrefix}_${slice.label}'),
                color: slice.color,
                ratio: largest > 0 ? slice.value / largest : 0,
                label: slice.label,
                bytes: slice.value,
                scheme: scheme,
              ),
            ),
      ],
    );
  }

  /// One labeled bar per legend row. Its remainder uses the exact same
  /// theme text color as the surrounding border, rather than an arbitrary
  /// gray. The foreground token matches selected (active) controls.
  Widget _storageAmountBar({
    required Key key,
    required Color color,
    required double ratio,
    required String label,
    required double bytes,
    required ColorScheme scheme,
  }) {
    final outline = scheme.onSurface;
    final foreground = scheme.onSecondary;
    // Keep the requested active button text color. A subtle outline in the
    // theme's surface-ink color preserves readability on very light bars.
    final foregroundShadows = [
      for (final offset in const [
        Offset(-0.7, -0.7),
        Offset(0.7, -0.7),
        Offset(-0.7, 0.7),
        Offset(0.7, 0.7),
      ])
        Shadow(color: outline, offset: offset, blurRadius: 0.3),
    ];
    final amount = ratio.clamp(0.0, 1.0);
    return SizedBox(
      key: key,
      height: 34,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: amount,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: outline, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    key: Key('storageBreakdownBarLabel_$label'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      shadows: foregroundShadows,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  formatStorageBytes(bytes),
                  key: Key('storageBreakdownBarValue_$label'),
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    shadows: foregroundShadows,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 操作ボタン ────────────────────────────────────────────────────────

  /// [category]の大きさで決まる操作の、行の下の文と押せるかどうか。
  /// 大きさが分かっていて0より大きいときだけ押せる。集計中は「集計中…」、
  /// 大きさが分からないとき（集計できなかった・読めなかった分類で0）は
  /// 数字を出さない（0Bは分かった値ではない）。その場合も下の行は空のまま
  /// 残す（行の高さが変わると、その下の行が動く）。
  ({String subtitle, bool enabled}) _sizedAction(
    AppLocalizations l10n,
    StorageCategory category,
  ) {
    final breakdown = _currentBreakdown;
    if (breakdown == null) {
      return (
        subtitle: _scanning ? l10n.storageCalculating : '',
        enabled: false,
      );
    }
    final bytes = breakdown.bytesOf(category);
    if (bytes <= 0 && breakdown.incomplete.contains(category)) {
      return (subtitle: '', enabled: false);
    }
    return (subtitle: formatStorageBytes(bytes), enabled: bytes > 0);
  }

  Widget _buildActions(
    AppLocalizations l10n, {
    required ({String subtitle, bool enabled}) cache,
    required ({String subtitle, bool enabled}) trash,
  }) {
    // 行を押せなくするのは、大きさで決まる分だけ。操作が進んでいる間の
    // 二度押しは[_runAction]が止める（[_actionBusy]の注意を参照）。
    return Column(
      children: [
        _actionTile(
          icon: Icons.cleaning_services_outlined,
          title: l10n.storageClearCacheButton,
          subtitle: cache.subtitle,
          focusNode: _cacheRowFocus,
          onTap: cache.enabled ? _confirmClearCache : null,
        ),
        _actionTile(
          icon: Icons.image_not_supported_outlined,
          title: l10n.storageRemoveUnusedMaterialsButton,
          onTap: _confirmRemoveUnusedMaterials,
        ),
        _actionTile(
          icon: Icons.delete_sweep_outlined,
          title: l10n.storageEmptyTrashButton,
          subtitle: trash.subtitle,
          focusNode: _trashRowFocus,
          onTap: trash.enabled ? _confirmEmptyTrash : null,
        ),
        _actionTile(
          icon: Icons.folder_open_outlined,
          title: l10n.storageOrganizeProjectsButton,
          onTap: _openProjects,
        ),
        Divider(height: 24),
        _actionTile(
          icon: Icons.warning_amber_outlined,
          iconColor: ThemeService.activeColorScheme.error,
          title: l10n.storageEraseAllButton,
          titleColor: ThemeService.activeColorScheme.error,
          onTap: _confirmEraseAll,
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    FocusNode? focusNode,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        focusNode: focusNode,
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: titleColor)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }

  // ─── 各操作の確認ダイアログ・実処理 ──────────────────────────────────

  /// 操作を1つだけ走らせる。[action]は大きさが変わりうることをしたかを返し、
  /// したなら終わった後に集計し直す。以前は読み込み中に本文ごと隠れることが
  /// 二度押しを防いでいた。本文を出したままにしたので、ここで防ぐ。
  Future<void> _runAction(Future<bool> Function() action) async {
    if (_actionBusy) return;
    _actionBusy = true;
    // 途中で失敗したときも、どこまで消えたか分からないので集計し直す。
    var sizesChanged = true;
    try {
      sizesChanged = await action();
    } finally {
      _actionBusy = false;
      if (sizesChanged) {
        // 画面を閉じた後に終わった操作でも、覚えている結果は捨てる
        // （捨てないと、開き直した画面が操作の前の値・集計を使う）。
        _service.invalidate();
        if (mounted) unawaited(_reload(restart: true));
      }
    }
  }

  /// 確かめた後の処理を走らせ、その間だけ見出しに処理中の印を出す。行は
  /// 押せるままにしておく（押しても[_runAction]が受け付けない）：押せなく
  /// すると、キーボードで選んでいた行がフォーカスを失う。
  Future<T> _work<T>(Future<T> Function() body) async {
    if (mounted) setState(() => _working = true);
    try {
      return await body();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// 作品を消す・ゴミ箱へ移すための行き先なので、戻ってきたら集計し直す。
  Future<void> _openProjects() => _runAction(() async {
    await context.push('/home');
    return true;
  });

  Future<void> _confirmClearCache() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      itemName: l10n.storageCategoryCache,
    );
    if (!ok || !mounted) return false;
    try {
      final freed = await _work(_service.clearCache);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.storageClearCacheDoneSnackbar(formatStorageBytes(freed)),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text(l10n.communityErrorGeneric),
          ),
        ),
      );
    }
    return true;
  });

  Future<void> _confirmRemoveUnusedMaterials() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      itemName: l10n.storageRemoveUnusedMaterialsButton,
    );
    if (!ok || !mounted) return false;
    final ps = context.read<ProjectService>();
    final ms = context.read<MaterialService>();
    final removed = await _work(() async {
      var count = 0;
      for (final project in ps.projects) {
        count += await ms.removeUnused(
          projectId: project.id,
          isUsed: (materialId) => ps.isMaterialUsed(project.id, materialId),
        );
      }
      return count;
    });
    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.materialRemovedSnackbar(removed))),
    );
    return true;
  });

  Future<void> _confirmEmptyTrash() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    // ゴミ箱のフォルダ（中の作品ごと）も含めて空にする。
    final targets = ps.trash.map((p) => p.id).toSet();
    // 読めていない作品を含むフォルダは消さない（中の読めた作品ごと残す）
    // ので、消すものとして並べない。開いた後で読めなくなったものは、下で
    // 消せなかったと知らせる。
    final folderTargets = ps.trashedFolders
        .where((t) => !ps.trashedFolderHasUnreadWorks(t))
        .map((t) => t.folder.id)
        .toSet();
    bool holdsUnread() => ps.trashedFolders.any(ps.trashedFolderHasUnreadWorks);
    // 残すフォルダしか無いときは、何も並ばないダイアログを出さず（「削除」を
    // 押しても何も消えずに閉じた）、読み込めていないことを知らせる。
    if (folderTargets.isEmpty && ps.looseTrash.isEmpty && holdsUnread()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeProjectsLoadFailed)));
      return false;
    }
    // 途中で失敗してから閉じた場合も、消せた分だけ大きさは変わっている。
    var attempted = false;
    await showDialog<bool>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homePermanentDeleteConfirmTitle,
        message: l10n.homePermanentDeleteConfirmBody,
        // 残すフォルダがあることも伝える。
        pendingMessage: () => holdsUnread()
            ? '${l10n.homePermanentDeleteConfirmBody}\n'
                  '${l10n.homeProjectsLoadFailed}'
            : l10n.homePermanentDeleteConfirmBody,
        confirmLabel: l10n.commonDelete,
        itemNames: const [],
        pendingItemNames: () => [
          for (final t in ps.trashedFolders)
            if (folderTargets.contains(t.folder.id)) t.folder.name,
          for (final p in ps.looseTrash)
            if (targets.contains(p.id)) p.name,
        ],
        onApply: () async {
          attempted = true;
          // 読めていない作品を含むフォルダは中の読めた作品ごと残し、他を
          // 消し終えてから、空にし切れなかったことを知らせる（記録だけを
          // 消すと、中の作品は読めた後に1件ずつゴミ箱へ出る）。
          TrashedFolderUnreadException? heldBack;
          for (final id in folderTargets) {
            try {
              await ps.permanentDeleteTrashedFolder(id);
            } on TrashedFolderUnreadException catch (refused) {
              heldBack = refused;
            }
          }
          for (final id in targets) {
            final folder = ps.trashedFolderOf(id);
            if (folder != null && ps.trashedFolderHasUnreadWorks(folder)) {
              continue;
            }
            if (ps.trash.any((p) => p.id == id)) {
              await ps.permanentDelete(id);
            }
          }
          if (heldBack != null) throw heldBack;
        },
      ),
    );
    return attempted;
  });

  Future<void> _confirmEraseAll() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l10n.storageEraseAllConfirmTitle),
        content: Text(l10n.storageEraseAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeService.activeColorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.storageEraseAllButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    // 実際の全データ削除は、他の全Serviceが保持するメモリ上の状態も
    // まとめて破棄する必要があり影響範囲が大きいため、ここでは
    // ディスク上のNIARIMデータ（プロジェクト・素材・書き出し・自作
    // アセット・キャッシュ）のみを削除し、アプリの再起動を促す
    // 案内にとどめる（中途半端な状態のままメモリ上の各Serviceを
    // 使い続けるリスクを避けるため）。
    await _work(_service.eraseAllData);
    if (!mounted) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.storageEraseAllDoneSnackbar)));
    return true;
  });
}

/// 欄の中に出す知らせ（集計できなかった・一部を読めなかった・端末の容量を
/// 取得できなかった）と、やり直しのボタン。失敗を色では表さず、その欄が
/// 載っている面の本文の色のまま、先頭のアイコンで示す。
///
/// やり直している間（[busy]）も同じ所に残り、ボタンは押せるままにする
/// （重ねて押しても、走っている1回にまとめられる）。ボタンを消す・押せなく
/// すると、キーボードで押した人のフォーカスがほかのボタンへ飛ぶ。
class _StorageNotice extends StatelessWidget {
  const _StorageNotice({
    super.key,
    required this.message,
    required this.busy,
    required this.retryKey,
    required this.retryFocusNode,
    required this.onRetry,
  });

  final String message;
  final bool busy;
  final Key retryKey;
  final FocusNode retryFocusNode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = DefaultTextStyle.of(context).style.color;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        // 文が「集計中」のときは、同じ言葉を二重に読ませない。
                        semanticsLabel: message == l10n.storageCalculating
                            ? null
                            : l10n.storageCalculating,
                      ),
                    ),
                  )
                else
                  Icon(Icons.error_outline, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: retryKey,
              focusNode: retryFocusNode,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.communityRetry),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageAmount {
  final double value;
  final Color color;
  final String label;

  const _StorageAmount(this.value, this.color, this.label);
}
