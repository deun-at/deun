import 'package:deun/widgets/empty_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../provider.dart';
import '../../helper/helper.dart';
import '../../widgets/shimmer_card_list.dart';
import 'expense_model.dart';

class ExpenseList extends ConsumerStatefulWidget {
  const ExpenseList({super.key});

  @override
  ConsumerState<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends ConsumerState<ExpenseList> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> updateExpenseList() async {
    return ref.refresh(expenseListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Expense>> expenseProvider = ref.watch(expenseListProvider);

    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.expenses),
          centerTitle: true,
        ),
        body: switch (expenseProvider) {
          AsyncData(:final value) => SafeArea(
              child: RefreshIndicator(
                  onRefresh: () async {
                    updateExpenseList();
                  },
                  child: GroupedListView(
                      elements: value,
                      groupBy: (Expense element) => toHumanDateString(element.createdAt),
                      useStickyGroupSeparators: true,
                      stickyHeaderBackgroundColor: Theme.of(context).colorScheme.surface,
                      order: GroupedListOrder.DESC,
                      groupSeparatorBuilder: (String value) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                      itemBuilder: (context, expense) {
                        // Access the Group instance
                        Color colorSeedValue = Color(expense.group.colorValue);

                        return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Card(
                                elevation: 8,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                surfaceTintColor: colorSeedValue,
                                shadowColor: Colors.transparent,
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(12.0),
                                    onTap: () {
                                      GoRouter.of(context).push("/group/details/expense",
                                          extra: {'group': expense.group, 'expense': expense}).then(
                                        (value) async {
                                          await updateExpenseList();
                                        },
                                      );
                                    },
                                    child: Padding(
                                        padding: const EdgeInsets.fromLTRB(10, 5, 5, 10),
                                        child: Column(
                                          children: [
                                            Align(
                                              alignment: Alignment.bottomLeft,
                                              child: Text(
                                                expense.name,
                                                style: Theme.of(context).textTheme.headlineMedium,
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.bottomLeft,
                                              child: Text(
                                                toCurrency(expense.amount),
                                                style: Theme.of(context).textTheme.labelLarge,
                                              ),
                                            )
                                          ],
                                        )))));
                      }))),
          AsyncError() => EmptyListWidget(
              label: AppLocalizations.of(context)!.expenseNoEntries,
              onRefresh: () async {
                await updateExpenseList();
              }),
          _ => const ShimmerCardList(
              height: 70,
              listEntryLength: 20,
            ),
        });
  }
}
