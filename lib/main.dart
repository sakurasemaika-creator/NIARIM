import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/push_notification_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_bootstrap.dart';
import 'app_runner.dart';
import 'config/ported_code_licenses.dart';
import 'utils/app_error_reporter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面が真っ白になる（＝リリースビルドの既定ErrorWidgetが文字の無い
  // ボックスを描く）代わりに、何が起きたかを画面へ出し、原因を追える
  // ようにする。詳細はAppErrorReporterのコメント参照。
  AppErrorReporter.install();

  _registerBundledFontLicenses();
  registerPortedCodeLicenses();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Push messaging is optional: an absent/misconfigured Firebase install must
  // never prevent offline animation editing or widget tests from starting.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp();
      PushNotificationService.firebaseAvailable = true;
    } catch (error) {
      debugPrint('FCM initialization unavailable: $error');
    }
  }
  final runner = AppRunner(show: runApp, beforeStepFor: _debugStartupFailure);
  AppRunner.current = runner;
  await runner.start();
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
