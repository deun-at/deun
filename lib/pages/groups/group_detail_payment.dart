import 'package:deun/helper/helper.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:deun/main.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

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
                              if (groupShare.shareAmount < 0 && toNumber(groupShare.shareAmount) != '-0.00') {
                                listViewChildren.add(
                                  ListTile(
                                    title: Text(groupShare.dipslayName),
                                    subtitle:
                                        Text(AppLocalizations.of(context)!.toCurrency(groupShare.shareAmount.abs())),
                                    trailing: const Icon(Icons.payment),
                                    onTap: () {
                                      openPayBackDialog(context, widget.group, email, groupShare);
                                    },
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
    Color activeColor = Theme.of(context).colorScheme.onSurface;
    Color disabledColor = Theme.of(context).colorScheme.outline;

    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.payBackDialogTitle),
        children: [
          SimpleDialogOption(
            child: Text(
              AppLocalizations.of(context)!.payBackDialog(groupShare.dipslayName, groupShare.shareAmount.abs()),
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: activeColor),
            ),
          ),
          Divider(),
          SimpleDialogOption(
            onPressed: () async {
              if (groupShare.paypalMe == null) {
                return;
              }
              if (!await launchUrl(
                  Uri.parse("https://www.paypal.me/${groupShare.paypalMe}/${groupShare.shareAmount.abs()}"))) {
                throw Exception(
                    'Could not launch https://www.paypal.me/${groupShare.paypalMe}/${groupShare.shareAmount.abs()}');
              }
            },
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.payBackDialogPaypal,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: groupShare.paypalMe == null ? disabledColor : activeColor),
                ),
                const Spacer(),
                Icon(
                  Icons.payments_outlined,
                  color: groupShare.paypalMe == null ? disabledColor : activeColor,
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              if (groupShare.iban == null) {
                return;
              }

              Clipboard.setData(ClipboardData(text: groupShare.iban as String)).then((_) {});
            },
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.payBackDialogIban,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: groupShare.iban == null ? disabledColor : activeColor),
                ),
                const Spacer(),
                Icon(Icons.credit_card, color: groupShare.iban == null ? disabledColor : activeColor),
              ],
            ),
          ),
          Divider(),
          SimpleDialogOption(
            onPressed: () async {
              try {
                await Group.payBack(context, widget.group.id, email, groupShare.shareAmount.abs());
                if (context.mounted) {
                  showSnackBar(context, groupDetailScaffoldMessengerKey,
                      AppLocalizations.of(context)!.payBackSuccess(email, groupShare.shareAmount.abs()));
                }
              } catch (e) {
                debugPrint(e.toString());
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
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.payBackDialogDone,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: activeColor),
                ),
                const Spacer(),
                Icon(Icons.credit_score, color: activeColor),
              ],
            ),
          ),
          SizedBox(height: 10),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context); // Close delete dialog
            },
            child: Text(
              AppLocalizations.of(context)!.close,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: activeColor),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
