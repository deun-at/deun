// typed-routes: the real route table opened by location alone. Every group and
// expense page loads its ids from the path; a bad id shows not-found.

import 'package:deun/app_paths.dart';
import 'package:deun/app_router.dart';
import 'package:deun/deep_links.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
import 'package:deun/pages/groups/presentation/group_detail.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/pages/groups/presentation/group_detail_payment.dart';
import 'package:deun/pages/groups/presentation/group_invite_page.dart';
import 'package:deun/pages/groups/presentation/group_join_page.dart';
import 'package:deun/pages/groups/presentation/group_list.dart';
import 'package:deun/pages/groups/presentation/group_members_page.dart';
import 'package:deun/pages/statistics/category_detail_bottom_sheet.dart';
import 'package:deun/pages/statistics/group_statistics_page.dart';
import 'package:deun/pages/statistics/month_detail_bottom_sheet.dart';
import 'package:deun/widgets/route_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper/app_router_harness.dart';

void main() {
  testWidgets(
    'the join location opens the join page with the group, the token and the name it carries',
    (tester) async {
      const token = '9b2c4e1a-6d3f-4a8b-b1c2-7e5d0f9a3c64';
      await pumpApp(
        tester,
        AppPaths.groupJoin(groupId, token: token, name: 'Trip to Rome'),
        loads: FakeRouteLoads.standard(),
      );
      await settle(tester);

      final page = tester.widget<GroupJoinPage>(find.byType(GroupJoinPage));
      expect(
        (page.groupId, page.token, page.groupName),
        (groupId, token, 'Trip to Rome'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'every group and expense location shows a loading state, then the page for the ids in its path',
    (tester) async {
      final cases = <String, void Function(WidgetTester)>{
        AppPaths.group(groupId): (t) => expect(
          t.widget<GroupDetail>(find.byType(GroupDetail)).group.id,
          groupId,
        ),
        AppPaths.groupEdit(groupId): (t) => expect(
          t.widget<GroupEdit>(find.byType(GroupEdit)).group!.id,
          groupId,
        ),
        AppPaths.groupMembers(groupId): (t) => expect(
          t.widget<GroupMembersPage>(find.byType(GroupMembersPage)).group.id,
          groupId,
        ),
        AppPaths.groupShare(groupId): (t) => expect(
          t.widget<GroupInvitePage>(find.byType(GroupInvitePage)).group.id,
          groupId,
        ),
        AppPaths.groupPayment(groupId): (t) => expect(
          t
              .widget<GroupPaymentBottomSheet>(
                find.byType(GroupPaymentBottomSheet),
              )
              .group
              .id,
          groupId,
        ),
        AppPaths.groupStatistics(groupId): (t) => expect(
          t
              .widget<GroupStatisticsPage>(find.byType(GroupStatisticsPage))
              .group
              .id,
          groupId,
        ),
        AppPaths.groupStatisticsMonth(
          groupId,
          start: DateTime(2025, 2),
          end: DateTime(2025, 3),
        ): (t) {
          final sheet = t.widget<StatisticsMonthDetailBottomSheet>(
            find.byType(StatisticsMonthDetailBottomSheet),
          );
          expect(sheet.group.id, groupId);
          expect(sheet.monthStart, DateTime(2025, 2));
          expect(sheet.monthEnd, DateTime(2025, 3));
        },
        AppPaths.expenseNew(groupId): (t) {
          final editor = t.widget<ExpenseDetail>(find.byType(ExpenseDetail));
          expect(editor.group.id, groupId);
          expect(editor.expense, isNull);
        },
        AppPaths.expense(groupId, expenseId): (t) {
          final read = t.widget<ExpenseDetailRead>(
            find.byType(ExpenseDetailRead),
          );
          expect(read.group.id, groupId);
          expect(read.expense.id, expenseId);
        },
        AppPaths.expenseEdit(groupId, expenseId): (t) {
          final editor = t.widget<ExpenseDetail>(find.byType(ExpenseDetail));
          expect(editor.group.id, groupId);
          expect(editor.expense!.id, expenseId);
        },
        AppPaths.expenseClaim(groupId, claimExpenseId): (t) {
          final claim = t.widget<ClaimPage>(find.byType(ClaimPage));
          expect(claim.group.id, groupId);
          expect(claim.expense.id, claimExpenseId);
        },
      };
      for (final MapEntry(key: location, value: expectPage) in cases.entries) {
        await pumpApp(tester, location, loads: FakeRouteLoads.standard());
        await tester.pump();
        expect(find.byKey(kRouteLoadingKey), findsWidgets, reason: location);
        await settle(tester);
        expect(find.byKey(kRouteLoadingKey), findsNothing, reason: location);
        expectPage(tester);
        expect(tester.takeException(), isNull, reason: location);
      }
    },
  );

  testWidgets(
    'the category sheet opens at once with the group, category and window in its location',
    (tester) async {
      final location = AppPaths.groupStatisticsCategory(
        groupId,
        category: 'food',
        start: DateTime(2025, 1),
        end: DateTime(2025, 7),
      );
      await pumpApp(tester, location, loads: FakeRouteLoads.standard());
      await tester.pump();
      // The statistics page beneath is still loading; the sheet is not waiting
      // on it.
      expect(find.byKey(kRouteLoadingKey), findsWidgets);
      final sheet = tester.widget<CategoryDetailBottomSheet>(
        find.byType(CategoryDetailBottomSheet),
      );
      expect(sheet.groupId, groupId);
      expect(sheet.categoryName, 'food');
      expect(sheet.monthStart, DateTime(2025, 1));
      expect(sheet.monthEnd, DateTime(2025, 7));
      await settle(tester);
    },
  );

  testWidgets(
    'an id that is not a UUID shows not-found on every route without loading anything',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      const bad = 'not-a-uuid';
      final badGroup = [
        AppPaths.group(bad),
        AppPaths.groupEdit(bad),
        AppPaths.groupMembers(bad),
        AppPaths.groupShare(bad),
        AppPaths.groupPayment(bad),
        AppPaths.groupStatistics(bad),
        AppPaths.groupStatisticsMonth(
          bad,
          start: DateTime(2025, 2),
          end: DateTime(2025, 3),
        ),
        AppPaths.groupStatisticsCategory(
          bad,
          category: 'food',
          start: DateTime(2025, 1),
          end: DateTime(2025, 7),
        ),
        AppPaths.expenseNew(bad),
        AppPaths.expense(bad, expenseId),
        AppPaths.expenseEdit(bad, expenseId),
        AppPaths.expenseClaim(bad, expenseId),
      ];
      final badExpense = [
        AppPaths.expense(groupId, bad),
        AppPaths.expenseEdit(groupId, bad),
        AppPaths.expenseClaim(groupId, bad),
      ];
      for (final location in [...badGroup, ...badExpense]) {
        final loads = FakeRouteLoads.standard();
        await pumpApp(tester, location, loads: loads);
        await settle(tester);
        expect(find.text(l10n.pageNotFound), findsWidgets, reason: location);
        expect(find.text(l10n.generalError), findsNothing, reason: location);
        expect(loads.expenseCalls, isEmpty, reason: location);
        if (badGroup.contains(location)) {
          expect(loads.groupCalls, isEmpty, reason: location);
        }
        expect(tester.takeException(), isNull, reason: location);
      }
    },
  );

  testWidgets(
    'a group or expense with no row, or an expense from another group, shows not-found on every route',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final locations = [
        AppPaths.group(missingGroupId),
        AppPaths.groupEdit(missingGroupId),
        AppPaths.groupMembers(missingGroupId),
        AppPaths.groupShare(missingGroupId),
        AppPaths.groupPayment(missingGroupId),
        AppPaths.groupStatistics(missingGroupId),
        AppPaths.groupStatisticsMonth(
          missingGroupId,
          start: DateTime(2025, 2),
          end: DateTime(2025, 3),
        ),
        AppPaths.expenseNew(missingGroupId),
        AppPaths.expense(missingGroupId, expenseId),
        AppPaths.expenseEdit(missingGroupId, expenseId),
        AppPaths.expenseClaim(missingGroupId, expenseId),
        AppPaths.expense(groupId, missingExpenseId),
        AppPaths.expenseEdit(groupId, missingExpenseId),
        AppPaths.expenseClaim(groupId, missingExpenseId),
        // foreignExpenseId's row belongs to otherGroupId, not groupId.
        AppPaths.expense(groupId, foreignExpenseId),
        AppPaths.expenseEdit(groupId, foreignExpenseId),
        AppPaths.expenseClaim(groupId, foreignExpenseId),
      ];
      for (final location in locations) {
        await pumpApp(tester, location, loads: FakeRouteLoads.standard());
        await settle(tester);
        expect(find.text(l10n.pageNotFound), findsWidgets, reason: location);
        expect(find.text(l10n.generalError), findsNothing, reason: location);
        expect(tester.takeException(), isNull, reason: location);
      }
    },
  );

  testWidgets(
    'the not-found back action returns to the group list, from a page and from a sheet',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // A page: the group beneath loads fine, so a plain pop would land on it.
      await pumpApp(
        tester,
        AppPaths.expense(groupId, missingExpenseId),
        loads: FakeRouteLoads.standard(),
      );
      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.byType(GroupList), findsOneWidget);
      expect(find.byType(GroupDetail), findsNothing);
      expect(find.text(l10n.pageNotFound), findsNothing);

      // A sheet: its close action.
      await pumpApp(
        tester,
        AppPaths.groupShare(missingGroupId),
        loads: FakeRouteLoads.standard(),
      );
      await settle(tester);
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.byType(GroupList), findsOneWidget);
      expect(find.text(l10n.pageNotFound), findsNothing);
    },
  );

  testWidgets(
    'a stale /group/details location or old child location shows Page not found without crashing',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final location in const [
        '/group/details',
        '/group/details/expense',
        '/group/details/expense-detail',
        '/group/details/claim',
        '/group/details/statistics',
        '/group/details/statistics/month',
        '/group/details/statistics/category',
        '/group/details/payment',
        '/group/edit',
        '/group/members',
        '/group/share',
      ]) {
        final loads = FakeRouteLoads.standard();
        await pumpApp(tester, location, loads: loads);
        await settle(tester);
        expect(find.text(l10n.pageNotFound), findsWidgets, reason: location);
        expect(loads.groupCalls, isEmpty, reason: location);
        expect(tester.takeException(), isNull, reason: location);
      }
    },
  );

  testWidgets(
    'a month or category location with a missing or unparseable window lands on the group statistics page',
    (tester) async {
      final statistics = AppPaths.groupStatistics(groupId);
      final valid = DateTime(2025, 3).toIso8601String();
      for (final location in [
        '$statistics/month',
        '$statistics/month?from=garbage&to=$valid',
        '$statistics/category?name=food&from=$valid',
        '$statistics/category?from=$valid&to=$valid',
      ]) {
        final router = await pumpApp(
          tester,
          location,
          loads: FakeRouteLoads.standard(),
        );
        await settle(tester);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          statistics,
          reason: location,
        );
        expect(
          tester
              .widget<GroupStatisticsPage>(find.byType(GroupStatisticsPage))
              .group
              .id,
          groupId,
          reason: location,
        );
        expect(
          find.byType(StatisticsMonthDetailBottomSheet),
          findsNothing,
          reason: location,
        );
        expect(
          find.byType(CategoryDetailBottomSheet),
          findsNothing,
          reason: location,
        );
        expect(tester.takeException(), isNull, reason: location);
      }
    },
  );

  // Match level: PrivacyPolicy cannot be built without a webview platform, and
  // the builders behind these paths moved verbatim.
  testWidgets(
    'every allowlisted deep link and /update-password resolves to its route',
    (tester) async {
      final router = buildAppRouter(
        rootNavigatorKey: GlobalKey<NavigatorState>(),
        initialLocation: '/group',
      );
      addTearDown(router.dispose);
      const allowlisted = {
        '/group/join?groupId=123e4567-e89b-12d3-a456-426614174000&name=Trip':
            '/group/join',
        '/friend/accept?email=sam@example.com': '/friend/accept',
        '/friend/accept?u=sam&c=0001': '/friend/accept',
        '/group': '/group',
        '/friend': '/friend',
        '/setting': '/setting',
        '/setting/privacy-policy': '/setting/privacy-policy',
        '/setting/contact': '/setting/contact',
      };
      for (final MapEntry(key: link, value: route) in allowlisted.entries) {
        expect(validateDeepLink(link), link, reason: 'still on the allowlist');
        final match = router.configuration.findMatch(Uri.parse(link));
        expect(match.isError, isFalse, reason: link);
        expect(match.fullPath, route, reason: link);
      }
      final recovery = router.configuration.findMatch(
        Uri.parse('/update-password'),
      );
      expect(recovery.isError, isFalse);
      expect(recovery.fullPath, '/update-password');
    },
  );
}
