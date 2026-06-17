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
      });

      expect(partition.youPay.map((e) => e.email), ['a@test.com']);
      expect(partition.owesYou.map((e) => e.email), ['b@test.com']);
    });

    test('amount getter is the magnitude (always non-negative)', () {
      final partition = PaymentPartition.fromSummary({
        'a@test.com': _summary(shareAmount: -12.34),
      });
      expect(partition.youPay.single.amount, 12.34);
    });

    test('balances within half a cent are treated as settled and omitted', () {
      final partition = PaymentPartition.fromSummary({
        'a@test.com': _summary(shareAmount: 0.004),
        'b@test.com': _summary(shareAmount: -0.004),
      });
      expect(partition.isEmpty, isTrue);
    });

    test('youPay is sorted by descending magnitude', () {
      final partition = PaymentPartition.fromSummary({
        'small@test.com': _summary(shareAmount: -5.0),
        'big@test.com': _summary(shareAmount: -50.0),
        'mid@test.com': _summary(shareAmount: -20.0),
      });
      expect(
        partition.youPay.map((e) => e.email),
        ['big@test.com', 'mid@test.com', 'small@test.com'],
      );
    });

    test('owesYou is sorted by descending magnitude', () {
      final partition = PaymentPartition.fromSummary({
        'small@test.com': _summary(shareAmount: 5.0),
        'big@test.com': _summary(shareAmount: 50.0),
      });
      expect(partition.owesYou.map((e) => e.email), ['big@test.com', 'small@test.com']);
    });

    test('empty summary yields an empty partition', () {
      expect(PaymentPartition.fromSummary({}).isEmpty, isTrue);
    });
  });

  group('paymentMethodsFor', () {
    test('cash is always available', () {
      expect(paymentMethodsFor(_summary(shareAmount: -10)), [PaymentMethod.cash]);
    });

    test('paypal appears only when paypalMe is non-empty', () {
      expect(
        paymentMethodsFor(_summary(shareAmount: -10, paypalMe: 'sam')),
        [PaymentMethod.paypal, PaymentMethod.cash],
      );
    });

    test('iban appears only when iban is non-empty', () {
      expect(
        paymentMethodsFor(_summary(shareAmount: -10, iban: 'DE123')),
        [PaymentMethod.iban, PaymentMethod.cash],
      );
    });

    test('paypal present but iban absent → only paypal + cash', () {
      final methods = paymentMethodsFor(_summary(shareAmount: -10, paypalMe: 'sam', iban: ''));
      expect(methods.contains(PaymentMethod.paypal), isTrue);
      expect(methods.contains(PaymentMethod.iban), isFalse);
      expect(methods.contains(PaymentMethod.cash), isTrue);
    });

    test('blank/whitespace contact fields are treated as absent', () {
      expect(
        paymentMethodsFor(_summary(shareAmount: -10, paypalMe: '   ', iban: '')),
        [PaymentMethod.cash],
      );
    });

    test('all methods when both contact fields are present', () {
      expect(
        paymentMethodsFor(_summary(shareAmount: -10, paypalMe: 'sam', iban: 'DE123')),
        [PaymentMethod.paypal, PaymentMethod.iban, PaymentMethod.cash],
      );
    });
  });
}
