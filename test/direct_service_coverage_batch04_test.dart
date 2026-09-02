import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/performance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityService direct coverage', () {
    test('bookmark ordering tags locks visibility follow lists and notifications work', () {
      final service = CommunityService();
      final first = service.works.first;
      final second = service.works[1];

      service.toggleBookmark(first.id);
      service.toggleBookmark(second.id);
      expect(service.bookmarkedIdsNewestFirst.take(2), [second.id, first.id]);
      service.toggleBookmark(first.id);
      service.toggleBookmark(first.id);
      expect(service.bookmarkedIdsNewestFirst.first, first.id,
          reason: 're-bookmark moves a work to newest position');

      const tag = 'direct-audit-tag';
      service.addTag(first.id, tag);
      expect(service.byId(first.id)!.tags, contains(tag));
      service.toggleTagLock(first.id, tag);
      expect(service.byId(first.id)!.lockedTags, contains(tag));
      service.removeTag(first.id, tag);
      expect(service.byId(first.id)!.tags, contains(tag),
          reason: 'locked tags cannot be removed');
      service.toggleTagLock(first.id, tag);
      service.removeTag(first.id, tag);
      expect(service.byId(first.id)!.tags, isNot(contains(tag)));

      final beforePublished = service.byId(first.id)!.isNiarimPublished;
      service.toggleNiarimVisibility(first.id);
      expect(service.byId(first.id)!.isNiarimPublished, !beforePublished);
      service.toggleNiarimVisibility(first.id);
      expect(service.byId(first.id)!.isNiarimPublished, beforePublished);

      final otherAuthor = service.works
          .map((w) => w.authorId)
          .firstWhere((id) => id != kDummySelfAuthorId);
      final beforeFollowerCount = service.followerCountOf(otherAuthor);
      service.toggleFavoriteAuthor(otherAuthor);
      expect(service.isFavoriteAuthor(otherAuthor), isTrue);
      expect(service.followingIdsOf(kDummySelfAuthorId), contains(otherAuthor));
      expect(service.followingNamesOf(kDummySelfAuthorId),
          contains(service.authorNameOf(otherAuthor)));
      expect(service.followerIdsOf(otherAuthor), contains(kDummySelfAuthorId));
      expect(service.followerCountOf(otherAuthor), beforeFollowerCount + 1);
      service.toggleFavoriteAuthor(otherAuthor);
      expect(service.isFavoriteAuthor(otherAuthor), isFalse);

      final publicAuthor = service.works
          .map((w) => w.authorId)
          .toSet()
          .firstWhere(service.isFollowersPublic, orElse: () => kDummySelfAuthorId);
      if (!service.isFollowersPublic(publicAuthor)) {
        service.setSelfFollowersPublic(true);
      }
      final visibleIds = service.visibleFollowerIdsOf(publicAuthor);
      final visibleNames = service.visibleFollowerNamesOf(publicAuthor);
      expect(visibleNames.length, visibleIds.length);
      for (var i = 0; i < visibleIds.length; i++) {
        expect(visibleNames[i], service.authorNameOf(visibleIds[i]) ?? visibleIds[i]);
      }

      final unread = service.unreadFollowNotificationCount;
      if (unread > 0) {
        service.markAllFollowNotificationsRead();
        expect(service.unreadFollowNotificationCount, 0);
        expect(service.followNotifications.every((n) => n.isRead), isTrue);
      }
    });
  });

  group('PerformanceService direct coverage', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'quality_level': 'medium',
          'default_preset': 'medium',
        }));

    test('preset getters custom setters copy reset and persistence work', () async {
      final service = PerformanceService();
      await service.detectDeviceCapability();
      expect(service.qualityLevel, QualityLevel.medium);
      expect(service.defaultPreset, QualityLevel.medium);
      expect(service.tiltEnabled, isFalse);
      expect(service.prevOnionSkinFrames, 3);
      expect(service.nextOnionSkinFrames, 3);
      expect(service.saveMode, SaveMode.slot);
      expect(service.slotCount, 10);

      service.setQualityLevel(QualityLevel.high);
      expect(service.tiltEnabled, isTrue);
      expect(service.prevOnionSkinFrames, 5);
      expect(service.nextOnionSkinFrames, 5);
      expect(service.saveMode, SaveMode.tree);
      expect(service.slotCount, 0);

      service.setQualityLevel(QualityLevel.custom);
      service.setCustomTilt(true);
      service.setCustomShowPrev(false);
      service.setCustomShowNext(false);
      service.setCustomOnionSkinPrev(7);
      service.setCustomOnionSkinNext(8);
      service.setCustomSaveMode(SaveMode.tree);
      service.setCustomSlotCount(4);
      await Future<void>.delayed(Duration.zero);
      expect(service.tiltEnabled, isTrue);
      expect(service.showPrevOnion, isFalse);
      expect(service.showNextOnion, isFalse);
      expect(service.prevOnionSkinFrames, 7);
      expect(service.nextOnionSkinFrames, 8);
      expect(service.saveMode, SaveMode.tree);
      expect(service.slotCount, 4);

      service.copyPresetToCustom(QualityLevel.low);
      expect(service.tiltEnabled, isFalse);
      expect(service.showPrevOnion, isTrue);
      expect(service.showNextOnion, isTrue);
      expect(service.prevOnionSkinFrames, 1);
      expect(service.nextOnionSkinFrames, 1);
      expect(service.saveMode, SaveMode.slot);
      expect(service.slotCount, 5);

      service.copyPresetToCustom(QualityLevel.high);
      expect(service.tiltEnabled, isTrue);
      expect(service.prevOnionSkinFrames, 5);
      expect(service.saveMode, SaveMode.tree);

      service.resetCustomToDefault();
      expect(service.tiltEnabled, isFalse);
      expect(service.prevOnionSkinFrames, 3);
      expect(service.nextOnionSkinFrames, 3);
      expect(service.saveMode, SaveMode.slot);
      expect(service.slotCount, 10);

      await Future<void>.delayed(Duration.zero);
      final restored = PerformanceService();
      await restored.detectDeviceCapability();
      expect(restored.qualityLevel, QualityLevel.custom);
      expect(restored.tiltEnabled, isFalse);
      expect(restored.prevOnionSkinFrames, 3);
      expect(restored.nextOnionSkinFrames, 3);
      expect(restored.saveMode, SaveMode.slot);
      expect(restored.slotCount, 10);
    });
  });
}
