import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'app_bootstrap.dart';
import 'app_startup.dart';
import 'utils/app_error_reporter.dart';
import 'utils/bundled_font_licenses.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面が真っ白になる（＝リリースビルドの既定ErrorWidgetが文字の無い
  // ボックスを描く）代わりに、何が起きたかを画面へ出し、原因を追える
  // ようにする。詳細はAppErrorReporterのコメント参照。
  AppErrorReporter.install();

  registerBundledFontLicenses();

  runApp(
    AppStartup(initialize: initializeApplication, child: const NiarimApp()),
  );
}

Future<AppServices> initializeApplication() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  return buildAppServices();
}
