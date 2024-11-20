import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:split_it_supa/main.dart';
import 'package:split_it_supa/widgets/shimmer_card_list.dart';

import '../../helper/helper.dart';

class ExpenseList extends StatefulWidget {
  const ExpenseList({super.key});

  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  void updateExpenseList() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Future<List<Map<String, dynamic>>> _data = supabase.from('expense').select(
        '*, ...group(group_id:id, group_name:name, group_color_value:color_value)');

    return Scaffold(
      body: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text(AppLocalizations.of(context)!.groupEntriesError,
                      style: Theme.of(context).textTheme.headlineMedium));
            }

            if (!snapshot.hasData) {
              return const ShimmerCardList(
                height: 70,
                listEntryLength: 20,
              );
            }

            // Access the QuerySnapshot
            return SafeArea(
                child: RefreshIndicator(
                    onRefresh: () async {
                      updateExpenseList();
                    },
                    child: GroupedListView(
                        elements: snapshot.data ?? [],
                        groupBy: (element) =>
                            toHumanDateString(element['created_at']),
                        useStickyGroupSeparators: true,
                        stickyHeaderBackgroundColor:
                            Theme.of(context).colorScheme.surface,
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
                          Color colorSeedValue =
                              Color(expense['group_color_value']);

                          dynamic expenseAmount = expense['amount'] ?? 0;
                          double sumAmount =
                              double.parse(expenseAmount.toString());
                          String formatSumAmount =
                              "€${sumAmount.toStringAsFixed(2)}";

                          return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Card(
                                  elevation: 8,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainer,
                                  surfaceTintColor: colorSeedValue,
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(12.0),
                                      onTap: () {
                                        GoRouter.of(context).push(
                                            "/group/details/expense?groupDocId=${expense['group_id']}&expenseDocId=${expense['id']}");
                                      },
                                      child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              10, 5, 5, 10),
                                          child: Column(
                                            children: [
                                              Align(
                                                alignment: Alignment.bottomLeft,
                                                child: Text(
                                                  expense['name'],
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium,
                                                ),
                                              ),
                                              Align(
                                                alignment: Alignment.bottomLeft,
                                                child: Text(
                                                  formatSumAmount,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge,
                                                ),
                                              )
                                            ],
                                          )))));
                        })));
          }),
    );
  }
}
