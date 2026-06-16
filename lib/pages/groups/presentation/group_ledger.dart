import '../../expenses/data/expense_model.dart';

/// The three ledger row presentations on the group-detail screen.
enum LedgerRowType {
  /// A single-entry expense: category icon, title, payer + your-net, amount.
  quick,

  /// A multi-entry (itemized) expense that supports per-item claiming.
  itemized,

  /// A settle-up / payment row (`is_paid_back_row`).
  payback,
}

/// Classifies an [Expense] into one of the three ledger [LedgerRowType]s.
///
/// Detection (from the real model, not recomputed business logic):
/// - [LedgerRowType.payback] when [Expense.isPaidBackRow] is true (a settle-up
///   row always has exactly one synthetic entry, so this is checked first).
/// - [LedgerRowType.itemized] when the expense has more than one
///   `expenseEntries` — multiple line items are the itemized/claim substrate.
/// - [LedgerRowType.quick] otherwise (a single entry with member shares).
LedgerRowType classifyLedgerRow(Expense expense) {
  if (expense.isPaidBackRow) return LedgerRowType.payback;
  if (expense.expenseEntries.length > 1) return LedgerRowType.itemized;
  return LedgerRowType.quick;
}

/// One calendar day of the ledger: a normalized [day] (midnight) and the
/// expenses falling on it, in their original order.
class LedgerDaySection {
  const LedgerDaySection({required this.day, required this.expenses});

  /// The day, normalized to local midnight, used for the day header.
  final DateTime day;

  /// Expenses on [day], preserving the source list's order.
  final List<Expense> expenses;
}

/// Groups [expenses] into ordered [LedgerDaySection]s by calendar day.
///
/// The source list order is preserved both across days and within each day, so
/// the provider's existing sort (date desc, then createdAt desc) carries
/// through unchanged. A day's `expenseDate` is parsed leniently; unparseable
/// values fall back to epoch so they still group together deterministically.
List<LedgerDaySection> groupExpensesByDay(List<Expense> expenses) {
  final sections = <LedgerDaySection>[];
  final indexByDay = <DateTime, int>{};

  for (final expense in expenses) {
    final parsed = DateTime.tryParse(expense.expenseDate);
    final local = (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
    final day = DateTime(local.year, local.month, local.day);

    final existing = indexByDay[day];
    if (existing == null) {
      indexByDay[day] = sections.length;
      sections.add(LedgerDaySection(day: day, expenses: [expense]));
    } else {
      sections[existing].expenses.add(expense);
    }
  }

  return sections;
}
