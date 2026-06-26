import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/personal_groups_section.dart';
import 'package:deun/pages/statistics/widgets/personal_summary_section.dart';
import 'package:deun/pages/statistics/widgets/personal_trend_section.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalStatisticsPage extends ConsumerStatefulWidget {
  const PersonalStatisticsPage({super.key});

  @override
  ConsumerState<PersonalStatisticsPage> createState() => _PersonalStatisticsPageState();
}

class _PersonalStatisticsPageState extends ConsumerState<PersonalStatisticsPage> {
  // ponytail: fixed range — v3 personal stats has no range control (DESIGN_SPEC §14).
  static const _range = StatsRange.sixMonths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(personalStatisticsProvider(_range));
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          DeunHeader(title: l10n.statisticsPersonalOverviewTitle),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    state.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyLarge),
                      ),
                      data: (data) {
                        if (data.expenseCount == 0 && data.groups.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyLarge),
                            ),
                          );
                        }
                        return const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PersonalSummarySection(range: _range),
                            PersonalTrendSection(range: _range),
                            PersonalGroupsSection(range: _range),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
