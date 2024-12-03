import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../widgets/decimal_text_input_formatter.dart';
import '../groups/group_member_model.dart';
import 'expense_entry_model.dart';

class ExpenseEntryWidget extends StatefulWidget {
  const ExpenseEntryWidget({super.key, required this.expenseEntry, required this.index, required this.onRemove, required this.groupMembers});

  final int index;
  final ExpenseEntry expenseEntry;
  final Function onRemove;
  final List<GroupMember> groupMembers;

  @override
  State<ExpenseEntryWidget> createState() => _ExpenseEntryWidgetState();
}

class _ExpenseEntryWidgetState extends State<ExpenseEntryWidget> {
  @override
  Widget build(BuildContext context) {
    const double spacing = 10;

    return Column(children: [
      Card(
          elevation: 8,
          shadowColor: Colors.transparent,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                          child: FormBuilderTextField(
                        key: ValueKey("${widget.index}_name"),
                        name: "expense_entry[${widget.index}][name]",
                        style: Theme.of(context).textTheme.titleLarge,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: AppLocalizations.of(context)!.expenseEntryTitle,
                        ),
                      )),
                      const SizedBox(width: spacing),
                      IconButton.filledTonal(
                        onPressed: () => widget.onRemove(),
                        icon: const Icon(Icons.delete),
                      )
                    ],
                  ),
                  const SizedBox(height: spacing),
                  Row(
                    children: [
                      Flexible(
                          child: FormBuilderTextField(
                        key: ValueKey("${widget.index}_amount"),
                        name: "expense_entry[${widget.index}][amount]",
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: FormBuilderValidators.required(errorText: AppLocalizations.of(context)!.expenseEntryAmountValidationEmpty),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.expenseEntryAmount,
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: spacing),
                  FormBuilderField(
                    key: ValueKey("${widget.index}_shares"),
                    name: "expense_entry[${widget.index}][shares]",
                    initialValue: widget.expenseEntry.expenseEntryShares.isNotEmpty
                        ? widget.expenseEntry.expenseEntryShares
                            .map(
                              (e) => e.email,
                            )
                            .toSet()
                        : widget.groupMembers.map((e) => e.email).toSet(),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormBuilderValidators.required(errorText: AppLocalizations.of(context)!.expenseEntrySharesValidationEmpty),
                    builder: (FormFieldState<dynamic> field) {
                      Set<String> fieldValue = field.value;

                      return InputDecorator(
                          decoration: InputDecoration(
                            label: Text(AppLocalizations.of(context)!.expenseEntrySharesLable),
                            errorText: field.errorText,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(0),
                          ),
                          child: Align(
                              alignment: Alignment.topLeft,
                              child: Wrap(spacing: 8, children: <Widget>[
                                FilterChip(
                                  label: Text(AppLocalizations.of(context)!.all),
                                  onSelected: (bool newValue) {
                                    if (newValue) {
                                      fieldValue = widget.groupMembers.map((e) => e.email).toSet();
                                    } else {
                                      fieldValue = <String>{};
                                    }

                                    field.didChange(fieldValue);
                                  },
                                  selected: fieldValue.length == widget.groupMembers.length,
                                ),
                                ...widget.groupMembers.map((groupMember) {
                                  return FilterChip(
                                      label: Text(groupMember.displayName),
                                      onSelected: (bool newValue) {
                                        if (newValue) {
                                          fieldValue.add(groupMember.email);
                                        } else {
                                          fieldValue.remove(groupMember.email);
                                        }
                                        field.didChange(fieldValue);
                                      },
                                      selected: fieldValue.contains(groupMember.email));
                                }),
                              ])));
                    },
                  ),
                ],
              ))),
      const SizedBox(height: spacing)
    ]);
  }
}
