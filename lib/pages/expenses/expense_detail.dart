import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:split_it_supa/main.dart';

class ExpenseDetail extends StatefulWidget {
  const ExpenseDetail(
      {super.key, required this.handleColorSelect, required this.groupDocId, required this.expenseDocId});

  final void Function(int) handleColorSelect;
  final int groupDocId;
  final int expenseDocId;

  @override
  State<ExpenseDetail> createState() => _ExpenseDetailState();
}

class _ExpenseDetailState extends State<ExpenseDetail> {
  @override
  Widget build(BuildContext context) {
    Future _data = supabase.from('expense').select('').eq('id', widget.expenseDocId);

    return FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text(AppLocalizations.of(context)!.generalError,
                    style: Theme.of(context).textTheme.headlineMedium));
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                value: null,
              ),
            );
          }

          dynamic data = snapshot.data!.first;

          return Scaffold(
            appBar: AppBar(
                leading: const BackButton(),
                title: Text(data["name"]),
                centerTitle: true),
            body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              Center(
                  child: Text(data["name"],
                      style: Theme.of(context).textTheme.headlineMedium)),
            ]),
          );
        });
  }
}
