import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/users/user_model.dart';

void main() {
  group('SupaUser.fromJson', () {
    test('creates with required fields', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test User',
      });

      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.isGuest, false);
    });

    test('creates with all fields', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'user_id': 'uid123',
        'first_name': 'Test',
        'last_name': 'User',
        'display_name': 'Test User',
        'username': 'testuser',
        'username_code': '1234',
        'paypal_me': 'testuser',
        'iban': 'DE89370400440532013000',
        'locale': 'de',
        'created_at': '2024-03-15T10:00:00',
        'is_guest': true,
      });

      expect(user.email, 'test@example.com');
      expect(user.userId, 'uid123');
      expect(user.firstName, 'Test');
      expect(user.lastName, 'User');
      expect(user.displayName, 'Test User');
      expect(user.username, 'testuser');
      expect(user.usernameCode, '1234');
      expect(user.paypalMe, 'testuser');
      expect(user.iban, 'DE89370400440532013000');
      expect(user.locale, 'de');
      expect(user.isGuest, true);
    });

    test('isGuest defaults to false', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test',
      });

      expect(user.isGuest, false);
    });

    test('nullable fields are null when missing', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test',
      });

      expect(user.userId, isNull);
      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
      expect(user.paypalMe, isNull);
      expect(user.iban, isNull);
      expect(user.locale, isNull);
    });
  });

  group('SupaUserX.fullUsername', () {
    test('returns username#code when both set', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test',
        'username': 'alex',
        'username_code': '1234',
      });

      expect(user.fullUsername, 'alex#1234');
    });

    test('returns displayName when username is null', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test User',
      });

      expect(user.fullUsername, 'Test User');
    });
  });

  group('SupaUserX.needsOnboarding', () {
    test('true when username is null', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test',
      });

      expect(user.needsOnboarding, true);
    });

    test('true when username is empty', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test',
        'username': '',
      });

      expect(user.needsOnboarding, true);
    });

    test('false when username is set', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test',
        'username': 'alex',
        'username_code': '1234',
      });

      expect(user.needsOnboarding, false);
    });
  });

  group('SupaUser.fromJson displayName default', () {
    test('defaults to empty string when display_name is missing', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
      });

      expect(user.displayName, '');
    });

    test('defaults to empty string when display_name is null', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': null,
      });

      expect(user.displayName, '');
    });

    test('uses provided display_name when present', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Alice',
      });

      expect(user.displayName, 'Alice');
    });
  });

  group('SupaUser.fromJson edge cases', () {
    test('guest user with minimal fields', () {
      final user = SupaUser.fromJson({
        'email': 'guest+123@guest.invalid',
        'display_name': 'Guest',
        'is_guest': true,
      });

      expect(user.email, 'guest+123@guest.invalid');
      expect(user.isGuest, true);
      expect(user.userId, isNull);
      expect(user.username, isNull);
    });

    test('empty string fields are preserved not nulled', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': '',
        'username': '',
      });

      expect(user.displayName, '');
      expect(user.username, '');
    });
  });

  group('SupaUserX.fullUsername with default displayName', () {
    test('returns empty string when no username and no displayName', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
      });

      expect(user.fullUsername, '');
    });

    test('returns displayName when username is set but code is null', () {
      final user = SupaUser.fromJson({
        'email': 'test@example.com',
        'display_name': 'Test',
        'username': 'alex',
      });

      expect(user.fullUsername, 'Test');
    });
  });

  group('SupaUser equality', () {
    test('two users with same fields are equal', () {
      final a = SupaUser(email: 'a@b.com', displayName: 'A');
      final b = SupaUser(email: 'a@b.com', displayName: 'A');

      expect(a, equals(b));
    });

    test('different email means not equal', () {
      final a = SupaUser(email: 'a@b.com', displayName: 'A');
      final b = SupaUser(email: 'x@b.com', displayName: 'A');

      expect(a, isNot(equals(b)));
    });

    test('copyWith preserves other fields', () {
      final user = SupaUser(
        email: 'test@example.com',
        displayName: 'Test',
        locale: 'de',
        isGuest: true,
      );

      final updated = user.copyWith(displayName: 'Updated');

      expect(updated.displayName, 'Updated');
      expect(updated.email, 'test@example.com');
      expect(updated.locale, 'de');
      expect(updated.isGuest, true);
    });
  });

  group('SupaUser.toJson', () {
    test('round-trip preserves all fields', () {
      final original = SupaUser(
        email: 'test@example.com',
        displayName: 'Test User',
        userId: 'uid123',
        isGuest: true,
        locale: 'de',
      );

      final json = original.toJson();
      final restored = SupaUser.fromJson(json);

      expect(restored.email, original.email);
      expect(restored.displayName, original.displayName);
      expect(restored.userId, original.userId);
      expect(restored.isGuest, original.isGuest);
      expect(restored.locale, original.locale);
    });

    test('round-trip with default displayName', () {
      final original = SupaUser(email: 'test@example.com');

      final json = original.toJson();
      final restored = SupaUser.fromJson(json);

      expect(restored.displayName, '');
      expect(restored.email, 'test@example.com');
      expect(restored.isGuest, false);
    });
  });
}
