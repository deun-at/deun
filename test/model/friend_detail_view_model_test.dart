import 'package:deun/pages/friends/presentation/friend_detail_view_model.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

SupaUser _user({String? paypalMe, String? iban}) => SupaUser(
      email: 'sam@test.com',
      displayName: 'Sam',
      paypalMe: paypalMe,
      iban: iban,
    );

void main() {
  group('friendPayBackMethods', () {
    test('mark paid is always available', () {
      expect(friendPayBackMethods(_user()), [FriendPayBackMethod.markPaid]);
    });

    test('paypal appears only when paypalMe is non-empty', () {
      expect(
        friendPayBackMethods(_user(paypalMe: 'sam')),
        [FriendPayBackMethod.paypal, FriendPayBackMethod.markPaid],
      );
    });

    test('iban appears only when iban is non-empty', () {
      expect(
        friendPayBackMethods(_user(iban: 'DE123')),
        [FriendPayBackMethod.iban, FriendPayBackMethod.markPaid],
      );
    });

    test('paypal present but iban absent → only paypal + mark paid', () {
      final methods = friendPayBackMethods(_user(paypalMe: 'sam', iban: ''));
      expect(methods.contains(FriendPayBackMethod.paypal), isTrue);
      expect(methods.contains(FriendPayBackMethod.iban), isFalse);
      expect(methods.contains(FriendPayBackMethod.markPaid), isTrue);
    });

    test('blank/whitespace contact fields are treated as absent', () {
      expect(
        friendPayBackMethods(_user(paypalMe: '   ', iban: '')),
        [FriendPayBackMethod.markPaid],
      );
    });

    test('all methods when both contact fields are present', () {
      expect(
        friendPayBackMethods(_user(paypalMe: 'sam', iban: 'DE123')),
        [FriendPayBackMethod.paypal, FriendPayBackMethod.iban, FriendPayBackMethod.markPaid],
      );
    });
  });
}
