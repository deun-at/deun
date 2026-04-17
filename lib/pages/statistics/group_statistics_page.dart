import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/categories_section.dart';
import 'package:deun/pages/statistics/widgets/members_section.dart';
import 'package:deun/pages/statistics/widgets/range_selector.dart';
import 'package:deun/pages/statistics/widgets/summary_section.dart';
import 'package:deun/pages/statistics/widgets/trend_section.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupStatisticsPage extends ConsumerStatefulWidget {
  const GroupStatisticsPage({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupStatisticsPage> createState() => _GroupStatisticsPageState();
}

class _GroupStatisticsPageState extends ConsumerState<GroupStatisticsPage> {
  StatsRange _range = StatsRange.sixMonths;
  int _offset = 0;

  StatsWindow _currentWindow() {
    final now = DateTime.now();
    if (_range == StatsRange.allTime) {
      final end = DateTime(now.year, now.month + 1, 1);
      final start = DateTime(now.year - 10, 1, 1);
      return StatsWindow(start, end);
    }
    final lastIncluded = DateTime(now.year, now.month - _offset, 1);
    final end = DateTime(lastIncluded.year, lastIncluded.month + 1, 1);
    final months = _range.months!;
    final start = DateTime(lastIncluded.year, lastIncluded.month - (months - 1), 1);
    return StatsWindow(start, end);
  }

  void _openMonth(MonthBucket bucket) {
    GoRouter.of(context).push('/group/details/statistics/month', extra: {
      'group': widget.group,
      'monthStart': bucket.start,
      'monthEnd': bucket.end,
    });
  }

  void _openCategory(String categoryName) {
    final window = _currentWindow();
    GoRouter.of(context).push('/group/details/statistics/category', extra: {
      'groupId': widget.group.id,
      'categoryName': categoryName,
      'monthStart': window.start,
      'monthEnd': window.end,
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = StatsRangeArgs(
      groupId: widget.group.id,
      range: _range,
      endOffsetMonths: _offset,
    );
    final l10n = AppLocalizations.of(context)!;

    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.statisticsTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: StatsRangeSelector(
                    current: _range,
                    onChanged: (r) => setState(() {
                      _range = r;
                      _offset = 0;
                    }),
                    offsetMonths: _offset,
                    onOffsetChanged: (o) => setState(() => _offset = o),
                  ),
                ),
                SliverToBoxAdapter(child: StatsSummarySection(args: args)),
                SliverToBoxAdapter(
                  child: StatsTrendSection(args: args, onMonthTap: _openMonth),
                ),
                SliverToBoxAdapter(child: StatsMembersSection(args: args)),
                SliverToBoxAdapter(
                  child: StatsCategoriesSection(args: args, onCategoryTap: _openCategory),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    );
  }
}
