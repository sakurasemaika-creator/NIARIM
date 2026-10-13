import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'app_bootstrap.dart';
import 'utils/app_error_reporter.dart';
import 'widgets/startup_failure_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面が真っ白になる（＝リリースビルドの既定ErrorWidgetが文字の無い
  // ボックスを描く）代わりに、何が起きたかを画面へ出し、原因を追える
  // ようにする。詳細はAppErrorReporterのコメント参照。
  AppErrorReporter.install();

  _registerBundledFontLicenses();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await _startApp();
}

int _startupAttempts = 0;

/// Serviceを初期化してアプリ本体を出す。
///
/// 初期化に失敗すると、何も出ないまま起動画面で止まる（runAppが一度も
/// 呼ばれない）。代わりに起動失敗画面を出し、そこから同じ手順で
/// やり直せるようにする。失敗した回の途中まで作ったServiceは
/// [buildAppProviders]が片付けてから例外を投げるので、やり直しで
/// 購読やリスナーが二重になることはない。
Future<void> _startApp() async {
  final attempt = ++_startupAttempts;
  try {
    final providers = await buildAppProviders(
      beforeStep: _debugStartupFailure(attempt),
    );
    runApp(MultiProvider(providers: providers, child: const NiarimApp()));
  } on AppStartupException catch (failure) {
    AppErrorReporter.record(failure, failure.stackTrace);
    debugPrint('$failure');
    debugPrintStack(stackTrace: failure.stackTrace);
    runApp(
      StartupFailureApp(
        // やり直しにも失敗したときは、押した「もう一度試す」の状態を
        // 引き継がない新しい画面にする。
        key: ValueKey(attempt),
        details: _startupFailureDetails(failure),
        languageCode: failure.languageCode,
        onRetry: _startApp,
      ),
    );
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

/// 起動失敗画面を実際の画面で確かめるための、デバッグビルド専用の仕掛け。
/// `--dart-define=NIARIM_DEBUG_FAIL_STARTUP_STEP=<処理名>`で起動すると、
/// その処理の直前で`NIARIM_DEBUG_FAIL_STARTUP_ATTEMPTS`回（既定1回）だけ
/// 失敗する。リリースビルドでは常にnull。
const String _debugFailStartupStep = String.fromEnvironment(
  'NIARIM_DEBUG_FAIL_STARTUP_STEP',
);
const int _debugFailStartupAttempts = int.fromEnvironment(
  'NIARIM_DEBUG_FAIL_STARTUP_ATTEMPTS',
  defaultValue: 1,
);

StartupStepHook? _debugStartupFailure(int attempt) {
  if (!kDebugMode ||
      _debugFailStartupStep.isEmpty ||
      attempt > _debugFailStartupAttempts) {
    return null;
  }
  return (step) {
    if (step == _debugFailStartupStep) {
      throw StateError('Injected startup failure before "$step"');
    }
  };
}

/// 同梱フォント（白光明朝・くらむぼん・Noto Serif JP。いずれもSIL Open
/// Font License 1.1）の著作権表示とライセンス本文を、Flutter標準の
/// ライセンス一覧（設定 → 利用規約・ライセンス → オープンソース
/// ライセンス）へ登録する。
///
/// OFL第2条は、フォントを再配布する際に著作権表示とライセンス本文を
/// 同梱することを求めている。パッケージのライセンスはLicenseRegistryが
/// 自動収集するが、assets/fonts/へ直接置いたフォントファイルは収集対象に
/// ならないため、ここで明示的に登録する。
void _registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/FONT_LICENSES.txt',
    );
    yield LicenseEntryWithLineBreaks(const [
      'HakkouMincho',
      'Kuramubon',
      'Noto Serif JP',
      'Dela Gothic One',
      'Noto Serif KR / SC',
      'Noto Sans KR / SC',
    ], text);
  });
}
