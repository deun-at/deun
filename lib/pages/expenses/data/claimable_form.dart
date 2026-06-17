/// Returns a copy of the expense editor's form value with a `claimable` flag
/// set on every itemized entry, so [ExpenseRepository.saveAll] explodes the
/// lines into per-unit claim entries.
///
/// Used only by the itemized editor's "Add & share for claiming" CTA — a plain
/// save leaves entries untouched so the existing manual-split path is kept.
///
/// Entry keys look like `expense_entry[<index>][<field>]`; this adds
/// `expense_entry[<index>][claimable] = true` for each distinct index found.
/// The input map is not mutated.
Map<String, dynamic> markEntriesClaimable(Map<String, dynamic> formValue) {
  final out = Map<String, dynamic>.from(formValue);
  final indexPattern = RegExp(r'^expense_entry\[(.*?)\]');
  final indices = <String>{};
  for (final key in formValue.keys) {
    final match = indexPattern.firstMatch(key);
    if (match != null) {
      indices.add(match.group(1)!);
    }
  }
  for (final index in indices) {
    out['expense_entry[$index][claimable]'] = true;
  }
  return out;
}
