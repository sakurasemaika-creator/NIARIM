import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/community_service.dart';

void main() {
  test('ダミー作品でもタグは1作品10件まで', () {
    final service = CommunityService();
    final work = service.works.first;

    expect(CommunityService.maxTagsPerWork, 10);

    for (var i = 0; i < 20; i++) {
      if (service.byId(work.id)!.tags.length >= CommunityService.maxTagsPerWork) {
        break;
      }
      service.addTag(work.id, 'limit_test_$i');
    }

    final atLimit = service.byId(work.id)!;
    expect(atLimit.tags.length, CommunityService.maxTagsPerWork);

    service.addTag(work.id, 'overflow_tag');

    final afterOverflow = service.byId(work.id)!;
    expect(afterOverflow.tags.length, CommunityService.maxTagsPerWork);
    expect(afterOverflow.tags, isNot(contains('overflow_tag')));
  });
}
