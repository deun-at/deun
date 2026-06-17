import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';

import 'package:deun/widgets/theme_builder.dart';
import '../data/group_model.dart';
import 'group_share_view_model.dart';

class GroupShareWidget extends StatelessWidget {
  const GroupShareWidget({super.key, required this.group, this.textColor, this.onRemind});

  final Group group;
  final Color? textColor;
  final void Function(String email)? onRemind;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    List<Widget> sharedWidget = group.groupSharesSummary
        .map(
          (String key, GroupSharesSummary e) {
            if (e.shareAmount.abs() < 0.005) {
              return MapEntry(key, const SizedBox());
            }

            Color textColor = shareBalanceColor(e.shareAmount, semantic);
            String paidByYourself = "";
            if (e.shareAmount > 0) {
              paidByYourself = "yes";
            }

            final textWidget = Text(
              AppLocalizations.of(context)!.groupDisplayAmount(
                  e.displayName, paidByYourself, e.shareAmount.abs()),
              style:
                  Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
            );

            return MapEntry(
              key,
              Align(
                alignment: Alignment.bottomLeft,
                child: (onRemind != null && e.shareAmount > 0)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: textWidget),
                          const SizedBox(width: 4),
                          SizedBox(
                            height: 28,
                            width: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(Icons.notification_add_outlined),
                              tooltip: AppLocalizations.of(context)!.reminderSend,
                              onPressed: () => onRemind!(key),
                            ),
                          ),
                        ],
                      )
                    : textWidget,
              ),
            );
          },
        )
        .entries
        .map((e) => e.value)
        .toList();

    String paidByYourselfAll = "";
    Color textColorAll = shareBalanceColor(group.totalShareAmount, semantic);
    if (group.totalShareAmount > 0) {
      paidByYourselfAll = "yes";
    }

    String totalSharedText = AppLocalizations.of(context)!
        .groupDisplaySumAmount(paidByYourselfAll, group.totalShareAmount.abs());
    bool isAllDone = group.totalShareAmount.abs() < 0.005;
    if (isAllDone) {
      totalSharedText = AppLocalizations.of(context)!.allDone;
      textColorAll = semantic.success;
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
          Icon(Icons.check_circle_outlined, size: 20, color: semantic.success),
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
