import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../app_state.dart';
import '../../constants.dart';
import '../../main.dart';
import '../../widgets/decimal_text_input_formatter.dart';
import '../groups/group_model.dart';
import 'expense_model.dart';

class ExpenseBottomSheet extends StatefulWidget {
  const ExpenseBottomSheet(
      {super.key,
      required this.appState,
      required this.groupId,
      this.expenseId});

  final AppState appState;
  final int groupId;
  final int? expenseId;

  @override
  State<ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends State<ExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final expenseNameController = TextEditingController();
  final expenseAmountController = TextEditingController();

  ColorSeed groupColor = ColorSeed.baseColor;
  final NumberFormat numFormat = NumberFormat('###,##0.00', 'en_US');
  String? titleText;

  @override
  void initState() {
    super.initState();

    final Group? group = widget.appState.groupItems.value[widget.groupId];

    if (group != null) {
      final Expense? expense = group.expenses[widget.expenseId];

      if (expense != null) {
        expenseNameController.text = expense.name;
        expenseAmountController.text = expense.amount.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10;

    return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                          widget.expenseId == null
                              ? AppLocalizations.of(context)!.createExpense
                              : AppLocalizations.of(context)!.editExpense,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: spacing),
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: expenseNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!
                                .expenseNameValidationEmpty;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.expenseName,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        controller: expenseAmountController,
                        inputFormatters: [
                          DecimalTextInputFormatter(decimalRange: 2)
                        ],
                        onFieldSubmitted: (value) {
                          final formattedPrice =
                              numFormat.format(double.parse(value));
                          debugPrint('Formatted $formattedPrice');
                          expenseAmountController.value = TextEditingValue(
                            text: formattedPrice,
                            selection: TextSelection.collapsed(
                                offset: formattedPrice.length),
                          );
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!
                                .expenseAmountValidationEmpty;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText:
                              AppLocalizations.of(context)!.expenseAmount,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Map<String, dynamic> upsertVals = {
                                'group_id': widget.groupId,
                                'name': expenseNameController.text,
                                'amount':
                                    double.parse(expenseAmountController.text),
                                'user_id': supabase.auth.currentUser?.id
                              };

                              if (widget.expenseId != null) {
                                upsertVals.addAll({'id': widget.expenseId});
                              }
                              supabase
                                  .from('expense')
                                  .upsert(upsertVals)
                                  .then((value) async {
                                await widget.appState.fetchGroupData();
                                await widget.appState.fetchExpenseData();
                                Navigator.pop(context);
                              });
                            }
                          },
                          child: Text(widget.expenseId != null
                              ? AppLocalizations.of(context)!.update
                              : AppLocalizations.of(context)!.create))
                    ],
                  )))),
    );
  }
}
