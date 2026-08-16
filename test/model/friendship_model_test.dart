import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/currency_breakdown.dart';
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
      final normalized = isSettled(amount, Currency.eur) ? 0.0 : amount;
      expect(normalized, 0.0);
    });

    test('half a cent is outstanding and kept', () {
      // Was 0.01 here: the friend list used to swallow anything under a cent,
      // while the payment screen already offered it as a debt.
      const amount = 0.005;
      final normalized = isSettled(amount, Currency.eur) ? 0.0 : amount;
      expect(normalized, 0.005);
    });

    test('a negative settled shareAmount is normalized too', () {
      const amount = -0.004;
      final normalized = isSettled(amount, Currency.eur) ? 0.0 : amount;
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

  group('friendBalancesByCurrency', () {
    Friendship friend(List<CurrencyAmount> balances) {
      final f = Friendship();
      f.status = 'accepted';
      f.isIncomingRequest = false;
      f.balances = balances;
      return f;
    }

    test('a friendship spanning EUR and JPY exposes both, primary first', () {
      final f = friend(const [
        CurrencyAmount(Currency.eur, -25.50),
        CurrencyAmount(Currency.jpy, 3000),
      ]);
      expect(f.breakdown.primary, const CurrencyAmount(Currency.jpy, 3000));
      expect(f.breakdown.hiddenCount, 1);
      expect(f.currency, Currency.jpy);
      expect(f.shareAmount, 3000);
    });

    test(
      'direction follows the PRIMARY currency, never a cross-currency sum',
      () {
        // The friend owes the user ¥3,000 while the user owes them €25.50. The
        // primary is JPY, so the friendship reads "owed", and no direction is
        // inferred from 3000 - 25.5.
        final f = friend(const [
          CurrencyAmount(Currency.eur, -25.50),
          CurrencyAmount(Currency.jpy, 3000),
        ]);
        expect(f.shareAmount, greaterThan(0));
        // Each currency keeps its own sign in the expanded rows.
        expect(f.breakdown.others.single.amount, lessThan(0));
      },
    );

    test(
      'contributions in the same currency are summed, then rounded once',
      () {
        final f = friend(const [
          CurrencyAmount(Currency.eur, 10.005),
          CurrencyAmount(Currency.eur, 10.005),
        ]);
        expect(f.shareAmount, 20.01);
        expect(f.breakdown.isSingleCurrency, isTrue);
      },
    );

    test('a settled friendship reports exactly 0 with no disclosure', () {
      final f = friend(const [
        CurrencyAmount(Currency.eur, 0.004),
        CurrencyAmount(Currency.eur, -0.004),
      ]);
      expect(f.shareAmount, 0);
      expect(f.breakdown.hiddenCount, 0);
    });

    test('a friend with no mutual balance is EUR zero, single-currency', () {
      final f = friend(const []);
      expect(f.shareAmount, 0);
      expect(f.currency, Currency.eur);
      expect(f.breakdown.isSingleCurrency, isTrue);
    });

    test('the list form folds several friendships into one breakdown', () {
      final b = friendBalancesByCurrency([
        friend(const [CurrencyAmount(Currency.eur, 10)]),
        friend(const [
          CurrencyAmount(Currency.eur, 5),
          CurrencyAmount(Currency.usd, 40),
        ]),
      ]);
      expect(b.primary, const CurrencyAmount(Currency.usd, 40));
      expect(b.others, const [CurrencyAmount(Currency.eur, 15)]);
    });

    test('setting balances again invalidates the cached breakdown', () {
      final f = friend(const [CurrencyAmount(Currency.eur, 10)]);
      expect(f.shareAmount, 10);
      f.balances = const [CurrencyAmount(Currency.jpy, 500)];
      expect(f.currency, Currency.jpy);
      expect(f.shareAmount, 500);
    });
  });
}
