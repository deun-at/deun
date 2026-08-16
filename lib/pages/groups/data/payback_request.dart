import 'package:deun/l10n/app_localizations.dart';

import 'group_member_model.dart';

/// Why a payback was refused, decided before anything is written.
enum PaybackRejection {
  /// Payer and payee are the same member — such a row moves no money and would
  /// only pollute the ledger.
  samePerson,

  /// The payer has no active `group_member` row in the group (never a member, or
  /// soft-removed).
  payerNotInGroup,

  /// The payee has no active `group_member` row in the group.
  payeeNotInGroup,

  /// Zero or negative: there is nothing to record.
  nonPositiveAmount,
}

/// What recording a payback should do, decided before anything is written.
///
/// Mirrors [MemberRemovalOutcome]'s shape deliberately: the decision is pure and
/// unit-testable, and the repository only applies it.
sealed class PaybackPlan {
  const PaybackPlan();
}

/// The payback must not be written. [displayName] names the member the message
/// is about (empty for reasons that name nobody).
class PaybackRejected extends PaybackPlan {
  const PaybackRejected({required this.reason, this.displayName = ''});

  final PaybackRejection reason;
  final String displayName;

  /// The copy to surface. One switch, so a new reason cannot ship without one.
  String message(AppLocalizations l10n) => switch (reason) {
    PaybackRejection.samePerson => l10n.paybackRecordSamePersonError,
    PaybackRejection.payerNotInGroup || PaybackRejection.payeeNotInGroup =>
      l10n.paybackRecordNotMemberError(displayName),
    PaybackRejection.nonPositiveAmount => l10n.paybackRecordAmountError,
  };
}

/// The payback may be written exactly as described here.
class PaybackAccepted extends PaybackPlan {
  const PaybackAccepted({
    required this.paidBy,
    required this.paidFor,
    required this.amount,
    required this.recordedBy,
    required this.paidByDisplayName,
    required this.paidForDisplayName,
    required this.recordedByDisplayName,
    required this.payerIsGuest,
  });

  final String paidBy;
  final String paidFor;
  final double amount;

  /// The signed-in user who is recording this. Equal to [paidBy] on the
  /// self-payback path.
  final String recordedBy;

  final String paidByDisplayName;
  final String paidForDisplayName;
  final String recordedByDisplayName;

  /// A guest has no device, so no push can reach them.
  final bool payerIsGuest;

  /// True when someone other than the payer is recording this payment.
  bool get isOnBehalf => paidBy != recordedBy;

  /// Both parties whose money moved. Because there is no owner concept, the
  /// deterrent is visibility — the payee ALWAYS hears about it, and so does the
  /// payer whenever they are a real user.
  ///
  /// `sendNotification` strips the current user from every receiver set, so on
  /// the self-payback path this reduces to exactly `{paidFor}` — the set that
  /// path has always sent.
  Set<String> get notificationReceivers => {paidFor, if (!payerIsGuest) paidBy};
}

/// Thrown by [GroupRepository.payBack] when the plan is a [PaybackRejected], so
/// a caller that skipped the pre-flight check still cannot write.
class PaybackRejectedException implements Exception {
  const PaybackRejectedException(this.rejection);

  final PaybackRejected rejection;

  @override
  String toString() => 'PaybackRejectedException(${rejection.reason.name})';
}

/// Decides whether "[paidBy] paid [paidFor] [amount]", recorded by
/// [recordedBy], may be written against [members] (the group's FULL
/// `group_member` roster, soft-removed rows included — the distinction between
/// "never a member" and "removed" only exists if removed rows are present).
///
/// Pure: no Supabase, no context, no clock. Checks run in a fixed order —
/// same-person, payer, payee, amount — so the reason is deterministic when more
/// than one applies.
PaybackPlan resolvePayback({
  required String paidBy,
  required String paidFor,
  required double amount,
  required String recordedBy,
  required List<GroupMember> members,
}) {
  GroupMember? active(String email) {
    for (final member in members) {
      if (member.email == email && !member.isRemoved) return member;
    }
    return null;
  }

  // Names a member even when they are removed or unknown, so the block message
  // can say "Carol is no longer in this group" rather than echoing an email.
  String anyName(String email) {
    for (final member in members) {
      if (member.email == email) return member.displayName;
    }
    return email;
  }

  if (paidBy == paidFor) {
    return const PaybackRejected(reason: PaybackRejection.samePerson);
  }

  final payer = active(paidBy);
  if (payer == null) {
    return PaybackRejected(
      reason: PaybackRejection.payerNotInGroup,
      displayName: anyName(paidBy),
    );
  }

  final payee = active(paidFor);
  if (payee == null) {
    return PaybackRejected(
      reason: PaybackRejection.payeeNotInGroup,
      displayName: anyName(paidFor),
    );
  }

  if (amount <= 0) {
    return const PaybackRejected(reason: PaybackRejection.nonPositiveAmount);
  }

  return PaybackAccepted(
    paidBy: paidBy,
    paidFor: paidFor,
    amount: amount,
    recordedBy: recordedBy,
    paidByDisplayName: payer.displayName,
    paidForDisplayName: payee.displayName,
    recordedByDisplayName: anyName(recordedBy),
    payerIsGuest: payer.isGuest,
  );
}
