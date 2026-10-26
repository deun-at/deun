// typed-routes: every in-app way into a group or expense page, over the real
// route table with the loads faked. Each test taps the control a user taps
// and reads which page opened, and for which group and expense.

import 'package:deun/app_paths.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/receipt_scan_result.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/receipt_scanner_sheet.dart';
import 'package:deun/pages/groups/presentation/group_detail.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/pages/groups/presentation/group_detail_payment.dart';
import 'package:deun/pages/groups/presentation/group_invite_page.dart';
import 'package:deun/pages/statistics/category_detail_bottom_sheet.dart';
import 'package:deun/pages/statistics/group_statistics_page.dart';
import 'package:deun/pages/statistics/month_detail_bottom_sheet.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/push_notifications.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helper/app_router_harness.dart';

Finder _headerAction(String tooltip) => find.byWidgetPredicate(
  (w) => w is HeaderIconButton && w.tooltip == tooltip,
);

List<Override> _statistics({
  List<MonthBucket> months = const [],
  List<CategoryMonthTotal> categories = const [],
}) => [
  groupSpendingSummaryProvider.overrideWith(
    (ref, StatsRangeArgs args) async => SpendingSummary.empty,
  ),
  groupTrendProvider.overrideWith((ref, StatsRangeArgs args) async => months),
  groupMemberBreakdownProvider.overrideWith(
    (ref, StatsRangeArgs args) async => const <MemberSpendingBreakdown>[],
  ),
  groupCategoryBreakdownProvider.overrideWith(
    (ref, StatsRangeArgs args) async => categories,
  ),
];

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a group list row opens that group detail', (tester) async {
    final loads = FakeRouteLoads.standard();
    final group = loads.groups[groupId]!;
    await pumpApp(tester, '/group', loads: loads, listed: [group]);
    await settle(tester);
    await tester.tap(find.text(group.name));
    await settle(tester);
    expect(
      tester.widget<GroupDetail>(find.byType(GroupDetail)).group,
      same(group),
    );
  });

  testWidgets(
    'the group detail opens the form, share sheet, settle-up, statistics and new expense of its group',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final actions = <(Finder, void Function())>[
        (
          _headerAction(l10n.editGroup),
          () => expect(
            tester.widget<GroupEdit>(find.byType(GroupEdit)).group!.id,
            groupId,
          ),
        ),
        (
          find.text(l10n.invite),
          () => expect(
            tester
                .widget<GroupInvitePage>(find.byType(GroupInvitePage))
                .group
                .id,
            groupId,
          ),
        ),
        (
          find.text(l10n.groupDetailSettleUp),
          () => expect(
            tester
                .widget<GroupPaymentBottomSheet>(
                  find.byType(GroupPaymentBottomSheet),
                )
                .group
                .id,
            groupId,
          ),
        ),
        (
          find.text(l10n.statisticsTitle),
          () => expect(
            tester
                .widget<GroupStatisticsPage>(find.byType(GroupStatisticsPage))
                .group
                .id,
            groupId,
          ),
        ),
        (
          find.text(l10n.addNewExpense),
          () {
            final editor = tester.widget<ExpenseDetail>(
              find.byType(ExpenseDetail),
            );
            expect(editor.group.id, groupId);
            expect(editor.expense, isNull);
            expect(editor.receiptResult, isNull);
          },
        ),
      ];
      for (final (target, expectPage) in actions) {
        await pumpApp(
          tester,
          AppPaths.group(groupId),
          loads: FakeRouteLoads.standard(),
        );
        await settle(tester);
        await tester.tap(target);
        await settle(tester);
        expectPage();
      }
    },
  );

  testWidgets('the group form opens the share sheet of its group', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      AppPaths.groupEdit(groupId),
      loads: FakeRouteLoads.standard(),
    );
    await settle(tester);
    await tester.ensureVisible(find.text(l10n.groupInviteTitle));
    await tester.pump();
    await tester.tap(find.text(l10n.groupInviteTitle));
    await settle(tester);
    expect(
      tester.widget<GroupInvitePage>(find.byType(GroupInvitePage)).group.id,
      groupId,
    );
  });

  testWidgets(
    'the read view opens the editor and the claim page of its expense',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final location = AppPaths.expense(groupId, claimExpenseId);

      await pumpApp(tester, location, loads: FakeRouteLoads.standard());
      await settle(tester);
      await tester.tap(_headerAction(l10n.edit));
      await settle(tester);
      final editor = tester.widget<ExpenseDetail>(find.byType(ExpenseDetail));
      expect(editor.group.id, groupId);
      expect(editor.expense!.id, claimExpenseId);

      await pumpApp(tester, location, loads: FakeRouteLoads.standard());
      await settle(tester);
      await tester.ensureVisible(find.text(l10n.expenseReviewClaimTitle));
      await tester.pump();
      await tester.tap(find.text(l10n.expenseReviewClaimTitle));
      await settle(tester);
      final claim = tester.widget<ClaimPage>(find.byType(ClaimPage));
      expect(claim.group.id, groupId);
      expect(claim.expense.id, claimExpenseId);
    },
  );

  testWidgets('the claim page opens the editor of its expense', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      AppPaths.expenseClaim(groupId, claimExpenseId),
      loads: FakeRouteLoads.standard(),
    );
    await settle(tester);
    await tester.tap(find.byTooltip(l10n.claimEditItems));
    await settle(tester);
    final editor = tester.widget<ExpenseDetail>(find.byType(ExpenseDetail));
    expect(editor.group.id, groupId);
    expect(editor.expense!.id, claimExpenseId);
  });

  testWidgets(
    'a group notification opens that group after one load, without a fetch first',
    (tester) async {
      final loads = FakeRouteLoads.standard();
      final rootKey = GlobalKey<NavigatorState>();
      await pumpApp(tester, '/friend', loads: loads, rootNavigatorKey: rootKey);
      await settle(tester);
      await openPushMessage(
        const RemoteMessage(data: {'type': 'group', 'expense_id': groupId}),
        rootKey,
        loadExpense: loads.loadExpense,
      );
      await settle(tester);
      expect(
        tester.widget<GroupDetail>(find.byType(GroupDetail)).group.id,
        groupId,
      );
      expect(loads.groupCalls, [groupId]);
    },
  );

  testWidgets(
    'a notification for a group that no longer exists shows not-found',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final loads = FakeRouteLoads.standard();
      final rootKey = GlobalKey<NavigatorState>();
      await pumpApp(tester, '/friend', loads: loads, rootNavigatorKey: rootKey);
      await settle(tester);
      await openPushMessage(
        const RemoteMessage(
          data: {'type': 'group', 'expense_id': missingGroupId},
        ),
        rootKey,
        loadExpense: loads.loadExpense,
      );
      await settle(tester);
      expect(find.text(l10n.pageNotFound), findsWidgets);
      expect(find.byType(GroupDetail), findsNothing);
    },
  );

  testWidgets(
    'the month sheet gets the tapped month, and its location reopens the same month',
    (tester) async {
      _tallView(tester);
      final months = [
        MonthBucket(
          start: DateTime(2025, 1),
          end: DateTime(2025, 2),
          total: 10,
        ),
        MonthBucket(
          start: DateTime(2025, 2),
          end: DateTime(2025, 3),
          total: 20,
        ),
        MonthBucket(
          start: DateTime(2025, 3),
          end: DateTime(2025, 4),
          total: 30,
        ),
      ];
      final router = await pumpApp(
        tester,
        AppPaths.groupStatistics(groupId),
        loads: FakeRouteLoads.standard(),
        overrides: _statistics(months: months),
      );
      await settle(tester);
      await tester.tap(find.text('Feb 25'));
      await settle(tester);
      final sheet = tester.widget<StatisticsMonthDetailBottomSheet>(
        find.byType(StatisticsMonthDetailBottomSheet),
      );
      expect(sheet.group.id, groupId);
      expect(sheet.monthStart, DateTime(2025, 2));
      expect(sheet.monthEnd, DateTime(2025, 3));

      // A pushed sheet is the router's current state, location included.
      final location = router.state.uri.toString();
      await pumpApp(
        tester,
        location,
        loads: FakeRouteLoads.standard(),
        overrides: _statistics(months: months),
      );
      await settle(tester);
      final reopened = tester.widget<StatisticsMonthDetailBottomSheet>(
        find.byType(StatisticsMonthDetailBottomSheet),
      );
      expect(reopened.group.id, groupId);
      expect(reopened.monthStart, sheet.monthStart);
      expect(reopened.monthEnd, sheet.monthEnd);
    },
  );

  testWidgets(
    'the category sheet gets the tapped category and the shown window, and its location reopens them',
    (tester) async {
      _tallView(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      const name = 'Café & Bar über';
      final categories = [
        const CategoryMonthTotal(
          categoryName: name,
          categoryDisplayName: name,
          total: 25,
        ),
      ];
      final router = await pumpApp(
        tester,
        AppPaths.groupStatistics(groupId),
        loads: FakeRouteLoads.standard(),
        overrides: _statistics(categories: categories),
      );
      await settle(tester);
      // An unknown name renders under the Other category's label.
      await tester.tap(find.text(ExpenseCategory.other.getDisplayName(l10n)));
      await settle(tester);
      final sheet = tester.widget<CategoryDetailBottomSheet>(
        find.byType(CategoryDetailBottomSheet),
      );
      // The page opens on its six-month window ending with the current month.
      final now = DateTime.now();
      expect(sheet.groupId, groupId);
      expect(sheet.categoryName, name);
      expect(sheet.monthStart, DateTime(now.year, now.month - 5, 1));
      expect(sheet.monthEnd, DateTime(now.year, now.month + 1, 1));

      // A pushed sheet is the router's current state, location included.
      final location = router.state.uri.toString();
      await pumpApp(
        tester,
        location,
        loads: FakeRouteLoads.standard(),
        overrides: _statistics(categories: categories),
      );
      await settle(tester);
      final reopened = tester.widget<CategoryDetailBottomSheet>(
        find.byType(CategoryDetailBottomSheet),
      );
      expect(reopened.categoryName, name);
      expect(reopened.monthStart, sheet.monthStart);
      expect(reopened.monthEnd, sheet.monthEnd);
    },
  );

  testWidgets(
    'a receipt scanned from the group detail pre-fills the new-expense editor',
    (tester) async {
      const receipt = ReceiptScanResult(
        merchantName: 'Corner Bistro',
        total: 42.5,
      );
      await pumpApp(
        tester,
        AppPaths.group(groupId),
        loads: FakeRouteLoads.standard(),
      );
      await settle(tester);
      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await settle(tester);
      // Stand in for a finished scan: the sheet pops with its result.
      Navigator.of(
        tester.element(find.byType(ReceiptScannerSheet)),
      ).pop(receipt);
      await settle(tester);
      final editor = tester.widget<ExpenseDetail>(find.byType(ExpenseDetail));
      expect(editor.group.id, groupId);
      expect(editor.receiptResult, same(receipt));
      expect(
        tester
            .state<FormBuilderState>(find.byType(FormBuilder))
            .instantValue['name'],
        'Corner Bistro',
      );
    },
  );
}
