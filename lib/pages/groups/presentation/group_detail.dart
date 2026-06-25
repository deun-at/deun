import 'dart:async';
import 'dart:io';

import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/data/reminder_repository.dart';
import 'package:deun/pages/groups/presentation/group_detail_list.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants.dart';
import '../../../widgets/native_ad_block.dart';
import '../../expenses/data/receipt_scan_result.dart';
import '../../expenses/presentation/receipt_scanner_sheet.dart';
import '../provider/group_detail.dart';

import '../../../widgets/card_list_view_builder.dart';
import '../../../widgets/restyle/avatar_stack.dart';
import '../../../widgets/restyle/money_text.dart';
import '../../../widgets/theme_builder.dart';
import '../../groups/data/group_member_model.dart';
import '../data/group_model.dart';
import 'group_share_widget.dart';

class GroupDetail extends ConsumerStatefulWidget {
  const GroupDetail({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends ConsumerState<GroupDetail> {
  final ScrollController _scrollController = ScrollController();
  final SearchController _searchController = SearchController();
  int oldLength = 0;
  Widget? _adBlock;
  bool _showText = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);

    if (kIsWeb) {
      _adBlock = const SizedBox();
    } else {
      _adBlock = NativeAdBlock(
        adUnitId: Platform.isAndroid ? MobileAdMobs.androidExpenseList.value : MobileAdMobs.iosExpenseList.value,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_showText) {
        setState(() {
          _showText = false;
        });
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_showText) {
        setState(() {
          _showText = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        return Scaffold(
          body: NotificationListener<ScrollUpdateNotification>(
            child: NestedScrollView(
              physics: const BouncingScrollPhysics(),
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar.medium(
                  title: Text(widget.group.name,
                      style: GoogleFonts.robotoSerif(
                          textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  actions: [
                    SearchAnchor(
                      builder: (context, controller) {
                        return IconButton(
                          tooltip: AppLocalizations.of(context)!.expensesSearchTitle,
                          onPressed: () {
                            controller.openView();
                          },
                          icon: const Icon(Icons.search),
                        );
                      },
                      searchController: _searchController,
                      suggestionsBuilder: (context, controller) {
                        if (controller.text.isEmpty) {
                          return <Widget>[
                            CardListTile(
                              isTop: true,
                              isBottom: true,
                              child: ListTile(
                                title: Text(AppLocalizations.of(context)!.expensesSearchDescription),
                              ),
                            ),
                          ];
                        }
                        return getExpenseSuggestions(controller, widget.group);
                      },
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.statisticsTitle,
                      onPressed: () {
                        GoRouter.of(context).push("/group/details/statistics", extra: {'group': widget.group});
                      },
                      icon: const Icon(Icons.bar_chart),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.editGroup,
                      onPressed: () {
                        GoRouter.of(context).push("/group/edit", extra: {'group': widget.group});
                      },
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer(
                        builder: (ctx, watch, child) {
                          final groupDetailState = ref.watch(groupDetailProvider(widget.group.id));
                          final isLoading = groupDetailState.isLoading;
                          final groupDetail = groupDetailState.value;

                          if (isLoading || groupDetail == null) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 5.0, top: 5.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                      height: 30, width: 250, child: ShimmerCardList(height: 20, listEntryLength: 1)),
                                  SizedBox(
                                    height: 16,
                                    width: 250,
                                    child: ShimmerCardList(height: 10, listEntryLength: 1),
                                  ),
                                  SizedBox(
                                    height: 16,
                                    width: 250,
                                    child: ShimmerCardList(height: 10, listEntryLength: 1),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _GroupBalanceHero(group: groupDetail),
                                const SizedBox(height: 14),
                                _GroupQuickActions(group: groupDetail),
                                const SizedBox(height: 14),
                                GroupShareWidget(
                                  group: groupDetail,
                                  onRemind: (email) async {
                                  try {
                                    final lastReminder = await ReminderRepository.getLastReminder(groupDetail.id, email);
                                    if (lastReminder != null && DateTime.now().difference(lastReminder).inHours < 24) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(AppLocalizations.of(context)!.reminderCooldown)),
                                        );
                                      }
                                      return;
                                    }

                                    await ReminderRepository.sendReminder(groupDetail.id, email);

                                    if (context.mounted) {
                                      sendPaymentReminderNotification(
                                        context,
                                        groupDetail.id,
                                        {email},
                                        groupDetail.groupSharesSummary[email]?.shareAmount.abs() ?? 0,
                                      );

                                      final displayName = groupDetail.groupSharesSummary[email]?.displayName ?? email;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(AppLocalizations.of(context)!.reminderSent(displayName))),
                                      );
                                    }
                                    } catch (e) {
                                      debugPrint('Reminder failed for $email: $e');
                                      if (context.mounted) {
                                        showSnackBar(context, AppLocalizations.of(context)!.generalError);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              body: SafeArea(
                top: false,
                child: GroupDetailList(
                  group: widget.group,
                  adBlock: _adBlock,
                ),
              ),
            ),
            onNotification: (ScrollUpdateNotification notification) {
              final FocusScopeNode currentScope = FocusScope.of(context);
              if (notification.dragDetails != null && !currentScope.hasPrimaryFocus && currentScope.hasFocus) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
              return false;
            },
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                onPressed: () {
                  GoRouter.of(context).push("/group/details/payment", extra: {'group': widget.group});
                },
                child: const Icon(Icons.credit_card),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: "floating_action_button_scan",
                onPressed: () async {
                  final result = await showModalBottomSheet<ReceiptScanResult>(
                    context: context,
                    sheetAnimationStyle: kSheetAnimationStyle,
                    builder: (context) => const ReceiptScannerSheet(),
                  );
                  if (result != null && context.mounted) {
                    unawaited(GoRouter.of(context).push("/group/details/expense", extra: {
                      'group': widget.group,
                      'expense': null,
                      'receiptResult': result,
                    }));
                  }
                },
                child: const Icon(Icons.document_scanner_outlined),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: "floating_action_button_main",
                extendedIconLabelSpacing: _showText ? 10 : 0,
                extendedPadding: _showText ? null : const EdgeInsets.all(16),
                onPressed: () {
                  GoRouter.of(context).push("/group/details/expense", extra: {'group': widget.group, 'expense': null});
                },
                label: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: _showText ? Text(AppLocalizations.of(context)!.addNewExpense) : const Text(""),
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Iterable<Widget>> getExpenseSuggestions(SearchController controller, Group group) async {
    final String input = controller.value.text;

    if (input.isEmpty) {
      return [];
    }

    final l10n = AppLocalizations.of(context)!;

    List<Expense> result = await ExpenseRepository.fetchData(group.id, 0, 9, input);
    if (result.isEmpty) {
      return [
        CardListTile(
          isTop: true,
          isBottom: true,
          child: ListTile(
            title: Text(l10n.expensesSearchEmpty),
          ),
        ),
      ];
    }

    int resultLength = result.length;
    int index = 0;

    return result.map(
      (expense) {
        double expenseSum = expense.expenseEntries.values.fold<double>(0, (sum, expense) => sum + expense.amount);

        bool isTop = false;
        bool isBottom = false;
        if (index == 0) {
          isTop = true;
        }

        if (index == resultLength - 1) {
          isBottom = true;
        }

        index++;

        return CardListTile(
          isTop: isTop,
          isBottom: isBottom,
          child: ListTile(
            title: Text(expense.name),
            subtitle: Text(AppLocalizations.of(context)!.toCurrency(expenseSum)),
            trailing: Text(formatDate(expense.expenseDate, context)),
            onTap: () async {
              controller.closeView("");
              unawaited(GoRouter.of(context).push("/group/details/expense", extra: {'group': group, 'expense': expense}));
            },
          ),
        );
      },
    );
  }
}

/// Color hero summarizing the group balance: lead label + amount, the member
/// avatar stack, and a "Settle up" button into the payment screen.
///
/// The surrounding [ThemeBuilder] has already re-tinted the theme by
/// `Group.colorValue`, so the hero's tint comes from `colorScheme.primary*`.
class _GroupBalanceHero extends StatelessWidget {
  const _GroupBalanceHero({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group-tinted hero surface from the (already re-themed) color scheme.
    final Color heroSurface = isDark ? colorScheme.primaryContainer : colorScheme.primary;
    final Color onHero = isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    final net = group.totalShareAmount;
    final bool settled = net.abs() < 0.005;

    final String leadLabel;
    final MoneySemantic semanticMode;
    if (settled) {
      leadLabel = l10n.balanceSettled;
      semanticMode = MoneySemantic.neutral;
    } else if (net > 0) {
      leadLabel = l10n.balanceOwed;
      semanticMode = MoneySemantic.neutral;
    } else {
      leadLabel = l10n.balanceOwe;
      semanticMode = MoneySemantic.neutral;
    }

    final members = group.groupMembers
        .map((GroupMember m) => AvatarStackMember(
              name: m.displayName,
              colorKey: m.email,
              isYou: m.email == supabase.auth.currentUser?.email,
            ))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: heroSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leadLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onHeroMuted),
          ),
          const SizedBox(height: 6),
          MoneyText(
            settled ? 0 : net.abs(),
            semantic: semanticMode,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: onHero),
            animate: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (members.isNotEmpty)
                AvatarStack(
                  members: members,
                  ringColor: heroSurface,
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  GoRouter.of(context).push("/group/details/payment", extra: {'group': group});
                },
                icon: const Icon(Icons.credit_card, size: 18),
                label: Text(l10n.groupDetailSettleUp),
                style: FilledButton.styleFrom(
                  backgroundColor: onHero,
                  foregroundColor: heroSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The Statistics + Invite quick-action row beneath the hero.
class _GroupQuickActions extends StatelessWidget {
  const _GroupQuickActions({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              GoRouter.of(context).push("/group/details/statistics", extra: {'group': group});
            },
            icon: const Icon(Icons.bar_chart, size: 18),
            label: Text(l10n.statisticsTitle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              GoRouter.of(context).push("/group/share", extra: {'group': group});
            },
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(l10n.invite),
          ),
        ),
      ],
    );
  }
}
