import 'package:deun/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep links keep their allowlist', () {
    const accepted = [
      '/group/join?groupId=123e4567-e89b-12d3-a456-426614174000',
      '/group/join?groupId=123e4567-e89b-12d3-a456-426614174000&name=Trip',
      '/friend/accept?email=maya@deun.app',
      '/friend/accept?u=maya&c=4821',
      '/group',
      '/friend',
      '/setting',
      '/setting/privacy-policy',
      '/setting/contact',
    ];
    const rejected = [
      '/dev/gallery',
      '/group/details',
      '/group/details/expense',
      '/update-password',
      '/setting/statistics',
      '/group/join',
      '/group/join?groupId=not-a-uuid',
      '/friend/accept',
      '/friend/accept?email=not-an-email',
      '/friend/accept?u=maya',
      '/friend/accept?u=&c=4821',
      '',
    ];
    for (final link in accepted) {
      expect(validateDeepLink(link), link, reason: '$link is allowlisted');
    }
    for (final link in rejected) {
      expect(validateDeepLink(link), isNull, reason: '$link is rejected');
    }
  });
}
