import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Restyled category detail sheet: the expenses in one category for a single
/// month, in a [SheetScaffold] with restyle list rows and the category accent.
class CategoryDetailBottomSheet extends ConsumerWidget {
  const CategoryDetailBottomSheet({
    super.key,
    required this.groupId,
    required this.categoryName,
    required this.monthStart,
    required this.monthEnd,
  });

  final String groupId;
  final String categoryName;
  final DateTime monthStart;
  final DateTime monthEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = CategoryExpenseDetailsArgs(
      groupId: groupId,
      categoryName: categoryName,
      monthStart: monthStart,
      monthEnd: monthEnd,
    );
    final state = ref.watch(categoryExpenseDetailsProvider(args));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => ExpenseCategory.other,
    );
    final color = category.getColor(context);

    return SheetScaffold(
      title: category.getDisplayName(l10n),
      titleTrailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.getIcon(), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('MMMM yyyy').format(monthStart),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          state.when(
            loading: () => const ShimmerCardList(height: 60, listEntryLength: 8),
            error: (error, _) => _Empty(text: l10n.statisticsNoExpensesFound, theme: theme),
            data: (expenses) {
              if (expenses.isEmpty) {
                return _Empty(text: l10n.statisticsNoExpensesFound, theme: theme);
              }
              return SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final expense in expenses)
                      ListTile(
                        title: Text(expense.expenseName, style: theme.textTheme.bodyLarge),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy').format(DateTime.parse(expense.expenseDate)),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            Text(
                              l10n.paidBy(expense.paidByDisplayName),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        trailing: MoneyText(
                          expense.amount,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.theme});
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
