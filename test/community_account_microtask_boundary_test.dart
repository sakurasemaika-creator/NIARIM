import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_models.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final oldPrivate = <String, dynamic>{
  'workId': 'old-private',
  'authorId': 'old-owner',
  'channelName': 'Synthetic old',
  'title': 'Private synthetic fixture',
  'postedAt': '2026-10-22T00:00:00Z',
  'isNiarimPublished': false,
};

class QueuedAccountApi extends CommunityApi {
  QueuedAccountApi(this.switchAccount)
    : super(NiarimApiClient(baseUrl: 'https://example.invalid'));
  final void Function() switchAccount;

  @override
  Future<ApiMyWorks> myWorks({String? cursor}) {
    switchAccount();
    return Future.value(
      ApiMyWorks.fromJson({
        'authorId': 'old-owner',
        'works': [oldPrivate],
      }),
    );
  }

  @override
  Future<ApiWork> updateWorkAiImageVideoDisclosure(
    String id, {
    required bool containsGenerativeAiImageOrVideo,
  }) {
    switchAccount();
    return Future.value(ApiWork.fromJson(oldPrivate));
  }

  @override
  Future<ApiWork> updateWorkVisibility(
    String id, {
    required bool isNiarimPublished,
  }) {
    switchAccount();
    return Future.value(ApiWork.fromJson(oldPrivate));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'synchronous and queued account changes cannot restore old owner data',
    () async {
      final failures = <String, String>{};
      for (final mode in ['owner', 'ai', 'visibility']) {
        for (var depth = 0; depth < 8; depth++) {
          SharedPreferences.setMockInitialValues({});
          late CommunityService service;
          final switched = Completer<void>();
          void enqueue(int left) {
            if (left > 0) {
              scheduleMicrotask(() => enqueue(left - 1));
              return;
            }
            service.forgetOwner();
            service.setCurrentUserId('new-owner');
            switched.complete();
          }

          service = CommunityService(
            api: QueuedAccountApi(() => enqueue(depth)),
          );
          await service.contentFiltersReady;
          service.setCurrentUserId('old-owner');
          service.applyServerWork(
            ApiWork.fromJson(oldPrivate).toCommunityWork(),
          );
          try {
            if (mode == 'owner') {
              await service.loadOwnWorks();
            } else if (mode == 'ai') {
              await service.setAiImageVideoDisclosure('old-private', true);
            } else {
              await service.setNiarimVisibility('old-private', true);
            }
          } on CommunityAccountChangedException {
            // Account-scoped cancellation is expected.
          }
          await switched.future;
          await Future<void>.delayed(Duration.zero);
          if (service.currentUserId != 'new-owner' ||
              service.byId('old-private') != null) {
            failures['$mode depth=$depth'] =
                'owner=${service.currentUserId}, old private retained=${service.byId('old-private') != null}';
          }
          service.dispose();
        }
      }
      expect(
        failures,
        isEmpty,
        reason:
            'Account generation must be checked before API invocation and immediately before store mutation.',
      );
    },
  );
}
