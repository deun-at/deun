import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/payback_request.dart';

/// The `group_member` table of ONE group, as the write paths leave it.
///
/// [save] runs the production row resolution — the same
/// [GroupRepository.resolveMemberWrite] `_saveAllLegacy` hands to Supabase, and
/// the same union/dedup `save_group_all` performs server-side — against
/// whatever rows the table already holds, and applies the result. Neither write
/// path ever deletes, so rows only accumulate.
///
/// The point is that the equivalence tests below compare two *sequences of real
/// writes*: nothing here decides which rows survive, it only stores them.
class _FakeGroupMemberTable {
  final Set<String> rows = <String>{};

  void save(List<Map<String, dynamic>> submittedMembers) {
    final write = GroupRepository.resolveMemberWrite(
      groupId: 'g1',
      members: submittedMembers,
      existingEmails: Set<String>.from(rows),
    );
    for (final row in write.inserts) {
      rows.add(row['email'] as String);
    }
    // reAddEmails only clears `removed_at` on rows that are already there —
    // no row is added, and none is removed.
  }
}

/// The per-member balances `update_group_member_shares` derives for the rows a
/// group ended up with: ONE expense of [amount] paid by [paidBy], split evenly
/// across every member row.
///
/// Balances are a function of the `group_member` rows, so two save paths that
/// write the same rows must produce the same balances — and one stray
/// placeholder row would change the split, which is exactly what this has to
/// catch.
Map<String, double> _balancesFor(
  Set<String> memberRows, {
  required String paidBy,
  double amount = 90,
}) {
  final emails = memberRows.toList();
  final share = amount / emails.length;

  final group = Group();
  group.calculateGroupSharesSummarySimplified({
    'group_shares_summary': [
      for (final email in emails)
        {
          'paid_by': paidBy,
          'paid_for': email,
          'share_amount': share,
          'total_expenses': share,
          'total_share_amount': email == paidBy ? amount - share : -share,
          'paid_by_display_name': paidBy.split('@').first,
          'paid_by_paypal_me': null,
          'paid_by_iban': null,
          'paid_for_display_name': email.split('@').first,
          'paid_for_paypal_me': null,
          'paid_for_iban': null,
        },
    ],
  }, paidBy);

  return group.groupSharesSummary.map(
    (email, summary) => MapEntry(email, summary.shareAmount),
  );
}

void main() {
  group('GroupRepository.decodeGroupMembersString', () {
    test('parses valid JSON with multiple members', () {
      const json =
          '[{"email":"a@b.com","display_name":"Alice"},{"email":"c@d.com","display_name":"Bob"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(2));
      expect(result[0]['email'], 'a@b.com');
      expect(result[0]['display_name'], 'Alice');
      expect(result[1]['email'], 'c@d.com');
      expect(result[1]['display_name'], 'Bob');
    });

    test('parses single member', () {
      const json = '[{"email":"solo@test.com","display_name":"Solo"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['email'], 'solo@test.com');
    });

    test('preserves is_guest and is_guest_pending flags', () {
      const json =
          '[{"email":"guest+1@guest.invalid","display_name":"Guest","is_guest":true,"is_guest_pending":false}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result[0]['is_guest'], true);
      expect(result[0]['is_guest_pending'], false);
    });

    test('preserves pending guest entries', () {
      const json =
          '[{"email":"","display_name":"New Guest","is_guest_pending":true}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['is_guest_pending'], true);
      expect(result[0]['display_name'], 'New Guest');
    });

    test('handles members with extra fields gracefully', () {
      const json =
          '[{"email":"a@b.com","display_name":"Alice","some_future_field":"value"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result, hasLength(1));
      expect(result[0]['email'], 'a@b.com');
      expect(result[0]['some_future_field'], 'value');
    });

    test('handles members with missing optional fields', () {
      const json = '[{"email":"a@b.com","display_name":"Alice"}]';

      final result = GroupRepository.decodeGroupMembersString(json);

      expect(result[0]['is_guest'], isNull);
      expect(result[0]['username'], isNull);
    });
  });

  // -------------------------------------------------------------------------
  // group-create-simplify: create submits ONE member row — the creator — and
  // adding the rest through the edit form lands in exactly the same place the
  // old create-with-members flow did.
  // -------------------------------------------------------------------------
  group('GroupRepository.resolveSaveMembers', () {
    const me = 'me@test.com';
    const ann = 'ann@test.com';
    const bob = 'bob@test.com';

    /// The roster the edit form carries once Ann and Bob have been added to a
    /// freshly created group (Group.toJson seeds the creator).
    const rosterJson =
        '[{"email":"me@test.com","display_name":"Me"},'
        '{"email":"ann@test.com","display_name":"Ann"},'
        '{"email":"bob@test.com","display_name":"Bob"}]';

    // U3-T1
    test('a create submits exactly one row: the creator, and nothing else', () {
      final members = GroupRepository.resolveSaveMembers(
        isCreate: true,
        membersJson: null,
        currentUserEmail: me,
      );

      expect(members, [
        {'email': me},
      ]);
      // No placeholder: the old empty-list fallback wrote display_name: ''.
      expect(members.single.containsKey('display_name'), isFalse);
    });

    // U3-T2
    test('a create with no signed-in user submits no row at all', () {
      expect(
        GroupRepository.resolveSaveMembers(
          isCreate: true,
          membersJson: null,
          currentUserEmail: null,
        ),
        isEmpty,
      );
      expect(
        GroupRepository.resolveSaveMembers(
          isCreate: true,
          membersJson: null,
          currentUserEmail: '',
        ),
        isEmpty,
        reason: 'never a row with an empty email',
      );
    });

    // U3-T3
    test('an edit submits exactly the roster the form carries', () {
      final members = GroupRepository.resolveSaveMembers(
        isCreate: false,
        membersJson: rosterJson,
        currentUserEmail: me,
      );

      expect(members.map((m) => m['email']).toList(), [me, ann, bob]);
    });

    // U3-T4
    test('an empty payload never becomes a placeholder member row', () {
      expect(GroupRepository.decodeGroupMembersString(null), isEmpty);
      expect(GroupRepository.decodeGroupMembersString('[]'), isEmpty);
      expect(
        GroupRepository.resolveSaveMembers(
          isCreate: false,
          membersJson: null,
          currentUserEmail: me,
        ),
        isEmpty,
      );
    });

    /// OLD flow: create carried the members, so ONE write submitted all three
    /// at once (that is `decodeGroupMembersString` on the create form value)
    /// into an empty group.
    _FakeGroupMemberTable oldFlow() {
      return _FakeGroupMemberTable()
        ..save(GroupRepository.decodeGroupMembersString(rosterJson));
    }

    /// NEW flow: the create write submits the creator alone, then the edit save
    /// submits the roster the member form carries — which still contains the
    /// creator. Two writes, and the second one runs against the row the first
    /// one left behind.
    _FakeGroupMemberTable newFlow() {
      return _FakeGroupMemberTable()
        ..save(
          GroupRepository.resolveSaveMembers(
            isCreate: true,
            membersJson: null,
            currentUserEmail: me,
          ),
        )
        ..save(
          GroupRepository.resolveSaveMembers(
            isCreate: false,
            membersJson: rosterJson,
            currentUserEmail: me,
          ),
        );
    }

    // U3-T5 — criterion 5 (rows)
    test('create-then-add-in-edit writes the same group_member rows as the old '
        'create-with-members flow', () {
      final oldRows = oldFlow().rows;
      final newRows = newFlow().rows;

      expect(newRows, oldRows);
      expect(newRows, {me, ann, bob});
      expect(
        newRows,
        isNot(contains('')),
        reason: 'no empty-email placeholder row is ever written',
      );
    });

    // U3-T5b — the creator is written ONCE, by the create write; the edit save
    // that follows resubmits them and must add no second row.
    test(
      'the edit save re-submits the creator without duplicating their row',
      () {
        final table = _FakeGroupMemberTable()
          ..save(
            GroupRepository.resolveSaveMembers(
              isCreate: true,
              membersJson: null,
              currentUserEmail: me,
            ),
          );
        expect(table.rows, {me});

        final editWrite = GroupRepository.resolveMemberWrite(
          groupId: 'g1',
          members: GroupRepository.resolveSaveMembers(
            isCreate: false,
            membersJson: rosterJson,
            currentUserEmail: me,
          ),
          existingEmails: Set<String>.from(table.rows),
        );

        expect(
          editWrite.inserts.map((row) => row['email']).toList(),
          [ann, bob],
          reason: 'only the members the group does not have yet are inserted',
        );
        expect(
          editWrite.reAddEmails,
          [me],
          reason: "the creator's existing row is kept, never inserted twice",
        );
      },
    );

    // U3-T6 — criterion 5 (balances)
    test('...and the same balances', () {
      final oldBalances = _balancesFor(oldFlow().rows, paidBy: me);
      final newBalances = _balancesFor(newFlow().rows, paidBy: me);

      expect(newBalances, oldBalances);
      // 90 paid by me, split three ways: each of the other two owes me 30.
      expect(oldBalances, {ann: 30.0, bob: 30.0});
    });
  });

  // -------------------------------------------------------------------------
  // group-create-simplify: members reach a group through the EDIT save now, so
  // that is the save that has to notify them.
  // -------------------------------------------------------------------------
  group('GroupRepository.resolveNotificationReceivers', () {
    const me = 'me@test.com';
    const ann = 'ann@test.com';
    const bob = 'bob@test.com';

    test('notifies only the members this save actually adds', () {
      expect(
        GroupRepository.resolveNotificationReceivers(
          members: [
            {'email': me},
            {'email': ann},
            {'email': bob},
          ],
          existingEmails: {me, ann},
        ),
        {bob},
      );
    });

    test('a create submits the creator alone, so nobody is left to notify', () {
      // sendNotification strips the current user from every receiver set, so a
      // receiver set that is only ever the creator can never reach anybody.
      expect(
        GroupRepository.resolveNotificationReceivers(
          members: GroupRepository.resolveSaveMembers(
            isCreate: true,
            membersJson: null,
            currentUserEmail: me,
          ),
          existingEmails: const <String>{},
        ),
        {me},
        reason:
            'the diff itself is the creator — saveAll skips the create call '
            'rather than invoking the push function with an empty receiver list',
      );
    });

    test(
      'guests and pending guests are never notified: they have no device',
      () {
        expect(
          GroupRepository.resolveNotificationReceivers(
            members: [
              {'email': ann},
              {'email': 'guest@test.com', 'is_guest': true},
              {'display_name': 'Zoe', 'is_guest_pending': true},
              {'email': ''},
            ],
            existingEmails: const <String>{},
          ),
          {ann},
        );
      },
    );

    test('a member re-added after removal is notified again', () {
      // _activeMemberEmails counts only rows with removed_at == null, so a
      // soft-removed member reads as new — coming back IS being added.
      expect(
        GroupRepository.resolveNotificationReceivers(
          members: [
            {'email': me},
            {'email': ann},
          ],
          existingEmails: {me},
        ),
        {ann},
      );
    });
  });

  group('active/done balance filter', () {
    test('is built from the shared epsilon, not a literal', () {
      expect(
        GroupRepository.activeBalanceFilter,
        'total_share_amount.gte.0.005,total_share_amount.lte.-0.005',
      );
      expect(kSettledEpsilon, 0.005);
    });

    test('the tab threshold and the client predicate agree on 0.007', () {
      // 0.007 is >= the filter's 0.005 bound, so the group stays on the active
      // tab — and isSettled(0.007) is false, so every screen agrees with it.
      expect(isSettled(0.007, Currency.eur), isFalse);
      expect(GroupRepository.activeBalanceFilter, contains('gte.0.005'));
    });

    test('the query bounds bracket every supported currency', () {
      // The predicates cannot see a row's currency, so they must be a superset:
      // the active bound is the SMALLEST supported epsilon and the done bound
      // the LARGEST. narrowToStatus makes the real decision per row.
      for (final c in kSupportedCurrencies) {
        expect(
          c.settledEpsilon,
          inInclusiveRange(kSettledEpsilon, kMaxSettledEpsilon),
          reason: c.code,
        );
      }
      expect(kMaxSettledEpsilon, Currency.jpy.settledEpsilon);
      expect(kMaxSettledEpsilon, 0.5);
    });
  });

  // ---------------------------------------------------------------------------
  // multi-currency-core review: the server predicate is pinned to EUR, so the
  // per-currency decision has to happen on the client — otherwise a 0-decimal
  // group with |net| in [0.005, 0.5) renders a settled ¥0 hero while still
  // counting as active.
  // ---------------------------------------------------------------------------
  group('GroupRepository.narrowToStatus', () {
    Group g(String id, double net, String code) {
      final group = Group();
      group.id = id;
      group.name = id;
      group.colorValue = 0xFF5750E6;
      group.simplifiedExpenses = true;
      group.createdAt = '';
      group.userId = null;
      group.currencyCode = code;
      group.groupMembers = [];
      group.groupSharesSummary = {};
      group.totalExpenses = 0;
      group.totalShareAmount = net;
      group.expenses = null;
      return group;
    }

    List<String> ids(List<Group> groups) => [for (final x in groups) x.id];

    test('a sub-yen JPY balance is settled, so it is not active', () {
      final groups = [g('jpy-residue', 0.3, 'JPY'), g('jpy-real', 3, 'JPY')];
      expect(ids(GroupRepository.narrowToStatus(groups, 'active')), [
        'jpy-real',
      ]);
    });

    test('the same 0.3 balance IS active in EUR', () {
      final groups = [g('eur', 0.3, 'EUR')];
      expect(ids(GroupRepository.narrowToStatus(groups, 'active')), ['eur']);
    });

    test('done is the exact complement, per currency', () {
      final groups = [
        g('jpy-residue', 0.3, 'JPY'),
        g('jpy-real', -3, 'JPY'),
        g('eur-residue', 0.004, 'EUR'),
        g('eur-real', 0.007, 'EUR'),
      ];
      expect(ids(GroupRepository.narrowToStatus(groups, 'done')), [
        'jpy-residue',
        'eur-residue',
      ]);
      expect(ids(GroupRepository.narrowToStatus(groups, 'active')), [
        'jpy-real',
        'eur-real',
      ]);
    });

    test('EUR groups are unaffected — every existing caller passes EUR', () {
      final groups = [
        g('a', 0, 'EUR'),
        g('b', 12.5, 'EUR'),
        g('c', -0.004, 'EUR'),
      ];
      expect(ids(GroupRepository.narrowToStatus(groups, 'active')), ['b']);
      expect(ids(GroupRepository.narrowToStatus(groups, 'done')), ['a', 'c']);
    });

    test('an unrecognised filter (e.g. "all") passes everything through', () {
      final groups = [g('a', 0, 'JPY'), g('b', 0.3, 'JPY')];
      expect(ids(GroupRepository.narrowToStatus(groups, 'all')), ['a', 'b']);
    });

    test('it agrees with the hero: narrowed-out means isSettled', () {
      final residue = g('jpy-residue', 0.3, 'JPY');
      expect(GroupRepository.narrowToStatus([residue], 'active'), isEmpty);
      expect(isSettled(residue.totalShareAmount, residue.currency), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // payback-on-behalf: `paidBy` defaults to the current user, and that default
  // must leave the RPC call exactly as it was before the parameter existed.
  // -------------------------------------------------------------------------
  group('GroupRepository.payBackRpcParams', () {
    // 16
    test('the self-payback path sends exactly what it sent before', () {
      expect(
        GroupRepository.payBackRpcParams(
          groupId: 'g1',
          paidBy: 'me@test.com',
          paidFor: 'ann@test.com',
          amount: 12.5,
        ),
        {
          '_group_id': 'g1',
          '_paid_by': 'me@test.com',
          '_paid_for': 'ann@test.com',
          '_amount': 12.5,
        },
      );
    });

    // 17
    test('recording on behalf changes _paid_by and nothing else', () {
      final mine = GroupRepository.payBackRpcParams(
        groupId: 'g1',
        paidBy: 'me@test.com',
        paidFor: 'bob@test.com',
        amount: 12.5,
      );
      final onBehalf = GroupRepository.payBackRpcParams(
        groupId: 'g1',
        paidBy: 'ann@test.com',
        paidFor: 'bob@test.com',
        amount: 12.5,
      );

      expect(onBehalf['_paid_by'], 'ann@test.com');
      expect(
        Map<String, dynamic>.of(onBehalf)..remove('_paid_by'),
        Map<String, dynamic>.of(mine)..remove('_paid_by'),
      );
    });

    // 18
    test('the argument names are the four both RPCs declare, in order', () {
      // pay_back_exact(_group_id, _paid_by, _paid_for, _amount) delegates to
      // pay_back with the same four, so one map serves both call sites.
      expect(
        GroupRepository.payBackRpcParams(
          groupId: 'g1',
          paidBy: 'a@test.com',
          paidFor: 'b@test.com',
          amount: 1,
        ).keys.toList(),
        ['_group_id', '_paid_by', '_paid_for', '_amount'],
      );
    });
  });

  // `payBackRpcParams` only proves the map's shape — it is handed whatever the
  // caller decided. The DEFAULT itself lives in `planPayBack`, which is the
  // single place `payBack` gets its payer from, so it is asserted here.
  group('GroupRepository.planPayBack', () {
    final roster = [
      _groupMember('me@test.com', 'Me'),
      _groupMember('ann@test.com', 'Ann'),
      _groupMember('bob@test.com', 'Bob'),
    ];

    // 44 — criterion: the self-payback path sends byte-identical params.
    test('omitting paidBy makes the signed-in user the payer', () {
      final plan =
          GroupRepository.planPayBack(
                paidFor: 'ann@test.com',
                amount: 12.5,
                recordedBy: 'me@test.com',
                members: roster,
              )
              as PaybackAccepted;

      expect(plan.paidBy, 'me@test.com');
      expect(plan.isOnBehalf, isFalse);
      // What `payBack` sends for that plan — exactly the pre-feature call.
      expect(
        GroupRepository.payBackRpcParams(
          groupId: 'g1',
          paidBy: plan.paidBy,
          paidFor: plan.paidFor,
          amount: plan.amount,
        ),
        {
          '_group_id': 'g1',
          '_paid_by': 'me@test.com',
          '_paid_for': 'ann@test.com',
          '_amount': 12.5,
        },
      );
    });

    // 45 — an explicit payer is the only thing that moves `_paid_by`.
    test('an explicit paidBy overrides the default and nothing else', () {
      final plan =
          GroupRepository.planPayBack(
                paidBy: 'ann@test.com',
                paidFor: 'bob@test.com',
                amount: 12.5,
                recordedBy: 'me@test.com',
                members: roster,
              )
              as PaybackAccepted;

      expect(plan.paidBy, 'ann@test.com');
      expect(plan.recordedBy, 'me@test.com');
      expect(plan.isOnBehalf, isTrue);
      expect(
        GroupRepository.payBackRpcParams(
          groupId: 'g1',
          paidBy: plan.paidBy,
          paidFor: plan.paidFor,
          amount: plan.amount,
        )['_paid_by'],
        'ann@test.com',
      );
    });

    // 46 — the default is not a bypass: it goes through the same guard.
    test('the defaulted payer is still validated', () {
      expect(
        GroupRepository.planPayBack(
          paidFor: 'me@test.com',
          amount: 12.5,
          recordedBy: 'me@test.com',
          members: roster,
        ),
        isA<PaybackRejected>().having(
          (r) => r.reason,
          'reason',
          PaybackRejection.samePerson,
        ),
      );
      expect(
        GroupRepository.planPayBack(
          paidFor: 'ann@test.com',
          amount: 12.5,
          recordedBy: 'zoe@test.com',
          members: roster,
        ),
        isA<PaybackRejected>().having(
          (r) => r.reason,
          'reason',
          PaybackRejection.payerNotInGroup,
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // payback-on-behalf review: `payBackAll` settles a CROSS-GROUP total, so a
  // group it cannot write must neither abort the run nor be reported as paid.
  // ---------------------------------------------------------------------------
  group('GroupRepository.resolvePayBackAll', () {
    const me = 'me@test.com';
    const friend = 'ann@test.com';

    /// A group in which the current user owes [friend] [owed], with whichever
    /// members are given.
    Group group(
      String name, {
      double owed = 10,
      List<GroupMember>? members,
      String currencyCode = 'EUR',
    }) {
      final g = Group();
      g.id = 'id-$name';
      g.name = name;
      g.currencyCode = currencyCode;
      g.groupMembers =
          members ?? [_groupMember(me, 'Me'), _groupMember(friend, 'Ann')];
      final summary = GroupSharesSummary();
      summary.displayName = 'Ann';
      summary.shareAmount = -owed;
      g.groupSharesSummary = {friend: summary};
      return g;
    }

    PayBackAllPlan resolve(List<Group> groups) =>
        GroupRepository.resolvePayBackAll(
          groups: groups,
          email: friend,
          recordedBy: me,
        );

    test(
      'an ordinary shared group is settled with its own per-group amount',
      () {
        final plan = resolve([group('Trip', owed: 12.5)]);

        expect(plan.skipped, isEmpty);
        expect(plan.settle.single.groupId, 'id-Trip');
        expect(plan.settle.single.groupName, 'Trip');
        expect(plan.settle.single.amount, 12.5);
      },
    );

    test(
      'a group with nothing outstanding is neither settled nor reported',
      () {
        final plan = resolve([group('Trip', owed: 0)]);

        expect(plan.settle, isEmpty);
        expect(plan.skipped, isEmpty);
      },
    );

    // The friend was soft-removed from one shared group. That group cannot be
    // written — but the run must still settle the others AND name this one, or
    // the friend sheet confirms the full cross-group total as paid.
    test(
      'a group whose payee is soft-removed is skipped by name, not settled',
      () {
        final plan = resolve([
          group('Trip'),
          group(
            'Flat share',
            members: [
              _groupMember(me, 'Me'),
              _groupMember(friend, 'Ann')
                ..removedAt = DateTime.utc(2026, 8, 15),
            ],
          ),
        ]);

        expect(plan.settle.map((t) => t.groupName), ['Trip']);
        expect(plan.skipped, ['Flat share']);
      },
    );

    // The mirror case: the CURRENT USER is the one who was removed. The payer
    // check used to be missing, so this threw `payerNotInGroup` out of
    // `Future.wait` and aborted the whole multi-group settle behind a generic
    // error — after earlier groups had already been written.
    test(
      'a group the current user was removed from is skipped, not thrown',
      () {
        final plan = resolve([
          group(
            'Flat share',
            members: [
              _groupMember(me, 'Me')..removedAt = DateTime.utc(2026, 8, 15),
              _groupMember(friend, 'Ann'),
            ],
          ),
          group('Trip'),
        ]);

        expect(plan.settle.map((t) => t.groupName), ['Trip']);
        expect(plan.skipped, ['Flat share']);
      },
    );

    test('every skipped group is named, so none can be silently dropped', () {
      final removedFriend = [
        _groupMember(me, 'Me'),
        _groupMember(friend, 'Ann')..removedAt = DateTime.utc(2026, 8, 15),
      ];
      final plan = resolve([
        group('Flat share', members: removedFriend),
        group('Ski trip', members: removedFriend),
      ]);

      expect(plan.settle, isEmpty);
      expect(plan.skipped, ['Flat share', 'Ski trip']);
    });

    test(
      'the roster is handed to the write, so payBack needs no extra read',
      () {
        final plan = resolve([group('Trip')]);

        expect(plan.settle.single.members.map((m) => m.email), [me, friend]);
      },
    );
  });

  group('PayBackAllResult', () {
    test('a run with no skipped group is complete', () {
      expect(
        const PayBackAllResult(
          settledGroupNames: ['Trip'],
          skippedGroupNames: [],
        ).isComplete,
        isTrue,
      );
    });

    test('a run that skipped anything is not complete', () {
      expect(
        const PayBackAllResult(
          settledGroupNames: ['Trip'],
          skippedGroupNames: ['Flat share'],
        ).isComplete,
        isFalse,
      );
    });
  });

  group('PayBackAllResult per-currency amounts', () {
    const me = 'me@test.com';
    const friend = 'ann@test.com';

    Group group(
      String name, {
      double owed = 10,
      List<GroupMember>? members,
      String currencyCode = 'EUR',
    }) {
      final g = Group();
      g.id = 'id-$name';
      g.name = name;
      g.currencyCode = currencyCode;
      g.groupMembers =
          members ?? [_groupMember(me, 'Me'), _groupMember(friend, 'Ann')];
      final summary = GroupSharesSummary();
      summary.displayName = 'Ann';
      summary.shareAmount = -owed;
      g.groupSharesSummary = {friend: summary};
      return g;
    }

    PayBackAllPlan resolve(List<Group> groups) =>
        GroupRepository.resolvePayBackAll(
          groups: groups,
          email: friend,
          recordedBy: me,
        );

    test('a plan carries each group\'s own currency', () {
      final plan = resolve([
        group('Flat', owed: 25.50),
        group('Tokyo', owed: 3000, currencyCode: 'JPY'),
      ]);
      expect(plan.settle.map((t) => t.currency).toList(), [
        Currency.eur,
        Currency.jpy,
      ]);
      expect(plan.settle.map((t) => t.amount).toList(), [25.50, 3000]);
    });

    test('the result names per-currency totals, never one merged figure', () {
      final amounts = sumByCurrency(const [
        CurrencyAmount(Currency.eur, 25.50),
        CurrencyAmount(Currency.jpy, 3000),
        CurrencyAmount(Currency.eur, 4.50),
      ]);
      final result = PayBackAllResult(
        settledGroupNames: const ['Flat', 'Tokyo', 'Ski'],
        skippedGroupNames: const [],
        settledAmounts: amounts,
      );
      expect(
        formatCurrencyAmounts(result.settledAmounts, const Locale('en')),
        'JPY 3,000 + EUR 30.00',
      );
      expect(result.isComplete, isTrue);
    });

    test('a single-currency settle formats exactly as before', () {
      final result = PayBackAllResult(
        settledGroupNames: const ['Flat'],
        skippedGroupNames: const [],
        settledAmounts: sumByCurrency(const [
          CurrencyAmount(Currency.eur, 25.50),
        ]),
      );
      expect(
        formatCurrencyAmounts(result.settledAmounts, const Locale('en')),
        'EUR 25.50',
      );
    });
  });
}

GroupMember _groupMember(String email, String displayName) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = displayName;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}
