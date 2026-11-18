import '../l10n/app_localizations.dart';

const communityNotificationsRoute = '/community/notifications';
const communityNotificationSettingsRoute = '/settings/notifications';
const communityMyWorksRoute = '/community/my-works';

enum CommunityPushCategory {
  publication;

  String get preferenceKey => 'push_notice_$name';
}

// Feature-local labels follow the same locale selection as the in-app
// activity feed. Android's matching strings cover OS-level notifications.
const _labels = <String, List<String>>{
  'ja': [
    "この端末のプッシュ通知",
    "作品広場やミッションの更新を受け取ります。オフにしてもアプリ内の通知は確認できます。",
    "予約していた作品が公開されました",
    "新しいミッション達成通知があります",
    "作品が投稿されました",
    "作品が公開されました",
    "作品の投稿・公開通知",
  ],
  'en': [
    "Push notifications on this device",
    "Get updates from the plaza and missions. Notifications still appear in the app when this is off.",
    "Your scheduled work was published",
    "You have a new mission achievement",
    "Your work was posted",
    "Your work was published",
    "Work posts and publications",
  ],
  'es': [
    "Notificaciones push en este dispositivo",
    "Recibe novedades de la plaza y las misiones. Las notificaciones siguen disponibles en la aplicación al desactivar esta opción.",
    "Se publicó tu obra programada",
    "Has alcanzado un nuevo objetivo de misión",
    "Se registró tu obra",
    "Se publicó tu obra",
    "Registro y publicación de obras",
  ],
  'fr': [
    "Notifications push sur cet appareil",
    "Recevez les mises à jour de la place et des missions. Les notifications restent consultables dans l’application si cette option est désactivée.",
    "Votre œuvre programmée a été publiée",
    "Vous avez accompli un nouvel objectif de mission",
    "Votre œuvre a été enregistrée",
    "Votre œuvre a été publiée",
    "Enregistrement et publication des œuvres",
  ],
  'ko': [
    "이 기기의 푸시 알림",
    "작품 광장과 미션 소식을 받습니다. 꺼도 앱에서 알림을 확인할 수 있습니다.",
    "예약한 작품이 공개되었습니다",
    "새 미션 달성 알림이 있습니다",
    "작품이 게시되었습니다",
    "작품이 공개되었습니다",
    "작품 게시 및 공개 알림",
  ],
  'zh': [
    "此设备的推送通知",
    "接收作品广场和任务的新消息。关闭后仍可在应用内查看通知。",
    "你预约的作品已公开",
    "你有新的任务达成通知",
    "你的作品已投稿",
    "你的作品已公开",
    "作品投稿与公开",
  ],
  'zh_Hant': [
    "此裝置的推播通知",
    "接收作品廣場和任務的新消息。關閉後仍可在應用程式內查看通知。",
    "你預約的作品已公開",
    "你有新的任務達成通知",
    "你的作品已投稿",
    "你的作品已公開",
    "作品投稿與公開",
  ],
};

List<String> _for(AppLocalizations l10n) =>
    _labels[l10n.localeName] ??
    _labels[l10n.localeName.split('_').first] ??
    _labels['en']!;

String devicePushLabel(AppLocalizations l10n) => _for(l10n)[0];

String devicePushDescription(AppLocalizations l10n) => _for(l10n)[1];

const _noticeTextIndices = {
  'scheduledRelease': 2,
  'mission_achievement': 3,
  'workPosted': 4,
  'workPublicationConfirmed': 5,
};

bool supportsNotificationType(Object? kind) =>
    kind == null || _noticeTextIndices.containsKey(kind);

String? communityNoticeText(AppLocalizations l10n, Object? kind) {
  final index = _noticeTextIndices[kind];
  return index == null ? null : _for(l10n)[index];
}

String publicationPushLabel(AppLocalizations l10n) => _for(l10n)[6];

String? notificationRoute(Object? route) {
  if (route == communityNotificationsRoute ||
      route == communityMyWorksRoute ||
      route == '/creator-missions') {
    return route as String;
  }
  if (route is String &&
      RegExp(r'^/community/work/[A-Za-z0-9_-]{11}$').hasMatch(route)) {
    return route;
  }
  return null;
}
