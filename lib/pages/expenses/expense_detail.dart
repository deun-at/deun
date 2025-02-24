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

  final DraggableScrollableController _draggableScrollableController = DraggableScrollableController();

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

    _draggableScrollableController.addListener(() {
      final pixelToSize = _draggableScrollableController.pixelsToSize(170);
      if (_draggableScrollableController.size <= pixelToSize) {
        _draggableScrollableController.jumpTo(pixelToSize);
      }
    });
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
                  showSnackBar(
                      context, groupDetailScaffoldMessengerKey, AppLocalizations.of(context)!.expenseDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(
                      context, groupDetailScaffoldMessengerKey, AppLocalizations.of(context)!.expenseDeleteError);
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
      expenseActions.add(IconButton(
        onPressed: () {
          openDeleteItemDialog(context, widget.expense!);
        },
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onSurface),
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
                    showSnackBar(
                        context, groupDetailScaffoldMessengerKey, AppLocalizations.of(context)!.expenseCreateSuccess);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showSnackBar(
                        context, groupDetailScaffoldMessengerKey, AppLocalizations.of(context)!.expenseCreateError);
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
        controller: _draggableScrollableController,
        expand: false,
        initialChildSize: .8,
        minChildSize: 0,
        snap: true,
        builder: (context, scrollController) {
          return Container(
              decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
              clipBehavior: Clip.antiAlias,
              child: PopScope(
                  canPop: !isLoading, // Prevent back navigation if loading
                  child: Stack(children: [
                    Scaffold(
                      body: CustomScrollView(controller: scrollController, slivers: [
                        SliverPersistentHeader(
                            pinned: true, // Keeps it fixed at the top
                            floating: true, // Set to true if you want it to appear when scrolling up
                            delegate: _SliverAppBarDelegate(
                              minHeight: 20,
                              maxHeight: 20,
                              child: Container(
                                width: double.infinity,
                                color: Theme.of(context).colorScheme.surface,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    width: 32.0,
                                    height: 4.0,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                ),
                              ),
                            )),
                        SliverList.list(children: [
                          Padding(
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
                                      ))))
                        ])
                      ]),
                      bottomNavigationBar: BottomAppBar(
                          child: IconTheme(
                              data: IconThemeData(color: Theme.of(context).colorScheme.surface),
                              child: Row(
                                children: <Widget>[
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    color: Theme.of(context).colorScheme.onSurface,
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  const Spacer(),
                                  ...expenseActions
                                ],
                              ))),
                    ),
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
                  ])));
        });
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight || oldDelegate.maxHeight != maxHeight || oldDelegate.child != child;
  }
}
