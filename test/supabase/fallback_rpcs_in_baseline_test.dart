// legacy-fallback-removal: every RPC whose client fallback was deleted is
// defined in supabase/schema/baseline.sql ITSELF, with no migration replayed
// after it. A function that only a not-yet-applied migration creates may be
// missing on the live instance, and its fallback must stay until Jakob
// applies that migration. Red means a write that has no fallback any more
// fails for every user.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rebuild_set.dart';

/// The RPCs lib/ now calls with no client-side fallback.
const _noFallback = [
  'save_group_all',
  'save_expense_all',
  'pay_back_exact',
  'claim_set_unit_shares',
];

void main() {
  test(
    'every RPC whose fallback was deleted is defined in the dump itself',
    () {
      final noMigrations = Directory.systemTemp.createTempSync(
        'no_migrations_',
      );
      addTearDown(() => noMigrations.deleteSync(recursive: true));

      final dump = RebuildSet.load(migrationsDir: noMigrations.path);

      expect([
        for (final name in _noFallback)
          if (!dump.hasFunction(name)) name,
      ], isEmpty);
    },
  );
}
