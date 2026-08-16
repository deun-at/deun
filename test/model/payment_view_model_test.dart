import 'package:deun/helper/currency.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/payment_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

GroupSharesSummary _summary({
  String displayName = 'Sam',
  String? paypalMe,
  String? iban,
  required double shareAmount,
}) {
  final s = GroupSharesSummary();
  s.displayName = displayName;
  s.paypalMe = paypalMe;
  s.iban = iban;
  s.shareAmount = shareAmount;
  return s;
}

void main() {
  group('PaymentPartition.fromSummary', () {
    test('negative balances go to youPay, positive to owesYou', () {
      final partition = PaymentPartition.fromSummary({
        'a@test.com': _summary(displayName: 'A', shareAmount: -10.0),
        'b@test.com': _summary(displayName: 'B', shareAmount: 25.0),
      }, currency: Currency.eur);

      expect(partition.youPay.map((e) => e.email), ['a@test.com']);
      expect(partition.owesYou.map((e) => e.email), ['b@test.com']);
    });

    test('amount getter is the magnitude (always non-negative)', () {
      final partition = PaymentPartition.fromSummary({
        'a@test.com': _summary(shareAmount: -12.34),
      }, currency: Currency.eur);
      expect(partition.youPay.single.amount, 12.34);
    });

    test('balances within half a cent are treated as settled and omitted', () {
      final partition = PaymentPartition.fromSummary({
        'a@test.com': _summary(shareAmount: 0.004),
        'b@test.com': _summary(shareAmount: -0.004),
      }, currency: Currency.eur);
      expect(partition.isEmpty, isTrue);
    });

    test('youPay is sorted by descending magnitude', () {
      final partition = PaymentPartition.fromSummary({
        'small@test.com': _summary(shareAmount: -5.0),
        'big@test.com': _summary(shareAmount: -50.0),
        'mid@test.com': _summary(shareAmount: -20.0),
      }, currency: Currency.eur);
      expect(partition.youPay.map((e) => e.email), [
        'big@test.com',
        'mid@test.com',
        'small@test.com',
      ]);
    });

    test('owesYou is sorted by descending magnitude', () {
      final partition = PaymentPartition.fromSummary({
        'small@test.com': _summary(shareAmount: 5.0),
        'big@test.com': _summary(shareAmount: 50.0),
      }, currency: Currency.eur);
      expect(partition.owesYou.map((e) => e.email), [
        'big@test.com',
        'small@test.com',
      ]);
    });

    test('empty summary yields an empty partition', () {
      expect(
        PaymentPartition.fromSummary({}, currency: Currency.eur).isEmpty,
        isTrue,
      );
    });

    // payback-on-behalf: a payback naming a soft-removed member is rejected
    // before any write, so the settle-up surface must not offer one a row —
    // its Pay button could only throw.
    test('a soft-removed counterparty is offered in neither bucket', () {
      final partition = PaymentPartition.fromSummary(
        {
          'gone@test.com': _summary(displayName: 'Gone', shareAmount: -10.0),
          'owes@test.com': _summary(displayName: 'Owes', shareAmount: 10.0),
          'left@test.com': _summary(displayName: 'Left', shareAmount: 25.0),
        },
        removedEmails: {'gone@test.com', 'left@test.com'},
        currency: Currency.eur,
      );

      expect(partition.youPay, isEmpty);
      expect(partition.owesYou.map((e) => e.email), ['owes@test.com']);
    });

    test('a group whose only outstanding balance is with a removed member '
        'offers nothing to settle', () {
      expect(
        PaymentPartition.fromSummary(
          {'gone@test.com': _summary(shareAmount: -10.0)},
          removedEmails: {'gone@test.com'},
          currency: Currency.eur,
        ).isEmpty,
        isTrue,
      );
    });

    // payback-on-behalf review: removal is gated on the member's NET group
    // balance while these rows are PAIRWISE, so a member who was settled overall
    // can still be soft-removed carrying a live debt with one person. Dropping
    // that balance from every bucket made `isEmpty` — and with it the screen's
    // "all settled" state — claim a group was square while the overall hero
    // still showed a non-zero amount.
    test(
      'an outstanding balance with a removed member is reported, not lost',
      () {
        final partition = PaymentPartition.fromSummary(
          {'gone@test.com': _summary(displayName: 'Gone', shareAmount: -10.0)},
          removedEmails: {'gone@test.com'},
          currency: Currency.eur,
        );

        expect(partition.stranded.single.email, 'gone@test.com');
        expect(partition.stranded.single.amount, 10.0);
        // Still not settle-able from this screen…
        expect(partition.isEmpty, isTrue);
        // …but the screen is NOT all settled.
        expect(partition.isFullySettled, isFalse);
      },
    );

    test('a settled balance with a removed member is not stranded either', () {
      final partition = PaymentPartition.fromSummary(
        {'gone@test.com': _summary(shareAmount: 0.004)},
        removedEmails: {'gone@test.com'},
        currency: Currency.eur,
      );

      expect(partition.stranded, isEmpty);
      expect(partition.isFullySettled, isTrue);
    });

    test('stranded balances are sorted by descending magnitude', () {
      final partition = PaymentPartition.fromSummary(
        {
          'small@test.com': _summary(shareAmount: -5.0),
          'big@test.com': _summary(shareAmount: 50.0),
        },
        removedEmails: {'small@test.com', 'big@test.com'},
        currency: Currency.eur,
      );

      expect(partition.stranded.map((e) => e.email), [
        'big@test.com',
        'small@test.com',
      ]);
    });

    test('an active counterparty is never stranded', () {
      final partition = PaymentPartition.fromSummary(
        {
          'here@test.com': _summary(shareAmount: -10.0),
          'gone@test.com': _summary(shareAmount: -10.0),
        },
        removedEmails: {'gone@test.com'},
        currency: Currency.eur,
      );

      expect(partition.youPay.map((e) => e.email), ['here@test.com']);
      expect(partition.stranded.map((e) => e.email), ['gone@test.com']);
      expect(partition.isFullySettled, isFalse);
    });

    test('a genuinely settled group is fully settled', () {
      expect(
        PaymentPartition.fromSummary({}, currency: Currency.eur).isFullySettled,
        isTrue,
      );
    });

    test('no removedEmails filters nothing, as every other caller expects', () {
      expect(
        PaymentPartition.fromSummary({
          'a@test.com': _summary(shareAmount: -10.0),
        }, currency: Currency.eur).youPay.single.email,
        'a@test.com',
      );
    });
  });

  group('paymentMethodsFor', () {
    test('cash is always available', () {
      expect(paymentMethodsFor(_summary(shareAmount: -10)), [
        PaymentMethod.cash,
      ]);
    });

    test('paypal appears only when paypalMe is non-empty', () {
      expect(paymentMethodsFor(_summary(shareAmount: -10, paypalMe: 'sam')), [
        PaymentMethod.paypal,
        PaymentMethod.cash,
      ]);
    });

    test('iban appears only when iban is non-empty', () {
      expect(paymentMethodsFor(_summary(shareAmount: -10, iban: 'DE123')), [
        PaymentMethod.iban,
        PaymentMethod.cash,
      ]);
    });

    test('paypal present but iban absent → only paypal + cash', () {
      final methods = paymentMethodsFor(
        _summary(shareAmount: -10, paypalMe: 'sam', iban: ''),
      );
      expect(methods.contains(PaymentMethod.paypal), isTrue);
      expect(methods.contains(PaymentMethod.iban), isFalse);
      expect(methods.contains(PaymentMethod.cash), isTrue);
    });

    test('blank/whitespace contact fields are treated as absent', () {
      expect(
        paymentMethodsFor(
          _summary(shareAmount: -10, paypalMe: '   ', iban: ''),
        ),
        [PaymentMethod.cash],
      );
    });

    test('all methods when both contact fields are present', () {
      expect(
        paymentMethodsFor(
          _summary(shareAmount: -10, paypalMe: 'sam', iban: 'DE123'),
        ),
        [PaymentMethod.paypal, PaymentMethod.iban, PaymentMethod.cash],
      );
    });
  });
}
