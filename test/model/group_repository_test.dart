import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/group_model.dart';

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
      expect(isSettled(0.007), isFalse);
      expect(GroupRepository.activeBalanceFilter, contains('gte.0.005'));
    });
  });
}
