final _regexMeta = RegExp(r'[\\.^$*+?()\[\]{}|]');

/// A PostgREST filter that matches rows whose column contains [typed] as a
/// literal substring, ignoring case.
///
/// Uses `imatch` (Postgres `~*`) rather than `ilike`, because PostgREST
/// rewrites every `*` in a like pattern to `%` and offers no escape. Each of
/// the 14 ARE metacharacters is preceded by a backslash; everything else,
/// including `%` and `_`, is already literal in a regex.
({String operator, String value}) literalSearchFilter(String typed) => (
  operator: 'imatch',
  value: typed.replaceAllMapped(_regexMeta, (m) => '\\${m[0]}'),
);
