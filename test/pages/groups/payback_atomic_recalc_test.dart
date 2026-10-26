// payback-atomic-recalc: GroupRepository.payBack issues the payback write and
// nothing else. The balance recalculation runs inside `pay_back` on the
// server, so a thrown error means nothing was recorded and a retry is safe.
// Every RPC goes through GroupRepository.payBackRpcOverride and every push to
// a no-op transport; no test here reaches the network.

import 'package:deun/helper/notification_sender.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _groupId = 'g1';
const _ann = 'ann@test.com';
const _bob = 'bob@test.com';

GroupMember _member(String email, String displayName) => GroupMember()
  ..groupId = _groupId
  ..email = email
  ..displayName = displayName
  ..isGuest = false
  ..isFavorite = false;

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final roster = [_member(_ann, 'Ann'), _member(_bob, 'Bob')];
  final expectedParams = GroupRepository.payBackRpcParams(
    groupId: _groupId,
    paidBy: _ann,
    paidFor: _bob,
    amount: 12.5,
  );
  const missingExact = PostgrestException(
    message: 'Could not find the function public.pay_back_exact',
    code: 'PGRST202',
  );

  late List<String> calls;
  late List<Map<String, dynamic>> sent;

  /// Records every RPC payBack issues; [respond] returns its result or throws.
  void answer(Object? Function(String function) respond) {
    GroupRepository.payBackRpcOverride = (function, params) async {
      calls.add(function);
      sent.add(params);
      return respond(function);
    };
  }

  Future<void> payBack() => GroupRepository.payBack(
    _groupId,
    _bob,
    12.5,
    paidBy: _ann,
    members: roster,
    notifications: NotificationSender(
      en,
      push: (type, objectId, receivers, title, body) async {},
      groupRow: (_) async => const {
        'name': 'Trip',
        'currency_code': 'EUR',
        'user_display_name': 'Zoe',
      },
    ),
  );

  setUpAll(() async {
    // A local, signed-out client: payBack reads supabase.auth for the recorder.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(() {
    calls = [];
    sent = [];
    GroupRepository.resetPayBackFallback();
  });

  tearDown(() {
    GroupRepository.payBackRpcOverride = null;
    GroupRepository.resetPayBackFallback();
  });

  group('a recorded payback completes on its write alone', () {
    test(
      'one pay_back_exact, and no client-side recalculation to fail after it',
      () async {
        answer(
          (function) => function == 'pay_back_exact'
              ? 'payback-1'
              : throw StateError('unexpected RPC $function'),
        );

        await payBack();

        expect(calls, ['pay_back_exact']);
      },
    );

    test(
      'without pay_back_exact: one probe plus pay_back, then pay_back alone',
      () async {
        answer(
          (function) => switch (function) {
            'pay_back_exact' => throw missingExact,
            'pay_back' => 'payback-1',
            _ => throw StateError('unexpected RPC $function'),
          },
        );

        await payBack();
        expect(calls, ['pay_back_exact', 'pay_back']);
        // Both RPCs receive the same four-argument map.
        expect(sent, everyElement(equals(expectedParams)));

        calls.clear();
        await payBack();
        expect(calls, ['pay_back']);
      },
    );
  });

  group('a failed write throws and is never written again', () {
    test(
      'a rejection from pay_back_exact is thrown after that one RPC',
      () async {
        const rejection = PostgrestException(
          message: 'pay_back: bob@test.com is not a current member of group g1',
          code: '23503',
        );
        answer((_) => throw rejection);

        await expectLater(payBack(), throwsA(same(rejection)));
        expect(calls, ['pay_back_exact']);
      },
    );

    test(
      'a dropped connection on the pay_back fallback is thrown after that one write',
      () async {
        final dropped = Exception('connection reset');
        answer(
          (function) =>
              function == 'pay_back_exact' ? throw missingExact : throw dropped,
        );

        await expectLater(payBack(), throwsA(same(dropped)));
        expect(calls, ['pay_back_exact', 'pay_back']);
      },
    );
  });
}
