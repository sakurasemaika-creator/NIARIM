import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/push_notification_service.dart';

void main() {
  test('simulated FCM delivery accepts only NIARIM-owned deep links', () {
    // Data and notification fields are constructed with the real Firebase
    // Messaging model, but never deliver a production push or register a token.
    final mission = RemoteMessage(
      messageId: 'simulated-mission',
      data: const {'targetRoute': '/creator-missions'},
      notification: RemoteNotification(
        title: 'ミッション達成', body: 'アプリ内の内容を確認',
      ),
    );
    final work = RemoteMessage(
      messageId: 'simulated-work',
      data: const {'targetRoute': '/community/work/Ab_12345678'},
    );
    final hostile = RemoteMessage(
      messageId: 'simulated-invalid-link',
      data: const {'targetRoute': '/community/work/Ab_12345678?admin=true'},
    );
    expect(PushNotificationService.routeForData(mission.data),
        '/creator-missions');
    expect(PushNotificationService.routeForData(work.data),
        '/community/work/Ab_12345678');
    expect(PushNotificationService.routeForData(hostile.data), isNull);
    for (final disallowed in [
      'https://example.invalid/creator-missions',
      '//example.invalid',
      '/community/work/../admin',
      '/community/work/Ab_12345678/extra',
      '/settings',
      '',
    ]) {
      final message = RemoteMessage(
        data: {'targetRoute': disallowed},
      );
      expect(PushNotificationService.routeForData(message.data), isNull,
          reason: 'Rejected unsafe or unknown FCM route: $disallowed');
    }
  });

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
