import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/community_service.dart';
import '../../widgets/responsive.dart';

/// フォロー通知一覧画面（Task#134継続：「フォローされたら通知が来る
/// ようにしてほしい」という要望を受けた実装）。
///
/// バックエンド未実装かつ実際のマルチユーザー環境が無いため、通知の
/// 中身はアプリ起動時に生成するダミーデータ（自分を既にフォローして
/// いるダミー作者を、過去に届いた通知として表示）のみで、新しい
/// フォローをリアルタイムに検知して通知を追加する仕組みは無い。
///
/// これはアプリ内通知（in-app notification）であり、端末のOS通知として
/// アプリを閉じていても届く「真のプッシュ通知」ではない。真のプッシュ
/// 通知にはFirebase Cloud Messaging等の導入と、他ユーザーの操作を検知
/// できるサーバー側の実装（16章）の両方が必要で、現状のNIARIMには
/// どちらも存在しない。詳細は`29_動画投稿・ランキング機能仕様.md`
/// 21.3節・22.6節を参照。
class CommunityFollowNotificationsScreen extends StatefulWidget {
  const CommunityFollowNotificationsScreen({super.key});

  @override
  State<CommunityFollowNotificationsScreen> createState() =>
      _CommunityFollowNotificationsScreenState();
}

class _CommunityFollowNotificationsScreenState
    extends State<CommunityFollowNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // 画面を開いたタイミングで全て既読にする（アプリ内通知の一般的な
    // 挙動。build中にnotifyListenersを誘発しないようフレーム後に行う）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityService>().markAllFollowNotificationsRead();
    });
  }

  String _formatDate(DateTime d) {
    final mo = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mo/$dd';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final notifications = context.watch<CommunityService>().followNotifications;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityFollowNotificationsTitle)),
      body: desktopCentered(
        context,
        notifications.isEmpty
            ? Center(
                child: Text(l10n.communityFollowNotificationsEmpty,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            : ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = notifications[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Text(n.followerName.substring(0, 1),
                          style: TextStyle(color: scheme.onPrimaryContainer)),
                    ),
                    title: Text(l10n.communityFollowNotificationBody(n.followerName)),
                    subtitle: Text(_formatDate(n.followedAt)),
                  );
                },
              ),
      ),
    );
  }
}
