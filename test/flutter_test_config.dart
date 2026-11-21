import 'dart:async';
import 'dart:ui';

import 'package:niarim/services/settings_service.dart';

/// テストは日本語の端末として動かす。表示言語を選んでいないときは端末の
/// 言語で始まるが、flutter_testの端末は英語（en_US）で、日本語の文言を
/// 探すテストが多いため。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SettingsService.deviceLocales = () => const [Locale('ja', 'JP')];
  await testMain();
}
