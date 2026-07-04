import 'dart:io';

import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/spaced_card_list.dart';
import 'package:deun/widgets/staggered_list.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
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

    // Native ads are only mounted in non-web RELEASE builds. In debug/test (and
    // the design-audit) builds the ad unit IDs come from empty
    // String.fromEnvironment dart-defines, so the AdMob SDK paints its own red
    // "Ad with the following id could not be found: 0" debug platform-view
    // instead of an ad (design-audit F33). Gating creation behind !kDebugMode
    // means no ad is ever requested or mounted in debug, so that banner can
    // never appear on the home — while production (release, real fill) keeps
    // the ad feature unchanged.
    if (kIsWeb || kDebugMode) {
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
                  // Single scroll view: the empty content + create-first-group
                  // CTA are laid out inline (not via EmptyListWidget's own inner
                  // ListView, which would nest an unbounded viewport). With no
                  // group list to head, the "+ New" section-header action isn't
                  // rendered, so the empty state carries the create affordance
                  // (F91: the standalone FAB was removed as redundant when
                  // groups exist).
                  child: ListView(
                    children: [
                      _GreetingHeader(),
                      const SizedBox(height: 100),
                      Icon(Icons.group_outlined,
                          size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        l10n.groupNoEntries,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: PrimaryButton(
                          label: l10n.addNewGroup,
                          icon: Icons.add,
                          onPressed: () => GoRouter.of(context).push("/group/edit"),
                        ),
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
                  child: ShimmerCardList(
                    height: 100,
                    listEntryLength: 8,
                    shape: ShimmerShape.card,
                  ),
                ),
              ],
            ),
        },
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
        emphasized: true,
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
        // SPACED list preset (F143): consistent inter-card gap owned by the list.
        ...staggeredChildren(context, spacedCardItems(cardItems)),
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

/// Time-of-day greeting buckets used on the groups home header.
enum GreetingBucket { morning, afternoon, evening, night }

/// Pure hour->bucket mapping (device local time). Boundaries:
/// morning 05-11, afternoon 12-16, evening 17-21, night 22-04.
/// Exposed for tests so the choice doesn't depend on wall-clock.
GreetingBucket greetingBucketForHour(int hour) {
  if (hour >= 5 && hour < 12) return GreetingBucket.morning;
  if (hour >= 12 && hour < 17) return GreetingBucket.afternoon;
  if (hour >= 17 && hour < 22) return GreetingBucket.evening;
  return GreetingBucket.night;
}

String greetingLabel(AppLocalizations l10n, GreetingBucket bucket) {
  switch (bucket) {
    case GreetingBucket.morning:
      return l10n.homeGreetingMorning;
    case GreetingBucket.afternoon:
      return l10n.homeGreetingAfternoon;
    case GreetingBucket.evening:
      return l10n.homeGreetingEvening;
    case GreetingBucket.night:
      return l10n.homeGreetingNight;
  }
}

/// Time-aware greeting ("Good evening" over the user's name), multi-line,
/// with the current user's avatar on the right.
class _GreetingHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(userDetailProvider);

    final user = userAsync.value;
    final name = (user?.displayName.isNotEmpty ?? false)
        ? user!.displayName
        : (user?.firstName ?? '');

    final greeting = greetingLabel(l10n, greetingBucketForHour(DateTime.now().hour));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Muted secondary greeting line (DESIGN_SPEC "Text secondary").
                Text(
                  greeting,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Name line: Bricolage display tier (v3 hero-style header).
                Text(
                  name.isEmpty ? l10n.groups : name,
                  style: textTheme.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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

    // Lead label only — the hero amount is now always white-on-ink (F90), so the
    // net sign drives just the wording, not a semantic color on the big number.
    final String leadLabel;
    if (settled) {
      leadLabel = l10n.homeOverallSettled;
    } else if (net > 0) {
      leadLabel = l10n.homeOverallOwed;
    } else {
      leadLabel = l10n.homeOverallOwe;
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
            // v3 hero lead: 13px / w600 muted (handoff Groups home). labelLarge
            // defaults to w500 which read too light against the hero amount.
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: onHeroMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          if (settled)
            Text(
              l10n.toCurrency(0),
              // Hero amount: big w700 Bricolage display tier (DESIGN_SPEC
              // "hero amount"). displayMedium (45px / w700 / -0.02em, tabular)
              // is the shared big-amount token — displaySmall (40px / w600) was
              // too small and too light versus the v3 hero.
              style: Theme.of(context).textTheme.displayMedium?.copyWith(color: onHero),
            )
          else
            // Hero amount renders white-on-ink like the settled branch (F90):
            // the big number is neutral onHero; only the _HeroStat chips below
            // carry semantic green/red. semanticMode still drives the lead label.
            MoneyText(
              net.abs(),
              semantic: MoneySemantic.neutral,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(color: onHero),
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
          // v3 stat-chip label: 11px / w600 muted (handoff Groups home). The
          // default labelMedium w500 read too light next to the w700 amount.
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: onHeroMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
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
