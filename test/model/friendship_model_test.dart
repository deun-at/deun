import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';

// Minimal mock for supabase.auth.currentUser?.email
// The Friendship model uses supabase global, so we test the sorting logic
// and the data structure separately.

void main() {
  group('Friendship sorting', () {
    test('sort puts non-zero amounts before zero amounts', () {
      // Test the sorting comparator logic extracted from FriendshipRepository
      final amounts = [0.0, 5.0, 0.0, -3.0, 10.0];
      amounts.sort((a, b) {
        if (a == 0 && b != 0) return 1;
        if (a != 0 && b == 0) return -1;
        if (a == 0 && b == 0) return 0;
        return b.compareTo(a);
      });
      expect(amounts, [10.0, 5.0, -3.0, 0.0, 0.0]);
    });

    test('sort orders by share amount descending when both non-zero', () {
      final amounts = [5.0, 10.0, 3.0, -2.0];
      amounts.sort((a, b) {
        if (a == 0 && b != 0) return 1;
        if (a != 0 && b == 0) return -1;
        if (a == 0 && b == 0) return 0;
        if (a == b) return 0;
        return b.compareTo(a);
      });
      expect(amounts, [10.0, 5.0, 3.0, -2.0]);
    });

    test('a settled shareAmount is normalized to zero', () {
      const amount = 0.004;
      final normalized = isSettled(amount) ? 0.0 : amount;
      expect(normalized, 0.0);
    });

    test('half a cent is outstanding and kept', () {
      // Was 0.01 here: the friend list used to swallow anything under a cent,
      // while the payment screen already offered it as a debt.
      const amount = 0.005;
      final normalized = isSettled(amount) ? 0.0 : amount;
      expect(normalized, 0.005);
    });

    test('a negative settled shareAmount is normalized too', () {
      const amount = -0.004;
      final normalized = isSettled(amount) ? 0.0 : amount;
      expect(normalized, 0.0);
    });
  });

  group('Friendship model fields', () {
    test('status values', () {
      final f = Friendship();
      f.status = 'pending';
      expect(f.status, 'pending');

      f.status = 'accepted';
      expect(f.status, 'accepted');
    });

    test('isIncomingRequest flag', () {
      final f = Friendship();
      f.isIncomingRequest = true;
      expect(f.isIncomingRequest, true);

      f.isIncomingRequest = false;
      expect(f.isIncomingRequest, false);
    });
  });
}
