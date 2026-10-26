import 'dart:async';

import 'package:deun/helper/currency.dart';
import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/member_repository.dart';
import 'package:deun/pages/users/current_user.dart';
import 'package:deun/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_member_model.dart';
import 'payback_request.dart';

part 'payback_repository.g.dart';

class PaybackRepository {
  PaybackRepository(
    this._supabase,
    this._currentUser, {
    required GroupRepository groups,
    required MemberRepository members,
    PaybackRpc? rpc,
    PayBackAllWrite? payBackAllWrite,
  }) : _groups = groups,
       _members = members,
       _rpc = rpc,
       _payBackAllWrite = payBackAllWrite;

  final SupabaseClient _supabase;
  final CurrentUser? _currentUser;
  final GroupRepository _groups;
  final MemberRepository _members;

  /// Null outside tests. When set, every RPC a payback write issues goes
  /// through it instead of the client.
  final PaybackRpc? _rpc;

  /// Null outside tests. When set, [applyPayBackAll] runs it in place of each
  /// settled target's write; the notify step still follows each write.
  final PayBackAllWrite? _payBackAllWrite;

  /// Every RPC a payback write issues.
  Future<Object?> _payBackRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    final rpc = _rpc;
    if (rpc != null) return rpc(function, params);
    return await _supabase.rpc(function, params: params);
  }

  /// The `pay_back_exact` argument map, the ONE place those parameter names
  /// live. Pure, so a test can prove that defaulting `paidBy` to the current
  /// user leaves the self-payback call byte-identical to what it sent before the
  /// parameter existed.
  static Map<String, dynamic> payBackRpcParams({
    required String groupId,
    required String paidBy,
    required String paidFor,
    required double amount,
  }) => {
    "_group_id": groupId,
    "_paid_by": paidBy,
    "_paid_for": paidFor,
    "_amount": amount,
  };

  /// The payback plan for "[paidBy] paid [paidFor] [amount]", recorded by
  /// [recordedBy], with **the default for [paidBy] applied here**: a null
  /// [paidBy] means the signed-in user, which is what keeps the self-payback
  /// path sending exactly the `_paid_by` it sent before the parameter existed.
  ///
  /// Split out of [payBack] so that default has one home and a pure test can
  /// assert it — [payBack] itself needs a Supabase session and an RPC.
  @visibleForTesting
  static PaybackPlan planPayBack({
    String? paidBy,
    required String paidFor,
    required double amount,
    required String recordedBy,
    required List<GroupMember> members,
  }) => resolvePayback(
    paidBy: paidBy ?? recordedBy,
    paidFor: paidFor,
    amount: amount,
    recordedBy: recordedBy,
    members: members,
  );

  /// Records "[paidBy] paid [email] [amount]" in [groupId].
  ///
  /// [paidBy] defaults to the signed-in user, so every existing call site keeps
  /// its exact behaviour and the common case stays on this one code path — the
  /// feature extends the RPC call, it does not re-route it. Passing a different
  /// member records a payback on their behalf: any member may do this for any
  /// two distinct members (there is no owner concept in Deun — see the plan's
  /// Decisions), and the deterrent is visibility, which is why BOTH parties are
  /// notified and the recorder is persisted.
  ///
  /// The plan is resolved by [planPayBack] *before* anything is written; a
  /// rejection throws [PaybackRejectedException] having written nothing. The
  /// same two rules are enforced inside `pay_back` by
  /// `20260816010000_payback_on_behalf.sql` for concurrent clients.
  ///
  /// Completes only once the payback AND its balance recalculation have
  /// committed: `pay_back` runs `update_group_member_shares` in the same
  /// transaction (`20261026120000_pay_back_atomic_recalc.sql`), so this method
  /// throws only when nothing was recorded, and retrying after an error never
  /// records the payment twice. A response lost in transit after the server
  /// committed is the one exception: it still surfaces as an error.
  ///
  /// [members] is the group's FULL roster (soft-removed rows included). Every
  /// in-app caller already holds it on the group it is settling, so pass it:
  /// the fallback SELECT costs a round trip on the hot self-settle path and
  /// turns a transient read failure into a failed settle.
  ///
  /// [notifications] sends the push that follows the write.
  Future<void> payBack(
    String groupId,
    String email,
    double amount, {
    String? paidBy,
    List<GroupMember>? members,
    required NotificationSender notifications,
  }) async {
    final recordedBy = _currentUser?.email ?? '';
    final plan = planPayBack(
      paidBy: paidBy,
      paidFor: email,
      amount: amount,
      recordedBy: recordedBy,
      members: members ?? await _members.roster(groupId),
    );

    final PaybackAccepted accepted;
    switch (plan) {
      case PaybackRejected():
        // No write of any kind: the guard is the throw itself.
        throw PaybackRejectedException(plan);
      case PaybackAccepted():
        accepted = plan;
    }

    await _writePayBack(groupId, accepted);
    _notifyPayBack(notifications, groupId, accepted);
  }

  /// The write half of a payback: ONE RPC, `pay_back_exact`, which snaps
  /// `amount` to the exact outstanding value server-side (settle-residue) and
  /// records the payback through `pay_back`. It completes only once the server
  /// has committed. Any failure, a missing function included, is thrown as the
  /// RPC's own error having recorded nothing: there is no client-side
  /// fallback.
  Future<void> _writePayBack(String groupId, PaybackAccepted accepted) async {
    await _payBackRpc(
      'pay_back_exact',
      payBackRpcParams(
        groupId: groupId,
        paidBy: accepted.paidBy,
        paidFor: accepted.paidFor,
        amount: accepted.amount,
      ),
    );
  }

  /// The notify step a single payback and every settle-all group share.
  /// Fire-and-forget: never delays or fails a write that committed. The server
  /// names both parties from the emails and picks the on-behalf copy when the
  /// signed-in recorder is not the payer.
  static void _notifyPayBack(
    NotificationSender notifications,
    String groupId,
    PaybackAccepted accepted,
  ) {
    unawaited(
      notifications.paybackRecorded(
        groupId: groupId,
        receivers: accepted.notificationReceivers,
        amount: accepted.amount,
        paidBy: accepted.paidBy,
        paidFor: accepted.paidFor,
      ),
    );
  }

  /// Which of [groups] a settle-everything-with-[email] run may actually write,
  /// and which it has to leave alone.
  ///
  /// Pure, so the fan-out below is only the *application* of a decision that can
  /// be unit-tested. A group lands in [PayBackAllPlan.skipped] when
  /// [resolvePayback] would reject its payback — which is the same rule
  /// [payBack] enforces, so a skipped group is exactly a group whose write would
  /// have thrown. Checking the whole plan (rather than only the payee's
  /// membership) also covers the mirror case: the **current user** soft-removed
  /// from a shared group, which would otherwise throw `payerNotInGroup` out of
  /// `Future.wait` and abort every group that had not been written yet.
  static PayBackAllPlan resolvePayBackAll({
    required List<Group> groups,
    required String email,
    required String recordedBy,
  }) {
    final settle = <PayBackAllTarget>[];
    final skipped = <String>[];

    for (final group in groups) {
      // Only settle groups where the current user owes this friend, and pay back
      // exactly the per-group amount — not the cross-group total.
      // `amountToSettleWith` is the same value the payment screen shows and
      // applies the same settled predicate, so a balance can never be settled on
      // one path and outstanding on the other.
      final amount = group.amountToSettleWith(email);
      if (amount == null) continue;

      final plan = planPayBack(
        paidFor: email,
        amount: amount,
        recordedBy: recordedBy,
        members: group.groupMembers,
      );
      if (plan is! PaybackAccepted) {
        skipped.add(group.name);
        continue;
      }

      settle.add(
        PayBackAllTarget(
          groupId: group.id,
          groupName: group.name,
          currency: group.currency,
          amount: amount,
          // The plan just resolved: the write and its push need no extra read.
          accepted: plan,
        ),
      );
    }

    return PayBackAllPlan(settle: settle, skipped: skipped);
  }

  /// Settles every active group the current user shares with [email].
  ///
  /// Returns what actually happened. A group whose payback would be rejected —
  /// because [email] or the current user is soft-removed from it — is skipped
  /// rather than written, and is **named in the result** so the caller cannot
  /// report a total as settled when part of it is still outstanding.
  Future<PayBackAllResult> payBackAll(
    String email, {
    required NotificationSender notifications,
  }) async {
    final groupList = await _groups.fetchData("active", paidTo: email);
    return applyPayBackAll(
      resolvePayBackAll(
        groups: groupList,
        email: email,
        recordedBy: _currentUser?.email ?? '',
      ),
      notifications: notifications,
    );
  }

  /// Writes every settled target, each followed by the same notify step a single
  /// payback runs. A failed write sends nothing for its group, does not hold back
  /// the others (Future.wait waits for all), and still fails the run.
  @visibleForTesting
  Future<PayBackAllResult> applyPayBackAll(
    PayBackAllPlan plan, {
    required NotificationSender notifications,
  }) async {
    final write =
        _payBackAllWrite ??
        (PayBackAllTarget t) => _writePayBack(t.groupId, t.accepted);
    await Future.wait(
      plan.settle.map((target) async {
        await write(target);
        _notifyPayBack(notifications, target.groupId, target.accepted);
      }),
    );

    return PayBackAllResult(
      settledGroupNames: [for (final target in plan.settle) target.groupName],
      skippedGroupNames: plan.skipped,
      settledAmounts: sumByCurrency([
        for (final target in plan.settle)
          CurrencyAmount(target.currency, target.amount.abs()),
      ]),
    );
  }
}

@Riverpod(keepAlive: true)
PaybackRepository paybackRepository(Ref ref) => PaybackRepository(
  ref.watch(supabaseClientProvider),
  ref.watch(currentUserProvider),
  groups: ref.watch(groupRepositoryProvider),
  members: ref.watch(memberRepositoryProvider),
);

/// One group a [PaybackRepository.payBackAll] run will settle, with everything
/// that write needs already resolved.
class PayBackAllTarget {
  const PayBackAllTarget({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.amount,
    required this.accepted,
  });

  final String groupId;
  final String groupName;

  /// The group's own currency — the one this per-group write settles in.
  final Currency currency;

  /// The per-group amount, never the cross-group total.
  final double amount;

  /// The payback plan already resolved against the group's full roster: the
  /// write takes its ids and amount, the push its receivers and names.
  final PaybackAccepted accepted;
}

/// Settle-all's per-target write, as one function.
typedef PayBackAllWrite = Future<void> Function(PayBackAllTarget target);

/// One RPC as a payback write issues it: the function name and its argument
/// map.
typedef PaybackRpc =
    Future<Object?> Function(String function, Map<String, dynamic> params);

/// What a settle-everything-with-one-friend run will and will not write, as
/// resolved by [PaybackRepository.resolvePayBackAll].
class PayBackAllPlan {
  const PayBackAllPlan({required this.settle, required this.skipped});

  final List<PayBackAllTarget> settle;

  /// Names of the groups whose payback would be rejected, in roster order.
  final List<String> skipped;
}

/// What a [PaybackRepository.payBackAll] run actually did.
///
/// Each group is settled in ITS OWN currency, so what was paid is a list of
/// per-currency totals, never one merged figure — the confirmation names them
/// all. [skippedGroupNames] stays load-bearing: a single group left unsettled
/// means a "you paid back X" confirmation would be a lie.
class PayBackAllResult {
  const PayBackAllResult({
    required this.settledGroupNames,
    required this.skippedGroupNames,
    this.settledAmounts = const [],
  });

  final List<String> settledGroupNames;
  final List<String> skippedGroupNames;

  /// Total actually settled per currency, primary first. Positive magnitudes.
  final List<CurrencyAmount> settledAmounts;

  /// True when every group that owed something was settled.
  bool get isComplete => skippedGroupNames.isEmpty;
}
