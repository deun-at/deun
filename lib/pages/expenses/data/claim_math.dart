/// A single claimable unit for cost-math purposes: its cost and the emails
/// of the members who have claimed it. Mirrors one `expense_entry`
/// (quantity 1, split_mode 'claim') with its `expense_entry_share` rows.
class ClaimUnit {
  const ClaimUnit({required this.unitCost, required this.claimers});

  final double unitCost;
  final List<String> claimers;

  bool get isClaimed => claimers.isNotEmpty;

  /// Cost to each claimer of this unit = unitCost / number of claimers.
  /// Returns 0 when nobody has claimed it (the payer covers unclaimed units).
  double get perClaimerCost => claimers.isEmpty ? 0 : unitCost / claimers.length;
}

/// A claim unit paired with its DB identity and display metadata, for the
/// claim screen's item list. [unit] carries the cost-math; [entryId] is the
/// `expense_entry.id` used to mutate claimers; [claimerNames] maps each
/// claimer email to its display name for avatars/labels.
class ClaimUnitRow {
  const ClaimUnitRow({
    required this.entryId,
    required this.name,
    required this.unit,
    required this.claimerNames,
  });

  final String entryId;
  final String? name;
  final ClaimUnit unit;
  final Map<String, String> claimerNames;
}

/// One item card on the claim screen (F131): all claim units that share an
/// item_group_id (a standalone unit forms a group of one), in stable unit
/// order. [unitCost] is the per-unit price ("€X each"); [quantity] the number
/// of ordered units — one tappable slot chip each.
class ClaimItemGroup {
  const ClaimItemGroup({
    required this.name,
    required this.unitCost,
    required this.units,
  });

  final String? name;
  final double unitCost;
  final List<ClaimUnitRow> units;

  int get quantity => units.length;

  /// The first unit nobody has claimed yet — target of "Split one" — or null
  /// when every slot is taken (the button dims).
  ClaimUnitRow? get firstFree {
    for (final row in units) {
      if (!row.unit.isClaimed) return row;
    }
    return null;
  }

  bool get hasFree => firstFree != null;

  /// The persona's cost across this item's units (their share of every unit
  /// they claim) — shown on the card's trailing edge when > 0.
  double costForPersona(String email) {
    double sum = 0;
    for (final row in units) {
      if (row.unit.claimers.contains(email)) sum += row.unit.perClaimerCost;
    }
    return sum;
  }
}

/// The per-persona view-state for one claim unit's chip on the claim screen
/// (Screen 9). Derived purely from a [ClaimUnitRow] for the current persona:
/// whether the persona claims it, how many members share it, the per-claimer
/// cost, and whether the unit is still open (no claimers — the dashed
/// "take one" affordance).
class ClaimChipState {
  const ClaimChipState({
    required this.claimedByYou,
    required this.splitCount,
    required this.perUnitCost,
    required this.open,
  });

  /// True when the persona is one of the unit's claimers.
  final bool claimedByYou;

  /// Number of members sharing this unit (0 when open).
  final int splitCount;

  /// Cost to each claimer = unitCost / claimers (0 when open). Reuses
  /// [ClaimUnit.perClaimerCost] — no separate math.
  final double perUnitCost;

  /// True when nobody has claimed the unit yet (renders the dashed chip).
  final bool open;

  /// Derives the chip state for [personaEmail] from [row].
  factory ClaimChipState.forPersona(ClaimUnitRow row, String personaEmail) {
    final claimers = row.unit.claimers;
    return ClaimChipState(
      claimedByYou: claimers.contains(personaEmail),
      splitCount: claimers.length,
      perUnitCost: row.unit.perClaimerCost,
      open: claimers.isEmpty,
    );
  }
}

/// The persona's confirm total = their share summed across every [rows] unit.
/// Equivalent to `memberShareTotals(...)[personaEmail]` — the amount surfaced
/// on the sticky "Confirm — I had €X" CTA.
double confirmTotalForPersona(List<ClaimUnitRow> rows, String personaEmail) {
  final totals = memberShareTotals(rows.map((r) => r.unit).toList());
  return totals[personaEmail] ?? 0.0;
}

/// Per-member share totals across all units. A member's total is the sum,
/// over every unit they claimed, of `unitCost / claimers`. Equivalent to
/// `Expense.groupMemberShareStatistic` for claim units (percentage = 100/n).
Map<String, double> memberShareTotals(List<ClaimUnit> units) {
  final totals = <String, double>{};
  for (final unit in units) {
    if (!unit.isClaimed) continue;
    final per = unit.perClaimerCost;
    for (final email in unit.claimers) {
      totals[email] = (totals[email] ?? 0) + per;
    }
  }
  return totals;
}

/// Sum of all unit costs that have at least one claimer.
double claimedTotal(List<ClaimUnit> units) {
  double sum = 0;
  for (final unit in units) {
    if (unit.isClaimed) sum += unit.unitCost;
  }
  return sum;
}

/// Sum of all unit costs (claimed or not).
double grandTotal(List<ClaimUnit> units) {
  double sum = 0;
  for (final unit in units) {
    sum += unit.unitCost;
  }
  return sum;
}

/// Total cost not yet claimed by anyone — the payer covers this.
double unclaimedTotal(List<ClaimUnit> units) =>
    grandTotal(units) - claimedTotal(units);
