import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/monetization_gate.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/input_handler.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('niarim_platform_final_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('stylus/touch/mouse classification and pressure/tilt conversion are correct', () {
    final handler = InputHandler();

    final stylus = PointerDownEvent(
      kind: PointerDeviceKind.stylus,
      position: const Offset(12, 34),
      pressure: 0.4,
      tilt: 0.5,
      orientation: math.pi / 2,
    );
    expect(handler.classifyInput(stylus), InputType.stylus);
    expect(handler.isStylusActive, isTrue);
    final point = handler.toStrokePoint(
      stylus,
      pressureCurve: (p) => p * 0.5,
    );
    expect(point.inputType, InputType.stylus);
    expect(point.x, closeTo(12, 0.001));
    expect(point.y, closeTo(34, 0.001));
    expect(point.pressure, closeTo(0.2, 0.001));
    expect(point.tiltX, closeTo(0, 0.001));
    expect(point.tiltY, closeTo(0.5, 0.001));
    expect(handler.shouldDraw(stylus, hasStylusSupport: true), isTrue);
    handler.onStylusUp();
    expect(handler.isStylusActive, isFalse);

    final inverted = const PointerDownEvent(
      kind: PointerDeviceKind.invertedStylus,
      position: Offset(1, 2),
    );
    expect(handler.classifyInput(inverted), InputType.stylus);

    final touch = const PointerDownEvent(
      kind: PointerDeviceKind.touch,
      position: Offset(2, 3),
    );
    expect(handler.classifyInput(touch), InputType.touch);
    expect(handler.shouldDraw(touch, hasStylusSupport: true), isFalse);
    expect(handler.shouldDraw(touch, hasStylusSupport: false), isTrue);

    final mouse = const PointerDownEvent(
      kind: PointerDeviceKind.mouse,
      position: Offset(4, 5),
    );
    expect(handler.classifyInput(mouse), InputType.mouse);
    expect(handler.shouldDraw(mouse, hasStylusSupport: true), isTrue);
  });

  test('material lifecycle persists, deduplicates, detects missing files and builds share bundle', () async {
    const projectId = 'ProjectAudit';
    final source = File('${root.path}/sample.png')
      ..writeAsBytesSync(List<int>.generate(128, (i) => i % 251));

    final service = MaterialService();
    final first = await service.addMaterial(
      projectId: projectId,
      sourcePath: source.path,
      type: MaterialType.image,
    );
    expect(first.id, 'Material0001');
    expect(await service.pathOf(projectId, first.id), isNotNull);

    final duplicate = await service.addMaterial(
      projectId: projectId,
      sourcePath: source.path,
      type: MaterialType.image,
    );
    expect(duplicate.id, first.id);
    expect(service.materialsOf(projectId), hasLength(1));

    final share = await service.buildShareBundle(
      projectId,
      {MaterialType.image},
    );
    expect(share.files, hasLength(1));
    expect(share.manifest, isNotNull);

    final restored = MaterialService();
    await restored.ensureLoaded(projectId);
    expect(restored.materialsOf(projectId), hasLength(1));
    expect(restored.materialsOf(projectId).single.id, first.id);
    expect(await restored.detectMissing(projectId), isEmpty);

    final storedPath = await restored.pathOf(projectId, first.id);
    expect(storedPath, isNotNull);
    File(storedPath!).deleteSync();
    final missing = await restored.detectMissing(projectId);
    expect(missing.map((m) => m.id), contains(first.id));
  });

  test('current Premium local path stays store-free and campaign-enabled before monetization date', () async {
    expect(kMonetizationEnabledFrom, DateTime(2027, 1, 1));
    expect(isMonetizationEnabled, isFalse,
        reason: 'This audit is for the current pre-2027 release configuration.');

    final service = PremiumService();
    await service.init();
    expect(service.storeAvailable, isFalse);
    expect(service.hasPurchasedPremium, isFalse);
    expect(service.isLaunchCampaignActive, isTrue);
    expect(service.isPremium, isTrue);

    final started = await service.buy(PremiumService.monthlyProductId);
    expect(started, isFalse);
    expect(service.purchaseError, isNotNull);
    expect(service.storeAvailable, isFalse);
    service.dispose();
  });

  test('purchased Premium metadata restores locally without requiring store access', () async {
    final purchasedAt = DateTime(2026, 6, 15, 12);
    SharedPreferences.setMockInitialValues({
      'is_premium': true,
      'premium_purchase_date': purchasedAt.millisecondsSinceEpoch,
      'premium_purchase_product_id': PremiumService.yearlyProductId,
    });
    final service = PremiumService();
    await service.init();
    expect(service.hasPurchasedPremium, isTrue);
    expect(service.purchaseDate, purchasedAt);
    expect(service.isPremium, isTrue);
    expect(service.storeAvailable, isFalse);
    expect(service.nextRenewalDate, isNotNull);
    service.dispose();
  });
}
