import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _path =
    'supabase/migrations/20260816020000_expense_entry_currency_rate.sql';

void main() {
  group('the provenance migration', () {
    late String sql;

    setUpAll(() {
      sql = File(_path).readAsStringSync();
    });

    test('exists and adds all five provenance columns, nullable', () {
      expect(File(_path).existsSync(), isTrue);
      expect(
        sql,
        contains('add column if not exists original_currency_code text'),
      );
      expect(sql, contains('add column if not exists conversion_rate numeric'));
      expect(sql, contains('add column if not exists rate_date date'));
      expect(sql, contains('add column if not exists original_amount numeric'));
      // Nullable with no default: existing rows must stay null, never backfill.
      expect(sql, isNot(contains('not null')));
      expect(sql, isNot(contains('default')));
    });

    test(
      'every LEDGER money column the editor reloads has an entry-currency twin',
      () {
        // The boundary rule: an editor field holds ENTRY-currency amounts while
        // the column holds the converted LEDGER value, so each such column
        // needs an original_* sibling. `expense_entry.amount` has
        // `original_amount`; `expense_entry_share.fixed_amount` has
        // `original_fixed_amount`. Without the second one a name-only re-save
        // of a converted exact-split expense converts the shares twice.
        expect(
          sql,
          contains('add column if not exists original_fixed_amount numeric'),
        );
        expect(sql, contains('alter table public.expense_entry_share'));
      },
    );

    test('save_expense_all threads the provenance on insert AND update', () {
      expect(
        sql,
        contains('create or replace function public.save_expense_all'),
      );
      // UPDATE SET
      expect(
        sql,
        contains('original_currency_code = r.original_currency_code'),
      );
      expect(sql, contains('conversion_rate = r.conversion_rate'));
      expect(sql, contains('rate_date = r.rate_date'));
      // expense INSERT column list, both branches (id-collision and plain insert)
      expect(
        'original_currency_code, conversion_rate, rate_date)'
            .allMatches(sql)
            .length,
        2,
      );
      // expense_entry INSERT
      expect(sql, contains('item_group_id, original_amount)'));
      expect(sql, contains('r.original_amount'));
      // expense_entry_share INSERT
      expect(sql, contains('original_fixed_amount)'));
      expect(sql, contains('s.original_fixed_amount'));
    });

    test('it never edits an already-applied migration', () {
      // The rule in manual-checks: always a new timestamped file. 20260618000000
      // is the previously-applied save_expense_all and must be untouched.
      final prior = File(
        'supabase/migrations/20260618000000_per_unit_claim_entries.sql',
      ).readAsStringSync();
      expect(prior, isNot(contains('original_currency_code')));
      expect(prior, isNot(contains('original_amount')));
      expect(prior, isNot(contains('original_fixed_amount')));
    });

    test('manual-checks carries an open pending entry for this feature', () {
      final ops = File('docs/ristretto/manual-checks.md').readAsStringSync();
      final pending = ops.split('## Applied').first;
      expect(pending, contains('multi-currency-expense-rate'));
      expect(
        pending,
        contains('20260816020000_expense_entry_currency_rate.sql'),
      );
      // The entry names every column the migration adds, so the hand-applied
      // verification cannot silently skip one.
      expect(pending, contains('original_fixed_amount'));
      expect(pending, isNot(contains('*(nothing pending)*')));
    });
  });
}
