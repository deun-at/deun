import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
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
  final _formKey = GlobalKey<FormBuilderState>();
  late Expense? expense;
  ColorSeed groupColor = ColorSeed.baseColor;

  @override
  void initState() {
    super.initState();

    Group? group = widget.appState.groupItems.value[widget.groupId];

    if (group != null) {
      expense = group.expenses[widget.expenseId];
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
              child: FormBuilder(
                  key: _formKey,
                  clearValueOnUnregister: true,
                  initialValue: expense?.toJson() ?? {},
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
                      FormBuilderTextField(
                        name: "name",
                        validator: FormBuilderValidators.required(
                            errorText: AppLocalizations.of(context)!
                                .expenseNameValidationEmpty),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.expenseName,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      FormBuilderTextField(
                        name: "amount",
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          DecimalTextInputFormatter(decimalRange: 2)
                        ],
                        validator: FormBuilderValidators.required(
                            errorText: AppLocalizations.of(context)!
                                .expenseAmountValidationEmpty),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText:
                              AppLocalizations.of(context)!.expenseAmount,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.saveAndValidate()) {
                              Map<String, dynamic> upsertVals =
                                  Map<String, dynamic>.from(
                                      _formKey.currentState!.value)
                                    ..addAll({
                                      'group_id': widget.groupId,
                                      'user_id': supabase.auth.currentUser?.id
                                    });

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
