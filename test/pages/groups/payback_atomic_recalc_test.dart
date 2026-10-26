// payback-atomic-recalc: PaybackRepository.payBack issues the payback write and
// nothing else. The balance recalculation runs inside `pay_back` on the
// server, so a thrown error means nothing was recorded and a retry is safe.
// Every RPC goes through the repository's `rpc` constructor parameter and every
// push to a no-op transport; no test here reaches the network.

import 'package:deun/helper/notification_sender.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/payback_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helper/fake_supabase.dart';
import '../../helper/unused_repositories.dart';

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
  final roster = [_member(_ann, 'Ann'), _member(_bob, 'Bob')];
  const missingExact = PostgrestException(
    message: 'Could not find the function public.pay_back_exact',
    code: 'PGRST202',
  );

  late List<String> calls;
  late PaybackRpc rpc;

  /// Records every RPC payBack issues; [respond] returns its result or throws.
  void answer(Object? Function(String function) respond) {
    rpc = (function, params) async {
      calls.add(function);
      return respond(function);
    };
  }

  // No signed-in user: payBack reads the recorder from the current user.
  Future<void> payBack() =>
      PaybackRepository(
        FakeSupabaseClient(),
        null,
        groups: UnusedGroupRepository(),
        members: UnusedMemberRepository(),
        rpc: rpc,
      ).payBack(
        _groupId,
        _bob,
        12.5,
        paidBy: _ann,
        members: roster,
        notifications: NotificationSender(push: (request) async {}),
      );

  setUp(() {
    calls = [];
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
      'a missing pay_back_exact is thrown after that one RPC, and the next payback issues it alone again',
      () async {
        answer((_) => throw missingExact);

        await expectLater(payBack(), throwsA(same(missingExact)));
        expect(calls, ['pay_back_exact']);

        calls.clear();
        await expectLater(payBack(), throwsA(same(missingExact)));
        expect(calls, ['pay_back_exact']);
      },
    );
  });
}
