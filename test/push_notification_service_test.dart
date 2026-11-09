import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/push_notification_service.dart';

void main() {
  test('only expected NIARIM push routes are navigable', () {
    expect(
      PushNotificationService.routeForData({
        'targetRoute': '/creator-missions',
      }),
      '/creator-missions',
    );
    expect(
      PushNotificationService.routeForData({
        'targetRoute': '/community/work/Ab_12345678',
      }),
      '/community/work/Ab_12345678',
    );
    expect(
      PushNotificationService.routeForData({'targetRoute': '/settings'}),
      isNull,
    );
    expect(
      PushNotificationService.routeForData({
        'targetRoute': 'https://evil.example/',
      }),
      isNull,
    );
    expect(
      PushNotificationService.routeForData({
        'targetRoute': '/community/work/../admin',
      }),
      isNull,
    );
  });
}
