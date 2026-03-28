import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../data/group_model.dart';

class GroupShareWidget extends StatelessWidget {
  const GroupShareWidget({super.key, required this.group, this.textColor});

  final Group group;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    List<Widget> sharedWidget = group.groupSharesSummary
        .map(
          (String key, GroupSharesSummary e) {
            if (toNumber(e.shareAmount.abs()) == '0.00') {
              return MapEntry(key, const SizedBox());
            }

            Color textColor = Colors.red;
            String paidByYourself = "";
            if (e.shareAmount > 0) {
              paidByYourself = "yes";
              textColor = Colors.green;
            }

            return MapEntry(
              key,
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  AppLocalizations.of(context)!.groupDisplayAmount(
                      e.displayName, paidByYourself, e.shareAmount.abs()),
                  style:
                      Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
                ),
              ),
            );
          },
        )
        .entries
        .map((e) => e.value)
        .toList();

    String paidByYourselfAll = "";
    Color textColorAll = Colors.red;
    if (group.totalShareAmount > 0) {
      paidByYourselfAll = "yes";
      textColorAll = Colors.green;
    }

    String totalSharedText = AppLocalizations.of(context)!
        .groupDisplaySumAmount(paidByYourselfAll, group.totalShareAmount.abs());
    bool isAllDone = toNumber(group.totalShareAmount.abs()) == '0.00';
    if (isAllDone) {
      totalSharedText = AppLocalizations.of(context)!.allDone;
      textColorAll = Colors.green;
    }

    sharedWidget.insert(
      0,
      Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          AppLocalizations.of(context)!.totalExpensesAmount(group.totalExpenses.abs()),
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: textColor ?? Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );

    Widget totalShareContent = Text(
      totalSharedText,
      style: Theme.of(context).textTheme.titleMedium!.copyWith(color: textColorAll),
    );

    if (isAllDone) {
      totalShareContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outlined, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          totalShareContent,
        ],
      );
    }

    sharedWidget.insert(
      1,
      Align(
        alignment: Alignment.bottomLeft,
        child: totalShareContent,
      ),
    );

    return Column(children: sharedWidget);
  }
}
