import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';

import '../../../../widgets/restyle/soft_card.dart';
import '../../../groups/data/group_member_model.dart';
import '../../provider/expense_editor_controller.dart';
import '../expense_entry_widget.dart';

/// The item cards. F161 D1: Quick renders the entry on the page bg (the split
/// section owns its own SoftCard around only the member rows). Itemized joins
/// its item rows inside a SINGLE SoftCard (the group_detail_list _DaySection
/// pattern) — the item rows render flat (no per-row card) so there is no
/// card-in-card nesting.
class EditorEntryList extends StatelessWidget {
  const EditorEntryList({
    super.key,
    required this.entries,
    required this.isSingleEntry,
    required this.currency,
    required this.members,
    required this.currentUserEmail,
    required this.amountController,
    required this.onRemove,
    required this.onLineTotalChanged,
  });

  final List<EditorEntry> entries;
  final bool isSingleEntry;
  final Currency currency;
  final List<GroupMember> members;

  /// The signed-in user's email, passed down so each entry marks "You".
  final String? currentUserEmail;
  final TextEditingController amountController;
  final ValueChanged<int> onRemove;

  /// Itemized total header lives in the parent; a child price/qty edit must
  /// rebuild it. FormBuilder.onChanged only fires the first time (it guards on
  /// _isDirty), so the parent wires an explicit per-edit rebuild here.
  final VoidCallback onLineTotalChanged;

  @override
  Widget build(BuildContext context) {
    final entryWidgets = entries
        .map(
          (e) => ExpenseEntryWidget(
            key: ValueKey(e.index),
            expenseEntry: e.expenseEntry,
            index: e.index,
            onRemove: () => onRemove(e.index),
            groupMembers: members,
            currentUserEmail: currentUserEmail,
            currency: currency,
            initialName: e.initialName,
            initialAmount: isSingleEntry ? null : e.initialAmount,
            initialQuantity: e.initialQuantity,
            isSingleEntry: isSingleEntry,
            expenseLevelAmountController: isSingleEntry
                ? amountController
                : null,
            onLineTotalChanged: isSingleEntry ? null : onLineTotalChanged,
          ),
        )
        .toList();
    if (isSingleEntry) {
      return Column(children: entryWidgets);
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SoftCard(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: Column(
          children: [
            for (int i = 0; i < entryWidgets.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              entryWidgets[i],
            ],
          ],
        ),
      ),
    );
  }
}
