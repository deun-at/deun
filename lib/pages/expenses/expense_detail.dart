import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../app_state.dart';
import '../../constants.dart';
import '../../main.dart';
import '../../widgets/decimal_text_input_formatter.dart';
import '../groups/group_model.dart';
import 'expense_entry.dart';
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
  final List<ExpenseEntryWidget> expenseEntryFields =
      List.empty(growable: true);
  int _newTextFieldId = 0;

  @override
  void initState() {
    super.initState();

    Group? group = widget.appState.groupItems.value[widget.groupId];

    if (group != null) {
      expense = group.expenses[widget.expenseId];

      if (expense != null && expense!.expenseEntries.isNotEmpty) {
        _newTextFieldId = expense!.expenseEntries.length;
        expense!.expenseEntries.forEach((key, expenseEntry) {
          expenseEntryFields.add(ExpenseEntryWidget(
              expenseEntry: expenseEntry,
              index: expenseEntry.index,
              onRemove: () => onRemove(expenseEntry)));
        });
      } else {
        ExpenseEntry _expenseEntry = ExpenseEntry(index: _newTextFieldId++);
        expenseEntryFields.add(ExpenseEntryWidget(
            expenseEntry: _expenseEntry,
            index: _expenseEntry.index,
            onRemove: () => onRemove(_expenseEntry)));
      }
    }
  }

  void onRemove(ExpenseEntry expenseEntry) {
    setState(() {
      debugPrint(expenseEntryFields
          .map(
            (e) => e.index.toString(),
          )
          .toString());
      int index = expenseEntryFields.indexWhere(
          (element) => element.expenseEntry.index == expenseEntry.index);

      debugPrint(index.toString());
      expenseEntryFields.removeAt(index);

      debugPrint(expenseEntryFields
          .map(
            (e) => e.index.toString(),
          )
          .toString());
    });
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
                      FormBuilderTextField(
                        name: "name",
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall!
                            .copyWith(
                                color: Theme.of(context).colorScheme.primary),
                        validator: FormBuilderValidators.required(
                            errorText: AppLocalizations.of(context)!
                                .expenseNameValidationEmpty),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText:
                              AppLocalizations.of(context)!.addExpenseTitle,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      ...expenseEntryFields,
                      Center(
                          child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.add),
                        label: Text(
                            AppLocalizations.of(context)!.addNewExpenseEntry),
                        onPressed: () {
                          setState(() {
                            ExpenseEntry _expenseEntry =
                                ExpenseEntry(index: _newTextFieldId++);
                            expenseEntryFields.add(ExpenseEntryWidget(
                              expenseEntry: _expenseEntry,
                              index: _expenseEntry.index,
                              onRemove: () => onRemove(_expenseEntry),
                            ));
                          });
                        },
                      )),
                      FilledButton(
                          onPressed: () async {
                            if (_formKey.currentState!.saveAndValidate()) {
                              await Expense.saveAll(
                                  widget.groupId,
                                  widget.expenseId,
                                  _formKey.currentState!.value);

                              await widget.appState.fetchGroupData();
                              await widget.appState.fetchExpenseData();
                              Navigator.pop(context);
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