import 'package:collection/collection.dart';

import 'expense_category.dart';
import 'split_mode.dart';

const _deep = DeepCollectionEquality();

/// One expense as the editor hands it to `ExpenseRepository.saveAll`: what is
/// on screen, typed. Amounts are in the ENTRY currency, as typed; the group
/// currency and the conversion travel beside the draft, not in it.
class ExpenseDraft {
  const ExpenseDraft({
    this.name,
    required this.expenseDate,
    this.paidBy,
    this.category,
    required this.entries,
  });

  final String? name;
  final DateTime expenseDate;

  /// The payer's member email.
  final String? paidBy;
  final ExpenseCategory? category;

  /// One per line, in on-screen order. The save numbers its rows in this
  /// order.
  final List<ExpenseEntryDraft> entries;

  /// This draft as "Add & share for claiming" saves it: every line claimable,
  /// so the save explodes it into per-unit claim entries, and, when
  /// [notifyEmails] is given, every line shared with those emails, so they are
  /// told there is something to claim. Returns a new draft and leaves this one
  /// unchanged.
  ExpenseDraft markEntriesClaimable({Set<String>? notifyEmails}) =>
      ExpenseDraft(
        name: name,
        expenseDate: expenseDate,
        paidBy: paidBy,
        category: category,
        entries: [
          for (final entry in entries) entry._markedClaimable(notifyEmails),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is ExpenseDraft &&
      other.name == name &&
      other.expenseDate == expenseDate &&
      other.paidBy == paidBy &&
      other.category == category &&
      _deep.equals(other.entries, entries);

  @override
  int get hashCode =>
      Object.hash(name, expenseDate, paidBy, category, _deep.hash(entries));

  @override
  String toString() =>
      'ExpenseDraft(name: $name, expenseDate: $expenseDate, paidBy: $paidBy, '
      'category: ${category?.name}, entries: $entries)';
}

/// One line of an [ExpenseDraft].
class ExpenseEntryDraft {
  const ExpenseEntryDraft({
    this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.splitMode = SplitMode.equal,
    this.shares = const {},
    this.shareData = const {},
    this.lockedMembers = const {},
    this.claimable = false,
    this.existingClaims = const [],
  });

  /// Null for a Quick line, which has no name field.
  final String? name;

  /// In the ENTRY currency, as typed.
  final double unitPrice;
  final int quantity;
  final SplitMode splitMode;

  /// Emails of the members the line is split between.
  final Set<String> shares;

  /// Each member's split value by email: an exact amount in the ENTRY
  /// currency, a percentage, or a number of parts. Every value keeps the
  /// runtime type the split section produced, so shares-mode parts stay `int`:
  /// the payload's `parts` lands in an integer column.
  final Map<String, num> shareData;

  /// Emails of the members whose split value the user set by hand.
  final Set<String> lockedMembers;

  /// Saved as one claim unit per quantity rather than as a split line.
  final bool claimable;

  /// Each existing claim unit's claimer emails, in unit order, so a re-save
  /// keeps who claimed what.
  final List<List<String>> existingClaims;

  ExpenseEntryDraft _markedClaimable(Set<String>? notifyEmails) =>
      ExpenseEntryDraft(
        name: name,
        unitPrice: unitPrice,
        quantity: quantity,
        splitMode: splitMode,
        shares: notifyEmails ?? shares,
        shareData: shareData,
        lockedMembers: lockedMembers,
        claimable: true,
        existingClaims: existingClaims,
      );

  @override
  bool operator ==(Object other) =>
      other is ExpenseEntryDraft &&
      other.name == name &&
      other.unitPrice == unitPrice &&
      other.quantity == quantity &&
      other.splitMode == splitMode &&
      _deep.equals(other.shares, shares) &&
      _deep.equals(other.shareData, shareData) &&
      _deep.equals(other.lockedMembers, lockedMembers) &&
      other.claimable == claimable &&
      _deep.equals(other.existingClaims, existingClaims);

  @override
  int get hashCode => Object.hash(
    name,
    unitPrice,
    quantity,
    splitMode,
    _deep.hash(shares),
    _deep.hash(shareData),
    _deep.hash(lockedMembers),
    claimable,
    _deep.hash(existingClaims),
  );

  @override
  String toString() =>
      'ExpenseEntryDraft(name: $name, unitPrice: $unitPrice, '
      'quantity: $quantity, splitMode: ${splitMode.name}, shares: $shares, '
      'shareData: $shareData, lockedMembers: $lockedMembers, '
      'claimable: $claimable, existingClaims: $existingClaims)';
}
