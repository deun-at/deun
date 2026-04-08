import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';

void main() {
  group('GroupMember.loadDataFromJson', () {
    test('loads all fields', () {
      final member = GroupMember();
      member.loadDataFromJson({
        'group_id': 'g1',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'username': 'testuser',
        'username_code': '1234',
        'is_guest': false,
        'is_favorite': true,
      });

      expect(member.groupId, 'g1');
      expect(member.email, 'test@example.com');
      expect(member.displayName, 'Test User');
      expect(member.username, 'testuser');
      expect(member.usernameCode, '1234');
      expect(member.isGuest, false);
      expect(member.isFavorite, true);
    });

    test('is_favorite defaults to false when missing', () {
      final member = GroupMember();
      member.loadDataFromJson({
        'group_id': 'g1',
        'email': 'test@example.com',
        'display_name': 'Test',
        'is_guest': false,
      });

      expect(member.isFavorite, false);
    });

    test('is_favorite defaults to false when null', () {
      final member = GroupMember();
      member.loadDataFromJson({
        'group_id': 'g1',
        'email': 'test@example.com',
        'display_name': 'Test',
        'is_guest': false,
        'is_favorite': null,
      });

      expect(member.isFavorite, false);
    });

    test('guest member', () {
      final member = GroupMember();
      member.loadDataFromJson({
        'group_id': 'g1',
        'email': 'guest@deun.app',
        'display_name': 'Guest User',
        'is_guest': true,
        'is_favorite': false,
      });

      expect(member.isGuest, true);
    });
  });

  group('GroupMember.fullUsername', () {
    test('returns username#code when both set', () {
      final member = GroupMember();
      member.loadDataFromJson({
        'group_id': 'g1',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'username': 'testuser',
        'username_code': '1234',
        'is_guest': false,
        'is_favorite': false,
      });

      expect(member.fullUsername, 'testuser#1234');
    });

    test('returns displayName when username is null', () {
      final member = GroupMember();
      member.loadDataFromJson({
        'group_id': 'g1',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'is_guest': false,
        'is_favorite': false,
      });

      expect(member.fullUsername, 'Test User');
    });
  });

  group('GroupMember.toJson', () {
    test('round-trip preserves all fields', () {
      final member = GroupMember();
      member.loadDataFromJson({
        'group_id': 'g1',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'username': 'testuser',
        'username_code': '1234',
        'is_guest': false,
        'is_favorite': true,
      });

      final json = member.toJson();
      expect(json['group_id'], 'g1');
      expect(json['email'], 'test@example.com');
      expect(json['display_name'], 'Test User');
      expect(json['username'], 'testuser');
      expect(json['username_code'], '1234');
      expect(json['is_guest'], false);
      expect(json['is_favorite'], true);
    });
  });
}
