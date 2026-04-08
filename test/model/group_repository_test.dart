import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/groups/data/group_repository.dart';

void main() {
  group('GroupRepository.decodeGroupMembersString', () {
    test('parses valid JSON with multiple members', () {
      final json =
          '[{"email":"a@b.com","display_name":"Alice"},{"email":"c@d.com","display_name":"Bob"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(2));
      expect(result[0]['email'], 'a@b.com');
      expect(result[0]['display_name'], 'Alice');
      expect(result[1]['email'], 'c@d.com');
      expect(result[1]['display_name'], 'Bob');
    });

    test('parses single member', () {
      final json = '[{"email":"solo@test.com","display_name":"Solo"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['email'], 'solo@test.com');
    });

    test('preserves is_guest and is_guest_pending flags', () {
      final json =
          '[{"email":"guest+1@guest.invalid","display_name":"Guest","is_guest":true,"is_guest_pending":false}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result[0]['is_guest'], true);
      expect(result[0]['is_guest_pending'], false);
    });

    test('preserves pending guest entries', () {
      final json =
          '[{"email":"","display_name":"New Guest","is_guest_pending":true}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['is_guest_pending'], true);
      expect(result[0]['display_name'], 'New Guest');
    });

    test('handles members with extra fields gracefully', () {
      final json =
          '[{"email":"a@b.com","display_name":"Alice","some_future_field":"value"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['email'], 'a@b.com');
      expect(result[0]['some_future_field'], 'value');
    });

    test('handles members with missing optional fields', () {
      final json = '[{"email":"a@b.com","display_name":"Alice"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result[0]['is_guest'], isNull);
      expect(result[0]['username'], isNull);
    });
  });
}
