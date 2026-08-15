import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_deletion_impact.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// A normal (non-payback) expense dated [date].
Expense _expense(String date, {String id = 'e1'}) {
  final e = Expense();
  e.id = id;
  e.groupId = 'g1';
  e.name = 'Dinner';
  e.amount = 20;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = date;
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = null;
  e.groupMemberShareStatistic = const {};
  e.expenseEntries = {};
  return e;
}

/// A payback row dated [date] that settled [amount] with [counterpartyName],
/// shaped the way `pay_back` writes one: a single entry with a single share.
Expense _payback(
  String date, {
  String id = 'p1',
  double amount = 12.5,
  String counterpartyEmail = 'b@test.com',
  String counterpartyName = 'Bob',
}) {
  final share = ExpenseEntryShare();
  share.expenseEntryId = '${id}_e';
  share.email = counterpartyEmail;
  share.displayName = counterpartyName;
  share.percentage = 100;
  share.fixedAmount = null;
  share.parts = null;
  share.isLocked = false;
  share.createdAt = '';

  final entry = ExpenseEntry(index: 0);
  entry.id = '${id}_e';
  entry.expenseId = id;
  entry.amount = amount;
  entry.quantity = 1;
  entry.splitMode = 'equal';
  entry.createdAt = '';
  entry.expenseEntryShares = [share];

  final e = Expense();
  e.id = id;
  e.groupId = 'g1';
  e.name = 'paid_back';
  e.amount = amount;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = date;
  e.createdAt = '';
  e.isPaidBackRow = true;
  e.category = null;
  e.groupMemberShareStatistic = {counterpartyEmail: amount};
  e.expenseEntries = {entry.id: entry};
  return e;
}

void main() {
  group('classifyExpenseDeletion', () {
    // 1 — a payback row names its counterparty and the settled amount
    test('deleting a payback row reports the counterparty and the amount', () {
      final impact = classifyExpenseDeletion(
        _payback('2026-01-10', amount: 12.5, counterpartyName: 'Bob'),
        const [],
      );

      expect(impact, isA<ExpenseDeletionReopensSettlement>());
      final reopens = impact as ExpenseDeletionReopensSettlement;
      expect(reopens.counterparty, 'Bob');
      expect(reopens.amount, 12.5);
    });

    // 2 — the empty-group case
    test('an expense in a group with no other rows at all is unguarded', () {
      expect(
        classifyExpenseDeletion(_expense('2026-01-10'), const []),
        ExpenseDeletionImpact.none,
      );
    });

    // 3 — THE date boundary, inclusive side
    test('a payback dated the SAME day counts as covering the expense', () {
      final impact = classifyExpenseDeletion(_expense('2026-01-10'), [
        _payback('2026-01-10'),
      ]);

      expect(impact, isA<ExpenseDeletionAlreadySettled>());
      expect((impact as ExpenseDeletionAlreadySettled).paybackCount, 1);
    });

    // 4 — THE date boundary, exclusive side
    test('a payback dated strictly BEFORE the expense does not cover it', () {
      expect(
        classifyExpenseDeletion(_expense('2026-01-10'), [
          _payback('2026-01-09'),
        ]),
        ExpenseDeletionImpact.none,
      );
    });

    // 5
    test('a payback dated after the expense covers it', () {
      final impact = classifyExpenseDeletion(_expense('2026-01-10'), [
        _payback('2026-01-11'),
      ]);

      expect((impact as ExpenseDeletionAlreadySettled).paybackCount, 1);
    });

    // 6
    test('paybackCount counts only the covering paybacks', () {
      final impact = classifyExpenseDeletion(_expense('2026-01-10'), [
        _payback('2026-01-09', id: 'p1'),
        _payback('2026-01-10', id: 'p2'),
        _payback('2026-01-31', id: 'p3'),
      ]);

      expect((impact as ExpenseDeletionAlreadySettled).paybackCount, 2);
    });

    // 7
    test('normal expenses in the list are never mistaken for settlements', () {
      expect(
        classifyExpenseDeletion(_expense('2026-01-10'), [
          _expense('2026-01-11', id: 'e2'),
          _expense('2026-02-01', id: 'e3'),
        ]),
        ExpenseDeletionImpact.none,
      );
    });

    // 8 — pay_back stamps now() into expense_date, so a same-day settle-up can
    // arrive carrying a time. It must still count as covering.
    test(
      'a same-day payback carrying a TIMESTAMP still covers the expense',
      () {
        final impact = classifyExpenseDeletion(_expense('2026-01-10'), [
          _payback('2026-01-10T23:45:00'),
        ]);

        expect((impact as ExpenseDeletionAlreadySettled).paybackCount, 1);
      },
    );
  });

  group('confirmation copy', () {
    // 9 — the no-regression pin: the unguarded case is today's copy, verbatim.
    test(
      'an unguarded delete reuses today plain confirmation strings',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        const impact = ExpenseDeletionImpact.none;

        expect(impact.confirmTitle(l10n), l10n.expenseDeleteItemTitle);
        expect(
          impact.confirmMessage(l10n, 'EUR'),
          l10n.expenseDeleteItemMessage,
        );
      },
    );

    // 10
    test(
      'the payback copy names the counterparty and the formatted amount',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        const impact = ExpenseDeletionImpact.reopensSettlement(
          counterparty: 'Bob',
          amount: 12.5,
        );

        expect(impact.confirmTitle(l10n), l10n.expenseDeletePaybackTitle);
        final message = impact.confirmMessage(l10n, 'EUR');
        expect(message, contains('Bob'));
        expect(message, contains(l10n.toCurrency(12.5, 'EUR')));
      },
    );

    // 11
    test(
      'the already-settled copy names how many settlements happened',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        const impact = ExpenseDeletionImpact.alreadySettled(paybackCount: 2);

        expect(impact.confirmTitle(l10n), l10n.expenseDeleteSettledTitle);
        expect(impact.confirmMessage(l10n, 'EUR'), contains('2'));
        expect(
          impact.confirmMessage(l10n, 'EUR'),
          l10n.expenseDeleteSettledMessage(2),
        );
      },
    );

    // 12 — every new string exists in DE too (and gen-l10n ran for both).
    test('all new copy exists in German and differs from English', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final de = await AppLocalizations.delegate.load(const Locale('de'));

      expect(de.expenseDeletePaybackTitle, isNotEmpty);
      expect(de.expenseDeletePaybackTitle, isNot(en.expenseDeletePaybackTitle));
      expect(de.expenseDeleteSettledTitle, isNotEmpty);
      expect(de.expenseDeleteSettledTitle, isNot(en.expenseDeleteSettledTitle));

      final dePayback = de.expenseDeletePaybackMessage('12,50 €', 'Bob');
      expect(dePayback, contains('Bob'));
      expect(dePayback, contains('12,50 €'));
      expect(
        dePayback,
        isNot(en.expenseDeletePaybackMessage('12,50 €', 'Bob')),
      );

      expect(de.expenseDeleteSettledMessage(2), contains('2'));
      expect(
        de.expenseDeleteSettledMessage(2),
        isNot(en.expenseDeleteSettledMessage(2)),
      );
    });
  });
}
