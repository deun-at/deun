import 'package:deun/helper/notification_sender.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every request the sender hands its transport.
class _SpyPush {
  final sent = <PushRequest>[];

  Future<void> call(PushRequest request) async => sent.add(request);
}

const _me = 'me@test.com';
const _ann = 'ann@test.com';
const _bob = 'bob@test.com';

/// The body the signed-in [_me] posts for the one push [send] issues.
Future<Map<String, dynamic>> _posted(
  Future<void> Function(NotificationSender sender) send,
) async {
  final spy = _SpyPush();
  await send(NotificationSender(push: spy.call));
  expect(spy.sent, hasLength(1));
  return pushRequestBody(spy.sent.single, senderEmail: _me);
}

Future<void> _sendEveryKind(NotificationSender s) async {
  await s.memberAdded('g1', {_ann});
  await s.paybackRecorded(
    groupId: 'g1',
    receivers: {_ann},
    amount: 12.5,
    paidBy: _me,
    paidFor: _ann,
  );
  await s.paymentReminder('g1', {_ann}, 12.5);
  await s.expenseCreated('e1', {_ann}, 12.5);
  await s.claimNudge(expenseId: 'e1', receivers: {_ann});
  await s.friendRequested({_ann});
  await s.friendAccepted({_ann});
}

void main() {
  group('every kind reaches the server with what it needs to write the push, '
      'and no text', () {
    test('member added', () async {
      expect(await _posted((s) => s.memberAdded('g1', {_me, _ann})), {
        'type': 'INSERT',
        'table': 'group',
        'record': {
          'kind': 'member_added',
          'type': 'group',
          'object_id': 'g1',
          'notification_receiver': [_ann],
        },
      });
    });

    test('payback recorded, by the payer or on their behalf', () async {
      expect(
        await _posted(
          (s) => s.paybackRecorded(
            groupId: 'g1',
            receivers: {_ann, _bob},
            amount: 12.5,
            paidBy: _bob,
            paidFor: _ann,
          ),
        ),
        {
          'type': 'INSERT',
          'table': 'group',
          'record': {
            'kind': 'payback_recorded',
            'type': 'group',
            'object_id': 'g1',
            'notification_receiver': [_ann, _bob],
            'amount': 12.5,
            'paid_by': _bob,
            'paid_for': _ann,
          },
        },
      );
    });

    test('payment reminder', () async {
      expect(await _posted((s) => s.paymentReminder('g1', {_me, _ann}, 12.5)), {
        'type': 'INSERT',
        'table': 'reminder',
        'record': {
          'kind': 'payment_reminder',
          'type': 'reminder',
          'object_id': 'g1',
          'notification_receiver': [_ann],
          'amount': 12.5,
        },
      });
    });

    test('expense created', () async {
      expect(
        await _posted((s) => s.expenseCreated('e1', {_me, _ann, _bob}, 12.5)),
        {
          'type': 'INSERT',
          'table': 'expense',
          'record': {
            'kind': 'expense_created',
            'type': 'expense',
            'object_id': 'e1',
            'notification_receiver': [_ann, _bob],
            'amount': 12.5,
          },
        },
      );
    });

    test('claim nudge', () async {
      expect(
        await _posted(
          (s) => s.claimNudge(expenseId: 'e1', receivers: {_me, _ann, _bob}),
        ),
        {
          'type': 'INSERT',
          'table': 'expense',
          'record': {
            'kind': 'claim_nudge',
            'type': 'expense',
            'object_id': 'e1',
            'notification_receiver': [_ann, _bob],
          },
        },
      );
    });

    test('friend request and friend accepted', () async {
      for (final (send, kind) in [
        (
          (NotificationSender s) => s.friendRequested({_bob}),
          'friend_requested',
        ),
        ((NotificationSender s) => s.friendAccepted({_bob}), 'friend_accepted'),
      ]) {
        expect(await _posted(send), {
          'type': 'INSERT',
          'table': 'friendship',
          'record': {
            'kind': kind,
            'type': 'friendship',
            'object_id': '',
            'notification_receiver': [_bob],
          },
        });
      }
    });
  });

  test('no send ever throws to its caller', () async {
    await expectLater(
      _sendEveryKind(
        NotificationSender(
          push: (request) async => throw Exception('push down'),
        ),
      ),
      completes,
    );
    await expectLater(
      _sendEveryKind(
        NotificationSender(push: (request) => throw Exception('push down')),
      ),
      completes,
    );
  });

  test('nothing is posted when nobody is signed in', () async {
    final posted = <Map<String, dynamic>>[];
    const request = PushRequest(
      kind: PushKind.friendRequested,
      objectId: '',
      receivers: {_ann},
    );
    await postPushRequest(
      request,
      senderEmail: null,
      post: (body) async => posted.add(body),
    );
    expect(posted, isEmpty);

    await postPushRequest(
      request,
      senderEmail: _me,
      post: (body) async => posted.add(body),
    );
    expect(posted, [pushRequestBody(request, senderEmail: _me)]);
  });
}
