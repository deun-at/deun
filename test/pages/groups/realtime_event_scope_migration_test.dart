// realtime-event-scope: the migration that lets deletes reach the filtered
// group and friendship channels and publishes group_member. Read as source,
// the way expense_rate_migration_test.dart reads its migration: the
// self-hosted instance is out of the build's reach.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'C11 the migration sets full identity on the two filtered tables and publishes group_member, guarded',
    () {
      final files = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_realtime_event_scope.sql'))
          .toList();
      expect(files, hasLength(1));
      final sql = files.single.readAsStringSync().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );

      expect(
        sql,
        contains(
          'alter table public.group_update_checker replica identity full',
        ),
      );
      expect(
        sql,
        contains('alter table public.friendship replica identity full'),
      );

      // The add sits in a guard, so a re-run or a FOR ALL TABLES publication
      // skips it.
      final guard = RegExp(r'do \$\$(.*?)\$\$').firstMatch(sql)?.group(1);
      expect(guard, isNotNull);
      expect(
        guard,
        contains(
          'alter publication supabase_realtime add table public.group_member',
        ),
      );
      expect(guard, contains('pg_publication_tables'));
      expect(guard, contains('puballtables'));
    },
  );
}
