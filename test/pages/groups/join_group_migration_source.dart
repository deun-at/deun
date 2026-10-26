// guest-merge-rpc: migrations as normalized source, shared by
// join_group_migration_test.dart, group_repository_test.dart,
// payback_atomic_recalc_migration_test.dart and
// group_write_rpcs_migration_test.dart. Read as
// source, the way realtime_event_scope_migration_test.dart reads its
// migration: the self-hosted instance is out of the build's reach.

import 'dart:io';

/// Lower-cased, `--` comments dropped, whitespace collapsed to one space, no
/// space just inside parentheses — so a reformat stays green and only a
/// changed statement goes red.
String normalizedSql(String raw) => raw
    .split('\n')
    .map((line) {
      final i = line.indexOf('--');
      return i < 0 ? line : line.substring(0, i);
    })
    .join(' ')
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('( ', '(')
    .replaceAll(' )', ')');

/// Every top-level `supabase/migrations/*.sql` (not `rollback/`), oldest first
/// by filename — the order the timestamps apply them in.
List<File> migrationFiles() =>
    Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// The one migration whose filename ends in [suffix], normalized — found by
/// suffix so its timestamp can move.
String migrationSqlBySuffix(String suffix) {
  final files = migrationFiles().where((f) => f.path.endsWith(suffix)).toList();
  if (files.length != 1) {
    throw StateError('expected one *$suffix, found ${files.length}');
  }
  return normalizedSql(files.single.readAsStringSync());
}

/// The guest-merge-rpc migration.
String joinGroupMigrationSql() =>
    migrationSqlBySuffix('_join_group_guest_merge.sql');

/// Every migration, normalized — for a helper that may live in whichever
/// migration landed first (`lock_group_member_writes`).
String allMigrationsSql() =>
    migrationFiles().map((f) => normalizedSql(f.readAsStringSync())).join(' ');

/// The argument names `public.<function>` declares in [sql], in order.
List<String> declaredArgs(String sql, String function) {
  final match = RegExp(
    'create or replace function public\\.${RegExp.escape(function)}\\s*\\(([^)]*)\\)',
  ).firstMatch(sql);
  if (match == null) throw StateError('$function is not defined');
  final args = match.group(1)!.trim();
  if (args.isEmpty) return const [];
  return [for (final arg in args.split(',')) arg.trim().split(' ').first];
}

/// The argument names `public.join_group` declares, in order.
List<String> joinGroupDeclaredArgs(String sql) =>
    declaredArgs(sql, 'join_group');

/// The body between a function's `$tag$` dollar quotes.
String functionBody(String sql, String tag) {
  final quote = RegExp.escape('\$$tag\$');
  final match = RegExp('$quote(.*?)$quote').firstMatch(sql);
  if (match == null) throw StateError('no \$$tag\$ body');
  return match.group(1)!;
}
