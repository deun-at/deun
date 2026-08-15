import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_repository.dart';

void main() {
  group('GroupRepository.decodeGroupMembersString', () {
    test('parses valid JSON with multiple members', () {
      const json =
          '[{"email":"a@b.com","display_name":"Alice"},{"email":"c@d.com","display_name":"Bob"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(2));
      expect(result[0]['email'], 'a@b.com');
      expect(result[0]['display_name'], 'Alice');
      expect(result[1]['email'], 'c@d.com');
      expect(result[1]['display_name'], 'Bob');
    });

    test('parses single member', () {
      const json = '[{"email":"solo@test.com","display_name":"Solo"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['email'], 'solo@test.com');
    });

    test('preserves is_guest and is_guest_pending flags', () {
      const json =
          '[{"email":"guest+1@guest.invalid","display_name":"Guest","is_guest":true,"is_guest_pending":false}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result[0]['is_guest'], true);
      expect(result[0]['is_guest_pending'], false);
    });

    test('preserves pending guest entries', () {
      const json =
          '[{"email":"","display_name":"New Guest","is_guest_pending":true}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['is_guest_pending'], true);
      expect(result[0]['display_name'], 'New Guest');
    });

    test('handles members with extra fields gracefully', () {
      const json =
          '[{"email":"a@b.com","display_name":"Alice","some_future_field":"value"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['email'], 'a@b.com');
      expect(result[0]['some_future_field'], 'value');
    });

    test('handles members with missing optional fields', () {
      const json = '[{"email":"a@b.com","display_name":"Alice"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result[0]['is_guest'], isNull);
      expect(result[0]['username'], isNull);
    });
  });

  group('active/done balance filter', () {
    test('is built from the shared epsilon, not a literal', () {
      expect(
        GroupRepository.activeBalanceFilter,
        'total_share_amount.gte.0.005,total_share_amount.lte.-0.005',
      );
      expect(kSettledEpsilon, 0.005);
    });

    test('the tab threshold and the client predicate agree on 0.007', () {
      // 0.007 is >= the filter's 0.005 bound, so the group stays on the active
      // tab — and isSettled(0.007) is false, so every screen agrees with it.
      expect(isSettled(0.007), isFalse);
      expect(GroupRepository.activeBalanceFilter, contains('gte.0.005'));
    });
  });
}
