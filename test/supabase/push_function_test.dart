// push-server-compose: the `push` Edge Function, held to the app it serves.
// deno is not installed and TypeScript cannot run in the gates, so (as
// exchange_rate_function_test.dart does for the exchange-rate function) the
// declarative half, push_kinds.json, is checked exactly against the ARB files,
// kSupportedCurrencies and PushKind, and index.ts's guards are pinned by source
// shape. A reformat of index.ts should not redden these; deleting a guard
// must. Live delivery is the manual check.

import 'dart:convert';
import 'dart:io';

import 'package:deun/helper/currency.dart';
import 'package:deun/helper/helper.dart' show kDefaultCurrencyCode;
import 'package:deun/helper/notification_sender.dart';
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

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final _placeholder = RegExp(r'\{(\w+)\}');

Set<String> _placeholders(String template) => {
  for (final m in _placeholder.allMatches(template)) m[1]!,
};

/// The push kind table's `kinds` map.
Map<String, dynamic> _kinds() =>
    _json('$_dir/push_kinds.json')['kinds'] as Map<String, dynamic>;

String _index() => File('$_dir/index.ts').readAsStringSync();

bool _has(String source, String pattern) => RegExp(pattern).hasMatch(source);

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

  group('push_kinds.json', () {
    // A: criterion "A receiver gets every kind in their own language, worded
    // as today".
    test('every kind has its English and German copy, worded as the ARB files '
        'word it, and every placeholder is bound', () {
      final kinds = _kinds();
      final enArb = _json('lib/l10n/app_en.arb');
      final deArb = _json('lib/l10n/app_de.arb');
      // Which ARB pair writes which push: the client's copy before this
      // feature, kind by kind.
      const arbKeys = {
        'member_added': {
          'default': ['groupNotificationTitle', 'groupNotificationBody'],
        },
        'payback_recorded': {
          'default': [
            'groupPayBackNotificationTitle',
            'groupPayBackNotificationBody',
          ],
          'on_behalf': [
            'groupPayBackOnBehalfNotificationTitle',
            'groupPayBackOnBehalfNotificationBody',
          ],
        },
        'payment_reminder': {
          'default': ['reminderNotificationTitle', 'reminderNotificationBody'],
        },
        'expense_created': {
          'default': ['expenseNotificationTitle', 'expenseNotificationBody'],
        },
        'claim_nudge': {
          'default': [
            'claimNudgeNotificationTitle',
            'claimNudgeNotificationBody',
          ],
        },
        'friend_requested': {
          'default': [
            'friendRequestNotificationTitle',
            'friendRequestNotificationBody',
          ],
        },
        'friend_accepted': {
          'default': [
            'friendAcceptNotificationTitle',
            'friendAcceptNotificationBody',
          ],
        },
      };
      expect(kinds.keys.toSet(), arbKeys.keys.toSet());

      for (final MapEntry(key: kind, value: variants) in arbKeys.entries) {
        final spec = kinds[kind] as Map<String, dynamic>;
        final copy = spec['copy'] as Map<String, dynamic>;
        final bindings = spec['bindings'] as Map<String, dynamic>;
        expect(copy.keys.toSet(), variants.keys.toSet(), reason: kind);

        final used = <String>{};
        for (final MapEntry(key: variant, value: keys) in variants.entries) {
          final parts = copy[variant] as Map<String, dynamic>;
          for (final (part, key) in [('title', keys[0]), ('body', keys[1])]) {
            final template = parts[part] as Map<String, dynamic>;
            final where = '$kind $variant $part';
            expect(template['key'], key, reason: where);
            expect(enArb[key], isA<String>(), reason: '$where: no en ARB');
            expect(deArb[key], isA<String>(), reason: '$where: no de ARB');
            expect(template['en'], enArb[key], reason: '$where en');
            expect(template['de'], deArb[key], reason: '$where de');
            for (final lang in ['en', 'de']) {
              final placeholders = _placeholders(template[lang] as String);
              expect(
                bindings.keys,
                containsAll(placeholders),
                reason: '$where $lang: a placeholder has no binding',
              );
              used.addAll(placeholders);
            }
          }
        }
        expect(
          bindings.keys.toSet(),
          used,
          reason: '$kind binds a placeholder no template has',
        );
      }
    });

    // B: criterion "Every name in a push belongs to the right person".
    test('every name in a push belongs to the right person', () {
      // Where a placeholder's text comes from. Only `amount` travels in the
      // request. Every other value is read from rows on the server: the
      // caller from the bearer token, paid_by/paid_for from the users stored
      // for the two emails that were sent.
      const sources = {
        'caller.display_name',
        'paid_by.display_name',
        'paid_for.display_name',
        'group.name',
        'expense.name',
        'amount',
      };
      for (final MapEntry(key: kind, value: spec) in _kinds().entries) {
        final bindings = (spec as Map)['bindings'] as Map<String, dynamic>;
        for (final MapEntry(key: placeholder, value: from)
            in bindings.entries) {
          final where = '$kind {$placeholder}';
          expect(sources, contains(from), reason: where);
          final expected = switch (placeholder) {
            'paidByDisplayName' => 'paid_by.display_name',
            'paidForDisplayName' => 'paid_for.display_name',
            'groupName' => 'group.name',
            'expenseName' => 'expense.name',
            'amount' => 'amount',
            // Every other person a push names is the one who sent it.
            _ when placeholder.toLowerCase().endsWith('displayname') =>
              'caller.display_name',
            _ => null,
          };
          expect(from, expected, reason: where);
        }
      }

      final source = _index();
      expect(
        _has(
          source,
          r'kind\.copy\.on_behalf\s*&&\s*callerEmail\s*!==\s*record\.paid_by',
        ),
        isTrue,
        reason: 'the on-behalf copy exactly when the caller is not the payer',
      );
      expect(
        _has(source, r"'caller\.display_name':\s*nameOf\(callerEmail\)"),
        isTrue,
      );
      expect(
        _has(source, r"'paid_by\.display_name':\s*nameOf\(record\.paid_by\)"),
        isTrue,
      );
      expect(
        _has(source, r"'paid_for\.display_name':\s*nameOf\(record\.paid_for\)"),
        isTrue,
      );
      expect(
        _has(source, r'record\.(title|body|\w*name\b|sender)'),
        isFalse,
        reason: 'apart from the amount, no push text comes from the request',
      );
    });

    // C: criterion "Amounts show in the group's currency, with that
    // currency's own number of decimals".
    test(
      "amounts show in the group's currency with that currency's own decimals",
      () {
        final table = _json('$_dir/push_kinds.json');
        expect((table['zero_decimal_currencies'] as List).toSet(), {
          for (final c in kSupportedCurrencies)
            if (c.decimalDigits == 0) c.code,
        });
        // index.ts renders every code outside that list with 2 decimals.
        expect(
          kSupportedCurrencies
              .where((c) => c.decimalDigits != 0)
              .every((c) => c.decimalDigits == 2),
          isTrue,
        );

        final source = _index();
        expect(
          _has(source, "currencyCode\\s*\\?\\?\\s*'$kDefaultCurrencyCode'"),
          isTrue,
          reason: 'a group with no currency code falls back to the default',
        );
        expect(
          _has(source, r'ZERO_DECIMAL\.has\(code\)\s*\?\s*0\s*:\s*2'),
          isTrue,
        );
        expect(
          _has(source, r'new Intl\.NumberFormat\(lang,'),
          isTrue,
          reason: "the receiver locale's grouping and decimal mark",
        );
        expect(
          _has(source, r'`\$\{code\} \$\{number\}`'),
          isTrue,
          reason: 'the code leads, as formatMoney renders it',
        );
        expect(
          _has(source, r'money\(record\.amount!?,\s*group\?\.currency_code'),
          isTrue,
          reason: "the group's own currency",
        );
      },
    );
  });

  // D: criterion "Every kind the client can send is one the server can write,
  // with the same routing type".
  test('every kind the client can send is one the server can write, with the '
      'same routing type', () {
    final kinds = _kinds();
    expect(kinds.keys.toSet(), {for (final k in PushKind.values) k.wireName});
    for (final k in PushKind.values) {
      expect(
        (kinds[k.wireName] as Map)['type'],
        k.routingType,
        reason: k.wireName,
      );
    }
  });

  group('index.ts', () {
    late String source;

    setUpAll(() => source = _index());

    // E: criterion "Tapping a push still opens what it opens today".
    // The client half stays with pushTargetFor's tests in
    // test/push_notifications_test.dart.
    test('tapping a push still opens what it opens today', () {
      expect(
        _has(
          source,
          r'data:\s*\{\s*type:\s*kind\.type,\s*expense_id:\s*record\.object_id,?\s*\}',
        ),
        isTrue,
        reason:
            "data['type'] is the kind's routing type, data['expense_id'] the object id",
      );
      expect(
        _has(source, r'notification:\s*\{\s*title,\s*body,?\s*\}'),
        isTrue,
      );
      expect(
        _has(source, r'record\.type\b'),
        isFalse,
        reason: 'routing comes from the kind table, never the request',
      );
    });

    // F: criterion "The language is the receiver's stored language".
    test(
      "the language is the receiver's stored language, never the sender's",
      () {
        expect(
          _has(source, r"from\('user'\)\s*\.select\('[^']*\blocale\b"),
          isTrue,
        );
        expect(
          _has(
            source,
            r"\.split\(/\[-_\]/\)\[0\]\s*===\s*'de'\s*\?\s*'de'\s*:\s*'en'",
          ),
          isTrue,
          reason:
              'German for a de subtag, English for null, en and anything else',
        );
        expect(_has(source, r'text\[langOf\(receiver\.locale\)\]'), isTrue);
        expect(
          RegExp(
            r'record\.(locale|lang)|accept-language',
            caseSensitive: false,
          ).hasMatch(source),
          isFalse,
          reason: 'nothing in the request chooses the language',
        );
      },
    );

    // G: criterion "Only a signed-in caller can send a push".
    test('only a signed-in caller can send a push, and only a known kind', () {
      expect(_has(source, r"req\.headers\.get\('Authorization'\)"), isTrue);
      expect(_has(source, r'supabase\.auth\.getUser\(callerJwt\)'), isTrue);
      expect(_has(source, r'const callerEmail = caller\?\.email'), isTrue);
      expect(
        _has(
          source,
          r"if \(!callerEmail\) \{\s*return reply\(\{ error: 'not_signed_in' \}, 401\)",
        ),
        isTrue,
      );
      expect(
        _has(source, r'const kind = KINDS\.get\(record\??\.kind\)'),
        isTrue,
      );
      expect(
        _has(
          source,
          r"if \(!kind\) \{\s*return reply\(\{ error: 'unknown_kind' \}, 400\)",
        ),
        isTrue,
      );
      // Both refusals return before anything is sent.
      final send = source.indexOf('getToken(');
      expect(send, greaterThan(-1));
      expect(
        source.indexOf("'not_signed_in'"),
        allOf(greaterThan(-1), lessThan(send)),
      );
      expect(
        source.indexOf("'unknown_kind'"),
        allOf(greaterThan(-1), lessThan(send)),
      );
      expect(
        _has(source, r'(record|payload)\.(sender|caller|user|from)\w*'),
        isFalse,
        reason: 'the sender is never a body field',
      );
    });

    // H: criterion "Only people who share the push's group or friendship with
    // the caller receive it".
    test("only people who share the push's group or friendship with the caller "
        'receive it', () {
      // Scopes follow the routing type: group and reminder pushes are
      // checked against their group, expense pushes against the expense's
      // group, friendship pushes against friendship rows.
      const scopeOf = {
        'group': 'group',
        'reminder': 'group',
        'expense': 'expense',
        'friendship': 'friendship',
      };
      for (final MapEntry(key: kind, value: spec) in _kinds().entries) {
        final s = spec as Map<String, dynamic>;
        expect(s['scope'], scopeOf[s['type']], reason: kind);
      }

      expect(
        _has(
          source,
          r"from\('expense'\)\s*\.select\('name, group_id'\)\s*\.eq\('id', record\.object_id\)",
        ),
        isTrue,
      );
      expect(_has(source, r'groupId = expense\.group_id'), isTrue);
      expect(
        _has(
          source,
          r"from\('group_member'\)\s*\.select\('email'\)\s*\.eq\('group_id', groupId\)\s*\.is\('removed_at', null\)",
        ),
        isTrue,
        reason: 'active members only',
      );
      expect(
        _has(
          source,
          r"if \(!active\.has\(callerEmail\)\) \{\s*return reply\(\{ error: 'not_a_member' \}, 403\)",
        ),
        isTrue,
      );
      expect(
        _has(
          source,
          r"record\.kind === 'payback_recorded' &&\s*!\(active\.has\(record\.paid_by \?\? ''\) && active\.has\(record\.paid_for \?\? ''\)\)",
        ),
        isTrue,
      );
      expect(
        _has(
          source,
          r'receivers = requested\.filter\(\(email\) => active\.has\(email\)\)',
        ),
        isTrue,
      );
      expect(
        _has(
          source,
          r"\.eq\('requester', callerEmail\)\s*\.in\('addressee', requested\)",
        ),
        isTrue,
      );
      expect(
        _has(
          source,
          r"\.eq\('addressee', callerEmail\)\s*\.in\('requester', requested\)",
        ),
        isTrue,
      );
      expect(
        _has(
          source,
          r'receivers = requested\.filter\(\(email\) => linked\.has\(email\)\)',
        ),
        isTrue,
      );
      expect(
        _has(source, r'email !== callerEmail'),
        isTrue,
        reason: 'the caller never receives their own push',
      );
      // Only the filtered receivers reach a device: the request's list is
      // read once, into `requested`.
      expect(
        RegExp(r'record\.notification_receiver').allMatches(source),
        hasLength(1),
      );
      expect(_has(source, r'const messages = receivers\.flatMap'), isTrue);
    });
  });
}
