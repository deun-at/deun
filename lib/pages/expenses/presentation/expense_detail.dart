import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../widgets/decimal_text_input_formatter.dart';
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
import '../../../widgets/user_avatar.dart';

class ExpenseEntryData {
  final int index;
  final ExpenseEntry expenseEntry;
  final VoidCallback onRemove;
  final List<GroupMember> groupMembers;
  String? initialName;
  String? initialAmount;
  String? initialQuantity;

  ExpenseEntryData({
    required this.index,
    required this.expenseEntry,
    required this.onRemove,
    required this.groupMembers,
    this.initialName,
    this.initialAmount,
    this.initialQuantity,
  });
}

class ExpenseDetail extends ConsumerStatefulWidget {
  const ExpenseDetail({super.key, required this.group, this.expense, this.receiptResult});

  final Group group;
  final Expense? expense;
  final ReceiptScanResult? receiptResult;

  @override
  ConsumerState<ExpenseDetail> createState() => _ExpenseDetailState();
}

class _ExpenseDetailState extends ConsumerState<ExpenseDetail> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: "0");
  final _paidBySearchController = SearchController();
  List<GroupMember> groupMembers = [];
  ColorSeed groupColor = ColorSeed.baseColor;
  final List<ExpenseEntryData> _entries = [];
  int _newTextFieldId = 0;

  bool get _isSingleEntry => _entries.length == 1;

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
        _entries.add(ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
        ));
      });
    } else if (widget.receiptResult != null && widget.receiptResult!.lineItems.isNotEmpty) {
      for (final item in widget.receiptResult!.lineItems) {
        final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
        _entries.add(ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
          initialName: item.name,
          initialAmount: item.amount.toStringAsFixed(2),
        ));
      }
    } else if (widget.receiptResult != null && widget.receiptResult!.total != null) {
      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(ExpenseEntryData(
        index: expenseEntry.index,
        expenseEntry: expenseEntry,
        onRemove: () => _removeEntry(expenseEntry),
        groupMembers: groupMembers,
        initialAmount: widget.receiptResult!.total!.toStringAsFixed(2),
      ));
    } else {
      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(ExpenseEntryData(
        index: expenseEntry.index,
        expenseEntry: expenseEntry,
        onRemove: () => _removeEntry(expenseEntry),
        groupMembers: groupMembers,
      ));
    }

    // Initialize amount controller from first entry data
    if (widget.expense != null && widget.expense!.expenseEntries.isNotEmpty) {
      final firstEntry = widget.expense!.expenseEntries.values.first;
      _amountController.text = firstEntry.unitPrice.toStringAsFixed(2);
    } else if (widget.receiptResult != null && widget.receiptResult!.total != null && widget.receiptResult!.lineItems.isEmpty) {
      _amountController.text = widget.receiptResult!.total!.toStringAsFixed(2);
    }

    // Apply receipt merchant name and date after first frame (form needs to be built)
    if (widget.receiptResult != null) {
      final receipt = widget.receiptResult!;
      if (receipt.merchantName != null) {
        _nameController.text = receipt.merchantName!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (receipt.merchantName != null) {
          _formKey.currentState?.fields['name']?.didChange(receipt.merchantName);
          detectAndUpdateCategory(receipt.merchantName!);
        }
        if (receipt.date != null) {
          _formKey.currentState?.fields['expense_date']?.didChange(receipt.date);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _paidBySearchController.dispose();
    super.dispose();
  }

  void _removeEntry(ExpenseEntry expenseEntry) {
    setState(() {
      _entries.removeWhere((e) => e.index == expenseEntry.index);
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

  List<GroupMember> get _sortedMembers {
    final currentEmail = supabase.auth.currentUser?.email;
    return [...widget.group.groupMembers]
      ..sort((a, b) {
        if (a.email == currentEmail) return -1;
        if (b.email == currentEmail) return 1;
        return a.fullUsername.compareTo(b.fullUsername);
      });
  }

  GroupMember? _findMember(String? email) {
    if (email == null) return null;
    try {
      return widget.group.groupMembers.firstWhere((m) => m.email == email);
    } catch (_) {
      return null;
    }
  }

  String _memberDisplayName(GroupMember member) {
    return member.email == supabase.auth.currentUser?.email
        ? AppLocalizations.of(context)!.you
        : member.displayName;
  }

  Widget _buildPaidBySelector() {
    final initialEmail = widget.expense?.paidBy ?? supabase.auth.currentUser?.email;

    return FormBuilderField<String>(
      name: "paid_by",
      initialValue: initialEmail,
      builder: (FormFieldState<String?> field) {
        final selectedMember = _findMember(field.value);

        return SearchAnchor(
          searchController: _paidBySearchController,
          builder: (BuildContext context, SearchController controller) {
            return CardListTile(
              isTop: true,
              isBottom: true,
              child: ListTile(
                leading: selectedMember != null
                    ? UserAvatar(displayName: selectedMember.displayName, radius: 18)
                    : null,
                title: Text(selectedMember != null
                    ? _memberDisplayName(selectedMember)
                    : AppLocalizations.of(context)!.expensePaidBy),
                subtitle: selectedMember != null
                    ? Text(selectedMember.fullUsername)
                    : null,
                onTap: () {
                  controller.text = '';
                  controller.openView();
                },
              ),
            );
          },
          suggestionsBuilder: (BuildContext context, SearchController controller) {
            final members = _sortedMembers;
            return members.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              return CardListTile(
                isTop: index == 0,
                isBottom: index == members.length - 1,
                child: ListTile(
                  leading: UserAvatar(displayName: member.displayName, radius: 18),
                  title: Text(_memberDisplayName(member)),
                  subtitle: Text(member.fullUsername),
                  onTap: () {
                    field.didChange(member.email);
                    controller.closeView(_memberDisplayName(member));
                  },
                ),
              );
            }).toList();
          },
        );
      },
    );
  }

  Widget _buildExpenseLevelAmount() {
    final firstIndex = _entries.first.index;
    return FormBuilderField(
      key: ValueKey("expense_level_amount_$firstIndex"),
      name: "expense_entry[$firstIndex][amount]",
      initialValue: _amountController.text != "0" ? _amountController.text : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.required(
        errorText: AppLocalizations.of(context)!.expenseEntryAmountValidationEmpty,
      ),
      builder: (FormFieldState<dynamic> field) {
        return InputDecorator(
          decoration: InputDecoration(
            errorText: field.errorText,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("€", style: Theme.of(context).textTheme.headlineMedium),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 0,
                    maxWidth: MediaQuery.of(context).size.width * 0.35,
                  ),
                  child: TextFormField(
                    controller: _amountController,
                    onChanged: (value) {
                      field.didChange(value);
                    },
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
                    style: Theme.of(context).textTheme.headlineMedium,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.only(right: 10, left: 10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addNewEntry() {
    setState(() {
      // When transitioning from single to multi, transfer expense-level amount to first entry
      if (_isSingleEntry && _amountController.text.isNotEmpty && _amountController.text != "0") {
        _entries.first.initialAmount = _amountController.text;
      }

      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(ExpenseEntryData(
        index: expenseEntry.index,
        expenseEntry: expenseEntry,
        onRemove: () => _removeEntry(expenseEntry),
        groupMembers: groupMembers,
      ));
    });
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
                      // Expense-level amount (single entry mode only)
                      if (_isSingleEntry) ...[
                        const SizedBox(height: spacing),
                        _buildExpenseLevelAmount(),
                      ],
                      const SizedBox(height: spacing),
                      _buildPaidBySelector(),
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
                      CardColumn(children: _entries.map((data) =>
                        ExpenseEntryWidget(
                          key: ValueKey(data.index),
                          expenseEntry: data.expenseEntry,
                          index: data.index,
                          onRemove: data.onRemove,
                          groupMembers: data.groupMembers,
                          initialName: data.initialName,
                          initialAmount: _isSingleEntry ? null : data.initialAmount,
                          initialQuantity: data.initialQuantity,
                          isSingleEntry: _isSingleEntry,
                        ),
                      ).toList()),
                      const SizedBox(height: spacing),
                      Center(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.add),
                          label: Text(AppLocalizations.of(context)!.addNewExpenseEntry),
                          onPressed: () => _addNewEntry(),
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
