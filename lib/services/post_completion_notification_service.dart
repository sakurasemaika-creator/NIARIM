import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A local OS notification after NIARIM's POST /works has succeeded.
/// Android's PendingIntent opens the owned work-detail route. This is not
/// a push notification: no background upload or FCM token is required.
class PostCompletionNotificationService {
  static const _channel =
      MethodChannel('com.niarim.niarim/post_notification');

  static Future<void> notifySuccess({
    required String workId,
    required String title,
    required bool scheduled,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(workId)) return;
    try {
      await _channel.invokeMethod<void>('showSuccess', {
        'workId': workId,
        'title': title,
        'scheduled': scheduled,
      });
    } on MissingPluginException {
      // Non-Android targets still show the in-app confirmation snackbar.
    } on PlatformException catch (error) {
      // Notification permission refusal must never turn a published work into
      // a failed upload and trigger another registration attempt.
      debugPrint('Post notification not available: ${error.code}');
    }
  }
}
