// guest-merge-rpc: the join_group migration as normalized source, shared by
// join_group_migration_test.dart and group_repository_test.dart. Read as
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

List<File> _migrations() =>
    Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// The guest-merge-rpc migration, found by suffix so its timestamp can move.
String joinGroupMigrationSql() {
  final files = _migrations()
      .where((f) => f.path.endsWith('_join_group_guest_merge.sql'))
      .toList();
  if (files.length != 1) {
    throw StateError(
      'expected one *_join_group_guest_merge.sql, found ${files.length}',
    );
  }
  return normalizedSql(files.single.readAsStringSync());
}

/// Every migration, normalized — for a helper that may live in whichever
/// migration landed first (`lock_group_member_writes`).
String allMigrationsSql() =>
    _migrations().map((f) => normalizedSql(f.readAsStringSync())).join(' ');

/// The argument names `public.join_group` declares, in order.
List<String> joinGroupDeclaredArgs(String sql) {
  final match = RegExp(
    r'create or replace function public\.join_group\s*\(([^)]*)\)',
  ).firstMatch(sql);
  if (match == null) throw StateError('join_group is not defined');
  return [
    for (final arg in match.group(1)!.split(',')) arg.trim().split(' ').first,
  ];
}

/// The body between a function's `$tag$` dollar quotes.
String functionBody(String sql, String tag) {
  final quote = RegExp.escape('\$$tag\$');
  final match = RegExp('$quote(.*?)$quote').firstMatch(sql);
  if (match == null) throw StateError('no \$$tag\$ body');
  return match.group(1)!;
}
