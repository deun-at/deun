import 'dart:io';

import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/staggered_list.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../constants.dart';
import '../../../provider.dart';
import '../../../widgets/native_ad_block.dart';
import '../../../widgets/shimmer_card_list.dart';
import '../provider/group_list.dart';
import 'group_list_item.dart';
import 'group_list_view_model.dart';
import '../data/group_model.dart';

class GroupList extends ConsumerStatefulWidget {
  const GroupList({super.key});

  @override
  ConsumerState<GroupList> createState() => _GroupListState();
}

class _GroupListState extends ConsumerState<GroupList> {
  final ScrollController _scrollController = ScrollController();
  Widget? _adBlock;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _adBlock = const SizedBox();
    } else {
      _adBlock = NativeAdBlock(
        adUnitId: Platform.isAndroid ? MobileAdMobs.androidGroupList.value : MobileAdMobs.iosGroupList.value,
      );
    }
  }

  Future<void> updateGroupList() async {
    await ref.read(groupListProvider.notifier).reload();
  }

  void _toggleFavorite(String groupId) {
    ref.read(groupListProvider.notifier).toggleFavorite(groupId);
  }

  @override
  Widget build(BuildContext context) {
    final groupList = ref.watch(groupListProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (groupList) {
          AsyncData(:final value) => value.isEmpty
              ? RefreshIndicator(
                  onRefresh: updateGroupList,
                  child: ListView(
                    children: [
                      _GreetingHeader(),
                      const SizedBox(height: 8),
                      EmptyListWidget(
                        icon: Icons.group_outlined,
                        label: l10n.groupNoEntries,
                        onRefresh: updateGroupList,
                      ),
                    ],
                  ),
                )
              : _buildList(value),
          AsyncError() => RefreshIndicator(
              onRefresh: updateGroupList,
              child: ListView(
                children: [
                  _GreetingHeader(),
                  const SizedBox(height: 8),
                  EmptyListWidget(
                    icon: Icons.group_outlined,
                    label: l10n.groupEntriesError,
                    onRefresh: updateGroupList,
                  ),
                ],
              ),
            ),
          _ => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GreetingHeader(),
                const Expanded(
                  child: ShimmerCardList(height: 100, listEntryLength: 8),
                ),
              ],
            ),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "floating_action_button_main",
        onPressed: () {
          GoRouter.of(context).push("/group/edit");
        },
        label: Text(l10n.addNewGroup),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List<Group> allGroups) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = sortGroups(allGroups, isFavorite: (g) => g.isFavorite);
    final overall = aggregateOverallBalance(allGroups);

    // Non-animated prefix items (header, hero, section label) are excluded from
    // the stagger so only the group cards enter with the animation.
    final List<Widget> prefixItems = [
      _GreetingHeader(),
      const SizedBox(height: 12),
      _OverallBalanceHero(overall: overall),
      const SizedBox(height: 24),
      SectionLabel(
        l10n.homeYourGroups,
        trailing: TextButton.icon(
          onPressed: () => GoRouter.of(context).push("/group/edit"),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.commonNew),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ),
      const SizedBox(height: 4),
    ];

    final List<Widget> cardItems = [
      for (final group in sorted)
        GroupListItem(
          key: ValueKey(group.id),
          group: group,
          isFavorite: group.isFavorite,
          onFavoriteToggle: () => _toggleFavorite(group.id),
        ),
    ];

    final listView = ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        ...prefixItems,
        ...staggeredChildren(context, cardItems),
      ],
    );

    final refreshable = RefreshIndicator(
      onRefresh: updateGroupList,
      child: MediaQuery.of(context).disableAnimations
          ? listView
          : AnimationLimiter(child: listView),
    );

    // The native ad lives in its OWN sibling region BELOW the scrolling card
    // list — never inside it. The AdMob AdWidget mounts an opaque platform-view
    // (PlatformViewHitTestBehavior.opaque); a failed/disposed ad would otherwise
    // sit in the card list's gesture arena and swallow taps meant for the group
    // cards (design-audit F01). Isolating it here means its hit-test region can
    // only ever cover its own footer box, and when the ad is not loaded the
    // NativeAdBlock collapses to a zero-size, non-hit-testing box (so this
    // footer occupies nothing).
    if (_adBlock == null) return refreshable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: refreshable),
        _adBlock!,
      ],
    );
  }
}

/// Greeting line ("Hi, {name}") with the current user's avatar on the right.
class _GreetingHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(userDetailProvider);

    final user = userAsync.value;
    final name = (user?.displayName.isNotEmpty ?? false)
        ? user!.displayName
        : (user?.firstName ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.isEmpty ? l10n.groups : l10n.homeGreeting(name),
              style: textTheme.headlineMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user != null)
            MemberAvatar(
              name: name.isEmpty ? user.email : name,
              colorKey: user.email,
              isYou: true,
              radius: 20,
            ),
        ],
      ),
    );
  }
}

/// Dark "ink" hero summarizing the user's overall balance across groups:
/// a big "you're owed / you owe €X" plus owed/owe stat chips.
class _OverallBalanceHero extends StatelessWidget {
  const _OverallBalanceHero({required this.overall});

  final OverallBalance overall;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final l10n = AppLocalizations.of(context)!;

    // Dark hero surface: ink card in light, a lighter raised card in dark
    // (DESIGN_SPEC "Dark hero card": #16181A light / #262824 dark).
    final Color heroSurface = isDark ? colorScheme.surfaceBright : colorScheme.onSurface;
    final Color onHero = isDark ? colorScheme.onSurface : colorScheme.surface;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    final net = overall.net;
    final bool settled = net.abs() < 0.01;

    final String leadLabel;
    final MoneySemantic semanticMode;
    if (settled) {
      leadLabel = l10n.homeOverallSettled;
      semanticMode = MoneySemantic.neutral;
    } else if (net > 0) {
      leadLabel = l10n.homeOverallOwed;
      semanticMode = MoneySemantic.positive;
    } else {
      leadLabel = l10n.homeOverallOwe;
      semanticMode = MoneySemantic.negative;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: heroSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? null : kDarkHeroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leadLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onHeroMuted),
          ),
          const SizedBox(height: 6),
          if (settled)
            Text(
              l10n.toCurrency(0),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: onHero),
            )
          else
            MoneyText(
              net.abs(),
              semantic: semanticMode,
              style: Theme.of(context).textTheme.displaySmall,
              animate: true,
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: l10n.homeStatOwed,
                  amount: overall.owed,
                  semantic: MoneySemantic.positive,
                  onHero: onHero,
                  onHeroMuted: onHeroMuted,
                  background: semantic.success.withValues(alpha: isDark ? 0.18 : 0.16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  label: l10n.homeStatOwe,
                  amount: overall.owe,
                  semantic: MoneySemantic.negative,
                  onHero: onHero,
                  onHeroMuted: onHeroMuted,
                  background: semantic.danger.withValues(alpha: isDark ? 0.18 : 0.16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One owed/owe stat chip inside the hero.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.amount,
    required this.semantic,
    required this.onHero,
    required this.onHeroMuted,
    required this.background,
  });

  final String label;
  final double amount;
  final MoneySemantic semantic;
  final Color onHero;
  final Color onHeroMuted;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium?.copyWith(color: onHeroMuted)),
          const SizedBox(height: 4),
          MoneyText(
            amount,
            semantic: semantic,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
