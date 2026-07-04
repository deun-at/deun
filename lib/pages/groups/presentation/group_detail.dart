import 'dart:async';
import 'dart:io';

import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/presentation/group_detail_list.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../constants.dart';
import '../../../widgets/restyle/deun_header.dart';
import '../../../widgets/restyle/primary_button.dart';
import '../../../widgets/native_ad_block.dart';
import '../../expenses/data/receipt_scan_result.dart';
import '../../expenses/presentation/receipt_scanner_sheet.dart';
import '../provider/group_detail.dart';

import '../../../widgets/card_list_view_builder.dart';
import '../../../widgets/restyle/avatar_stack.dart';
import '../../../widgets/restyle/soft_card.dart';
import '../../../widgets/restyle/money_text.dart';
import '../../../widgets/theme_builder.dart';
import '../../groups/data/group_member_model.dart';
import '../data/group_model.dart';

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
        adUnitId: Platform.isAndroid
            ? MobileAdMobs.androidExpenseList.value
            : MobileAdMobs.iosExpenseList.value,
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
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_showText) {
        setState(() {
          _showText = false;
        });
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
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
            child: Column(
              children: [
                // v3 group-detail header (COMPONENTS.md §2): single 38px row,
                // centered 16/700 title, arrow_back leading + ONE trailing edit.
                // Statistics lives in the in-content quick-action card below
                // (matches v3); the expense search moves into the scroll body.
                DeunHeader(
                  title: widget.group.name,
                  onLeading: () => GoRouter.of(context).pop(),
                  trailing: HeaderIconButton(
                    icon: Icons.tune,
                    tooltip: AppLocalizations.of(context)!.editGroup,
                    onTap: () {
                      GoRouter.of(
                        context,
                      ).push("/group/edit", extra: {'group': widget.group});
                    },
                  ),
                ),
                Expanded(
                  child: NestedScrollView(
                    physics: const BouncingScrollPhysics(),
                    controller: _scrollController,
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Consumer(
                              builder: (ctx, watch, child) {
                                final groupDetailState = ref.watch(
                                  groupDetailProvider(widget.group.id),
                                );
                                final isLoading = groupDetailState.isLoading;
                                final groupDetail = groupDetailState.value;

                                if (isLoading || groupDetail == null) {
                                  return const Padding(
                                    padding: EdgeInsets.only(
                                      bottom: 5.0,
                                      top: 5.0,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 30,
                                          width: 250,
                                          child: ShimmerCardList(
                                            height: 20,
                                            listEntryLength: 1,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 16,
                                          width: 250,
                                          child: ShimmerCardList(
                                            height: 10,
                                            listEntryLength: 1,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 16,
                                          width: 250,
                                          child: ShimmerCardList(
                                            height: 10,
                                            listEntryLength: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16.0,
                                    6.0,
                                    16.0,
                                    6.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _GroupBalanceHero(group: groupDetail),
                                      const SizedBox(height: 14),
                                      _GroupQuickActions(group: groupDetail),
                                      const SizedBox(height: 14),
                                      _buildExpenseSearch(context),
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
                ),
              ],
            ),
            onNotification: (ScrollUpdateNotification notification) {
              final FocusScopeNode currentScope = FocusScope.of(context);
              if (notification.dragDetails != null &&
                  !currentScope.hasPrimaryFocus &&
                  currentScope.hasFocus) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
              return false;
            },
          ),
          // v3 group detail (design_handoff, bottom action area): Scan and Add
          // expense sit side by side in ONE row. Scan = white circular button
          // with an accent icon; Add expense = full-color primary pill.
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: "floating_action_button_scan",
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerLowest,
                foregroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () async {
                  final result = await showModalBottomSheet<ReceiptScanResult>(
                    context: context,
                    sheetAnimationStyle: kSheetAnimationStyle,
                    barrierColor: kSheetBarrierColor,
                    builder: (context) => const ReceiptScannerSheet(),
                  );
                  if (result != null && context.mounted) {
                    unawaited(
                      GoRouter.of(context).push(
                        "/group/details/expense",
                        extra: {
                          'group': widget.group,
                          'expense': null,
                          'receiptResult': result,
                        },
                      ),
                    );
                  }
                },
                child: const Icon(Icons.document_scanner_outlined),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                heroTag: "floating_action_button_main",
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                extendedIconLabelSpacing: _showText ? 10 : 0,
                extendedPadding: _showText ? null : const EdgeInsets.all(16),
                onPressed: () {
                  GoRouter.of(context).push(
                    "/group/details/expense",
                    extra: {'group': widget.group, 'expense': null},
                  );
                },
                label: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: _showText
                      ? Text(AppLocalizations.of(context)!.addNewExpense)
                      : const Text(""),
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Expense search relocated out of the (now v3-faithful) header into the
  /// scroll body. v3 group detail has no header search action — this keeps the
  /// existing expense-search feature alive as a slim search bar above the list.
  Widget _buildExpenseSearch(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SearchAnchor(
      searchController: _searchController,
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          hintText: l10n.expensesSearchTitle,
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          onTap: controller.openView,
          onChanged: (_) => controller.openView(),
        );
      },
      suggestionsBuilder: (context, controller) {
        if (controller.text.isEmpty) {
          return <Widget>[
            CardListTile(
              isTop: true,
              isBottom: true,
              child: ListTile(title: Text(l10n.expensesSearchDescription)),
            ),
          ];
        }
        return getExpenseSuggestions(controller, widget.group);
      },
    );
  }

  Future<Iterable<Widget>> getExpenseSuggestions(
    SearchController controller,
    Group group,
  ) async {
    final String input = controller.value.text;

    if (input.isEmpty) {
      return [];
    }

    final l10n = AppLocalizations.of(context)!;

    List<Expense> result = await ExpenseRepository.fetchData(
      group.id,
      0,
      9,
      input,
    );
    if (result.isEmpty) {
      return [
        CardListTile(
          isTop: true,
          isBottom: true,
          child: ListTile(title: Text(l10n.expensesSearchEmpty)),
        ),
      ];
    }

    int resultLength = result.length;
    int index = 0;

    return result.map((expense) {
      double expenseSum = expense.expenseEntries.values.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

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
            unawaited(
              GoRouter.of(context).push(
                "/group/details/expense",
                extra: {'group': group, 'expense': expense},
              ),
            );
          },
        ),
      );
    });
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
    final Color heroSurface = isDark
        ? colorScheme.primaryContainer
        : colorScheme.primary;
    final Color onHero = isDark
        ? colorScheme.onPrimaryContainer
        : colorScheme.onPrimary;
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
        .map(
          (GroupMember m) => AvatarStackMember(
            name: m.displayName,
            colorKey: m.email,
            isYou: m.email == supabase.auth.currentUser?.email,
          ),
        )
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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: onHeroMuted),
          ),
          const SizedBox(height: 6),
          MoneyText(
            settled ? 0 : net.abs(),
            semantic: semanticMode,
            // Hero amount: matches the home hero (group_list.dart) — shared
            // displayMedium token (45px / w700 / -0.02em, tabular Bricolage).
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: onHero),
            animate: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (members.isNotEmpty)
                // Hero avatars render in ONE uniform tint (a translucent
                // on-hero token), not per-member colors (F140) — matching the
                // handoff's rgba(255,255,255,0.22) chips on the colored surface.
                AvatarStack(
                  members: members,
                  ringColor: heroSurface,
                  uniformColor: onHero.withValues(alpha: 0.22),
                ),
              const Spacer(),
              // Compact 999-radius pill (mockup L470: 9/18 pad), wrapped in
              // Flexible so a long localized label ("Begleichen") ellipsizes
              // instead of overflowing the hero Row.
              Flexible(
                child: PrimaryButton(
                  label: l10n.groupDetailSettleUp,
                  background: onHero,
                  foreground: heroSurface,
                  compact: true,
                  onPressed: () {
                    GoRouter.of(
                      context,
                    ).push("/group/details/payment", extra: {'group': group});
                  },
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
          child: _QuickActionCard(
            icon: Icons.bar_chart,
            label: l10n.statisticsTitle,
            onTap: () {
              GoRouter.of(
                context,
              ).push("/group/details/statistics", extra: {'group': group});
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.person_add_alt_1,
            label: l10n.invite,
            onTap: () {
              GoRouter.of(
                context,
              ).push("/group/share", extra: {'group': group});
            },
          ),
        ),
      ],
    );
  }
}

/// A single white-filled quick-action card (COMPONENTS §quick actions): an
/// accent-tinted icon beside a 700-weight label on a [SoftCard], left-aligned.
/// The icon picks up `colorScheme.primary` — the group's accent, since the
/// detail subtree is wrapped in the group-tinted `ThemeBuilder`.
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      onTap: onTap,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 21, color: colorScheme.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
