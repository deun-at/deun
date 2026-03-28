import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../constants.dart';
import '../../../main.dart';
import '../../../widgets/theme_builder.dart';
import '../../groups/data/group_model.dart';
import 'expense_entry_widget.dart';
import '../data/expense_entry_model.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';
import '../data/expense_category.dart';
import '../data/receipt_scan_result.dart';
import '../../../widgets/category_selector.dart';
import 'receipt_scanner_sheet.dart';

class ExpenseDetail extends ConsumerStatefulWidget {
  const ExpenseDetail({super.key, required this.group, this.expense});

  final Group group;
  final Expense? expense;

  @override
  ConsumerState<ExpenseDetail> createState() => _ExpenseDetailState();
}

class _ExpenseDetailState extends ConsumerState<ExpenseDetail> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _nameController = TextEditingController();
  List<GroupMember> groupMembers = [];
  ColorSeed groupColor = ColorSeed.baseColor;
  final List<ExpenseEntryWidget> expenseEntryFields = List.empty(growable: true);
  int _newTextFieldId = 0;

  ExpenseCategory? _detectedCategory;

  @override
  void initState() {
    super.initState();

    groupMembers = widget.group.groupMembers;
    _detectedCategory = widget.expense?.category;
    _nameController.text = widget.expense?.name ?? '';
    if (widget.expense != null && widget.expense!.expenseEntries.isNotEmpty) {
      _newTextFieldId = widget.expense!.expenseEntries.length;
      widget.expense!.expenseEntries.forEach((key, expenseEntry) {
        expenseEntryFields.add(ExpenseEntryWidget(
            key: ValueKey(expenseEntry.index),
            expenseEntry: expenseEntry,
            index: expenseEntry.index,
            onRemove: () => onRemove(expenseEntry),
            groupMembers: groupMembers));
      });
    } else {
      ExpenseEntry _expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      expenseEntryFields.add(ExpenseEntryWidget(
          key: ValueKey(_expenseEntry.index),
          expenseEntry: _expenseEntry,
          index: _expenseEntry.index,
          onRemove: () => onRemove(_expenseEntry),
          groupMembers: groupMembers));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void onRemove(ExpenseEntry expenseEntry) {
    setState(() {
      int index = expenseEntryFields.indexWhere((element) => element.expenseEntry.index == expenseEntry.index);
      expenseEntryFields.removeAt(index);
    });
  }

  void detectAndUpdateCategory(String title) {
    if (title.isNotEmpty) {
      final detectedCategory = CategoryDetector.detectCategory(title);
      final currentCategory = _formKey.currentState?.fields['category']?.value as ExpenseCategory?;

      // Only auto-update if no category is currently selected or if the existing category is 'other'
      if (currentCategory == null || currentCategory == ExpenseCategory.other) {
        if (detectedCategory != ExpenseCategory.other) {
          setState(() {
            _detectedCategory = detectedCategory;
          });
          _formKey.currentState?.fields['category']?.didChange(detectedCategory);
        }
      }
    }
  }

  Future<void> _showReceiptScanner() async {
    final result = await showModalBottomSheet<ReceiptScanResult>(
      context: context,
      builder: (context) => const ReceiptScannerSheet(),
    );
    if (result != null && mounted) {
      _applyReceiptData(result);
    }
  }

  void _applyReceiptData(ReceiptScanResult result) {
    if (result.isEmpty) {
      showSnackBar(context, AppLocalizations.of(context)!.receiptScanNoData);
      return;
    }

    // Set merchant name
    if (result.merchantName != null) {
      _nameController.text = result.merchantName!;
      _formKey.currentState?.fields['name']?.didChange(result.merchantName);
      detectAndUpdateCategory(result.merchantName!);
    }

    // Set date
    if (result.date != null) {
      _formKey.currentState?.fields['expense_date']?.didChange(result.date);
    }

    // Rebuild expense entry widgets from line items
    setState(() {
      expenseEntryFields.clear();

      if (result.lineItems.isNotEmpty) {
        for (final item in result.lineItems) {
          ExpenseEntry expenseEntry = ExpenseEntry(index: _newTextFieldId++);
          expenseEntryFields.add(ExpenseEntryWidget(
            key: ValueKey(expenseEntry.index),
            expenseEntry: expenseEntry,
            index: expenseEntry.index,
            onRemove: () => onRemove(expenseEntry),
            groupMembers: groupMembers,
            initialName: item.name,
            initialAmount: item.unitPrice.toStringAsFixed(2),
            initialQuantity: item.quantity > 1 ? item.quantity.toString() : null,
          ));
        }
      } else if (result.total != null) {
        ExpenseEntry expenseEntry = ExpenseEntry(index: _newTextFieldId++);
        expenseEntryFields.add(ExpenseEntryWidget(
          key: ValueKey(expenseEntry.index),
          expenseEntry: expenseEntry,
          index: expenseEntry.index,
          onRemove: () => onRemove(expenseEntry),
          groupMembers: groupMembers,
          initialAmount: result.total!.toStringAsFixed(2),
        ));
      }
    });

    showSnackBar(context, AppLocalizations.of(context)!.receiptScanSuccess);
  }

  void openDeleteItemDialog(BuildContext modalContext, Expense expense) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.expenseDeleteItemTitle),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
            onPressed: () async {
              try {
                await ExpenseRepository.delete(widget.expense!.id, widget.expense!.groupId);
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
    const double spacing = 8;

    List<Widget> expenseActions = [];

    Widget saveExpenseButton = FilledButton(
      onPressed: () async {
        if (_formKey.currentState!.saveAndValidate()) {
          try {
            await ExpenseRepository.saveAll(context, widget.group.id, widget.expense?.id, _formKey.currentState!.value);
            if (context.mounted) {
              showSnackBar(context, AppLocalizations.of(context)!.expenseCreateSuccess);
            }
          } catch (e) {
            if (context.mounted) {
              showSnackBar(context, AppLocalizations.of(context)!.expenseCreateError);
            }
          } finally {
            if (mounted) {
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          }
        }
      },
      child: Text(AppLocalizations.of(context)!.save),
    );

    if (widget.expense != null) {
      expenseActions.add(saveExpenseButton);

      expenseActions.add(IconButton(
        onPressed: () {
          openDeleteItemDialog(context, widget.expense!);
        },
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onSurface),
      ));
    } else {
      expenseActions.add(
        IconButton(
          onPressed: () => _showReceiptScanner(),
          icon: const Icon(Icons.document_scanner_outlined),
          tooltip: AppLocalizations.of(context)!.receiptScanButton,
        ),
      );
      expenseActions.add(
        Padding(padding: EdgeInsetsGeometry.only(right: 8), child: saveExpenseButton),
      );
    }

    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            actions: [...expenseActions],
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 40),
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
                          controller: _nameController,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(color: Theme.of(context).colorScheme.primary),
                          validator: FormBuilderValidators.required(
                              errorText: AppLocalizations.of(context)!.expenseNameValidationEmpty),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: AppLocalizations.of(context)!.addExpenseTitle,
                            contentPadding: EdgeInsets.only(left: 8, right: 8),
                          ),
                          onChanged: (value) {
                            field.didChange(value);
                            if (value.isNotEmpty) {
                              detectAndUpdateCategory(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: spacing),
                      FormBuilderChoiceChips(
                        showCheckmark: false,
                        name: "paid_by",
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.expensePaidBy,
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(left: 8, right: 8),
                        ),
                        initialValue: widget.expense?.paidBy ?? supabase.auth.currentUser?.email,
                        spacing: 8,
                        options: widget.group.groupMembers
                            .map(
                              (e) => FormBuilderChipOption(
                            value: e.email,
                            child: Text(e.email == supabase.auth.currentUser?.email
                                ? AppLocalizations.of(context)!.you
                                : e.displayName),
                          ),
                        )
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
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          hintText: AppLocalizations.of(context)!.addExpenseTitle,
                          contentPadding: EdgeInsets.only(left: 8, right: 8),
                        ),
                      ),
                      const SizedBox(height: spacing),
                      CategorySelector(
                        name: "category",
                        initialValue: _detectedCategory ?? widget.expense?.category,
                      ),
                      const SizedBox(height: spacing),
                      CardColumn(children: expenseEntryFields),
                      Center(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.add),
                          label: Text(AppLocalizations.of(context)!.addNewExpenseEntry),
                          onPressed: () {
                            setState(
                                  () {
                                ExpenseEntry _expenseEntry = ExpenseEntry(index: _newTextFieldId++);
                                expenseEntryFields.add(
                                  ExpenseEntryWidget(
                                    key: ValueKey(_expenseEntry.index),
                                    expenseEntry: _expenseEntry,
                                    index: _expenseEntry.index,
                                    onRemove: () => onRemove(_expenseEntry),
                                    groupMembers: groupMembers,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
