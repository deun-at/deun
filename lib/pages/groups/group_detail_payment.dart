import 'package:deun/helper/helper.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'group_model.dart';

class GroupPaymentBottomSheet extends ConsumerStatefulWidget {
  const GroupPaymentBottomSheet({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupPaymentBottomSheet> createState() => _GroupPaymentBottomSheetState();
}

class _GroupPaymentBottomSheetState extends ConsumerState<GroupPaymentBottomSheet> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Group> groupDetail = ref.watch(groupDetailProvider(widget.group.id));
    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 1,
        builder: (context, scrollController) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              title: Text(AppLocalizations.of(context)!.payBack),
              centerTitle: true,
            ),
            body: Container(
                color: Theme.of(context).colorScheme.surface,
                child: switch (groupDetail) {
                  AsyncData(:final value) => ListView.builder(
                      controller: scrollController,
                      itemCount: value.groupSharesSummary.length,
                      itemBuilder: (context, index) {
                        final String email = value.groupSharesSummary.keys.elementAt(index);
                        final GroupSharesSummary groupShare = value.groupSharesSummary.values.elementAt(index);
                        return groupShare.shareAmount < 0
                            ? ListTile(
                                title: Text(groupShare.dipslayName),
                                subtitle: Text(groupShare.shareAmount.abs().toString()),
                                trailing: const Icon(Icons.payment),
                                onTap: () {
                                  openPayBackDialog(context, widget.group, email, groupShare);
                                },
                              )
                            : const SizedBox();
                      },
                    ),
                  _ => const ShimmerCardList(
                      height: 50,
                      listEntryLength: 8,
                    ),
                }),
          );
        });
  }

  void openPayBackDialog(BuildContext modalContext, Group group, String email, GroupSharesSummary groupShare) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content:
            Text(AppLocalizations.of(context)!.payBackDialog(groupShare.dipslayName, groupShare.shareAmount.abs())),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(AppLocalizations.of(context)!.payBack),
            onPressed: () async {
              try {
                await Group.payBack(widget.group.id, email, groupShare.shareAmount.abs());
              } finally {
                //pop both dialog and edit page, because this item is not existing anymore
                Navigator.pop(context);
                Navigator.pop(modalContext);

                showSnackBar(
                    context, AppLocalizations.of(context)!.payBackSuccess(email, groupShare.shareAmount.abs()));
              }
            },
          ),
        ],
      ),
    );
  }
}
