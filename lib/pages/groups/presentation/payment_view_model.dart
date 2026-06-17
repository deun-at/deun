import '../data/group_model.dart';

/// A single settlement entry: the counterparty's email plus the already-computed
/// [GroupSharesSummary] from `group_model.dart`. The settlement amount lives in
/// `summary.shareAmount` (negative = you owe them, positive = they owe you) and
/// is NEVER recomputed here.
class PaymentEntry {
  const PaymentEntry({required this.email, required this.summary});

  final String email;
  final GroupSharesSummary summary;

  /// Magnitude of the settlement (always non-negative).
  double get amount => summary.shareAmount.abs();
}

/// A payment method a payee can be paid through, derived purely from the
/// payee's [GroupSharesSummary] contact fields.
enum PaymentMethod { paypal, iban, cash }

/// Threshold below which a balance is treated as settled (half a cent), matching
/// the convention used across the group detail / share widgets.
const double _kSettledEpsilon = 0.005;

/// Partitions an already-computed [groupSharesSummary] into the members the
/// current user owes ("you pay", negative balances) and the members who owe the
/// current user ("owes you", positive balances).
///
/// Binds to `GroupSharesSummary.shareAmount` — settlement math is done in
/// `group_model.dart`; this only buckets and orders by descending magnitude.
class PaymentPartition {
  const PaymentPartition({required this.youPay, required this.owesYou});

  /// Members the current user owes (negative balances), largest first.
  final List<PaymentEntry> youPay;

  /// Members who owe the current user (positive balances), largest first.
  final List<PaymentEntry> owesYou;

  bool get isEmpty => youPay.isEmpty && owesYou.isEmpty;

  static PaymentPartition fromSummary(Map<String, GroupSharesSummary> groupSharesSummary) {
    final youPay = <PaymentEntry>[];
    final owesYou = <PaymentEntry>[];

    groupSharesSummary.forEach((email, summary) {
      if (summary.shareAmount <= -_kSettledEpsilon) {
        youPay.add(PaymentEntry(email: email, summary: summary));
      } else if (summary.shareAmount >= _kSettledEpsilon) {
        owesYou.add(PaymentEntry(email: email, summary: summary));
      }
      // Amounts within the epsilon are considered settled and omitted.
    });

    youPay.sort((a, b) => b.amount.compareTo(a.amount));
    owesYou.sort((a, b) => b.amount.compareTo(a.amount));

    return PaymentPartition(youPay: youPay, owesYou: owesYou);
  }
}

/// The payment methods the [summary]'s payee can actually be paid through,
/// filtered from their `paypalMe` / `iban` contact fields. Cash is always
/// offered. PayPal/IBAN appear only when the payee has a non-empty value.
List<PaymentMethod> paymentMethodsFor(GroupSharesSummary summary) {
  final methods = <PaymentMethod>[];
  if ((summary.paypalMe ?? '').trim().isNotEmpty) {
    methods.add(PaymentMethod.paypal);
  }
  if ((summary.iban ?? '').trim().isNotEmpty) {
    methods.add(PaymentMethod.iban);
  }
  methods.add(PaymentMethod.cash);
  return methods;
}
