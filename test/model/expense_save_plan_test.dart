// typed-expense-draft: the complete `save_expense_all` parameters and the push
// one save produces, pinned as literals captured from the save arithmetic
// before the editor handed over a typed draft. The literals at the bottom are
// never edited: a red case here means the save now sends different money, or
// tells different people.
import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/expense_draft.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = 'a@test.com';
const _b = 'b@test.com';
const _c = 'c@test.com';

/// What one save is given.
typedef _Input = ExpenseDraft;

// ---- inputs -----------------------------------------------------------------

/// The expense-level fields every case shares, plus [entries].
_Input _base(List<ExpenseEntryDraft> entries) => ExpenseDraft(
  name: 'Dinner',
  expenseDate: DateTime(2026, 10, 26),
  paidBy: _a,
  category: ExpenseCategory.food,
  entries: entries,
);

/// One Quick line, as its split section hands it over: no name, one unit.
_Input _quick(
  double amount, {
  SplitMode splitMode = SplitMode.equal,
  Set<String> shares = const {},
  Map<String, num> shareData = const {},
  Set<String> locked = const {},
}) => _base([
  ExpenseEntryDraft(
    unitPrice: amount,
    splitMode: splitMode,
    shares: shares,
    shareData: shareData,
    lockedMembers: locked,
  ),
]);

_Input _equal() => _quick(
  30.0,
  shares: {_a, _b, _c},
  shareData: {_a: 10.0, _b: 10.0, _c: 10.0},
);

_Input _exactLocked() => _quick(
  30.0,
  splitMode: SplitMode.amount,
  shares: {_a, _b, _c},
  shareData: {_a: 12.0, _b: 9.0, _c: 9.0},
  locked: {_a},
);

_Input _percentage() => _quick(
  30.0,
  splitMode: SplitMode.percentage,
  shares: {_a, _b, _c},
  shareData: {_a: 50.0, _b: 25.0, _c: 25.0},
);

_Input _shares() => _quick(
  30.0,
  splitMode: SplitMode.shares,
  shares: {_a, _b, _c},
  shareData: {_a: 2, _b: 1, _c: 1},
);

_Input _exactAllZero() => _quick(
  30.0,
  splitMode: SplitMode.amount,
  shares: {_a, _b, _c},
  shareData: {_a: 0.0, _b: 0.0, _c: 0.0},
);

_Input _noSplitData() => _quick(30.0, shares: {_a, _b});

/// The Itemized CTA's lines after "Add & share for claiming": every line
/// claimable and shared with the whole group, one of them a discount.
_Input _itemizedWithDiscount() => _base([
  const ExpenseEntryDraft(
    name: 'Beer',
    unitPrice: 5.0,
    quantity: 3,
    shares: {_a, _b, _c},
    claimable: true,
  ),
  const ExpenseEntryDraft(
    name: 'Wine',
    unitPrice: 8.5,
    shares: {_a, _b, _c},
    claimable: true,
  ),
  const ExpenseEntryDraft(
    name: 'Discount',
    unitPrice: -0.8,
    shares: {_a, _b, _c},
    claimable: true,
  ),
]);

/// A shared 3x Beer re-saved at [quantity]. Its three units were claimed by a,
/// by b, and by both.
_Input _claimResave(int quantity) => _base([
  ExpenseEntryDraft(
    name: 'Beer',
    unitPrice: 5.0,
    quantity: quantity,
    shares: const {_a, _b, _c},
    claimable: true,
    existingClaims: const [
      [_a],
      [_b],
      [_a, _b],
    ],
  ),
]);

/// A plain multi-quantity line with no split at all.
_Input _implicitExplode() =>
    _base([const ExpenseEntryDraft(name: 'Beer', unitPrice: 5.0, quantity: 3)]);

_Input _jpy() => _quick(
  3000.0,
  shares: {_a, _b, _c},
  shareData: {_a: 1000.0, _b: 1000.0, _c: 1000.0},
);

_Input _chfExact() => _quick(
  4.5,
  splitMode: SplitMode.amount,
  shares: {_a, _b, _c},
  shareData: {_a: 1.5, _b: 1.5, _c: 1.5},
);

// ---- end of inputs ----------------------------------------------------------

const _jpyAt0058 = ExpenseConversion(
  groupCurrency: Currency.eur,
  entryCurrency: Currency.jpy,
  rate: 0.0058,
  rateDate: '2026-08-16',
);

const _chfAt09432 = ExpenseConversion(
  groupCurrency: Currency.eur,
  entryCurrency: Currency.chf,
  rate: 0.9432,
  rateDate: '2026-08-16',
);

ExpenseSavePlan _plan(
  _Input Function() input, {
  String? expenseId,
  ExpenseConversion? conversion,
}) => ExpenseRepository.planSave(
  groupId: 'g1',
  expenseId: expenseId,
  draft: input(),
  currency: Currency.eur,
  conversion: conversion,
  userId: 'user-1',
);

/// [value] as JSON with every map's keys sorted. Key order is not part of the
/// payload; number types are: 2 and 2.0 encode differently, and the integer
/// columns `save_expense_all` populates can refuse the second.
String _canonicalJson(Object? value) => jsonEncode(_sortedKeys(value));

Object? _sortedKeys(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.cast<String>().toList()..sort())
      key: _sortedKeys(value[key]),
  },
  List() => [for (final item in value) _sortedKeys(item)],
  _ => value,
};

class _Case {
  _Case(
    this.name,
    this.input, {
    this.expenseId,
    this.conversion,
    required this.rpcParams,
    required this.receivers,
    required this.amount,
    required this.sends,
  });

  final String name;
  final _Input Function() input;
  final String? expenseId;
  final ExpenseConversion? conversion;

  /// The complete `save_expense_all` parameters, as JSON.
  final String rpcParams;
  final Set<String> receivers;
  final double amount;
  final bool sends;
}

final _cases = [
  _Case(
    'equal split, created',
    _equal,
    rpcParams: _equalCreateParams,
    receivers: {_a, _b, _c},
    amount: 30.0,
    sends: true,
  ),
  _Case(
    'equal split, edited: the id rides in the expense row and nobody is pushed',
    _equal,
    expenseId: 'e1',
    rpcParams: _equalEditParams,
    receivers: {_a, _b, _c},
    amount: 30.0,
    sends: false,
  ),
  _Case(
    'exact split with one locked member',
    _exactLocked,
    rpcParams: _exactLockedParams,
    receivers: {_a, _b, _c},
    amount: 30.0,
    sends: true,
  ),
  _Case(
    'percentage split',
    _percentage,
    rpcParams: _percentageParams,
    receivers: {_a, _b, _c},
    amount: 30.0,
    sends: true,
  ),
  _Case(
    'shares split keeps whole-number parts',
    _shares,
    rpcParams: _sharesParams,
    receivers: {_a, _b, _c},
    amount: 30.0,
    sends: true,
  ),
  _Case(
    'an exact split whose amounts are all zero falls back to equal',
    _exactAllZero,
    rpcParams: _exactAllZeroParams,
    receivers: {_a, _b, _c},
    amount: 30.0,
    sends: true,
  ),
  _Case(
    'selected members but no split data: rows carry email and percentage only',
    _noSplitData,
    rpcParams: _noSplitDataParams,
    receivers: {_a, _b},
    amount: 30.0,
    sends: true,
  ),
  _Case(
    'itemized, shared for claiming, with a negative discount line',
    _itemizedWithDiscount,
    rpcParams: _itemizedClaimableDiscountParams,
    receivers: {_a, _b, _c},
    amount: 22.7,
    sends: true,
  ),
  _Case(
    'a 3x line re-saved as 4x keeps its units\' claimers and adds an unclaimed one',
    () => _claimResave(4),
    expenseId: 'e1',
    rpcParams: _claimResaveGrowParams,
    receivers: {_a, _b, _c},
    amount: 20.0,
    sends: false,
  ),
  _Case(
    'a 3x line re-saved as 2x keeps the first two units\' claimers',
    () => _claimResave(2),
    expenseId: 'e1',
    rpcParams: _claimResaveShrinkParams,
    receivers: {_a, _b, _c},
    amount: 10.0,
    sends: false,
  ),
  _Case(
    'a plain multi-quantity line with no split still explodes',
    _implicitExplode,
    rpcParams: _implicitExplodeParams,
    receivers: {},
    amount: 15.0,
    sends: true,
  ),
  _Case(
    '3000 JPY into a EUR group at 0.0058',
    _jpy,
    conversion: _jpyAt0058,
    rpcParams: _jpyParams,
    receivers: {_a, _b, _c},
    amount: 17.4,
    sends: true,
  ),
  _Case(
    '4.50 CHF at 0.9432 split exact 1.50/1.50/1.50',
    _chfExact,
    conversion: _chfAt09432,
    rpcParams: _chfExactParams,
    receivers: {_a, _b, _c},
    amount: 4.24,
    sends: true,
  ),
];

void main() {
  group('ExpenseRepository.planSave', () {
    for (final c in _cases) {
      test(c.name, () {
        final plan = _plan(
          c.input,
          expenseId: c.expenseId,
          conversion: c.conversion,
        );

        expect(
          _canonicalJson(plan.rpcParams),
          _canonicalJson(jsonDecode(c.rpcParams)),
        );
        expect(plan.notificationReceivers, c.receivers);
        expect(plan.notificationAmount, c.amount);
        expect(plan.sendsNotification, c.sends);
      });
    }
  });
}

// ---- captured literals: never edited ----------------------------------------

const _equalCreateParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": null, "amount": 30.0, "original_amount": null, "quantity": 1, "split_mode": "equal", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "b@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "c@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false}
      ]
    }
  ]
}
''';

const _equalEditParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null, "id": "e1"},
  "_entries": [
    {
      "entry": {"name": null, "amount": 30.0, "original_amount": null, "quantity": 1, "split_mode": "equal", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "b@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "c@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false}
      ]
    }
  ]
}
''';

const _exactLockedParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": null, "amount": 30.0, "original_amount": null, "quantity": 1, "split_mode": "exact", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 40.0, "fixed_amount": 12.0, "original_fixed_amount": null, "parts": null, "is_locked": true},
        {"email": "b@test.com", "percentage": 30.0, "fixed_amount": 9.0, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "c@test.com", "percentage": 30.0, "fixed_amount": 9.0, "original_fixed_amount": null, "parts": null, "is_locked": false}
      ]
    }
  ]
}
''';

const _percentageParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": null, "amount": 30.0, "original_amount": null, "quantity": 1, "split_mode": "percentage", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 50.0, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "b@test.com", "percentage": 25.0, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "c@test.com", "percentage": 25.0, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false}
      ]
    }
  ]
}
''';

const _sharesParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": null, "amount": 30.0, "original_amount": null, "quantity": 1, "split_mode": "shares", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 50.0, "fixed_amount": null, "original_fixed_amount": null, "parts": 2, "is_locked": false},
        {"email": "b@test.com", "percentage": 25.0, "fixed_amount": null, "original_fixed_amount": null, "parts": 1, "is_locked": false},
        {"email": "c@test.com", "percentage": 25.0, "fixed_amount": null, "original_fixed_amount": null, "parts": 1, "is_locked": false}
      ]
    }
  ]
}
''';

const _exactAllZeroParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": null, "amount": 30.0, "original_amount": null, "quantity": 1, "split_mode": "exact", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 33.333333333333336},
        {"email": "b@test.com", "percentage": 33.333333333333336},
        {"email": "c@test.com", "percentage": 33.333333333333336}
      ]
    }
  ]
}
''';

const _noSplitDataParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": null, "amount": 30.0, "original_amount": null, "quantity": 1, "split_mode": "equal", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 50.0},
        {"email": "b@test.com", "percentage": 50.0}
      ]
    }
  ]
}
''';

const _itemizedClaimableDiscountParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 10},
      "shares": []
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 11},
      "shares": []
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 12},
      "shares": []
    },
    {
      "entry": {"name": "Wine", "amount": 8.5, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 2, "sort_id": 40},
      "shares": []
    },
    {
      "entry": {"name": "Discount", "amount": -0.8, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 3, "sort_id": 50},
      "shares": []
    }
  ]
}
''';

const _claimResaveGrowParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null, "id": "e1"},
  "_entries": [
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 100.0}
      ]
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 11},
      "shares": [
        {"email": "b@test.com", "percentage": 100.0}
      ]
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 12},
      "shares": [
        {"email": "a@test.com", "percentage": 50.0},
        {"email": "b@test.com", "percentage": 50.0}
      ]
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 13},
      "shares": []
    }
  ]
}
''';

const _claimResaveShrinkParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null, "id": "e1"},
  "_entries": [
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 100.0}
      ]
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 11},
      "shares": [
        {"email": "b@test.com", "percentage": 100.0}
      ]
    }
  ]
}
''';

const _implicitExplodeParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": null, "conversion_rate": null, "rate_date": null},
  "_entries": [
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 10},
      "shares": []
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 11},
      "shares": []
    },
    {
      "entry": {"name": "Beer", "amount": 5.0, "original_amount": null, "quantity": 1, "split_mode": "claim", "item_group_seq": 1, "sort_id": 12},
      "shares": []
    }
  ]
}
''';

const _jpyParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": "JPY", "conversion_rate": 0.0058, "rate_date": "2026-08-16"},
  "_entries": [
    {
      "entry": {"name": null, "amount": 17.4, "original_amount": 3000.0, "quantity": 1, "split_mode": "equal", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "b@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false},
        {"email": "c@test.com", "percentage": 33.333333333333336, "fixed_amount": null, "original_fixed_amount": null, "parts": null, "is_locked": false}
      ]
    }
  ]
}
''';

const _chfExactParams = r'''
{
  "_group_id": "g1",
  "_expense": {"name": "Dinner", "expense_date": "2026-10-26 00:00:00.000", "paid_by": "a@test.com", "group_id": "g1", "user_id": "user-1", "category": "food", "original_currency_code": "CHF", "conversion_rate": 0.9432, "rate_date": "2026-08-16"},
  "_entries": [
    {
      "entry": {"name": null, "amount": 4.24, "original_amount": 4.5, "quantity": 1, "split_mode": "exact", "sort_id": 10},
      "shares": [
        {"email": "a@test.com", "percentage": 33.33333333333333, "fixed_amount": 1.42, "original_fixed_amount": 1.5, "parts": null, "is_locked": false},
        {"email": "b@test.com", "percentage": 33.33333333333333, "fixed_amount": 1.41, "original_fixed_amount": 1.5, "parts": null, "is_locked": false},
        {"email": "c@test.com", "percentage": 33.33333333333333, "fixed_amount": 1.41, "original_fixed_amount": 1.5, "parts": null, "is_locked": false}
      ]
    }
  ]
}
''';
