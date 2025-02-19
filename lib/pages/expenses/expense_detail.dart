import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/group_member_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../constants.dart';
import '../../main.dart';
import '../groups/group_model.dart';
import 'expense_entry_widget.dart';
import 'expense_entry_model.dart';
import 'expense_model.dart';

final _isLoading = StateProvider<bool>((ref) => false);

class ExpenseBottomSheet extends ConsumerStatefulWidget {
  const ExpenseBottomSheet({super.key, required this.group, this.expense});

  final Group group;
  final Expense? expense;

  @override
  ConsumerState<ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends ConsumerState<ExpenseBottomSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  List<GroupMember> groupMembers = [];
  ColorSeed groupColor = ColorSeed.baseColor;
  final List<ExpenseEntryWidget> expenseEntryFields = List.empty(growable: true);
  int _newTextFieldId = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_isLoading.notifier).state = false); // Reset loading state

    groupMembers = widget.group.groupMembers;
    if (widget.expense != null && widget.expense!.expenseEntries.isNotEmpty) {
      _newTextFieldId = widget.expense!.expenseEntries.length;
      widget.expense!.expenseEntries.forEach((key, expenseEntry) {
        expenseEntryFields.add(ExpenseEntryWidget(
            expenseEntry: expenseEntry,
            index: expenseEntry.index,
            onRemove: () => onRemove(expenseEntry),
            groupMembers: groupMembers));
      });
    } else {
      ExpenseEntry _expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      expenseEntryFields.add(ExpenseEntryWidget(
          expenseEntry: _expenseEntry,
          index: _expenseEntry.index,
          onRemove: () => onRemove(_expenseEntry),
          groupMembers: groupMembers));
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
              try {
                await widget.expense!.delete();
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.expenseDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.expenseDeleteError);
                }
              } finally {
                //pop both dialog and edit page, because this item is not existing anymore
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(modalContext);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10;
    final isLoading = ref.watch(_isLoading);

    List<Widget> expenseActions = [];

    if (widget.expense != null) {
      expenseActions.add(IconButton.filledTonal(
        onPressed: () {
          openDeleteItemDialog(context, widget.expense!);
        },
        icon: const Icon(Icons.delete_outline),
      ));
    }

    expenseActions.add(Padding(
        padding: const EdgeInsets.only(right: 10),
        child: FilledButton(
            onPressed: () async {
              if (_formKey.currentState!.saveAndValidate()) {
                ref.read(_isLoading.notifier).state = true; // Set loading to true
                try {
                  await Expense.saveAll(context, widget.group.id, widget.expense?.id, _formKey.currentState!.value);
                  if (context.mounted) {
                    showSnackBar(context, AppLocalizations.of(context)!.expenseCreateSuccess);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showSnackBar(context, AppLocalizations.of(context)!.expenseCreateError);
                  }
                } finally {
                  if (mounted) {
                    ref.read(_isLoading.notifier).state = false; // Stop loading
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.save))));

    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        snap: true,
        shouldCloseOnMinExtent: false,
        builder: (context, scrollController) {
          return PopScope(
              canPop: !isLoading, // Prevent back navigation if loading
              child: Stack(children: [
                Scaffold(
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
                      controller: scrollController,
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: Padding(
                              padding: MediaQuery.of(context).viewInsets,
                              child: FormBuilder(
                                  key: _formKey,
                                  clearValueOnUnregister: true,
                                  initialValue: widget.expense?.toJson() ?? {},
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      FormBuilderField(
                                          name: "name",
                                          builder: (FormFieldState<dynamic> field) => TextFormField(
                                                initialValue: field.value,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displaySmall!
                                                    .copyWith(color: Theme.of(context).colorScheme.primary),
                                                validator: FormBuilderValidators.required(
                                                    errorText:
                                                        AppLocalizations.of(context)!.expenseNameValidationEmpty),
                                                decoration: InputDecoration(
                                                  border: InputBorder.none,
                                                  hintText: AppLocalizations.of(context)!.addExpenseTitle,
                                                ),
                                                onChanged: (value) => field.didChange(value),
                                              )),
                                      const SizedBox(height: spacing),
                                      FormBuilderChoiceChip(
                                        name: "paid_by",
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.of(context)!.expensePaidBy,
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.all(0),
                                        ),
                                        initialValue: widget.expense?.paidBy ?? supabase.auth.currentUser?.email,
                                        spacing: 8,
                                        options: widget.group.groupMembers
                                            .map((e) => FormBuilderChipOption(
                                                  value: e.email,
                                                  child: Text(e.email == supabase.auth.currentUser?.email
                                                      ? AppLocalizations.of(context)!.you
                                                      : e.displayName),
                                                ))
                                            .toList(),
                                      ),
                                      const SizedBox(height: spacing),
                                      FormBuilderDateTimePicker(
                                        name: "expense_date",
                                        initialValue: widget.expense?.expenseDate != null
                                            ? DateTime.parse(widget.expense!.expenseDate)
                                            : DateTime.now(),
                                        inputType: InputType.date,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          labelText: AppLocalizations.of(context)!.expenseDate,
                                          hintText: AppLocalizations.of(context)!.addExpenseTitle,
                                        ),
                                      ),
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
                    )),
                if (isLoading)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {}, // Prevent interactions
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ),
              ]));
        });
  }
}
