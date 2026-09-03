import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'app_bootstrap.dart';
import 'utils/app_error_reporter.dart';

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

  final providers = await buildAppProviders();

  runApp(MultiProvider(providers: providers, child: const NiarimApp()));
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
