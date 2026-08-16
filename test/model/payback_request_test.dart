import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/payback_request.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = 'me@test.com';
const _ann = 'ann@test.com';
const _bob = 'bob@test.com';

GroupMember _member(
  String email, {
  required String displayName,
  bool isGuest = false,
  DateTime? removedAt,
}) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = displayName;
  m.isGuest = isGuest;
  m.isFavorite = false;
  m.removedAt = removedAt;
  return m;
}

List<GroupMember> _roster() => [
  _member(_me, displayName: 'Me'),
  _member(_ann, displayName: 'Ann'),
  _member(_bob, displayName: 'Bob'),
];

PaybackPlan _resolve({
  String paidBy = _ann,
  String paidFor = _bob,
  double amount = 12.5,
  String recordedBy = _me,
  List<GroupMember>? members,
}) => resolvePayback(
  paidBy: paidBy,
  paidFor: paidFor,
  amount: amount,
  recordedBy: recordedBy,
  members: members ?? _roster(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolvePayback', () {
    // 1 — criterion: any member may record "X paid Y" for any two distinct
    // members of that group.
    test('a member records a payback between two OTHER members', () {
      final plan = _resolve();

      expect(plan, isA<PaybackAccepted>());
      final accepted = plan as PaybackAccepted;
      expect(accepted.paidBy, _ann);
      expect(accepted.paidFor, _bob);
      expect(accepted.amount, 12.5);
      expect(accepted.recordedBy, _me);
      expect(accepted.isOnBehalf, isTrue);
    });

    // 2 — criterion: the existing self-payback path is not re-routed.
    test('a self-payback is accepted and is not on behalf of anyone', () {
      final accepted = _resolve(paidBy: _me, paidFor: _ann) as PaybackAccepted;

      expect(accepted.isOnBehalf, isFalse);
      expect(accepted.paidBy, _me);
      expect(accepted.recordedBy, _me);
    });

    // 3 — criterion: payer == payee is rejected before any write.
    test('payer and payee being the same member is rejected', () {
      final plan = _resolve(paidBy: _ann, paidFor: _ann);

      expect(plan, isA<PaybackRejected>());
      expect((plan as PaybackRejected).reason, PaybackRejection.samePerson);
    });

    // 4
    test('paying yourself back is rejected on the self path too', () {
      final plan = _resolve(paidBy: _me, paidFor: _me) as PaybackRejected;

      expect(plan.reason, PaybackRejection.samePerson);
    });

    // 5 — criterion: a member who is not in the group is rejected.
    test('a payer who is not in the group is rejected, named by email', () {
      final plan = _resolve(paidBy: 'zoe@test.com') as PaybackRejected;

      expect(plan.reason, PaybackRejection.payerNotInGroup);
      expect(plan.displayName, 'zoe@test.com');
    });

    // 6
    test('a payee who is not in the group is rejected', () {
      final plan = _resolve(paidFor: 'zoe@test.com') as PaybackRejected;

      expect(plan.reason, PaybackRejection.payeeNotInGroup);
      expect(plan.displayName, 'zoe@test.com');
    });

    // 7 — criterion: a soft-removed member is rejected, and still nameable.
    test('a soft-removed payer is rejected and named by display name', () {
      final plan =
          _resolve(
                paidBy: 'carol@test.com',
                members: [
                  ..._roster(),
                  _member(
                    'carol@test.com',
                    displayName: 'Carol',
                    removedAt: DateTime.utc(2026, 8, 15),
                  ),
                ],
              )
              as PaybackRejected;

      expect(plan.reason, PaybackRejection.payerNotInGroup);
      expect(plan.displayName, 'Carol');
    });

    // 8
    test('a soft-removed payee is rejected', () {
      final plan =
          _resolve(
                paidFor: 'carol@test.com',
                members: [
                  ..._roster(),
                  _member(
                    'carol@test.com',
                    displayName: 'Carol',
                    removedAt: DateTime.utc(2026, 8, 15),
                  ),
                ],
              )
              as PaybackRejected;

      expect(plan.reason, PaybackRejection.payeeNotInGroup);
      expect(plan.displayName, 'Carol');
    });

    // 9
    test('a zero or negative amount is rejected', () {
      expect(
        (_resolve(amount: 0) as PaybackRejected).reason,
        PaybackRejection.nonPositiveAmount,
      );
      expect(
        (_resolve(amount: -5) as PaybackRejected).reason,
        PaybackRejection.nonPositiveAmount,
      );
    });

    // 10 — an unauthenticated client would send an empty payer; the guard stops
    // it before the RPC rather than inserting a row with an empty paid_by.
    test('an empty payer is rejected, not sent to the RPC', () {
      final plan = _resolve(paidBy: '') as PaybackRejected;

      expect(plan.reason, PaybackRejection.payerNotInGroup);
    });

    // 11 — criterion: notify the payee AND the payer.
    test('both parties are notified when the payer is a real user', () {
      final accepted = _resolve() as PaybackAccepted;

      expect(accepted.notificationReceivers, {_ann, _bob});
      expect(accepted.payerIsGuest, isFalse);
    });

    // 12 — criterion: "...when the payer is a real user, not a guest".
    test('a guest payer is not notified — only the payee is', () {
      final accepted =
          _resolve(
                paidBy: 'guest+1@guest.invalid',
                members: [
                  ..._roster(),
                  _member(
                    'guest+1@guest.invalid',
                    displayName: 'Zoe',
                    isGuest: true,
                  ),
                ],
              )
              as PaybackAccepted;

      expect(accepted.notificationReceivers, {_bob});
      expect(accepted.payerIsGuest, isTrue);
    });

    // 13 — criterion: the self path's writes/sends are unchanged.
    // sendNotification strips the current user, so {me, ann} reaches {ann} —
    // exactly the set this path sent before the feature.
    test('a self-payback still reaches only the payee once the recorder is '
        'stripped', () {
      final accepted = _resolve(paidBy: _me, paidFor: _ann) as PaybackAccepted;

      expect(accepted.notificationReceivers, {_me, _ann});
      expect({...accepted.notificationReceivers}..remove(accepted.recordedBy), {
        _ann,
      });
    });

    // 14 — criterion: the notification must name who recorded it. Those names
    // come off the roster, so the copy works before the migration lands.
    test('the accepted plan carries every display name the notification '
        'needs', () {
      final accepted = _resolve() as PaybackAccepted;

      expect(accepted.paidByDisplayName, 'Ann');
      expect(accepted.paidForDisplayName, 'Bob');
      expect(accepted.recordedByDisplayName, 'Me');
    });
  });

  group('PaybackRejected.message', () {
    late AppLocalizations en;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    // 15
    test('each rejection maps to its own copy', () {
      expect(
        const PaybackRejected(reason: PaybackRejection.samePerson).message(en),
        en.paybackRecordSamePersonError,
      );
      expect(
        const PaybackRejected(
          reason: PaybackRejection.payeeNotInGroup,
          displayName: 'Carol',
        ).message(en),
        en.paybackRecordNotMemberError('Carol'),
      );
      expect(
        const PaybackRejected(
          reason: PaybackRejection.payerNotInGroup,
          displayName: 'Carol',
        ).message(en),
        en.paybackRecordNotMemberError('Carol'),
      );
      expect(
        const PaybackRejected(
          reason: PaybackRejection.nonPositiveAmount,
        ).message(en),
        en.paybackRecordAmountError,
      );
    });
  });
}
