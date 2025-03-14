import 'package:deun/helper/helper.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:deun/main.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';

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
    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        snap: true,
        builder: (context, scrollController) {
          return RoundedContainer(
              child: Scaffold(
                  appBar: AppBar(
                    title: Text(AppLocalizations.of(context)!.payBack),
                    centerTitle: true,
                  ),
                  body: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Consumer(
                        builder: (context, ref, child) {
                          final Group? group = ref.watch(groupDetailNotifierProvider(widget.group.id)).value;

                          if (group == null) {
                            return const ShimmerCardList(
                              height: 50,
                              listEntryLength: 8,
                            );
                          }

                          List<Widget> listViewChildren = [];

                          group.groupSharesSummary.forEach(
                            (email, groupShare) {
                              if (groupShare.shareAmount < 0) {
                                listViewChildren.add(
                                  ListTile(
                                    title: Text(groupShare.dipslayName),
                                    subtitle:
                                        Text(AppLocalizations.of(context)!.toCurrency(groupShare.shareAmount.abs())),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.payment),
                                      onPressed: () {
                                        openPayBackDialog(context, widget.group, email, groupShare);
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          );

                          if (listViewChildren.isEmpty) {
                            listViewChildren.add(ListTile(
                              titleTextStyle: Theme.of(context).textTheme.bodyLarge,
                              title: Text(AppLocalizations.of(context)!.payBackNoEntries),
                            ));
                          }

                          return ListView(
                            controller: scrollController,
                            children: listViewChildren,
                          );
                        },
                      ))));
        });
  }

  void openPayBackDialog(BuildContext modalContext, Group group, String email, GroupSharesSummary groupShare) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.payBackDialog(groupShare.dipslayName, groupShare.shareAmount.abs())),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: Text(AppLocalizations.of(context)!.payBack),
            onPressed: () async {
              // if (groupShare.paypalMe == null) {
              //   return;
              // }
              // if (!await launchUrl(Uri.parse("https://www.paypal.me/${groupShare.paypalMe}/200"))) {
              //   throw Exception('Could not launch https://flutter.dev');
              // }
              try {
                await Group.payBack(widget.group.id, email, groupShare.shareAmount.abs());
                if (context.mounted) {
                  showSnackBar(context, groupDetailScaffoldMessengerKey,
                      AppLocalizations.of(context)!.payBackSuccess(email, groupShare.shareAmount.abs()));
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(context, groupDetailScaffoldMessengerKey, AppLocalizations.of(context)!.payBackError);
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
}
