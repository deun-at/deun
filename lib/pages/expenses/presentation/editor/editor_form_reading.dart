import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../../data/expense_category.dart';
import '../../data/expense_draft.dart';
import '../../data/itemized_totals.dart';
import '../../data/split_mode.dart';
import '../../provider/expense_editor_controller.dart';

/// The current item lines, read live from the form fields so everything
/// derived from them tracks edits. THE one reader of the amount and quantity
/// fields: the itemized header, the converted preview and the switch-back all
/// go through it, so they cannot disagree about what is on screen.
List<ItemLine> editorFormLines(
  FormBuilderState? form,
  List<EditorEntry> entries,
) {
  final lines = <ItemLine>[];
  for (final entry in entries) {
    lines.add(
      ItemLine(
        unitPrice: editorUnitPrice(form, entry) ?? 0,
        quantity: editorQuantity(form, entry),
      ),
    );
  }
  return lines;
}

/// This entry's live unit price, or null when neither the field nor the
/// seeded value holds anything parseable (an empty or half-typed amount).
double? editorUnitPrice(FormBuilderState? form, EditorEntry entry) {
  final seeded = double.tryParse(entry.initialAmount ?? '');
  final value = form?.fields["expense_entry[${entry.index}][amount]"]?.value;
  if (value == null) return seeded;
  return double.tryParse(value.toString()) ?? seeded;
}

/// This entry's live amount-field text, falling back to the seeded value
/// before the field registers.
String editorUnitPriceText(FormBuilderState? form, EditorEntry entry) {
  final value = form?.fields["expense_entry[${entry.index}][amount]"]?.value;
  return value?.toString() ?? entry.initialAmount ?? '';
}

/// This entry's live quantity, defaulting to a single unit.
int editorQuantity(FormBuilderState? form, EditorEntry entry) {
  final value = form?.fields["expense_entry[${entry.index}][quantity]"]?.value;
  return int.tryParse(value?.toString() ?? '') ??
      int.tryParse(entry.initialQuantity ?? '') ??
      1;
}

/// What is on screen, as the draft the save hands over: one line per card in
/// [entries], in on-screen order, each read from the validated form [values]
/// by its exact field names. A field a card does not register takes the
/// default a missing one always had: a Quick card has no name or quantity,
/// an Itemized card no split fields. With [claimable], each card carries its
/// existing per-unit claims (F146), so re-sharing keeps them. Positional:
/// shrinking a quantity drops the last units' claims.
///
/// Throws a [FormatException] for an amount that does not parse.
ExpenseDraft editorDraftFromForm(
  Map<String, dynamic> values,
  List<EditorEntry> entries, {
  required bool claimable,
}) {
  return ExpenseDraft(
    name: values['name'] as String?,
    expenseDate: values['expense_date'] as DateTime,
    paidBy: values['paid_by'] as String?,
    category: values['category'] as ExpenseCategory?,
    entries: [
      for (final entry in entries)
        _entryDraftFrom(values, entry, claimable: claimable),
    ],
  );
}

ExpenseEntryDraft _entryDraftFrom(
  Map<String, dynamic> values,
  EditorEntry entry, {
  required bool claimable,
}) {
  final field = 'expense_entry[${entry.index}]';
  final shares = values['$field[shares]'] as Set<String>?;
  final shareData = values['$field[share_data]'] as Map<String, dynamic>?;
  final locked = values['$field[locked_members]'];
  return ExpenseEntryDraft(
    name: values['$field[name]'] as String?,
    unitPrice: double.parse(values['$field[amount]'] as String),
    quantity: int.tryParse(values['$field[quantity]']?.toString() ?? '1') ?? 1,
    splitMode: SplitMode.fromString(values['$field[split_mode]'] as String?),
    shares: {...?shares},
    shareData: Map<String, num>.from(shareData ?? const {}),
    lockedMembers: locked is Set<String> ? {...locked} : const {},
    existingClaims: claimable ? entry.expenseEntry.unitClaims : const [],
  );
}
