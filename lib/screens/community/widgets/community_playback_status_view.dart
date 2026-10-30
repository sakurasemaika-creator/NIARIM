import 'package:flutter/material.dart';
import '../../../services/api/community_api.dart';

/// Standalone, themed, localized alternative to a raw YouTube playback error.
/// Works inside the floating preview, detail view and future embedded player.
class CommunityPlaybackStatusView extends StatelessWidget {
  const CommunityPlaybackStatusView({
    super.key,
    required this.status,
    this.onRetry,
  });

  final CommunityPlaybackStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh_Hant' : locale.languageCode;
    final translations = _strings[language] ?? _strings['en']!;
    final index = switch (status) {
      CommunityPlaybackStatus.deleted => 0,
      CommunityPlaybackStatus.private => 1,
      CommunityPlaybackStatus.unavailable => 2,
      CommunityPlaybackStatus.unknown => 3,
      CommunityPlaybackStatus.checking => 4,
      CommunityPlaybackStatus.available => 4,
    };
    final title = translations[index * 2];
    final description = translations[index * 2 + 1];
    final icon = switch (status) {
      CommunityPlaybackStatus.deleted => Icons.delete_outline,
      CommunityPlaybackStatus.private => Icons.lock_outline,
      CommunityPlaybackStatus.unavailable => Icons.visibility_off_outlined,
      CommunityPlaybackStatus.unknown => Icons.cloud_off_outlined,
      CommunityPlaybackStatus.checking => Icons.hourglass_top_rounded,
      CommunityPlaybackStatus.available => Icons.play_circle_outline,
    };

    return Container(
      key: const Key('communityPlaybackStatusPanel'),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == CommunityPlaybackStatus.checking)
                SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: scheme.primary,
                  ),
                )
              else
                Icon(icon, size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                title,
                key: const Key('communityPlaybackStatusTitle'),
                maxLines: 3,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 4,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null &&
                  status != CommunityPlaybackStatus.checking) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('communityPlaybackRetry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(translations[10]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Title + explanation for deleted, private, unavailable, unknown, checking,
/// followed by "Retry". Never claim that a public API absence proves deletion.
const _strings = <String, List<String>>{
  'ja': [
    '動画は削除済みです', 'この動画は削除されているため再生できません。',
    'この動画は非公開です', '投稿者の公開設定により再生できません。',
    'この動画を利用できません', '削除または非公開の可能性があります。公開状態は確認できません。',
    '再生状態を確認できません', '通信や動画サービスの問題により確認できませんでした。',
    '動画の状態を確認中', '再生できるか確認しています。',
    '再確認',
  ],
  'en': [
    'Video deleted', 'This video has been deleted and cannot be played.',
    'Private video', 'This video cannot be played due to its privacy settings.',
    'Video unavailable', 'It may be deleted or private. Its status cannot be confirmed.',
    'Could not check the video', 'A connection or service issue prevented the check.',
    'Checking video', 'Checking whether this video is available.',
    'Try again',
  ],
  'es': [
    'Vídeo eliminado', 'Este vídeo se ha eliminado y no se puede reproducir.',
    'Vídeo privado', 'La configuración de privacidad impide reproducirlo.',
    'Vídeo no disponible', 'Puede estar eliminado o ser privado. No se puede confirmar.',
    'No se pudo comprobar', 'Un error de conexión o del servicio impidió la comprobación.',
    'Comprobando el vídeo', 'Comprobando si se puede reproducir.',
    'Reintentar',
  ],
  'fr': [
    'Vidéo supprimée', 'Cette vidéo a été supprimée et ne peut plus être lue.',
    'Vidéo privée', 'Les paramètres de confidentialité empêchent sa lecture.',
    'Vidéo indisponible', 'Elle peut être supprimée ou privée. Statut non confirmé.',
    'Vérification impossible', 'Un problème de connexion ou de service a empêché la vérification.',
    'Vérification en cours', 'Vérification de la disponibilité de la vidéo.',
    'Réessayer',
  ],
  'ko': [
    '삭제된 동영상', '삭제된 동영상으로 재생할 수 없습니다.',
    '비공개 동영상', '공개 설정으로 인해 재생할 수 없습니다.',
    '동영상을 사용할 수 없음', '삭제되었거나 비공개일 수 있습니다. 상태를 확인할 수 없습니다.',
    '상태 확인 실패', '네트워크 또는 서비스 문제로 확인하지 못했습니다.',
    '동영상 확인 중', '재생 가능 여부를 확인하고 있습니다.',
    '다시 확인',
  ],
  'zh': [
    '视频已删除', '此视频已删除，无法播放。',
    '视频不公开', '发布者的隐私设置禁止播放。',
    '视频不可用', '可能已删除或设为私密，无法确认状态。',
    '无法检查视频', '连接或服务故障导致检查失败。',
    '正在检查视频', '正在确认是否可以播放。',
    '重试',
  ],
  'zh_Hant': [
    '影片已刪除', '此影片已刪除，無法播放。',
    '私人影片', '發佈者的隱私設定禁止播放。',
    '影片無法使用', '可能已刪除或設為私人，無法確認狀態。',
    '無法檢查影片', '連線或服務問題導致檢查失敗。',
    '正在檢查影片', '正在確認是否可以播放。',
    '重試',
  ],
};
