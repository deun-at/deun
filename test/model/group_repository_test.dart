import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/payback_request.dart';

import '../pages/groups/join_group_migration_source.dart';

void main() {
  // -------------------------------------------------------------------------
  // group-member-add-flow: membership is not a group attribute any more —
  // create submits the creator alone, and an edit save submits nothing at
  // all. Adding a member happens on its own, through GroupRepository.addMember
  // (see test/model/member_add_test.dart).
  // -------------------------------------------------------------------------
  group('GroupRepository.resolveSaveMembers', () {
    const me = 'me@test.com';

    // U3-T1
    test('a create submits exactly one row: the creator, and nothing else', () {
      final members = GroupRepository.resolveSaveMembers(
        isCreate: true,
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
          currentUserEmail: null,
        ),
        isEmpty,
      );
      expect(
        GroupRepository.resolveSaveMembers(
          isCreate: true,
          currentUserEmail: '',
        ),
        isEmpty,
        reason: 'never a row with an empty email',
      );
    });

    test(
      'an edit save submits NO members at all: membership is not a group attribute',
      () {
        expect(
          GroupRepository.resolveSaveMembers(
            isCreate: false,
            currentUserEmail: me,
          ),
          isEmpty,
        );
      },
    );
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

    PayBackAllPlan resolve(List<Group> groups) =>
        GroupRepository.resolvePayBackAll(
          groups: groups,
          email: friend,
          recordedBy: me,
        );

    test(
      'an ordinary shared group is settled with its own per-group amount',
      () {
        final plan = resolve([_owingGroup('Trip', owed: 12.5)]);

        expect(plan.skipped, isEmpty);
        expect(plan.settle.single.groupId, 'id-Trip');
        expect(plan.settle.single.groupName, 'Trip');
        expect(plan.settle.single.amount, 12.5);
      },
    );

    test(
      'a group with nothing outstanding is neither settled nor reported',
      () {
        final plan = resolve([_owingGroup('Trip', owed: 0)]);

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
          _owingGroup('Trip'),
          _owingGroup(
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
          _owingGroup(
            'Flat share',
            members: [
              _groupMember(me, 'Me')..removedAt = DateTime.utc(2026, 8, 15),
              _groupMember(friend, 'Ann'),
            ],
          ),
          _owingGroup('Trip'),
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
        _owingGroup('Flat share', members: removedFriend),
        _owingGroup('Ski trip', members: removedFriend),
      ]);

      expect(plan.settle, isEmpty);
      expect(plan.skipped, ['Flat share', 'Ski trip']);
    });
  });

  group('GroupRepository.applyPayBackAll', () {
    const me = 'me@test.com';
    const friend = 'ann@test.com';
    final en = lookupAppLocalizations(const Locale('en'));
    const rows = <String, Map<String, dynamic>>{
      'id-Trip': {
        'name': 'Trip',
        'currency_code': 'EUR',
        'user_display_name': 'Zoe',
      },
      'id-Tokyo': {
        'name': 'Tokyo',
        'currency_code': 'JPY',
        'user_display_name': 'Zoe',
      },
      'id-Flat': {
        'name': 'Flat',
        'currency_code': 'EUR',
        'user_display_name': 'Zoe',
      },
    };

    late List<List<Object>> pushes;
    late List<String> writes;
    late NotificationSender notifications;

    PayBackAllPlan resolve(List<Group> groups) =>
        GroupRepository.resolvePayBackAll(
          groups: groups,
          email: friend,
          recordedBy: me,
        );

    setUp(() {
      pushes = [];
      writes = [];
      notifications = NotificationSender(
        en,
        push: (type, objectId, receivers, title, body) async =>
            pushes.add([type, objectId, Set.of(receivers), title, body]),
        groupRow: (id) async => rows[id]!,
      );
      GroupRepository.payBackAllWriteOverride = (target) async {
        writes.add(target.groupId);
      };
    });

    tearDown(() => GroupRepository.payBackAllWriteOverride = null);

    test(
      'each settled group tells the friend once, with its own amount in its own currency',
      () async {
        await GroupRepository.applyPayBackAll(
          resolve([
            _owingGroup('Trip', owed: 12.5),
            _owingGroup('Tokyo', owed: 3000, currencyCode: 'JPY'),
          ]),
          notifications: notifications,
        );
        await pumpEventQueue();

        expect(writes, unorderedEquals(['id-Trip', 'id-Tokyo']));
        expect(
          pushes,
          unorderedEquals([
            [
              'group',
              'id-Trip',
              {friend, me},
              en.groupPayBackNotificationTitle('Me', 'Trip'),
              en.groupPayBackNotificationBody('EUR 12.50'),
            ],
            [
              'group',
              'id-Tokyo',
              {friend, me},
              en.groupPayBackNotificationTitle('Me', 'Tokyo'),
              en.groupPayBackNotificationBody('JPY 3,000'),
            ],
          ]),
        );
      },
    );

    test(
      'a group whose write throws sends nothing; the others still send and the run still fails',
      () async {
        GroupRepository.payBackAllWriteOverride = (target) async {
          if (target.groupId == 'id-Flat') throw Exception('rpc down');
          writes.add(target.groupId);
        };

        await expectLater(
          GroupRepository.applyPayBackAll(
            resolve([
              _owingGroup('Trip'),
              _owingGroup('Flat'),
              _owingGroup('Tokyo', owed: 3000, currencyCode: 'JPY'),
            ]),
            notifications: notifications,
          ),
          throwsException,
        );
        await pumpEventQueue();

        expect(
          pushes.map((p) => p[1]),
          unorderedEquals(['id-Trip', 'id-Tokyo']),
        );
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

  // -------------------------------------------------------------------------
  // guest-merge-rpc: the join call's name and arguments are the migration's.
  // -------------------------------------------------------------------------
  group('GroupRepository.joinGroupRpcParams', () {
    test(
      'names the function the migration defines and sends exactly its arguments',
      () {
        final sql = joinGroupMigrationSql();
        expect(
          sql,
          contains(
            'create or replace function public.${GroupRepository.joinGroupRpcName}(',
          ),
        );
        final declared = joinGroupDeclaredArgs(sql).toSet();

        expect(
          GroupRepository.joinGroupRpcParams(
            groupId: 'g1',
            guestEmail: 'guest+1@guest.invalid',
          ).keys.toSet(),
          declared,
        );
        expect(
          GroupRepository.joinGroupRpcParams(groupId: 'g1').keys.toSet(),
          declared,
        );

        expect(
          GroupRepository.joinGroupRpcParams(
            groupId: 'g1',
            guestEmail: 'guest+1@guest.invalid',
          ),
          {'_group_id': 'g1', '_guest_email': 'guest+1@guest.invalid'},
        );
        expect(GroupRepository.joinGroupRpcParams(groupId: 'g1'), {
          '_group_id': 'g1',
          '_guest_email': null,
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // group-write-rpcs: the settled threshold travels with the removal.
  // -------------------------------------------------------------------------
  group('GroupRepository.removeMemberRpcParams', () {
    test("sends the settled epsilon of the group's own currency", () {
      expect(
        GroupRepository.removeMemberRpcParams(
          groupId: 'g1',
          email: 'ann@test.com',
          currency: Currency.eur,
        )['_settled_epsilon'],
        0.005,
      );
      expect(
        GroupRepository.removeMemberRpcParams(
          groupId: 'g1',
          email: 'ann@test.com',
          currency: Currency.jpy,
        )['_settled_epsilon'],
        0.5,
      );
    });
  });

  // -------------------------------------------------------------------------
  // group-write-rpcs: the four writes call the migration's functions with
  // exactly its arguments, one rpc each.
  // -------------------------------------------------------------------------
  group('group-write RPC calls', () {
    test(
      'each call names its function and sends exactly its declared arguments, in order',
      () {
        final sql = migrationSqlBySuffix('_group_write_rpcs.sql');
        final calls = <String, Map<String, dynamic>>{
          GroupRepository.addMemberRpcName: GroupRepository.addMemberRpcParams(
            groupId: 'g1',
            email: 'ann@test.com',
          ),
          GroupRepository.removeMemberRpcName:
              GroupRepository.removeMemberRpcParams(
                groupId: 'g1',
                email: 'ann@test.com',
                currency: Currency.eur,
              ),
          GroupRepository.deleteRpcName: GroupRepository.deleteRpcParams('g1'),
          ExpenseRepository.deleteRpcName: ExpenseRepository.deleteRpcParams(
            'e1',
            'g1',
          ),
        };

        expect(calls.keys.toSet(), {
          'add_group_member',
          'remove_group_member',
          'delete_group',
          'delete_expense',
        });
        for (final MapEntry(key: function, value: params) in calls.entries) {
          expect(
            params.keys.toList(),
            declaredArgs(sql, function),
            reason: function,
          );
        }
        // Each value lands on its own argument (no swapped ids).
        expect(calls.values.toList(), [
          {'_group_id': 'g1', '_email': 'ann@test.com'},
          {
            '_group_id': 'g1',
            '_email': 'ann@test.com',
            '_settled_epsilon': 0.005,
          },
          {'_group_id': 'g1'},
          {'_expense_id': 'e1', '_group_id': 'g1'},
        ]);
      },
    );

    test('each of the four writes is one rpc call and no other statement', () {
      String method(String path, String signature) {
        final source = File(path).readAsStringSync().replaceAll('\r\n', '\n');
        final start = source.indexOf(signature);
        expect(start, isNonNegative, reason: signature);
        final end = source.indexOf(
          RegExp(r'\n  (///|static |@)'),
          start + signature.length,
        );
        return source.substring(start, end < 0 ? source.length : end);
      }

      const groups = 'lib/pages/groups/data/group_repository.dart';
      const expenses = 'lib/pages/expenses/data/expense_repository.dart';
      final bodies = {
        'addMemberRpcName': method(
          groups,
          'static Future<MemberAddOutcome> addMember(',
        ),
        'removeMemberRpcName': method(
          groups,
          'static Future<MemberRemovalOutcome> removeMember(',
        ),
        'deleteRpcName (group)': method(groups, 'static Future<void> delete('),
        'deleteRpcName (expense)': method(
          expenses,
          'static Future<void> delete(',
        ),
      };
      for (final MapEntry(key: name, value: body) in bodies.entries) {
        expect('supabase.'.allMatches(body), hasLength(1), reason: name);
        expect(body, contains('supabase.rpc('), reason: name);
        expect(body, contains(name.split(' ').first), reason: name);
      }
    });
  });
}

/// A group in which the current user (`me@test.com`) owes `ann@test.com`
/// [owed], with whichever members are given.
Group _owingGroup(
  String name, {
  double owed = 10,
  List<GroupMember>? members,
  String currencyCode = 'EUR',
}) {
  const me = 'me@test.com';
  const friend = 'ann@test.com';
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

GroupMember _groupMember(String email, String displayName) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = displayName;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}
