import 'expense_model.dart';

/// Whether an expense is itemized (more than one line item).
///
/// Mirrors the predicate the editor uses to choose its layout (E1-T2 used
/// `expenseEntries.length > 1`). The read view shows the "Review & claim"
/// banner for itemized expenses only.
bool isItemizedExpense(Expense expense) => expense.expenseEntries.length > 1;

/// One member's row in the read-view per-member breakdown.
///
/// [share] is the amount this member is responsible for (their slice of the
/// expense, taken straight from [Expense.groupMemberShareStatistic]). [net] is
/// their net position for this single expense: the payer lent everything they
/// covered for others (positive), everyone else owes their share (negative).
class MemberBreakdownEntry {
  const MemberBreakdownEntry({
    required this.email,
    required this.share,
    required this.net,
    required this.isPayer,
  });

  /// The member's email (also the avatar color key).
  final String email;

  /// What this member's portion of the expense costs them.
  final double share;

  /// Net for this expense: `+` lent, `-` owes, `0` even.
  final double net;

  /// Whether this member paid the expense.
  final bool isPayer;
}

/// Builds the per-member breakdown for the read view directly from the already
/// computed [Expense.groupMemberShareStatistic] — it does NOT recompute shares.
///
/// The net is derived, not recomputed:
/// - the payer's net = `total − (their own share)` (what they covered for
///   everyone else), positive because they lent it;
/// - every other member's net = `−(their share)`, because they owe it.
///
/// Members are returned in [memberEmails] order so the caller controls sort
/// (e.g. "you" first). A member with no share entry and who is not the payer is
/// omitted (they are not involved in this expense).
List<MemberBreakdownEntry> buildMemberBreakdown({
  required Expense expense,
  required List<String> memberEmails,
}) {
  final shareStat = expense.groupMemberShareStatistic;
  final payer = expense.paidBy;
  final result = <MemberBreakdownEntry>[];

  for (final email in memberEmails) {
    final isPayer = email == payer;
    final hasShare = shareStat.containsKey(email);
    if (!hasShare && !isPayer) continue;

    final share = shareStat[email] ?? 0;
    final net = isPayer ? (expense.amount - share) : -share;
    result.add(MemberBreakdownEntry(
      email: email,
      share: share,
      net: net,
      isPayer: isPayer,
    ));
  }

  return result;
}
