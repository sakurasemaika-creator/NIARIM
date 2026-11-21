package com.niarim.niarim

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

// Data-only FCM messages reach this service before Android displays anything.
// FlutterFire's separate receiver and inherited token callbacks remain in place.
class CommunityFirebaseMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        CommunityNotices.receive(applicationContext, message.data)
    }
}
