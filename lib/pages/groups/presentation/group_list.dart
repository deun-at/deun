import 'dart:io';

import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/native_ad_block.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants.dart';
import '../../../widgets/shimmer_card_list.dart';
import '../provider/group_list.dart';
import 'group_list_item.dart';
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
      _adBlock = SizedBox();
    } else {
      _adBlock = NativeAdBlock(
        adUnitId: Platform.isAndroid
            ? MobileAdMobs.androidGroupList.value
            : MobileAdMobs.iosGroupList.value,
      );
    }
  }

  Future<void> updateGroupList() async {
    ref.read(groupListProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final groupList = ref.watch(groupListProvider);

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar.medium(
            title: Text(
              AppLocalizations.of(context)!.groups,
              style: GoogleFonts.robotoSerif(
                textStyle: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
        body: switch (groupList) {
          AsyncData(:final value) => value.isEmpty
              ? EmptyListWidget(
                  icon: Icons.group_outlined,
                  label: AppLocalizations.of(context)!.groupNoEntries,
                  onRefresh: () => updateGroupList(),
                )
              : _buildSectionedList(value),
          AsyncError() => EmptyListWidget(
              icon: Icons.group_outlined,
              label: AppLocalizations.of(context)!.groupNoEntries,
              onRefresh: () async {
                await updateGroupList();
              },
            ),
          _ => ShimmerCardList(height: 100, listEntryLength: 8),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "floating_action_button_main",
        onPressed: () {
          GoRouter.of(context).push("/group/edit");
        },
        label: Text(AppLocalizations.of(context)!.addNewGroup),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionedList(List<Group> allGroups) {
    final favoriteGroups = allGroups.where((g) => g.isFavorite).toList();
    final activeGroups = allGroups
        .where((g) => !g.isFavorite && g.totalShareAmount.abs() >= 0.01)
        .toList();
    final settledGroups = allGroups
        .where((g) => !g.isFavorite && g.totalShareAmount.abs() < 0.01)
        .toList();

    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => updateGroupList(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (favoriteGroups.isNotEmpty) ...[
            _buildSectionHeader(
              AppLocalizations.of(context)!.groupSectionFavorites,
              Icons.star,
              Colors.amber,
            ),
            GroupCardListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              groupList: favoriteGroups,
              itemCount: favoriteGroups.length,
              itemBuilder: (context, index) {
                Group group = favoriteGroups[index];
                return GroupListItem(
                  key: ValueKey(group.id),
                  group: group,
                  isFavorite: true,
                  onFavoriteToggle: () => _toggleFavorite(group.id),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          if (activeGroups.isNotEmpty) ...[
            GroupCardListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              adBlock: _adBlock,
              groupList: activeGroups,
              itemCount: activeGroups.length,
              itemBuilder: (context, index) {
                Group group = activeGroups[index];
                return GroupListItem(
                  key: ValueKey(group.id),
                  group: group,
                  isFavorite: false,
                  onFavoriteToggle: () => _toggleFavorite(group.id),
                );
              },
            ),
          ],
          if (settledGroups.isNotEmpty) ...[
            _buildSectionHeader(
              AppLocalizations.of(context)!.groupSectionSettled,
              Icons.check_circle_outlined,
              colorScheme.outline,
            ),
            CardListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              color: colorScheme.surfaceContainerLowest,
              itemCount: settledGroups.length,
              itemBuilder: (context, index) {
                Group group = settledGroups[index];
                return GroupListItem(
                  key: ValueKey(group.id),
                  group: group,
                  isFavorite: false,
                  isMuted: true,
                  onFavoriteToggle: () => _toggleFavorite(group.id),
                );
              },
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(String groupId) {
    ref.read(groupListProvider.notifier).toggleFavorite(groupId);
  }
}
