// schema-baseline: the rebuild set — supabase/schema/baseline.sql plus every
// migration stamped after its dump stamp, replayed in filename order — read as
// source, and the scans that hold the baseline and lib/ to it. Test-only:
// nothing the app ships reads SQL, and the self-hosted instance is out of the
// build's reach. supabase/schema/README.md states the same rule.

import 'dart:io';

/// One top-level SQL statement, or one psql meta-command line.
class _Statement {
  _Statement(this.text, this.outside, this.bodies);

  /// As written, trimmed, leading comments and the closing `;` excluded.
  final String text;

  /// Lower-cased and whitespace-collapsed, with comments dropped, every
  /// single-quoted literal emptied to `''` and every dollar-quoted body
  /// replaced by `$$`.
  final String outside;

  /// The dollar-quoted bodies, delimiters excluded, in order.
  final List<String> bodies;
}

final _dollarTag = RegExp(r'\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$');
final _identChar = RegExp(r'[A-Za-z0-9_]');

/// Splits [sql] into top-level statements on `;`, never inside a
/// single-quoted literal, a quoted identifier, a dollar-quoted body or a
/// comment. A line starting with `\` where a statement would start (pg_dump's
/// `\restrict`) is a statement of its own.
List<_Statement> _split(String sql) {
  final statements = <_Statement>[];
  final outside = StringBuffer();
  final bodies = <String>[];
  int? start;

  void close(int end) {
    if (start != null) {
      statements.add(
        _Statement(
          sql.substring(start!, end).trim(),
          outside
              .toString()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
          List.of(bodies),
        ),
      );
    }
    start = null;
    outside.clear();
    bodies.clear();
  }

  var i = 0;
  while (i < sql.length) {
    final c = sql[i];
    if (sql.startsWith('--', i)) {
      final eol = sql.indexOf('\n', i);
      i = eol < 0 ? sql.length : eol;
    } else if (sql.startsWith('/*', i)) {
      final end = sql.indexOf('*/', i + 2);
      outside.write(' ');
      i = end < 0 ? sql.length : end + 2;
    } else if (c == r'\' && start == null) {
      final eol = sql.indexOf('\n', i);
      final end = eol < 0 ? sql.length : eol;
      start = i;
      outside.write(sql.substring(i, end));
      close(end);
      i = end;
    } else if (c == "'") {
      start ??= i;
      outside.write("''");
      i = _closingQuote(sql, i);
    } else if (c == '"') {
      start ??= i;
      final end = _closingQuote(sql, i);
      outside.write(sql.substring(i, end));
      i = end;
    } else if (c == r'$' &&
        (i == 0 || !_identChar.hasMatch(sql[i - 1])) &&
        _dollarTag.matchAsPrefix(sql, i) != null) {
      start ??= i;
      final tag = _dollarTag.matchAsPrefix(sql, i)![0]!;
      final end = sql.indexOf(tag, i + tag.length);
      bodies.add(sql.substring(i + tag.length, end < 0 ? sql.length : end));
      outside.write(r' $$ ');
      i = end < 0 ? sql.length : end + tag.length;
    } else if (c == ';') {
      close(i);
      i++;
    } else {
      if (start != null || c.trim().isNotEmpty) {
        start ??= i;
        outside.write(c);
      }
      i++;
    }
  }
  close(sql.length);
  return statements;
}

/// The index just past the quote that closes the literal or quoted identifier
/// opening at [open]; a doubled quote is an escaped one.
int _closingQuote(String sql, int open) {
  final quote = sql[open];
  var i = open + 1;
  while (i < sql.length) {
    if (sql[i] == quote) {
      if (i + 1 < sql.length && sql[i + 1] == quote) {
        i += 2;
        continue;
      }
      return i + 1;
    }
    i++;
  }
  return sql.length;
}

final _dataHead = RegExp(r'^(?:copy|insert)\b');
final _setval = RegExp(r'\bsetval\s*\(');

/// The first line of each top-level statement that carries row data: a
/// `COPY`, an `INSERT` or a `setval(` call. Dollar-quoted bodies are not top
/// level, so a function that inserts (`pay_back`) passes. Empty when clean.
List<String> findDataStatements(String sql) => [
  for (final s in _split(sql))
    if (_dataHead.hasMatch(s.outside) || _setval.hasMatch(s.outside))
      s.text.split('\n').first.trim(),
];

/// Named secret shapes — never entropy, so pg_dump's `\restrict` key and a
/// `GRANT … TO service_role` do not trip them.
final _secretShapes = <String, RegExp>{
  'JWT': RegExp(r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'),
  'Bearer token': RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=-]{16,}',
    caseSensitive: false,
  ),
  'URL with credentials': RegExp(
    r'''\b[a-z][a-z0-9+.-]*://[^\s/:@'"]+:[^\s/@'"]+@''',
    caseSensitive: false,
  ),
  'private key': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  'password literal': RegExp(
    r'''\bpassword(?:\s+'[^']+'|=[^\s'"]+)''',
    caseSensitive: false,
  ),
  'password hash': RegExp(
    r'SCRAM-SHA-256\$\d+:|\bmd5[0-9a-f]{32}\b|\$2[aby]\$\d\d\$[./A-Za-z0-9]{53}',
  ),
  // A setting value, never the `jwt_secret text` column of _realtime.tenants.
  // (Plain strings: a raw triple-quoted string cannot end in a quote.)
  'jwt_secret value': RegExp(
    'jwt_secret["\']?\\s*(?:=|\\bto\\b|,)\\s*\'[^\']+\'',
    caseSensitive: false,
  ),
  'vault secret literal': RegExp(
    '\\bvault\\.(?:create|update)_secret\\s*\\(\\s*\'',
    caseSensitive: false,
  ),
  'email': RegExp(
    r'[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})',
  ),
};

/// `'<shape> at line <n>'` for every secret shape in [sql] — never the match
/// itself, so a red run cannot copy a live key into a log. An email in the
/// `guest.invalid` domain (minted guests) is allowed. Empty when clean.
List<String> findSecrets(String sql) {
  int lineOf(int offset) =>
      '\n'.allMatches(sql.substring(0, offset)).length + 1;
  return [
    for (final MapEntry(key: shape, value: pattern) in _secretShapes.entries)
      for (final m in pattern.allMatches(sql))
        if (shape != 'email' || m[1]!.toLowerCase() != 'guest.invalid')
          '$shape at line ${lineOf(m.start)}',
  ];
}

const _ident = r'(?:"[^"]+"|[a-z_][a-z0-9_$]*)';
const _qname = '$_ident(?:\\.$_ident)?';

/// `public."group"`, `"group"`, `GROUP` → `group`; `auth.users` stays
/// qualified. Matching is case-insensitive and unqualified means `public`.
String _key(String name) {
  final bare = name.trim().toLowerCase().replaceAll('"', '');
  return bare.startsWith('public.') ? bare.substring('public.'.length) : bare;
}

/// The text between the `(` at [open] and its matching `)`, in a
/// [_Statement.outside] (literals already emptied).
String _balanced(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')') {
      depth--;
      if (depth == 0) return s.substring(open + 1, i);
    }
  }
  return s.substring(open + 1);
}

/// [s] split on the commas outside any parentheses.
List<String> _topLevel(String s) {
  final parts = <String>[];
  var depth = 0;
  var from = 0;
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')') depth--;
    if (s[i] == ',' && depth == 0) {
      parts.add(s.substring(from, i).trim());
      from = i + 1;
    }
  }
  parts.add(s.substring(from).trim());
  return parts;
}

const _notColumns = {
  'constraint',
  'primary',
  'unique',
  'check',
  'foreign',
  'exclude',
  'like',
};

final _createFunction = RegExp(
  '^create (?:or replace )?function ($_qname) ?\\(',
);
final _dropFunction = RegExp('^drop function (?:if exists )?($_qname)');
final _createTable = RegExp(
  '^create (?:(?:global |local )?(?:temporary |temp )|unlogged )?table '
  '(?:if not exists )?($_qname)',
);
final _createView = RegExp(
  '^create (?:or replace )?(?:materialized )?view (?:if not exists )?($_qname)',
);
final _alterTable = RegExp(
  '^alter table (?:if exists )?(?:only )?($_qname) (.*)\$',
);
final _addColumn = RegExp('^add (?:column )?(?:if not exists )?($_ident)');
final _createIndex = RegExp(
  '^create (?:unique )?index (?:concurrently )?(?:if not exists )?($_ident) on ',
);
final _createPublication = RegExp(
  '^create publication ($_ident)(?: for (all tables|table (.*?)))?(?: with \\(.*\\))?\$',
);
final _alterPublication = RegExp(
  'alter publication ($_ident) (add|drop|set) table (.*)\$',
);
final _listedTable = RegExp('^(?:only )?($_qname)');

/// What a stretch of SQL leaves defined. [apply] runs statement by statement,
/// so a later definition replaces an earlier one.
class SqlObjects {
  /// Function key → its newest `CREATE [OR REPLACE] FUNCTION` statement.
  final functions = <String, String>{};
  final relations = <String>{};
  final columns = <String, Set<String>>{};
  final indexes = <String>{};
  final publications = <String, Set<String>>{};
  final allTablesPublications = <String>{};

  void apply(String sql) {
    for (final s in _split(sql)) {
      _apply(s);
    }
  }

  void _apply(_Statement s) {
    final sql = s.outside;
    if (_createFunction.firstMatch(sql) case final m?) {
      functions[_key(m[1]!)] = s.text;
    } else if (_dropFunction.firstMatch(sql) case final m?) {
      functions.remove(_key(m[1]!));
    } else if (_createTable.firstMatch(sql) case final m?) {
      final table = _key(m[1]!);
      relations.add(table);
      final open = sql.indexOf('(', m.end);
      if (open >= 0 && sql.substring(m.end, open).trim().isEmpty) {
        for (final element in _topLevel(_balanced(sql, open))) {
          _recordColumn(table, RegExp('^$_ident').firstMatch(element)?[0]);
        }
      }
    } else if (_createView.firstMatch(sql) case final m?) {
      relations.add(_key(m[1]!));
    } else if (_alterTable.firstMatch(sql) case final m?) {
      for (final clause in _topLevel(m[2]!)) {
        _recordColumn(_key(m[1]!), _addColumn.firstMatch(clause)?[1]);
      }
    } else if (_createIndex.firstMatch(sql) case final m?) {
      indexes.add(_key(m[1]!));
    } else if (_createPublication.firstMatch(sql) case final m?) {
      final name = _key(m[1]!);
      final tables = publications.putIfAbsent(name, () => {});
      if (m[2] == 'all tables') allTablesPublications.add(name);
      if (m[3] != null) tables.addAll(_tables(m[3]!));
    } else if (sql.startsWith('alter publication ')) {
      _alterPublicationIn(sql);
    } else if (sql.startsWith('do ')) {
      // A guarded add (`if not exists … then alter publication …`) counts.
      for (final body in s.bodies) {
        for (final inner in _split(body)) {
          _alterPublicationIn(inner.outside);
        }
      }
    }
  }

  void _recordColumn(String table, String? name) {
    if (name == null || _notColumns.contains(name)) return;
    columns.putIfAbsent(table, () => {}).add(_key(name));
  }

  void _alterPublicationIn(String sql) {
    final m = _alterPublication.firstMatch(sql);
    if (m == null) return;
    final name = _key(m[1]!);
    final tables = _tables(m[3]!);
    switch (m[2]) {
      case 'add':
        publications.putIfAbsent(name, () => {}).addAll(tables);
      case 'drop':
        publications[name]?.removeAll(tables);
      case 'set':
        publications[name] = tables;
    }
  }

  static Set<String> _tables(String list) => {
    for (final item in _topLevel(list))
      if (_listedTable.firstMatch(item) case final m?) _key(m[1]!),
  };
}

/// A migration file name's stamp, padded to 14 digits: `20260417_x.sql` →
/// `20260417000000`.
String _stamp(String fileName) {
  final digits = RegExp(r'^(\d+)_').firstMatch(fileName)?[1];
  if (digits == null || digits.length > 14) {
    throw FormatException('migration $fileName has no YYYYMMDD[HHMMSS] stamp');
  }
  return digits.padRight(14, '0');
}

/// The baseline plus exactly the migrations stamped after its dump stamp,
/// replayed in filename order — what a fresh stack is rebuilt from.
class RebuildSet {
  RebuildSet._(
    this.dumpStamp,
    this.replayedMigrations,
    this.preStampMigrations,
    this._migrationsDir,
    this._objects,
  );

  factory RebuildSet.load({
    String baselinePath = 'supabase/schema/baseline.sql',
    String migrationsDir = 'supabase/migrations',
  }) {
    final baseline = File(baselinePath).readAsStringSync();
    final dumpStamp = RegExp(
      r'^-- dump-stamp: (\d{14})\s*$',
      multiLine: true,
    ).firstMatch(baseline)?[1];
    if (dumpStamp == null) {
      throw StateError(
        '$baselinePath has no "-- dump-stamp: YYYYMMDDHHMMSS" header line',
      );
    }
    final names =
        Directory(migrationsDir)
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('.sql'))
            .toList()
          ..sort();
    final objects = SqlObjects()..apply(baseline);
    final replayed = <String>[];
    final preStamp = <String>[];
    for (final name in names) {
      if (_stamp(name).compareTo(dumpStamp) > 0) {
        objects.apply(File('$migrationsDir/$name').readAsStringSync());
        replayed.add(name);
      } else {
        preStamp.add(name);
      }
    }
    return RebuildSet._(dumpStamp, replayed, preStamp, migrationsDir, objects);
  }

  /// The baseline header's `-- dump-stamp:` value.
  final String dumpStamp;

  /// File names replayed over the baseline, in replay order.
  final List<String> replayedMigrations;

  /// File names the dump already contains, in filename order.
  final List<String> preStampMigrations;

  final String _migrationsDir;
  final SqlObjects _objects;

  /// A table or view.
  bool hasRelation(String name) => _objects.relations.contains(_key(name));

  bool hasFunction(String name) => _objects.functions.containsKey(_key(name));

  bool hasColumn(String table, String column) =>
      _objects.columns[_key(table)]?.contains(_key(column)) ?? false;

  bool hasIndex(String name) => _objects.indexes.contains(_key(name));

  bool inRealtimePublication(String table) =>
      _objects.allTablesPublications.contains('supabase_realtime')
      ? hasRelation(table)
      : _objects.publications['supabase_realtime']?.contains(_key(table)) ??
            false;

  /// The newest definition: a replayed migration wins over the baseline.
  String? latestFunctionSource(String name) => _objects.functions[_key(name)];

  /// Every function, added column and index a pre-stamp migration creates
  /// that the rebuild set lacks, as `<file>: <kind> <name>`. Empty means the
  /// dump really contains every migration stamped before it.
  List<String> preStampGaps() => [
    for (final name in preStampMigrations)
      for (final gap in _gaps(
        SqlObjects()..apply(File('$_migrationsDir/$name').readAsStringSync()),
      ))
        '$name: $gap',
  ];

  Iterable<String> _gaps(SqlObjects created) sync* {
    for (final f in created.functions.keys) {
      if (!hasFunction(f)) yield 'function $f';
    }
    for (final MapEntry(key: table, value: columns)
        in created.columns.entries) {
      for (final c in columns) {
        if (!hasColumn(table, c)) yield 'column $table.$c';
      }
    }
    for (final i in created.indexes) {
      if (!hasIndex(i)) yield 'index $i';
    }
  }
}

/// Writes [baseline] and [migrations] (file name → SQL; a `/` makes a
/// subfolder) under [root] and loads them — the fixture form of
/// [RebuildSet.load].
RebuildSet loadFixture(
  Directory root,
  String baseline, [
  Map<String, String> migrations = const {},
]) {
  final baselineFile = File('${root.path}/baseline.sql')
    ..createSync(recursive: true)
    ..writeAsStringSync(baseline);
  final migrationsDir = Directory('${root.path}/migrations')
    ..createSync(recursive: true);
  migrations.forEach(
    (name, sql) => File('${migrationsDir.path}/$name')
      ..createSync(recursive: true)
      ..writeAsStringSync(sql),
  );
  return RebuildSet.load(
    baselinePath: baselineFile.path,
    migrationsDir: migrationsDir.path,
  );
}

final _fromCall = RegExp(r'''\.from\(\s*(['"])([A-Za-z_]\w*)\1''');
final _rpcCall = RegExp(
  r'''rpc\(\s*(?:(['"])([A-Za-z_]\w*)\1|([A-Za-z_]\w*)\s*[,)])''',
  caseSensitive: false,
);
final _stringConst = RegExp(
  r'''\bconst\s+(?:String\s+)?([A-Za-z_]\w*)\s*=\s*(['"])([A-Za-z_]\w*)\2\s*;''',
);
final _channelCall = RegExp(r'\b(?:subscribeToChannel|syncInFilterChannels)\(');
final _tableArg = RegExp(r'''\btable:\s*(['"])([A-Za-z_]\w*)\1''');

/// Every `.from('…')` target in [dartSource]. Requiring a string literal
/// skips `List.from(x)`.
Set<String> clientRelations(String dartSource) => {
  for (final m in _fromCall.allMatches(dartSource)) m[2]!,
};

/// Every function [dartSource] names as the first argument of a call whose
/// callee ends in `rpc` (`.rpc(`, `_payBackRpc(`). The name is either a string
/// literal, possibly on the next line, or a `const` String declared in the
/// same source (`deleteRpcName`). An identifier that resolves to nothing,
/// such as a wrapper's own parameter, is ignored.
Set<String> clientRpcs(String dartSource) {
  final constants = {
    for (final m in _stringConst.allMatches(dartSource)) m[1]!: m[3]!,
  };
  return {
    for (final m in _rpcCall.allMatches(dartSource)) ?(m[2] ?? constants[m[3]]),
  };
}

/// Every `table: '…'` passed to `subscribeToChannel(` or
/// `syncInFilterChannels(` in [dartSource].
Set<String> clientRealtimeTables(String dartSource) => {
  for (final call in _channelCall.allMatches(dartSource))
    if (_tableArg.firstMatch(_dartArgs(dartSource, call.end - 1)) case final m?)
      m[2]!,
};

/// The text between the `(` at [open] and its matching `)`, skipping string
/// literals and `//` comments.
String _dartArgs(String source, int open) {
  var depth = 0;
  var i = open;
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
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
    i++;
  }
  return source.substring(open + 1);
}

/// The call targets in [dartSources] that [rebuild] lacks, sorted, as
/// `.from <name>` (needs a table or view), `.rpc <name>` (needs a function)
/// and `realtime <name>` (needs `supabase_realtime` membership).
List<String> missingTargets(RebuildSet rebuild, Iterable<String> dartSources) {
  final relations = <String>{};
  final rpcs = <String>{};
  final realtime = <String>{};
  for (final source in dartSources) {
    relations.addAll(clientRelations(source));
    rpcs.addAll(clientRpcs(source));
    realtime.addAll(clientRealtimeTables(source));
  }
  return [
    for (final r in relations)
      if (!rebuild.hasRelation(r)) '.from $r',
    for (final f in rpcs)
      if (!rebuild.hasFunction(f)) '.rpc $f',
    for (final t in realtime)
      if (!rebuild.inRealtimePublication(t)) 'realtime $t',
  ]..sort();
}
