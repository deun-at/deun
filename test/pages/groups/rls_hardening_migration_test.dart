// rls-hardening: who may read and write app data, read as source. The
// self-hosted instance is out of the build's reach, so this replays the
// rebuild set (supabase/schema/baseline.sql plus every migration stamped after
// it) the way the database applies it, and holds every write lib/ and its RPCs
// send to the policy that admits it. Behaviour is proven on the local harness
// (supabase/tests/rls_stopgap/30_cases.sql and 70_rls_hardening_cases.sql).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../supabase/rebuild_set.dart';
import 'join_group_migration_source.dart';

/// One policy as the rebuild set leaves it, normalized.
class _Policy {
  const _Policy(this.command, this.roles, this.using, this.check);

  /// `all`, `select`, `insert`, `update` or `delete`.
  final String command;

  /// The `TO` roles; empty means PUBLIC.
  final List<String> roles;
  final String? using;
  final String? check;

  bool covers(String c) => command == 'all' || command == c;

  bool get admitsAuthenticated =>
      roles.isEmpty ||
      roles.contains('authenticated') ||
      roles.contains('public');
}

/// One write statement: who sends it, on which table, which RLS command it
/// needs, and for an update the columns it sets.
typedef _Write = ({
  String source,
  String table,
  String command,
  Set<String> columns,
});

/// One statement mapped to what admits it.
typedef _Admit = ({String source, String table, String command, String policy});

/// Admitted by the table-level UPDATE/DELETE/TRUNCATE grant `lock table … in
/// share mode` needs, not by a policy.
const _tableGrant = '<table-level grant>';

/// No policy admits it, so it deletes nothing; the FK cascade from the parent
/// row the same RPC deletes removes the row (research/code-review-2026-10.md,
/// "Answered by the live instance").
const _cascadeNoOp = '<cascade>';

/// The SECURITY INVOKER RPCs the criterion names. lib/'s own `.rpc` calls are
/// added at run time, and every public function they call is followed.
const _namedRpcs = [
  'save_expense_all',
  'save_group_all',
  'claim_set_unit_shares',
  'pay_back',
  'pay_back_exact',
  'update_group_member_shares',
  'join_group',
  'add_group_member',
  'remove_group_member',
  'delete_group',
  'delete_expense',
];

// Policy names as written in the baseline and the stopgap migrations.
const _userInsert = 'user: insert own or guest';
const _userRead = 'user: signed-in read';
const _memberInsert = 'group_member: insert by member or creator';
const _memberUpdate = 'group_member: update by member';
const _memberDelete = 'group_member: delete by member';
const _memberRead = 'group_member: read own groups';
const _lines = 'expense_entry: group members';
const _shares = 'expense_entry_share: group members';
const _balances = 'group_shares_summary: group members';
const _tokens = 'device_tokens: owner only';
const _byMemberInsert = 'Enable insert for users based on group_member';
const _byMemberSelect = 'Enable select for users based on group_member';
const _byMemberUpdate = 'Enable update for users based on group_member';
const _byMemberDelete = 'Enable delete for users based on group_member';

/// Every write lib/ and its RPCs send today, and the policy that admits it.
/// An update or delete also needs the row visible, so it carries a `select`
/// row; so does an insert that returns its row or resolves a conflict.
const List<_Admit> _admits = [
  // lib/ — direct table writes
  (
    source: 'lib/auth_gate.dart',
    table: 'user',
    command: 'insert',
    policy: _userInsert,
  ),
  (
    source: 'lib/pages/users/user_repository.dart',
    table: 'user',
    command: 'insert',
    policy: _userInsert,
  ),
  (
    source: 'lib/pages/users/user_repository.dart',
    table: 'user',
    command: 'select',
    policy: _userRead,
  ),
  (
    source: 'lib/pages/users/user_repository.dart',
    table: 'user',
    command: 'update',
    policy: 'user: update own',
  ),
  (
    source: 'lib/pages/friends/data/friendship_repository.dart',
    table: 'friendship',
    command: 'insert',
    policy: 'Enable insert for users based on email',
  ),
  (
    source: 'lib/pages/friends/data/friendship_repository.dart',
    table: 'friendship',
    command: 'update',
    policy: ' Enable users to update their friendships',
  ),
  (
    source: 'lib/pages/friends/data/friendship_repository.dart',
    table: 'friendship',
    command: 'select',
    policy: 'Enable users to view their friendships',
  ),
  (
    source: 'lib/pages/friends/data/friendship_repository.dart',
    table: 'friendship',
    command: 'delete',
    policy: ' Enable users to delete their friendships',
  ),
  (
    source: 'lib/pages/groups/data/member_repository.dart',
    table: 'group_member',
    command: 'update',
    policy: _memberUpdate,
  ),
  (
    source: 'lib/pages/groups/data/member_repository.dart',
    table: 'group_member',
    command: 'select',
    policy: _memberRead,
  ),
  (
    source: 'lib/pages/groups/data/reminder_repository.dart',
    table: 'payment_reminder',
    command: 'insert',
    policy: 'Users can insert their own reminders',
  ),
  (
    source: 'lib/push_notifications.dart',
    table: 'device_tokens',
    command: 'insert',
    policy: _tokens,
  ),
  (
    source: 'lib/push_notifications.dart',
    table: 'device_tokens',
    command: 'update',
    policy: _tokens,
  ),
  (
    source: 'lib/push_notifications.dart',
    table: 'device_tokens',
    command: 'select',
    policy: _tokens,
  ),
  (
    source: 'lib/push_notifications.dart',
    table: 'device_tokens',
    command: 'delete',
    policy: _tokens,
  ),
  // save_expense_all
  (
    source: 'rpc:save_expense_all',
    table: 'expense',
    command: 'insert',
    policy: _byMemberInsert,
  ),
  (
    source: 'rpc:save_expense_all',
    table: 'expense',
    command: 'select',
    policy: _byMemberSelect,
  ),
  (
    source: 'rpc:save_expense_all',
    table: 'expense',
    command: 'update',
    policy: _byMemberUpdate,
  ),
  (
    source: 'rpc:save_expense_all',
    table: 'expense_entry',
    command: 'insert',
    policy: _lines,
  ),
  (
    source: 'rpc:save_expense_all',
    table: 'expense_entry',
    command: 'select',
    policy: _lines,
  ),
  (
    source: 'rpc:save_expense_all',
    table: 'expense_entry',
    command: 'delete',
    policy: _lines,
  ),
  (
    source: 'rpc:save_expense_all',
    table: 'expense_entry_share',
    command: 'insert',
    policy: _shares,
  ),
  // save_group_all: a create returns the new group before the creator's
  // membership row exists, so the owner policy is what lets it see the row.
  (
    source: 'rpc:save_group_all',
    table: 'group',
    command: 'insert',
    policy: 'Enable insert for authenticated users only',
  ),
  (
    source: 'rpc:save_group_all',
    table: 'group',
    command: 'select',
    policy: 'Enable users to view their own data only',
  ),
  (
    source: 'rpc:save_group_all',
    table: 'group',
    command: 'select',
    policy: _byMemberSelect,
  ),
  (
    source: 'rpc:save_group_all',
    table: 'group',
    command: 'update',
    policy: _byMemberUpdate,
  ),
  (
    source: 'rpc:save_group_all',
    table: 'user',
    command: 'insert',
    policy: _userInsert,
  ),
  (
    source: 'rpc:save_group_all',
    table: 'group_member',
    command: 'insert',
    policy: _memberInsert,
  ),
  (
    source: 'rpc:save_group_all',
    table: 'group_member',
    command: 'update',
    policy: _memberUpdate,
  ),
  (
    source: 'rpc:save_group_all',
    table: 'group_member',
    command: 'select',
    policy: _memberRead,
  ),
  // claim_set_unit_shares
  (
    source: 'rpc:claim_set_unit_shares',
    table: 'expense_entry_share',
    command: 'insert',
    policy: _shares,
  ),
  (
    source: 'rpc:claim_set_unit_shares',
    table: 'expense_entry_share',
    command: 'select',
    policy: _shares,
  ),
  (
    source: 'rpc:claim_set_unit_shares',
    table: 'expense_entry_share',
    command: 'delete',
    policy: _shares,
  ),
  // pay_back (pay_back_exact delegates to it and writes nothing itself)
  (
    source: 'rpc:pay_back',
    table: 'expense',
    command: 'insert',
    policy: _byMemberInsert,
  ),
  (
    source: 'rpc:pay_back',
    table: 'expense',
    command: 'select',
    policy: _byMemberSelect,
  ),
  (
    source: 'rpc:pay_back',
    table: 'expense_entry',
    command: 'insert',
    policy: _lines,
  ),
  (
    source: 'rpc:pay_back',
    table: 'expense_entry',
    command: 'select',
    policy: _lines,
  ),
  (
    source: 'rpc:pay_back',
    table: 'expense_entry_share',
    command: 'insert',
    policy: _shares,
  ),
  // update_group_member_shares: every recalculation, as any member
  (
    source: 'rpc:update_group_member_shares',
    table: 'group_shares_summary',
    command: 'insert',
    policy: _balances,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'group_shares_summary',
    command: 'update',
    policy: _balances,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'group_shares_summary',
    command: 'select',
    policy: _balances,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'group_shares_summary',
    command: 'delete',
    policy: _balances,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'group_update_checker',
    command: 'insert',
    policy: _byMemberInsert,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'group_update_checker',
    command: 'update',
    policy: _byMemberUpdate,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'group_update_checker',
    command: 'select',
    policy: _byMemberSelect,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'expense_update_checker',
    command: 'insert',
    policy: _byMemberInsert,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'expense_update_checker',
    command: 'update',
    policy: _byMemberUpdate,
  ),
  (
    source: 'rpc:update_group_member_shares',
    table: 'expense_update_checker',
    command: 'select',
    policy: _byMemberSelect,
  ),
  // join_group is SECURITY DEFINER since group-id-leak: it runs past RLS and
  // maps nothing here; the functions it calls are followed on their own.
  // reset_group_invite: an active member rotates the token as themselves.
  (
    source: 'rpc:reset_group_invite',
    table: 'group',
    command: 'update',
    policy: _byMemberUpdate,
  ),
  (
    source: 'rpc:reset_group_invite',
    table: 'group',
    command: 'select',
    policy: _byMemberSelect,
  ),
  (
    source: 'rpc:reset_group_invite',
    table: 'group_update_checker',
    command: 'insert',
    policy: _byMemberInsert,
  ),
  (
    source: 'rpc:reset_group_invite',
    table: 'group_update_checker',
    command: 'update',
    policy: _byMemberUpdate,
  ),
  (
    source: 'rpc:reset_group_invite',
    table: 'group_update_checker',
    command: 'select',
    policy: _byMemberSelect,
  ),
  // add_group_member
  (
    source: 'rpc:add_group_member',
    table: 'group_member',
    command: 'insert',
    policy: _memberInsert,
  ),
  (
    source: 'rpc:add_group_member',
    table: 'group_member',
    command: 'update',
    policy: _memberUpdate,
  ),
  (
    source: 'rpc:add_group_member',
    table: 'group_member',
    command: 'select',
    policy: _memberRead,
  ),
  // remove_group_member
  (
    source: 'rpc:remove_group_member',
    table: 'expense',
    command: 'lock',
    policy: _tableGrant,
  ),
  (
    source: 'rpc:remove_group_member',
    table: 'expense_entry_share',
    command: 'lock',
    policy: _tableGrant,
  ),
  (
    source: 'rpc:remove_group_member',
    table: 'group_member',
    command: 'update',
    policy: _memberUpdate,
  ),
  (
    source: 'rpc:remove_group_member',
    table: 'group_member',
    command: 'select',
    policy: _memberRead,
  ),
  (
    source: 'rpc:remove_group_member',
    table: 'group_member',
    command: 'delete',
    policy: _memberDelete,
  ),
  // delete_group
  (
    source: 'rpc:delete_group',
    table: 'group',
    command: 'delete',
    policy: _byMemberDelete,
  ),
  (
    source: 'rpc:delete_group',
    table: 'group',
    command: 'select',
    policy: _byMemberSelect,
  ),
  (
    source: 'rpc:delete_group',
    table: 'group_update_checker',
    command: 'delete',
    policy: _cascadeNoOp,
  ),
  (
    source: 'rpc:delete_group',
    table: 'group_update_checker',
    command: 'select',
    policy: _byMemberSelect,
  ),
  // delete_expense
  (
    source: 'rpc:delete_expense',
    table: 'expense',
    command: 'delete',
    policy: _byMemberDelete,
  ),
  (
    source: 'rpc:delete_expense',
    table: 'expense',
    command: 'select',
    policy: _byMemberSelect,
  ),
  (
    source: 'rpc:delete_expense',
    table: 'expense_update_checker',
    command: 'delete',
    policy: _cascadeNoOp,
  ),
  (
    source: 'rpc:delete_expense',
    table: 'expense_update_checker',
    command: 'select',
    policy: _byMemberSelect,
  ),
];

/// The text between the bracket at [open] and its match.
String _balanced(String s, int open) {
  final close = switch (s[open]) {
    '(' => ')',
    '{' => '}',
    _ => throw ArgumentError('no bracket at $open'),
  };
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == s[open]) depth++;
    if (s[i] == close) {
      depth--;
      if (depth == 0) return s.substring(open + 1, i);
    }
  }
  return s.substring(open + 1);
}

final _policyEvent = RegExp(
  r'create policy "([^"]+)" on public\."?([a-z_]+)"?([^;]*);'
  r'|drop policy if exists "([^"]+)" on public\."?([a-z_]+)"?'
  r'|alter table (?:only )?public\."?([a-z_]+)"? (enable|disable) row level security',
);
final _policyHead = RegExp(
  r'^ (?:as permissive )?(?:for (all|select|insert|update|delete) )?'
  r'(?:to ([a-z_]+(?:, [a-z_]+)*) ?)?',
);
final _columnGrantEvent = RegExp(
  r'revoke update on public\."?([a-z_]+)"? from [^;]*\bauthenticated\b'
  r'|grant update \(([^)]*)\) on public\."?([a-z_]+)"? to [^;]*\bauthenticated\b',
);
final _createTable = RegExp(r'create table public\."?([a-z_]+)"? \(');

_Policy _parsePolicy(String body) {
  final head = _policyHead.firstMatch(body)!;
  final using = body.indexOf(' using (');
  final check = body.indexOf(' with check (');
  return _Policy(
    head[1] ?? 'all',
    head[2]?.split(', ') ?? const [],
    using < 0 ? null : _balanced(body, using + ' using '.length),
    check < 0 ? null : _balanced(body, check + ' with check '.length),
  );
}

final _fromCall = RegExp(r'''\.from\(\s*(['"])([A-Za-z_]\w*)\1''');
final _writeVerb = RegExp(r'\.(insert|upsert|update|delete)\(');
final _mapKey = RegExp(r'''['"]([a-z_]+)['"]\s*:''');

/// The Dart text from [start] to the first `;` outside any bracket, string or
/// `//` comment: the rest of one call chain.
String _chainAt(String source, int start) {
  var depth = 0;
  var i = start;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final eol = source.indexOf('\n', i);
      i = eol < 0 ? source.length : eol;
      continue;
    }
    final c = source[i];
    if (c == "'" || c == '"') {
      i++;
      while (i < source.length && source[i] != c) {
        i += source[i] == r'\' ? 2 : 1;
      }
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      depth--;
    } else if (c == ';' && depth <= 0) {
      return source.substring(start, i);
    }
    i++;
  }
  return source.substring(start);
}

/// The keys of the map a write sends: a map literal, or a local the same file
/// declares as one (`final … upsertVals = {…}`). Empty when neither.
Set<String> _mapKeys(String source, String args) {
  final arg = args.trim();
  var literal = arg.startsWith('{') ? arg : null;
  final name = RegExp(r'^[A-Za-z_]\w*$').firstMatch(arg)?[0];
  if (name != null) {
    final decl = RegExp(
      r'\b' + RegExp.escape(name) + r'\s*=\s*\{',
    ).firstMatch(source);
    if (decl != null) literal = '{${_balanced(source, decl.end - 1)}}';
  }
  if (literal == null) return const {};
  return {for (final m in _mapKey.allMatches(literal)) m[1]!};
}

/// Every table write in one lib/ file.
List<_Write> _libWrites(String path, String source) {
  final writes = <_Write>[];
  for (final from in _fromCall.allMatches(source)) {
    final chain = _chainAt(source, from.end);
    final verb = _writeVerb.firstMatch(chain);
    if (verb == null) continue;
    final columns = _mapKeys(source, _balanced(chain, verb.end - 1));
    final returns = chain.indexOf('.select(', verb.end) >= 0;
    void add(String command, [Set<String> cols = const {}]) => writes.add((
      source: path,
      table: from[2]!,
      command: command,
      columns: cols,
    ));
    switch (verb[1]) {
      case 'insert':
        add('insert');
        if (returns) add('select');
      case 'upsert':
        add('insert');
        if (!RegExp(r'ignoreDuplicates:\s*true').hasMatch(chain)) {
          add('update', columns);
          add('select');
        } else if (returns) {
          add('select');
        }
      case 'update':
        add('update', columns);
        add('select');
      case 'delete':
        add('delete');
        add('select');
    }
  }
  return writes;
}

final _insertInto = RegExp(r'\binsert into (?:public\.)?"?([a-z_]+)"?');
final _updateSet = RegExp(
  r'(?<!do )\bupdate (?:public\.)?"?([a-z_]+)"?(?: as [a-z_]+| [a-z_]+)? '
  r'set (.*?)(?= from | where |$)',
);
final _doUpdateSet = RegExp(r' do update set (.*)$');
final _deleteFrom = RegExp(r'\bdelete from (?:public\.)?"?([a-z_]+)"?');
final _lockTable = RegExp(r'\block table (?:public\.)?"?([a-z_]+)"?');
final _callToken = RegExp(r'\b([a-z_][a-z0-9_]*)\(');
final _setColumn = RegExp(r'(?:^|, )([a-z_]+) =');

Set<String> _setColumns(String assignments) => {
  for (final m in _setColumn.allMatches(assignments)) m[1]!,
};

/// Every table write the RPCs in [roots] and every public function they call
/// send, as SECURITY INVOKER. A SECURITY DEFINER body runs as its owner, past
/// RLS, so its statements need no policy.
List<_Write> _rpcWrites(RebuildSet rebuild, Iterable<String> roots) {
  final writes = <_Write>[];
  final seen = <String>{};
  final queue = [...roots];
  while (queue.isNotEmpty) {
    final fn = queue.removeLast();
    if (!seen.add(fn)) continue;
    final source = rebuild.latestFunctionSource(fn);
    if (source == null) throw StateError('$fn is not in the rebuild set');
    final sql = normalizedSql(source);
    for (final call in _callToken.allMatches(sql)) {
      if (call[1] != fn && rebuild.hasFunction(call[1]!)) queue.add(call[1]!);
    }
    if (sql.contains('security definer')) continue;
    void add(String table, String command, [Set<String> cols = const {}]) =>
        writes.add((
          source: 'rpc:$fn',
          table: table,
          command: command,
          columns: cols,
        ));
    for (final piece in sql.split(';')) {
      for (final m in _insertInto.allMatches(piece)) {
        add(m[1]!, 'insert');
        final rest = piece.substring(m.end);
        if (rest.contains(' returning ')) add(m[1]!, 'select');
        final conflict = _doUpdateSet.firstMatch(rest);
        if (conflict != null) {
          add(m[1]!, 'update', _setColumns(conflict[1]!));
          add(m[1]!, 'select');
        }
      }
      for (final m in _updateSet.allMatches(piece)) {
        add(m[1]!, 'update', _setColumns(m[2]!));
        add(m[1]!, 'select');
      }
      for (final m in _deleteFrom.allMatches(piece)) {
        add(m[1]!, 'delete');
        add(m[1]!, 'select');
      }
      for (final m in _lockTable.allMatches(piece)) {
        add(m[1]!, 'lock');
      }
    }
  }
  return writes;
}

void main() {
  late RebuildSet rebuild;

  /// File name → normalized SQL, every replayed migration in replay order.
  late Map<String, String> replayed;

  /// Table → policy name (lower-cased) → policy, after the whole replay.
  late Map<String, Map<String, _Policy>> policies;
  late Set<String> rlsOn;
  late Set<String> appTables;

  /// Tables whose UPDATE authenticated holds per column only → those columns.
  late Map<String, Set<String>> columnGrants;
  late List<_Write> writes;

  Map<String, _Policy> on(String table) => policies[table] ?? const {};

  /// The (USING, WITH CHECK) of every policy that covers [command] on [table].
  Set<(String?, String?)> predicates(String table, String command) => {
    for (final p in on(table).values)
      if (p.covers(command)) (p.using, p.check),
  };

  String fn(String name) => normalizedSql(rebuild.latestFunctionSource(name)!);

  setUpAll(() {
    rebuild = RebuildSet.load();
    replayed = {
      for (final name in rebuild.replayedMigrations)
        name: normalizedSql(
          File('supabase/migrations/$name').readAsStringSync(),
        ),
    };
    final texts = [
      normalizedSql(File('supabase/schema/baseline.sql').readAsStringSync()),
      ...replayed.values,
    ];

    policies = {};
    rlsOn = {};
    appTables = {};
    columnGrants = {};
    for (final sql in texts) {
      appTables.addAll([for (final m in _createTable.allMatches(sql)) m[1]!]);
      for (final m in _policyEvent.allMatches(sql)) {
        if (m[1] != null) {
          policies.putIfAbsent(m[2]!, () => {})[m[1]!] = _parsePolicy(m[3]!);
        } else if (m[4] != null) {
          policies[m[5]!]?.remove(m[4]!);
        } else if (m[7] == 'enable') {
          rlsOn.add(m[6]!);
        } else {
          rlsOn.remove(m[6]!);
        }
      }
      for (final m in _columnGrantEvent.allMatches(sql)) {
        if (m[1] != null) {
          columnGrants[m[1]!] = {};
        } else {
          columnGrants
              .putIfAbsent(m[3]!, () => {})
              .addAll(m[2]!.split(',').map((c) => c.trim()));
        }
      }
    }

    final libSources = {
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
    };
    writes = [
      for (final MapEntry(key: path, value: source) in libSources.entries)
        ..._libWrites(path, source),
      ..._rpcWrites(rebuild, {
        ..._namedRpcs,
        for (final source in libSources.values) ...clientRpcs(source),
      }),
    ];
  });

  test(
    'C1 anon reaches nothing: no public table, sequence or function stays granted to anon, and later tables are not granted to it',
    () {
      final hardening = migrationSqlBySuffix('_rls_hardening.sql');
      expect(
        hardening,
        contains(
          'revoke execute on all functions in schema public from public, anon;',
        ),
        reason: 'anon inherits EXECUTE from PUBLIC on every function',
      );

      final all = replayed.values.join(' ');
      for (final kind in ['tables', 'sequences']) {
        expect(
          all,
          contains('revoke all on all $kind in schema public from anon;'),
        );
        expect(
          all,
          contains(
            'alter default privileges for role postgres, supabase_admin '
            'in schema public revoke all on $kind from anon;',
          ),
        );
      }
      expect(
        all,
        contains(
          'alter default privileges for role postgres, supabase_admin '
          'in schema public revoke execute on functions from anon;',
        ),
      );

      final handedBack = [
        for (final m in RegExp(r'\bgrant [^;]*? to ([^;]*);').allMatches(all))
          if (RegExp(r'\b(?:anon|public)\b').hasMatch(m[1]!)) m[0]!,
      ];
      expect(handedBack, isEmpty, reason: 'nothing replayed re-grants anon');
    },
  );

  test(
    'C1 a function a migration stamped after rls-hardening creates is revoked from public and anon in that migration',
    () {
      final hardening = rebuild.replayedMigrations.singleWhere(
        (name) => name.endsWith('_rls_hardening.sql'),
      );
      final creates = RegExp(
        r'create (?:or replace )?function public\.([a-z_][a-z0-9_]*)\(',
      );
      final open = [
        for (final name
            in rebuild.replayedMigrations
                .skipWhile((n) => n != hardening)
                .skip(1))
          for (final m in creates.allMatches(replayed[name]!))
            if (!RegExp(
              r'revoke execute on function public\.' +
                  RegExp.escape(m[1]!) +
                  r'\([^)]*\) from public, anon;',
            ).hasMatch(replayed[name]!))
              '$name: ${m[1]}',
      ];
      expect(
        open,
        isEmpty,
        reason: 'PUBLIC gets EXECUTE on every new function, and anon with it',
      );
    },
  );

  test('C2 every app table has RLS, and birthday_signup has no policy', () {
    expect(appTables, contains('birthday_signup'));
    expect(appTables.difference(rlsOn), isEmpty);
    expect(on('birthday_signup'), isEmpty);
  });

  test('C3 device tokens are readable and writable only by their owner', () {
    const owner = 'user_id = (select auth.uid())';
    for (final command in ['select', 'insert', 'update', 'delete']) {
      expect(predicates('device_tokens', command), {
        (owner, owner),
      }, reason: command);
    }
  });

  test(
    'C4 expense lines, shares and balances belong to the members of their group, soft-removed included',
    () {
      const member = {
        'expense_entry':
            'exists (select 1 from public.expense e '
            'where e.id = expense_entry.expense_id '
            'and public.is_group_member(e.group_id))',
        'expense_entry_share':
            'exists (select 1 from public.expense_entry ee '
            'join public.expense e on e.id = ee.expense_id '
            'where ee.id = expense_entry_share.expense_entry_id '
            'and public.is_group_member(e.group_id))',
        'group_shares_summary': 'public.is_group_member(group_id)',
      };
      for (final MapEntry(key: table, value: predicate) in member.entries) {
        for (final command in ['select', 'insert', 'update', 'delete']) {
          expect(predicates(table, command), {
            (predicate, predicate),
          }, reason: '$table $command');
        }
      }
      expect(
        fn('is_group_member'),
        isNot(contains('removed_at')),
        reason: 'a soft-removed member still sees their past groups',
      );
    },
  );

  test(
    'C5 a user row changes only by its owner, a guest is minted in the guest domain, and only an orphaned guest is deleted',
    () {
      const own = "email = (select auth.jwt() ->> 'email')";
      expect(predicates('user', 'select'), {('true', null)});
      expect(predicates('user', 'insert'), {
        (null, "$own or (is_guest and email like 'guest+%@guest.invalid')"),
      });
      expect(predicates('user', 'update'), {(own, own)});
      expect(predicates('user', 'delete'), {
        ('is_guest and not public.has_any_membership(email)', null),
      });
      expect(
        columnGrants['user']?.intersection({
          'email',
          'is_guest',
          'user_id',
          'created_at',
        }),
        isEmpty,
        reason: 'email cascades into every table; is_guest opens the delete',
      );

      final createGuest = File(
        'lib/pages/users/user_repository.dart',
      ).readAsStringSync();
      expect(createGuest, contains(r"'guest+$"));
      expect(createGuest, contains("@guest.invalid'"));
      final saveGroup = fn('save_group_all');
      expect(saveGroup, contains("_email := 'guest+' ||"));
      expect(saveGroup, contains("|| '@guest.invalid';"));
    },
  );

  test(
    "C6 membership changes only from inside the group or by the group's creator; joining goes through join_group",
    () {
      const own = "email = (select auth.jwt() ->> 'email')";
      const member = 'public.is_group_member(group_id)';
      const creator =
          'exists (select 1 from public."group" g '
          'where g.id = group_member.group_id '
          'and g.user_id = (select auth.uid()))';
      expect(predicates('group_member', 'insert'), {
        (null, '$member or $creator'),
      });
      expect(predicates('group_member', 'update'), {
        ('$own or $member', '$own or $member'),
      });
      expect(predicates('group_member', 'delete'), {(member, null)});
      // Decisions, "Reads of group_member": own rows and own groups only.
      expect(predicates('group_member', 'select'), {
        ("email = (auth.jwt() ->> 'email') or $member", null),
      });
      expect(
        columnGrants['group_member']?.intersection({'group_id', 'email'}),
        isEmpty,
        reason: 'moving a membership is a way into any group',
      );
    },
  );

  test(
    'C7 no policy here reads group_member: membership goes through SECURITY DEFINER helpers with a pinned search_path',
    () {
      final readsMembership = RegExp(
        r'\b(?:from|join) (?:public\.)?group_member\b',
      );
      final recursive = [
        for (final table in [
          'group_member',
          'user',
          'device_tokens',
          'expense_entry',
          'expense_entry_share',
          'group_shares_summary',
        ])
          for (final MapEntry(key: name, value: p) in on(table).entries)
            for (final predicate in [p.using, p.check])
              if (predicate != null && readsMembership.hasMatch(predicate))
                '$table "$name"',
      ];
      expect(recursive, isEmpty);

      final all = replayed.values.join(' ');
      for (final (helper, args) in [
        ('is_group_member', 'uuid'),
        ('has_any_membership', 'text'),
      ]) {
        final sql = fn(helper);
        expect(sql, contains(' stable security definer '), reason: helper);
        expect(sql, contains(" set search_path = '' "), reason: helper);
        expect(
          all,
          contains(
            'revoke execute on function public.$helper($args) from public, anon;',
          ),
        );
        expect(
          all,
          contains(
            'grant execute on function public.$helper($args) to authenticated',
          ),
        );
      }
      expect(
        fn('is_group_member'),
        contains(
          "from public.group_member gm where gm.group_id = _group_id "
          "and gm.email = (select auth.jwt() ->> 'email')",
        ),
      );
    },
  );

  test(
    'C8 every write lib/ and its RPCs send today maps to a policy that admits it',
    () {
      final unmapped = {
        for (final w in writes)
          if (!_admits.any(
            (a) =>
                a.source == w.source &&
                a.table == w.table &&
                a.command == w.command,
          ))
            '${w.source} ${w.command} ${w.table}',
      };
      expect(
        unmapped,
        isEmpty,
        reason: 'map each new write to the policy that admits it in _admits',
      );

      final all = replayed.values.join(' ');
      final revokes = RegExp(
        r'\brevoke ([a-z, ]+?) on (?:table )?'
        r'(?:public\."?([a-z_]+)"?|all tables in schema public) from ([^;]*);',
      );
      bool tableGrantRevoked(String table) => revokes
          .allMatches(all)
          .any(
            (m) =>
                (m[2] == null || m[2] == table) &&
                RegExp(r'\bauthenticated\b').hasMatch(m[3]!) &&
                RegExp(r'\b(?:all|update|delete|truncate)\b').hasMatch(m[1]!),
          );

      bool admitted(_Admit a) {
        if (a.policy == _cascadeNoOp) return true;
        if (a.policy == _tableGrant) return !tableGrantRevoked(a.table);
        final policy = on(a.table)[a.policy.toLowerCase()];
        return policy != null &&
            policy.covers(a.command) &&
            policy.admitsAuthenticated;
      }

      final refused = [
        for (final a in _admits)
          if (!admitted(a))
            '${a.source} ${a.command} ${a.table}: "${a.policy}"',
      ];
      expect(refused, isEmpty);
    },
  );

  test(
    'C8 every column a client or RPC update writes is granted to authenticated',
    () {
      final denied = {
        for (final w in writes)
          if (w.command == 'update' && columnGrants[w.table] != null)
            if (w.columns.isEmpty ||
                !columnGrants[w.table]!.containsAll(w.columns))
              '${w.source} ${w.table} ${w.columns}',
      };
      expect(denied, isEmpty);
    },
  );
}
