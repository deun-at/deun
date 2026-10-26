import 'dart:async';

import 'package:deun/helper/notification_sender.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records every push as [type, objectId, receivers, title, body].
class _SpyPush {
  final sent = <List<Object>>[];

  Future<void> call(
    String type,
    String objectId,
    Set<String> receivers,
    String title,
    String body,
  ) async {
    sent.add([type, objectId, Set.of(receivers), title, body]);
  }
}

const _ann = 'ann@test.com';
const _bob = 'bob@test.com';

const Map<String, dynamic> _tripRow = {
  'name': 'Trip',
  'currency_code': 'EUR',
  'user_display_name': 'Zoe',
};
const Map<String, dynamic> _dinnerRow = {
  'name': 'Dinner',
  'group_name': 'Trip',
  'group_currency_code': 'EUR',
  'user_display_name': 'Ann',
};

Future<Map<String, dynamic>> _offline(String _) async =>
    throw Exception('offline');

/// Issues [send] from a sender built inside a mounted widget, unmounts that
/// widget, and only then lets the lookup return [row].
Future<_SpyPush> _sendAfterUnmount(
  WidgetTester tester,
  Future<void> Function(NotificationSender sender) send,
  Map<String, dynamic> row,
) async {
  final spy = _SpyPush();
  final lookup = Completer<Map<String, dynamic>>();
  late NotificationSender sender;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          sender = NotificationSender.of(
            context,
            push: spy.call,
            groupRow: (_) => lookup.future,
            expenseRow: (_) => lookup.future,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  final sending = send(sender);
  await tester.pumpWidget(const SizedBox()); // the screen is gone
  lookup.complete(row); // only now does the lookup return
  await sending;
  return spy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    // Same setup as claim_nudge_test.dart: a local, signed-out client so the
    // default sender-name lookup can run. No test here reaches the network —
    // every push goes to a spy.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, Object>{};
            return null;
          },
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  group('a push outlives the screen that issued it', () {
    testWidgets('member added', (tester) async {
      final spy = await _sendAfterUnmount(
        tester,
        (s) => s.memberAdded('g1', {_ann}),
        _tripRow,
      );
      expect(spy.sent, [
        [
          'group',
          'g1',
          {_ann},
          en.groupNotificationTitle('Zoe'),
          en.groupNotificationBody('Trip'),
        ],
      ]);
    });

    testWidgets('payback recorded by the payer', (tester) async {
      final spy = await _sendAfterUnmount(
        tester,
        (s) => s.paybackRecorded(
          groupId: 'g1',
          receivers: {_ann},
          amount: 12.5,
          paidByDisplayName: 'Me',
          paidForDisplayName: 'Ann',
        ),
        _tripRow,
      );
      expect(spy.sent, [
        [
          'group',
          'g1',
          {_ann},
          en.groupPayBackNotificationTitle('Me', 'Trip'),
          en.groupPayBackNotificationBody('EUR 12.50'),
        ],
      ]);
    });

    testWidgets('payment reminder', (tester) async {
      final spy = await _sendAfterUnmount(
        tester,
        (s) => s.paymentReminder('g1', {_ann}, 12.5),
        _tripRow,
      );
      expect(spy.sent, [
        [
          'reminder',
          'g1',
          {_ann},
          en.reminderNotificationTitle('Zoe'),
          en.reminderNotificationBody('EUR 12.50', 'Trip'),
        ],
      ]);
    });

    // The reduce-motion case: the editor pops at Duration.zero, before this
    // lookup returns.
    testWidgets('expense created', (tester) async {
      final spy = await _sendAfterUnmount(
        tester,
        (s) => s.expenseCreated('e1', {_ann, _bob}, 12.5),
        _dinnerRow,
      );
      expect(spy.sent, [
        [
          'expense',
          'e1',
          {_ann, _bob},
          en.expenseNotificationTitle('Ann'),
          en.expenseNotificationBody('Dinner', 'Trip', 'EUR 12.50'),
        ],
      ]);
    });
  });

  group('the kinds without a late lookup send what they send today', () {
    test(
      'a payback recorded on someone\'s behalf names the recorder and both parties',
      () async {
        final spy = _SpyPush();
        await NotificationSender(
          en,
          push: spy.call,
          groupRow: (_) async => _tripRow,
        ).paybackRecorded(
          groupId: 'g1',
          receivers: {_ann, _bob},
          amount: 12.5,
          paidByDisplayName: 'Bob',
          paidForDisplayName: 'Ann',
          recordedByDisplayName: 'Zoe',
        );
        expect(spy.sent, [
          [
            'group',
            'g1',
            {_ann, _bob},
            en.groupPayBackOnBehalfNotificationTitle('Zoe', 'Trip'),
            en.groupPayBackOnBehalfNotificationBody('Bob', 'Ann', 'EUR 12.50'),
          ],
        ]);
      },
    );

    test('claim nudge', () async {
      final spy = _SpyPush();
      await NotificationSender(en, push: spy.call).claimNudge(
        expenseId: 'e1',
        receivers: {_ann, _bob},
        senderDisplayName: 'Ann',
        expenseName: 'Dinner',
        groupName: 'Trip',
      );
      expect(spy.sent, [
        [
          'expense',
          'e1',
          {_ann, _bob},
          en.claimNudgeNotificationTitle('Ann'),
          en.claimNudgeNotificationBody('Dinner', 'Trip'),
        ],
      ]);
    });

    test('friend request carries the sender\'s own display name', () async {
      final spy = _SpyPush();
      await NotificationSender(
        en,
        push: spy.call,
        senderName: () async => 'Ann',
      ).friendRequested({_bob});
      expect(spy.sent, [
        [
          'friendship',
          '',
          {_bob},
          en.friendRequestNotificationTitle,
          en.friendRequestNotificationBody('Ann'),
        ],
      ]);
    });

    test('friend accepted carries the sender\'s own display name', () async {
      final spy = _SpyPush();
      await NotificationSender(
        en,
        push: spy.call,
        senderName: () async => 'Ann',
      ).friendAccepted({_bob});
      expect(spy.sent, [
        [
          'friendship',
          '',
          {_bob},
          en.friendAcceptNotificationTitle,
          en.friendAcceptNotificationBody('Ann'),
        ],
      ]);
    });
  });

  group('amounts are in the group\'s own currency', () {
    test(
      'a JPY group\'s payback, reminder and expense pushes show yen with no minor digits',
      () async {
        final spy = _SpyPush();
        final sender = NotificationSender(
          en,
          push: spy.call,
          groupRow: (_) async => {
            'name': 'Tokyo',
            'currency_code': 'JPY',
            'user_display_name': 'Zoe',
          },
          expenseRow: (_) async => {
            'name': 'Ramen',
            'group_name': 'Tokyo',
            'group_currency_code': 'JPY',
            'user_display_name': 'Ann',
          },
        );
        await sender.paybackRecorded(
          groupId: 'g1',
          receivers: {_ann},
          amount: 3000,
          paidByDisplayName: 'Me',
          paidForDisplayName: 'Ann',
        );
        await sender.paymentReminder('g1', {_ann}, 3000);
        await sender.expenseCreated('e1', {_ann}, 3000);
        expect(spy.sent.map((p) => p[4]), [
          en.groupPayBackNotificationBody('JPY 3,000'),
          en.reminderNotificationBody('JPY 3,000', 'Tokyo'),
          en.expenseNotificationBody('Ramen', 'Tokyo', 'JPY 3,000'),
        ]);
      },
    );

    test(
      'a lookup row with no currency falls back to the default currency',
      () async {
        final spy = _SpyPush();
        final sender = NotificationSender(
          en,
          push: spy.call,
          groupRow: (_) async => {
            'name': 'Trip',
            'currency_code': null,
            'user_display_name': 'Zoe',
          },
          expenseRow: (_) async => {
            'name': 'Dinner',
            'group_name': 'Trip',
            'group_currency_code': null,
            'user_display_name': 'Ann',
          },
        );
        await sender.paymentReminder('g1', {_ann}, 12.5);
        await sender.expenseCreated('e1', {_ann}, 12.5);
        expect(spy.sent.map((p) => p[4]), [
          en.reminderNotificationBody('EUR 12.50', 'Trip'),
          en.expenseNotificationBody('Dinner', 'Trip', 'EUR 12.50'),
        ]);
      },
    );
  });

  test('a German sender\'s expense push is written in German', () async {
    final de = lookupAppLocalizations(const Locale('de'));
    final spy = _SpyPush();
    await NotificationSender(
      de,
      push: spy.call,
      expenseRow: (_) async => _dinnerRow,
    ).expenseCreated('e1', {_ann}, 12.5);
    expect(spy.sent, [
      [
        'expense',
        'e1',
        {_ann},
        de.expenseNotificationTitle('Ann'),
        de.expenseNotificationBody('Dinner', 'Trip', 'EUR 12,50'),
      ],
    ]);
  });

  group('no send ever throws to its caller', () {
    test(
      'a failed lookup sends nothing, for every kind that looks something up',
      () async {
        final spy = _SpyPush();
        final s = NotificationSender(
          en,
          push: spy.call,
          groupRow: _offline,
          expenseRow: _offline,
          senderName: () async => throw Exception('offline'),
        );
        await expectLater(s.memberAdded('g1', {_ann}), completes);
        await expectLater(
          s.paybackRecorded(
            groupId: 'g1',
            receivers: {_ann},
            amount: 12.5,
            paidByDisplayName: 'Me',
            paidForDisplayName: 'Ann',
          ),
          completes,
        );
        await expectLater(s.paymentReminder('g1', {_ann}, 12.5), completes);
        await expectLater(s.expenseCreated('e1', {_ann}, 12.5), completes);
        await expectLater(s.friendRequested({_ann}), completes);
        await expectLater(s.friendAccepted({_ann}), completes);
        expect(spy.sent, isEmpty);
      },
    );

    test('a throwing push function still completes normally', () async {
      final s = NotificationSender(
        en,
        push: (type, objectId, receivers, title, body) async =>
            throw Exception('push down'),
        groupRow: (_) async => _tripRow,
        senderName: () async => 'Ann',
      );
      await expectLater(s.memberAdded('g1', {_ann}), completes);
    });

    // Default sender-name lookup against the signed-out client from setUpAll.
    // Today `currentUser!` throws here.
    test(
      'with nobody signed in, friend request and friend accepted send nothing',
      () async {
        final spy = _SpyPush();
        final s = NotificationSender(en, push: spy.call);
        await expectLater(s.friendRequested({_ann}), completes);
        await expectLater(s.friendAccepted({_ann}), completes);
        expect(spy.sent, isEmpty);
      },
    );
  });

  test(
    'the push body keeps today\'s shape and leaves the signed-in sender out',
    () {
      expect(
        pushRequestBody(
          type: 'expense',
          objectId: 'e1',
          receivers: {'me@test.com', _ann},
          title: 'T',
          body: 'B',
          senderEmail: 'me@test.com',
        ),
        {
          'type': 'INSERT',
          'table': 'expense',
          'record': {
            'type': 'expense',
            'object_id': 'e1',
            'title': 'T',
            'body': 'B',
            'notification_receiver': [_ann],
          },
        },
      );
    },
  );
}
