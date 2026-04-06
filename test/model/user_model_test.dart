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
  });
}
