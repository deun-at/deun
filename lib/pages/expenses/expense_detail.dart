import 'package:deun/pages/groups/group_member_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../app_state.dart';
import '../../constants.dart';
import '../../main.dart';
import '../groups/group_model.dart';
import 'expense_entry_widget.dart';
import 'expense_entry_model.dart';
import 'expense_model.dart';

class ExpenseBottomSheet extends StatefulWidget {
  const ExpenseBottomSheet({super.key, required this.appState, required this.groupId, this.expenseId});

  final AppState appState;
  final String groupId;
  final String? expenseId;

  @override
  State<ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends State<ExpenseBottomSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  late Group? group;
  late Expense? expense;
  List<GroupMember> groupMembers = [];
  ColorSeed groupColor = ColorSeed.baseColor;
  final List<ExpenseEntryWidget> expenseEntryFields = List.empty(growable: true);
  int _newTextFieldId = 0;

  @override
  void initState() {
    super.initState();

    group = widget.appState.groupItems.value.data[widget.groupId];

    if (group != null) {
      expense = group?.expenses[widget.expenseId];

      groupMembers = group!.groupMembers;
      if (expense != null && expense!.expenseEntries.isNotEmpty) {
        _newTextFieldId = expense!.expenseEntries.length;
        expense!.expenseEntries.forEach((key, expenseEntry) {
          expenseEntryFields
              .add(ExpenseEntryWidget(expenseEntry: expenseEntry, index: expenseEntry.index, onRemove: () => onRemove(expenseEntry), groupMembers: groupMembers));
        });
      } else {
        ExpenseEntry _expenseEntry = ExpenseEntry(index: _newTextFieldId++);
        expenseEntryFields
            .add(ExpenseEntryWidget(expenseEntry: _expenseEntry, index: _expenseEntry.index, onRemove: () => onRemove(_expenseEntry), groupMembers: groupMembers));
      }
    }
  }

  void onRemove(ExpenseEntry expenseEntry) {
    setState(() {
      int index = expenseEntryFields.indexWhere((element) => element.expenseEntry.index == expenseEntry.index);

      expenseEntryFields.removeAt(index);
    });
  }

  void openDeleteItemDialog(BuildContext modalContext, Expense expense) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.expenseDeleteItemTitle),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
            onPressed: () async {
              await expense.delete();
              await widget.appState.fetchGroupData();
              await widget.appState.fetchExpenseData();
              Navigator.pop(context);
              Navigator.pop(modalContext);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10;

    List<Widget> expenseActions = [];

    if (expense != null) {
      expenseActions.add(IconButton(
        onPressed: () {
          openDeleteItemDialog(context, expense!);
        },
        icon: const Icon(Icons.delete),
      ));
    }

    expenseActions.add(Padding(
        padding: const EdgeInsets.only(right: 10),
        child: FilledButton(
            onPressed: () async {
              if (_formKey.currentState!.saveAndValidate()) {
                await Expense.saveAll(widget.groupId, widget.expenseId, _formKey.currentState!.value);
                await widget.appState.fetchGroupData();
                await widget.appState.fetchExpenseData();
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.save))));

    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: expenseActions,
        ),
        body: SingleChildScrollView(
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
                            style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.primary),
                            validator: FormBuilderValidators.required(errorText: AppLocalizations.of(context)!.expenseNameValidationEmpty),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: AppLocalizations.of(context)!.addExpenseTitle,
                            ),
                          ),
                          const SizedBox(height: spacing),
                          FormBuilderChoiceChip(
                              name: "paid_by",
                              decoration: InputDecoration(
                                label: Text(AppLocalizations.of(context)!.expensePaidBy),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(0),
                              ),
                              initialValue: expense?.paidBy ?? supabase.auth.currentUser?.email,
                              spacing: 8,
                              options: group!.groupMembers
                                  .map((e) => FormBuilderChipOption(
                                        value: e.email,
                                        child: Text(e.displayName),
                                      ))
                                  .toList()),
                          const SizedBox(height: spacing),
                          ...expenseEntryFields,
                          Center(
                              child: FilledButton.tonalIcon(
                            icon: const Icon(Icons.add),
                            label: Text(AppLocalizations.of(context)!.addNewExpenseEntry),
                            onPressed: () {
                              setState(() {
                                ExpenseEntry _expenseEntry = ExpenseEntry(index: _newTextFieldId++);
                                expenseEntryFields.add(ExpenseEntryWidget(
                                  expenseEntry: _expenseEntry,
                                  index: _expenseEntry.index,
                                  onRemove: () => onRemove(_expenseEntry),
                                  groupMembers: groupMembers,
                                ));
                              });
                            },
                          )),
                        ],
                      )))),
        ));
  }
}
