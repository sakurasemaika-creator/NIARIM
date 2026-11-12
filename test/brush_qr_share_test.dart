import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Small image-free brush round-trips all settings through QR', () async {
    final service = BrushService();
    await service.init();
    final original = service.brushes.firstWhere((b) => b.id == 'Brush0001');
    final payload = service.exportBrushQrPayload(original.id);
    expect(payload, isNotNull, reason: 'A simple built-in brush must fit QR');
    expect(payload, startsWith(BrushService.brushQrPrefix));
    expect(payload!.length, lessThanOrEqualTo(900));
    final imported = service.importBrushQrPayload(payload);
    expect(imported.id, isNot(original.id));
    expect(imported.name, original.name);
    expect(imported.size, original.size);
    expect(imported.spacing, original.spacing);
    expect(imported.opacity, original.opacity);
    expect(imported.grainStrength, original.grainStrength);
    expect(imported.pressureOn.toJson(), original.pressureOn.toJson());
    expect(imported.customImagePath, isNull);
    expect(imported.customImagePaths, isEmpty);
    expect(service.brushes.any((b) => b.id == imported.id), isTrue);
    expect(service.exportBrushQrPayload(original.id, maxChars: 10), isNull);
    service.dispose();
  });

  test('Image assets are not falsely claimed to fit into QR', () async {
    final service = BrushService();
    await service.init();
    final original = service.brushes.first;
    service.addBrush(original.copyWith(
      id: 'custom_image_test',
      name: '画像ブラシ',
      customImagePath: '/nonexistent-test-brush.png',
    ));
    expect(service.exportBrushQrPayload('custom_image_test'), isNull);
    expect(() => service.importBrushQrPayload('invalid'), throwsFormatException);
    service.dispose();
  });
}
