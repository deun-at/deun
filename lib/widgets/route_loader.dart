import 'package:deun/app_paths.dart';
import 'package:deun/deep_links.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/expense_by_id.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/empty_state.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The loading state's indicator, for tests.
const Key kRouteLoadingKey = ValueKey('route-loader-loading');

/// True when a load reported no row: `.single()` on zero rows, which RLS also
/// produces for a group or expense the user may not see.
bool isRowNotFound(Object error) =>
    error is PostgrestException && error.code == 'PGRST116';

/// Builds a group route's page from [prefetched] when it is the group in the
/// path, otherwise from `groupDetailProvider(groupId)`. The page shows whenever
/// a group is at hand, so a later failed reload never takes it down.
class GroupRouteLoader extends ConsumerWidget {
  const GroupRouteLoader({
    super.key,
    required this.groupId,
    this.prefetched,
    required this.builder,
  });

  final String groupId;
  final Group? prefetched;
  final Widget Function(BuildContext context, Group group) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isUuid(groupId)) return const RouteNotFound();
    final group = prefetched;
    if (group != null && group.id == groupId) return builder(context, group);
    final state = ref.watch(groupDetailProvider(groupId));
    final loaded = state.value;
    if (loaded != null) return builder(context, loaded);
    return _pending([
      state,
    ], onRetry: () => ref.invalidate(groupDetailProvider(groupId)));
  }
}

/// Builds an expense route's page from [prefetched] when it carries the group
/// and expense in the path, otherwise from `groupDetailProvider(groupId)` and
/// `expenseByIdProvider(expenseId)`, so the page shows the same group object
/// as the group page beneath it. An expense of another group is not found.
class ExpenseRouteLoader extends ConsumerWidget {
  const ExpenseRouteLoader({
    super.key,
    required this.groupId,
    required this.expenseId,
    this.prefetched,
    required this.builder,
  });

  final String groupId;
  final String expenseId;
  final ExpenseRouteExtra? prefetched;
  final Widget Function(BuildContext context, Group group, Expense expense)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isUuid(groupId) || !isUuid(expenseId)) return const RouteNotFound();
    final extra = prefetched;
    final prefetchedExpense = extra?.expense;
    if (extra != null &&
        prefetchedExpense != null &&
        extra.group.id == groupId &&
        prefetchedExpense.id == expenseId) {
      return builder(context, extra.group, prefetchedExpense);
    }
    final groupState = ref.watch(groupDetailProvider(groupId));
    final expenseState = ref.watch(expenseByIdProvider(expenseId));
    final group = groupState.value;
    final expense = expenseState.value;
    if (group != null && expense != null) {
      return expense.groupId == groupId
          ? builder(context, group, expense)
          : const RouteNotFound();
    }
    return _pending(
      [groupState, expenseState],
      onRetry: () {
        if (groupState.hasError) ref.invalidate(groupDetailProvider(groupId));
        if (expenseState.hasError) {
          ref.invalidate(expenseByIdProvider(expenseId));
        }
      },
    );
  }
}

/// A route whose loads have not all produced a value: not-found when one
/// reported no row, the error state when one failed otherwise (also while
/// Riverpod retries it), and loading while they run.
Widget _pending(
  List<AsyncValue<Object>> states, {
  required VoidCallback onRetry,
}) {
  final errors = [
    for (final state in states)
      if (state.error case final Object error) error,
  ];
  if (errors.any(isRowNotFound)) return const RouteNotFound();
  if (errors.isNotEmpty) return _RouteError(onRetry: onRetry);
  return const _RouteStateFrame(
    child: CircularProgressIndicator(key: kRouteLoadingKey),
  );
}

/// The not-found state. Its back action returns to the group list: nothing
/// beneath a page with a dead id is worth landing on.
class RouteNotFound extends StatelessWidget {
  const RouteNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return _RouteStateFrame(
      onBack: () => GoRouter.of(context).go('/group'),
      child: EmptyState(
        icon: Icons.search_off,
        headline: AppLocalizations.of(context)!.pageNotFound,
      ),
    );
  }
}

class _RouteError extends StatelessWidget {
  const _RouteError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _RouteStateFrame(
      child: EmptyState(
        icon: Icons.cloud_off,
        headline: l10n.generalError,
        actionLabel: l10n.retry,
        onAction: onRetry,
        tone: EmptyStateTone.error,
      ),
    );
  }
}

/// A header with a back action over centered content. Inside a bottom-sheet
/// route, the same content under a close action instead.
class _RouteStateFrame extends StatelessWidget {
  const _RouteStateFrame({required this.child, this.onBack});

  final Widget child;

  /// Null pops as usual.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context) is ModalBottomSheetRoute) {
      return SheetScaffold(
        // The title row carries the close action.
        title: '',
        titleTrailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        body: Center(child: child),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          DeunHeader(title: '', onLeading: onBack),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }
}
