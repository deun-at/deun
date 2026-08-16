import '../../../helper/helper.dart';
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

/// Partitions an already-computed [groupSharesSummary] into the members the
/// current user owes ("you pay", negative balances) and the members who owe the
/// current user ("owes you", positive balances).
///
/// Binds to `GroupSharesSummary.shareAmount` — settlement math is done in
/// `group_model.dart`; this only buckets, filters and orders by descending
/// magnitude.
class PaymentPartition {
  const PaymentPartition({
    required this.youPay,
    required this.owesYou,
    this.stranded = const [],
  });

  /// Members the current user owes (negative balances), largest first.
  final List<PaymentEntry> youPay;

  /// Members who owe the current user (positive balances), largest first.
  final List<PaymentEntry> owesYou;

  /// Soft-removed counterparties who still carry an outstanding balance,
  /// largest first.
  ///
  /// These are NOT settle-able from here — see [fromSummary] — but they are not
  /// invisible either: group-member-removal's contract keeps a removed member in
  /// the group-detail balance list ("a removed member stays in groupMembers, so
  /// the ledger and the balance list keep them"), and hiding an outstanding
  /// amount outright would leave the screen's overall hero contradicting a list
  /// that claims everything is settled.
  final List<PaymentEntry> stranded;

  /// True when there is nothing left to **settle from this screen**. Stranded
  /// balances are deliberately excluded: they are outstanding, but no Pay button
  /// can clear them.
  bool get isEmpty => youPay.isEmpty && owesYou.isEmpty;

  /// True when the screen has nothing at all to show — no settle-able row and no
  /// stranded balance. Only then is the group genuinely all settled.
  bool get isFullySettled => isEmpty && stranded.isEmpty;

  /// [removedEmails] are the group's soft-removed members
  /// (`Group.removedMemberEmails`). They are kept out of [youPay] / [owesYou]:
  /// payback-on-behalf rejects a payback naming a member who is no longer in the
  /// group — in `resolvePayback`, in `GroupRepository.payBack` and in `pay_back`
  /// — so a settle-up row for one could only offer a Pay button that throws. A
  /// balance stranded that way is cleared by adding the member back, not from
  /// here.
  ///
  /// It is still reported, in [stranded]: removal is gated on the member's *net*
  /// group balance while these rows are *pairwise*, so a member who was settled
  /// overall can leave a live debt with one particular person behind.
  /// `group_shares_summary` itself deliberately keeps them
  /// (group-member-removal), so the split lives at the settle-up surface.
  static PaymentPartition fromSummary(
    Map<String, GroupSharesSummary> groupSharesSummary, {
    Set<String> removedEmails = const {},
  }) {
    final youPay = <PaymentEntry>[];
    final owesYou = <PaymentEntry>[];
    final stranded = <PaymentEntry>[];

    groupSharesSummary.forEach((email, summary) {
      // Settled balances are omitted from every bucket.
      if (isSettled(summary.shareAmount)) return;
      if (removedEmails.contains(email)) {
        stranded.add(PaymentEntry(email: email, summary: summary));
        return;
      }
      if (summary.shareAmount < 0) {
        youPay.add(PaymentEntry(email: email, summary: summary));
      } else {
        owesYou.add(PaymentEntry(email: email, summary: summary));
      }
    });

    youPay.sort((a, b) => b.amount.compareTo(a.amount));
    owesYou.sort((a, b) => b.amount.compareTo(a.amount));
    stranded.sort((a, b) => b.amount.compareTo(a.amount));

    return PaymentPartition(
      youPay: youPay,
      owesYou: owesYou,
      stranded: stranded,
    );
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
