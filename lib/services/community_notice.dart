import '../l10n/app_localizations.dart';

const communityNotificationsRoute = '/community/notifications';

// Feature-local labels follow the same locale selection as the in-app
// activity feed. Android's matching strings cover OS-level notifications.
const _labels = <String, List<String>>{
  'ja': [
    "この端末のプッシュ通知",
    "作品広場やミッションの更新を受け取ります。オフにしてもアプリ内の通知は確認できます。",
    "新しいフォロワーが増えました",
    "作品がブックマークされました",
    "作品がリポストされました",
    "予約していた作品が公開されました",
    "新しいミッション達成通知があります",
  ],
  'en': [
    "Push notifications on this device",
    "Get updates from the plaza and missions. Notifications still appear in the app when this is off.",
    "You have a new follower",
    "A work was bookmarked",
    "A work was reposted",
    "Your scheduled work was published",
    "You have a new mission achievement",
  ],
  'es': [
    "Notificaciones push en este dispositivo",
    "Recibe novedades de la plaza y las misiones. Las notificaciones siguen disponibles en la aplicación al desactivar esta opción.",
    "Tienes un nuevo seguidor",
    "Han guardado una de tus obras",
    "Han compartido una de tus obras",
    "Se publicó tu obra programada",
    "Has alcanzado un nuevo objetivo de misión",
  ],
  'fr': [
    "Notifications push sur cet appareil",
    "Recevez les mises à jour de la place et des missions. Les notifications restent consultables dans l’application si cette option est désactivée.",
    "Vous avez un nouvel abonné",
    "Une de vos œuvres a été ajoutée aux favoris",
    "Une de vos œuvres a été repartagée",
    "Votre œuvre programmée a été publiée",
    "Vous avez accompli un nouvel objectif de mission",
  ],
  'ko': [
    "이 기기의 푸시 알림",
    "작품 광장과 미션 소식을 받습니다. 꺼도 앱에서 알림을 확인할 수 있습니다.",
    "새 팔로워가 생겼습니다",
    "작품이 북마크되었습니다",
    "작품이 리포스트되었습니다",
    "예약한 작품이 공개되었습니다",
    "새 미션 달성 알림이 있습니다",
  ],
  'zh': [
    "此设备的推送通知",
    "接收作品广场和任务的新消息。关闭后仍可在应用内查看通知。",
    "你有了新的关注者",
    "有作品被收藏了",
    "有作品被转发了",
    "你预约的作品已公开",
    "你有新的任务达成通知",
  ],
  'zh_Hant': [
    "此裝置的推播通知",
    "接收作品廣場和任務的新消息。關閉後仍可在應用程式內查看通知。",
    "你有了新的追蹤者",
    "有作品被收藏了",
    "有作品被轉發了",
    "你預約的作品已公開",
    "你有新的任務達成通知",
  ],
};

List<String> _for(AppLocalizations l10n) =>
    _labels[l10n.localeName] ??
    _labels[l10n.localeName.split('_').first] ??
    _labels['en']!;

String devicePushLabel(AppLocalizations l10n) => _for(l10n)[0];

String devicePushDescription(AppLocalizations l10n) => _for(l10n)[1];

String? communityNoticeText(AppLocalizations l10n, Object? kind) {
  final index = switch (kind) {
    'newFollower' => 2,
    'newBookmark' => 3,
    'newRepost' => 4,
    'scheduledRelease' => 5,
    'mission_achievement' => 6,
    _ => null,
  };
  return index == null ? null : _for(l10n)[index];
}

String? notificationRoute(Object? route) {
  if (route == communityNotificationsRoute || route == '/creator-missions') {
    return route as String;
  }
  if (route is String &&
      RegExp(r'^/community/work/[A-Za-z0-9_-]{11}$').hasMatch(route)) {
    return route;
  }
  return null;
}
