import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../widgets/decimal_text_input_formatter.dart';
import 'expense_model.dart';

class ExpenseEntryWidget extends StatefulWidget {
  const ExpenseEntryWidget(
      {super.key,
      required this.expenseEntry,
      required this.index,
      required this.onRemove});

  final int index;
  final ExpenseEntry expenseEntry;
  final Function onRemove;

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
                          validator: FormBuilderValidators.required(
                              errorText: AppLocalizations.of(context)!
                                  .expenseEntryNameValidationEmpty),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                AppLocalizations.of(context)!.expenseEntryTitle,
                          ),
                      )),
                      const SizedBox(width: spacing),
                      // Text(
                      //   AppLocalizations.of(context)!.expenseEntryTitle,
                      //   style: Theme.of(context).textTheme.titleMedium,
                      // ),
                      // const SizedBox(width: spacing),
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          DecimalTextInputFormatter(decimalRange: 2)
                        ],
                        validator: FormBuilderValidators.required(
                            errorText: AppLocalizations.of(context)!
                                .expenseEntryAmountValidationEmpty),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText:
                              AppLocalizations.of(context)!.expenseEntryAmount,
                        ),
                      )),
                    ],
                  )
                ],
              ))),
      const SizedBox(height: spacing)
    ]);
  }
}
