import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';

class _CountingPremiumService extends PremiumService {
  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addListenerCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCalls++;
    super.removeListener(listener);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AdvertisingService init is idempotent', () async {
    final premium = _CountingPremiumService();
    final service = AdvertisingService(premiumService: premium);
    await service.init();
    await service.init();
    expect(premium.addListenerCalls, 1);
    service.dispose();
    expect(premium.removeListenerCalls, 1);
    premium.dispose();
  });

  test('AppErrorReporter install does not wrap handlers twice', () {
    final beforeFlutter = FlutterError.onError;
    final beforePlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = beforeFlutter;
      PlatformDispatcher.instance.onError = beforePlatform;
    });

    AppErrorReporter.install();
    final firstFlutter = FlutterError.onError;
    final firstPlatform = PlatformDispatcher.instance.onError;
    AppErrorReporter.install();

    expect(identical(FlutterError.onError, firstFlutter), isTrue);
    expect(
      identical(PlatformDispatcher.instance.onError, firstPlatform),
      isTrue,
    );
  });
}
