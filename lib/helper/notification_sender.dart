import 'package:deun/main.dart';
import 'package:flutter/foundation.dart';

/// Every push the app sends. [wireName] is the `record.kind` the `push` Edge
/// Function looks up in supabase/functions/push/push_kinds.json, where the
/// text is written in each receiver's language. [routingType] is the FCM
/// `data['type']` a tap routes on (see `pushTargetFor`).
enum PushKind {
  memberAdded('member_added', 'group'),
  paybackRecorded('payback_recorded', 'group'),
  paymentReminder('payment_reminder', 'reminder'),
  expenseCreated('expense_created', 'expense'),
  claimNudge('claim_nudge', 'expense'),
  friendRequested('friend_requested', 'friendship'),
  friendAccepted('friend_accepted', 'friendship');

  const PushKind(this.wireName, this.routingType);

  final String wireName;
  final String routingType;
}

/// What the server needs to write one push, and no text: the server reads
/// every name from rows and writes the copy itself. [amount] is the number the
/// text shows; [paidBy] and [paidFor] are emails.
class PushRequest {
  const PushRequest({
    required this.kind,
    required this.objectId,
    required this.receivers,
    this.amount,
    this.paidBy,
    this.paidFor,
  });

  final PushKind kind;

  /// The group id (member added, payback, reminder), the expense id (expense
  /// created, claim nudge) or empty (friendship).
  final String objectId;
  final Set<String> receivers;
  final double? amount;
  final String? paidBy;
  final String? paidFor;
}

/// The `push` Edge Function call. Default: [_invokePush].
typedef PushTransport = Future<void> Function(PushRequest request);

/// The body posted to the `push` Edge Function. [senderEmail] is left out of
/// `notification_receiver`; the request is not mutated.
Map<String, dynamic> pushRequestBody(
  PushRequest request, {
  String? senderEmail,
}) => {
  'type': 'INSERT',
  'table': request.kind.routingType,
  'record': {
    'kind': request.kind.wireName,
    'type': request.kind.routingType,
    'object_id': request.objectId,
    'notification_receiver': [
      for (final receiver in request.receivers)
        if (receiver != senderEmail) receiver,
    ],
    if (request.amount != null) 'amount': request.amount,
    if (request.paidBy != null) 'paid_by': request.paidBy,
    if (request.paidFor != null) 'paid_for': request.paidFor,
  },
};

/// Posts [request] as the signed-in [senderEmail]. Nobody signed in posts
/// nothing. The server would refuse it anyway.
@visibleForTesting
Future<void> postPushRequest(
  PushRequest request, {
  required String? senderEmail,
  required Future<void> Function(Map<String, dynamic> body) post,
}) async {
  if (senderEmail == null) return;
  await post(pushRequestBody(request, senderEmail: senderEmail));
}

/// Sends every push as a [PushRequest]. Holds no BuildContext and no strings,
/// so a send never depends on the screen that issued it. Constructing one
/// touches no Supabase client: the default transport reaches `supabase` only
/// when a send runs. Every method completes normally on every failure.
class NotificationSender {
  NotificationSender({PushTransport? push}) : _push = push ?? _invokePush;

  final PushTransport _push;

  Future<void> memberAdded(String groupId, Set<String> receivers) => _send(
    PushRequest(
      kind: PushKind.memberAdded,
      objectId: groupId,
      receivers: receivers,
    ),
  );

  /// The server picks the on-behalf copy when the caller is not [paidBy].
  Future<void> paybackRecorded({
    required String groupId,
    required Set<String> receivers,
    required double amount,
    required String paidBy,
    required String paidFor,
  }) => _send(
    PushRequest(
      kind: PushKind.paybackRecorded,
      objectId: groupId,
      receivers: receivers,
      amount: amount,
      paidBy: paidBy,
      paidFor: paidFor,
    ),
  );

  Future<void> paymentReminder(
    String groupId,
    Set<String> receivers,
    double amount,
  ) => _send(
    PushRequest(
      kind: PushKind.paymentReminder,
      objectId: groupId,
      receivers: receivers,
      amount: amount,
    ),
  );

  Future<void> expenseCreated(
    String expenseId,
    Set<String> receivers,
    double amount,
  ) => _send(
    PushRequest(
      kind: PushKind.expenseCreated,
      objectId: expenseId,
      receivers: receivers,
      amount: amount,
    ),
  );

  Future<void> friendRequested(Set<String> receivers) => _send(
    PushRequest(
      kind: PushKind.friendRequested,
      objectId: '',
      receivers: receivers,
    ),
  );

  Future<void> friendAccepted(Set<String> receivers) => _send(
    PushRequest(
      kind: PushKind.friendAccepted,
      objectId: '',
      receivers: receivers,
    ),
  );

  Future<void> claimNudge({
    required String expenseId,
    required Set<String> receivers,
  }) => _send(
    PushRequest(
      kind: PushKind.claimNudge,
      objectId: expenseId,
      receivers: receivers,
    ),
  );

  Future<void> _send(PushRequest request) async {
    try {
      await _push(request);
    } catch (e) {
      debugPrint('Failed to send ${request.kind.wireName} notification: $e');
    }
  }
}

Future<void> _invokePush(PushRequest request) => postPushRequest(
  request,
  senderEmail: supabase.auth.currentUser?.email,
  post: (body) async {
    final res = await supabase.functions.invoke('push', body: body);
    debugPrint(res.data.toString());
  },
);
