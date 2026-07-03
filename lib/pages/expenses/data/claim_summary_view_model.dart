import 'claim_math.dart';

/// One member's claimed total, for the summary card's per-member list.
class MemberTotal {
  const MemberTotal({required this.email, required this.amount});

  final String email;
  final double amount;
}

/// The derived numbers behind the dark summary card on the claim screen
/// (Screen 9): the selected persona's share, the claimed/total progress, the
/// unclaimed remainder and the per-member totals.
///
/// All figures come from [claim_math] — nothing is recomputed here; this is a
/// thin presentation projection over [ClaimUnit]s for a chosen persona.
class ClaimSummary {
  const ClaimSummary({
    required this.yourShare,
    required this.yourClaimedCount,
    required this.claimed,
    required this.unclaimed,
    required this.total,
    required this.memberTotals,
  });

  /// The selected persona's claimed total across all units.
  final double yourShare;

  /// How many units the selected persona has claimed (F128 header count).
  final int yourClaimedCount;

  /// Sum of all unit costs that have at least one claimer.
  final double claimed;

  /// Cost not yet claimed by anyone (the payer covers it).
  final double unclaimed;

  /// Grand total of every unit (claimed or not).
  final double total;

  /// Per-member claimed totals, ordered by amount descending with the persona
  /// pinned first.
  final List<MemberTotal> memberTotals;

  /// Claimed fraction of the receipt (0..1); 0 for an empty receipt.
  double get progress => total <= 0 ? 0.0 : (claimed / total).clamp(0.0, 1.0);

  /// True when every unit has at least one claimer (nothing left unclaimed).
  bool get isFullyClaimed => total > 0 && unclaimed <= 0.005;

  /// True when there are no claimable units at all.
  bool get isEmpty => total <= 0 && memberTotals.isEmpty;
}

/// Builds a [ClaimSummary] for [personaEmail] from the receipt's claim [units].
///
/// "Your share" is the persona's total via [memberShareTotals]; per-member
/// totals are sorted by amount descending, then the persona is pinned to the
/// front so the card always leads with the previewed perspective.
ClaimSummary buildClaimSummary({
  required List<ClaimUnit> units,
  required String personaEmail,
}) {
  final totals = memberShareTotals(units);

  final ordered = totals.entries
      .map((e) => MemberTotal(email: e.key, amount: e.value))
      .toList()
    ..sort((a, b) {
      if (a.email == personaEmail) return -1;
      if (b.email == personaEmail) return 1;
      return b.amount.compareTo(a.amount);
    });

  return ClaimSummary(
    yourShare: totals[personaEmail] ?? 0.0,
    yourClaimedCount:
        units.where((u) => u.claimers.contains(personaEmail)).length,
    claimed: claimedTotal(units),
    unclaimed: unclaimedTotal(units),
    total: grandTotal(units),
    memberTotals: ordered,
  );
}
