import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_bootstrap.dart';
import 'router.dart';
import 'utils/app_error_reporter.dart';
import 'widgets/app_reset_progress_app.dart';
import 'widgets/startup_failure_app.dart';

/// アプリを起動する・初めから起動し直す（全データを削除して入れたばかりの
/// 状態に戻すとき）。
///
/// 起動に失敗したときは起動失敗画面を出し、「もう一度試す」で同じ手順を
/// やり直す。起動できた回のServiceは覚えておき、起動し直す前に止める。
class AppRunner {
  AppRunner({required this.show, this.beforeStepFor, this.waitForFrame});

  /// 画面の根を差し替える（アプリでは`runApp`）。
  final void Function(Widget app) show;

  /// [attempt]回目の起動の、各初期化処理の直前に呼ぶもの（デバッグビルドで
  /// 起動の失敗を試すため）。
  final StartupStepHook? Function(int attempt)? beforeStepFor;

  /// 差し替えた画面が描かれ、前の画面がツリーから外れるまで待つ（既定は
  /// 次のフレームの終わり）。
  final Future<void> Function()? waitForFrame;

  /// 動いているアプリのもの（`main`が入れる）。画面だけを載せたテストでは
  /// null。
  static AppRunner? current;

  int _attempts = 0;
  Future<void> Function()? _stopServices;
  bool _resetting = false;

  /// 全データの削除を始めてから、起動し直すまでの間か。
  bool get resetting => _resetting;

  /// Serviceを初期化してアプリ本体を出す。
  ///
  /// 初期化に失敗すると、何も出ないまま起動画面で止まる（runAppが一度も
  /// 呼ばれない）。代わりに起動失敗画面を出し、そこから同じ手順で
  /// やり直せるようにする。失敗した回の途中まで作ったServiceは
  /// [buildAppProviders]が片付けてから例外を投げるので、やり直しで
  /// 購読やリスナーが二重になることはない。
  Future<void> start() async {
    final attempt = ++_attempts;
    try {
      final providers = await buildAppProviders(
        beforeStep: beforeStepFor?.call(attempt),
        onStarted: (stop) => _stopServices = stop,
      );
      // 起動し直すたびに作り直す（前の回の画面の状態を持ち越さない）。
      show(
        MultiProvider(
          key: ValueKey(attempt),
          providers: providers,
          child: const NiarimApp(),
        ),
      );
    } on AppStartupException catch (failure) {
      AppErrorReporter.record(failure, failure.stackTrace);
      debugPrint('$failure');
      debugPrintStack(stackTrace: failure.stackTrace);
      show(
        StartupFailureApp(
          // やり直しにも失敗したときは、押した「もう一度試す」の状態を
          // 引き継がない新しい画面にする。
          key: ValueKey(attempt),
          details: _startupFailureDetails(failure),
          languageCode: failure.languageCode,
          onRetry: start,
        ),
      );
    }
  }

  /// 全データを削除して、入れたばかりの状態で起動し直す。
  ///
  /// 1. 進んでいることだけを出す画面に差し替え、前の画面をツリーから外す
  ///    （止めるServiceを見ている画面を残さない）。
  /// 2. [prepare]を呼ぶ（Serviceが動いている間に済ませること。Googleの
  ///    ログアウト等）。
  /// 3. Serviceを止める（並んでいる保存を書き終えてから破棄する。止める前に
  ///    消すと、後から書き終えた保存・設定が戻る）。
  /// 4. [erase]で消す。
  /// 5. 画面の履歴を起動画面だけにして、初めから起動する（初回の案内も
  ///    また出る）。
  ///
  /// [languageCode]は進んでいる画面の言語（消す前の設定）。
  Future<void> resetToFactory({
    required Future<void> Function() erase,
    Future<void> Function()? prepare,
    String? languageCode,
  }) async {
    if (_resetting) return;
    _resetting = true;
    try {
      show(AppResetProgressApp(languageCode: languageCode));
      await (waitForFrame ?? _nextFrame)();
      if (prepare != null) {
        try {
          await prepare();
        } catch (error, stack) {
          AppErrorReporter.record(error, stack);
        }
      }
      await stopServices();
      try {
        await erase();
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      appRouter.go('/');
      await start();
    } finally {
      _resetting = false;
    }
  }

  /// 起動できた回のServiceを止める（並んでいる保存を書き終えてから、作った
  /// 順の逆に破棄する）。止めるのは1回だけ。止めた後はアプリ本体の画面を
  /// 出したままにしないこと（破棄したServiceを見ている）。
  Future<void> stopServices() async {
    final stop = _stopServices;
    _stopServices = null;
    await stop?.call();
  }

  static Future<void> _nextFrame() async {
    // runAppは根の差し替えをタイマーで行うので、それを待ってからフレームを
    // 待つ。
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
  }
}

String _startupFailureDetails(AppStartupException failure) {
  final frames = failure.stackTrace
      .toString()
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(12);
  return [
    'step: ${failure.step}',
    'error: ${failure.error}',
    ...frames,
  ].join('\n');
}
