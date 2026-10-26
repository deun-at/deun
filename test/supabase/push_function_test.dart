// push-server-compose: the `push` Edge Function, held to the app it serves.
// deno is not installed and TypeScript cannot run in the gates, so (as
// exchange_rate_function_test.dart does for the exchange-rate function) the
// declarative half, push_kinds.json, is checked exactly against the ARB files,
// kSupportedCurrencies and PushKind, and index.ts's guards are pinned by source
// shape. A reformat of index.ts should not redden these; deleting a guard
// must. Live delivery is the manual check.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rebuild_set.dart';

const _dir = 'supabase/functions/push';

/// Credential shapes a Firebase setup leaves behind beyond the ones
/// [findSecrets] already names (private-key block, JWT, Bearer token).
final _pushCredentialShapes = <String, RegExp>{
  'service-account private_key field': RegExp(r'''["']private_key["']\s*:'''),
  'FCM server key': RegExp(r'AAAA[A-Za-z0-9_-]{7}:[A-Za-z0-9_-]{100,}'),
};

/// Shape names only, never the match, so a red run cannot log a key.
List<String> _findCredentials(String text) => [
  ...findSecrets(text),
  for (final MapEntry(key: shape, value: pattern)
      in _pushCredentialShapes.entries)
    if (pattern.hasMatch(text)) shape,
];

void main() {
  test('no credential is committed under supabase/functions/push', () {
    // The two added shapes fire on invented samples, built at run time so this
    // file holds no credential-shaped literal either.
    expect(
      _findCredentials('{"private_key": "x"}'),
      contains('service-account private_key field'),
    );
    expect(
      _findCredentials('AAAA${'a' * 7}:${'b' * 140}'),
      contains('FCM server key'),
    );

    final files = Directory(
      _dir,
    ).listSync(recursive: true).whereType<File>().toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        _findCredentials(file.readAsStringSync()),
        isEmpty,
        reason: file.path,
      );
    }
    // The service account comes from the functions container's environment.
    expect(
      File('$_dir/index.ts').readAsStringSync(),
      contains("Deno.env.get('FIREBASE_SERVICE_ACCOUNT')"),
    );
  });
}
