import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/community_milestone_store.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _PausedMilestoneStore extends InMemorySharedPreferencesStore {
  _PausedMilestoneStore(super.data) : super.withData();
  final started = Completer<void>();
  Completer<void>? gate;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final pending = gate;
    if (pending != null &&
        key == 'flutter.${CommunityMilestoneStore.prefix}old') {
      gate = null;
      started.complete();
      await pending.future;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dispose in [false, true]) {
    test(
      'late milestone read completion cannot mutate ${dispose ? 'disposed service' : 'new account'}',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final store = _PausedMilestoneStore({
          'flutter.${CommunityMilestoneStore.prefix}old': jsonEncode({
            'events': [
              CommunityMilestoneEvent(
                id: 'old-private',
                isFollower: false,
                count: 50,
                createdAt: DateTime.utc(2026, 10, 29),
                workTitle: 'PRIVATE OLD TITLE',
              ).toJson(),
            ],
          }),
        });
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = store;
        final service = CommunityService();
        var disposed = false;
        addTearDown(() {
          if (!disposed) service.dispose();
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = previous;
        });
        await service.contentFiltersReady;
        service.setCurrentUserId('old');
        await service.loadMilestones();
        expect(service.milestoneNotifications.single.read, isFalse);
        final gate = Completer<void>();
        store.gate = gate;
        final pending = service.markMilestonesRead();
        await store.started.future;
        if (dispose) {
          service.dispose();
          disposed = true;
        } else {
          service.forgetOwner();
          service.setCurrentUserId('new');
          await service.loadMilestones();
          expect(service.milestoneNotifications, isEmpty);
        }
        gate.complete();
        await pending;
        if (dispose) {
          expect(service.milestoneNotifications.single.read, isFalse);
        } else {
          expect(service.currentUserId, 'new');
          expect(
            service.milestoneNotifications,
            isEmpty,
            reason:
                'The old private work title must not appear in the next account',
          );
        }
      },
    );
  }
}
