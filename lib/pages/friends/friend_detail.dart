// import 'package:deun/helper/helper.dart';
// import 'package:deun/main.dart';
// import 'package:deun/pages/friends/friendship_model.dart';
// import 'package:deun/pages/users/user_model.dart';
// import 'package:deun/widgets/empty_list_widget.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// import '../../provider.dart';
// import '../../widgets/shimmer_card_list.dart';

// class FriendDetail extends ConsumerStatefulWidget {
//   const FriendDetail({super.key, required this.friendship});

//   final Friendship friendship;

//   @override
//   ConsumerState<FriendDetail> createState() => _FriendDetailState();
// }

// class _FriendDetailState extends ConsumerState<FriendDetail> {
//   final ScrollController _scrollController = ScrollController();
//   bool _showText = true;

//   @override
//   void initState() {
//     super.initState();
//     _scrollController.addListener(_handleScroll);
//   }

//   @override
//   void dispose() {
//     _scrollController.removeListener(_handleScroll);
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _handleScroll() {
//     if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
//       if (_showText) {
//         setState(() {
//           _showText = false;
//         });
//       }
//     } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
//       if (!_showText) {
//         setState(() {
//           _showText = true;
//         });
//       }
//     }
//   }

//   Future<void> updateFriendshipDetail() async {
//     return ref
//         .read(friendshipDetailNotifierProvider(widget.friendship.user.email).notifier)
//         .reload(widget.friendship.user.email);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final AsyncValue<Friendship> friendshipProvider =
//         ref.watch(friendshipDetailNotifierProvider(widget.friendship.user.email));

//     String currStatus = "";

//     return Scaffold(
//       body: NestedScrollView(
//           controller: _scrollController,
//           headerSliverBuilder: (context, innerBoxIsScrolled) => [
//                 SliverAppBar(
//                   expandedHeight: 120,
//                   flexibleSpace: FlexibleSpaceBar(
//                     title: Text(widget.friendship.user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
//                     centerTitle: true,
//                   ),
//                   floating: true, // Your appBar appears immediately
//                   snap: true, // Your appBar displayed %100 or %0
//                   pinned: true, // Your appBar pinned to top
//                 ),
//               ],
//           body: Container(
//               color: Theme.of(context).colorScheme.surface,
//               child: switch (friendshipProvider) {
//                 AsyncData(:final value) => RefreshIndicator(
//                         onRefresh: () async {
//                           updateFriendshipDetail();
//                         },
//                         child: ListView.builder(
//                           padding: EdgeInsets.zero,
//                           itemCount: value.length,
//                           itemBuilder: (context, index) {
//                             Friendship friendship = value[index];
//                             User user = friendship.user;
//                             Widget leadingHeader = const SizedBox();
//                             Widget trailingButton = const SizedBox();

//                             if ((currStatus == "pending" || currStatus == "") && friendship.status == "accepted") {
//                               leadingHeader = Padding(
//                                   padding: const EdgeInsets.only(top: 12, bottom: 12),
//                                   child: Text(
//                                     AppLocalizations.of(context)!.friends,
//                                     style: Theme.of(context).textTheme.headlineSmall,
//                                   ));
//                             } else if (currStatus == "" && friendship.status == "pending") {
//                               leadingHeader = Padding(
//                                   padding: const EdgeInsets.only(top: 12, bottom: 12),
//                                   child: Text(
//                                     AppLocalizations.of(context)!.friendsPending,
//                                     style: Theme.of(context).textTheme.headlineSmall,
//                                   ));
//                             }

//                             if (friendship.status == "pending") {
//                               if (friendship.isRequester) {
//                                 trailingButton = IconButton.filledTonal(
//                                   icon: const Icon(Icons.check),
//                                   onPressed: () {
//                                     Friendship.accepted(user.email);
//                                     showSnackBar(
//                                         context, AppLocalizations.of(context)!.friendshipAccept(user.displayName));
//                                   },
//                                 );
//                               } else {
//                                 trailingButton = IconButton.filledTonal(
//                                   style: IconButton.styleFrom(
//                                       backgroundColor: Theme.of(context).colorScheme.errorContainer,
//                                       foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
//                                   icon: const Icon(Icons.cancel_outlined),
//                                   onPressed: () {
//                                     Friendship.cancel(user.email);
//                                     showSnackBar(context,
//                                         AppLocalizations.of(context)!.friendshipRequestCancel(user.displayName));
//                                   },
//                                 );
//                               }
//                             } else {
//                               Color shareAmountColor = Theme.of(context).colorScheme.onSurface;
//                               if (friendship.shareAmount < 0) {
//                                 shareAmountColor = Colors.red;
//                               } else if (friendship.shareAmount > 0) {
//                                 shareAmountColor = Colors.green;
//                               }
//                               trailingButton = Text(
//                                   style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: shareAmountColor),
//                                   AppLocalizations.of(context)!.toCurrency(friendship.shareAmount));
//                               // trailingButton = IconButton.filledTonal(
//                               //   style: IconButton.styleFrom(
//                               //       backgroundColor: Theme.of(context).colorScheme.errorContainer,
//                               //       foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
//                               //   icon: const Icon(Icons.delete_outline),
//                               //   onPressed: () {
//                               //     openRemoveFriendDialog(
//                               //       context,
//                               //       user,
//                               //     );
//                               //   },
//                               // );
//                             }

//                             currStatus = friendship.status;
//                             return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                               Padding(padding: const EdgeInsets.only(left: 15, right: 15), child: leadingHeader),
//                               ListTile(
//                                 title: Text(user.displayName),
//                                 subtitle: Text(user.email),
//                                 trailing: trailingButton,
//                                 onTap: () {},
//                               ),
//                               const Divider(height: 0),
//                             ]);
//                           },
//                         )),
//                 AsyncError() => EmptyListWidget(
//                     label: AppLocalizations.of(context)!.friendsNoEntries,
//                     onRefresh: () async {
//                       await updateFriendshipDetail();
//                     }),
//                 _ => const ShimmerCardList(
//                     height: 70,
//                     listEntryLength: 20,
//                   ),
//               })),
//     );
//   }

//   void openRemoveFriendDialog(BuildContext modalContext, User user) {
//     showDialog<void>(
//       context: context,
//       builder: (context) => AlertDialog(
//         content: Text(AppLocalizations.of(context)!.removeFriend(user.displayName)),
//         actions: <Widget>[
//           TextButton(
//             child: Text(AppLocalizations.of(context)!.cancel),
//             onPressed: () => Navigator.pop(context),
//           ),
//           FilledButton(
//             style: FilledButton.styleFrom(
//               backgroundColor: Theme.of(context).colorScheme.error,
//               foregroundColor: Theme.of(context).colorScheme.onError,
//             ),
//             child: Text(AppLocalizations.of(context)!.remove),
//             onPressed: () async {
//               try {
//                 Friendship.remove(user.email);
//               } finally {
//                 Navigator.pop(context);
//                 showSnackBar(context, AppLocalizations.of(context)!.friendRemoved(user.displayName));
//               }
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
