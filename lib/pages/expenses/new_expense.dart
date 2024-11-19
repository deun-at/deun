import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:split_it_supa/main.dart';

import '../../constants.dart';
import '../../widgets/decimal_text_input_formatter.dart';

class ExpenseBottomSheet extends StatefulWidget {
  const ExpenseBottomSheet(
      {super.key, required this.groupDocId, required this.updateExpenseList, this.expenseDocId});

  final int groupDocId;
  final int? expenseDocId;
  final VoidCallback updateExpenseList;

  @override
  State<ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends State<ExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final expenseNameController = TextEditingController();
  final expenseAmountController = TextEditingController();

  ColorSeed groupColor = ColorSeed.baseColor;
  final NumberFormat numFormat = NumberFormat('###,##0.00', 'en_US');

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    expenseNameController.dispose();
    expenseAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10;

    String titleText = AppLocalizations.of(context)!.createNewExpense;

    debugPrint(widget.expenseDocId.toString());

    if(widget.expenseDocId != null) {
      supabase
      .from('expense')
      .select()
      .eq('id', widget.expenseDocId ?? '')
      .limit(1)
      .single()
      .then((value) {
        titleText = value['name'];
      });
    }

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
                      Text(titleText,
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
                              var amount =
                                  double.parse(expenseAmountController.text);

                              supabase.from('expense').insert({
                                'group_id': widget.groupDocId,
                                'name': expenseNameController.text,
                                'amount': amount,
                                'user_id': supabase.auth.currentUser?.id
                              }).then((value) {
                                widget.updateExpenseList();
                                Navigator.pop(context);
                              });
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.create))
                    ],
                  )))),
    );
  }
}
