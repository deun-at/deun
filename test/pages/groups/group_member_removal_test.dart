import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:deun/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// No flutter_localizations import: AppLocalizations.localizationsDelegates already
// bundles the Global*Localizations delegates, and an unused import fails analyze.

/// Acceptance tests for group-member-removal (model + read-path halves). Every
/// assertion restates an acceptance criterion from the plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

  Map<String, dynamic> memberJson(
    String email,
    String name, {
    String? removedAt,
  }) => {
    'group_id': 'g1',
    'email': email,
    'display_name': name,
    'username': null,
    'username_code': null,
    'is_guest': false,
    'is_favorite': false,
    'removed_at': ?removedAt,
  };

  Map<String, dynamic> groupJson({String? carolRemovedAt}) => {
    'id': 'g1',
    'name': 'Trip',
    'color_value': 0xFF000000,
    'simplified_expenses': false,
    'created_at': '',
    'user_id': null,
    'currency_code': 'EUR',
    'group_member': [
      memberJson('a@test.com', 'Alice'),
      memberJson('b@test.com', 'Bob'),
      memberJson('c@test.com', 'Carol', removedAt: carolRemovedAt),
    ],
    'group_shares_summary': const [],
  };

  group('GroupMember.removedAt / isRemoved', () {
    // 12
    test('a removed_at timestamp parses and marks the member removed', () {
      final m = GroupMember()
        ..loadDataFromJson(
          memberJson('c@test.com', 'Carol', removedAt: '2026-08-15T09:30:00Z'),
        );

      expect(m.removedAt, DateTime.parse('2026-08-15T09:30:00Z'));
      expect(m.isRemoved, isTrue);
    });

    // 13
    test('a row without removed_at is an active member', () {
      final m = GroupMember()
        ..loadDataFromJson(memberJson('a@test.com', 'Alice'));

      expect(m.removedAt, isNull);
      expect(m.isRemoved, isFalse);
    });

    // 14
    test('an explicit null removed_at is an active member', () {
      final m = GroupMember()
        ..loadDataFromJson({
          ...memberJson('a@test.com', 'Alice'),
          'removed_at': null,
        });

      expect(m.isRemoved, isFalse);
    });

    // 15
    test(
      'removed_at round-trips through toJson (and stays null when unset)',
      () {
        final removed = GroupMember()
          ..loadDataFromJson(
            memberJson(
              'c@test.com',
              'Carol',
              removedAt: '2026-08-15T09:30:00Z',
            ),
          );
        final active = GroupMember()
          ..loadDataFromJson(memberJson('a@test.com', 'Alice'));

        expect(
          DateTime.parse(removed.toJson()['removed_at'] as String),
          DateTime.parse('2026-08-15T09:30:00Z'),
        );
        expect(active.toJson()['removed_at'], isNull);
      },
    );

    // 16
    test(
      'groupSelectString fetches whole group_member rows, so removed_at arrives',
      () {
        // The column rides in on the `*`. If the select is ever narrowed to named
        // columns, removed_at must be listed explicitly or every member reads active.
        expect(Group.groupSelectString, contains('group_member(*'));
      },
    );
  });

  group('read-path filtering', () {
    // 17
    test('activeMembers drops a removed member and keeps the rest', () {
      final g = Group()
        ..loadDataFromJson(groupJson(carolRemovedAt: '2026-08-15T09:30:00Z'));

      expect(g.activeMembers.map((m) => m.email), ['a@test.com', 'b@test.com']);
    });

    // 18
    test(
      'a removed member stays in groupMembers, so the ledger and the balance list keep them',
      () {
        final g = Group()
          ..loadDataFromJson(groupJson(carolRemovedAt: '2026-08-15T09:30:00Z'));

        expect(g.groupMembers.map((m) => m.email), contains('c@test.com'));
        expect(
          g.groupMembers.firstWhere((m) => m.email == 'c@test.com').isRemoved,
          isTrue,
        );

        // Nothing filters group_shares_summary by removal status. Seed a real
        // summary row (Alice paid for Carol) and compute it directly for
        // Alice as the current user — Carol's balance row must still be a
        // key, proving the summary survives removal untouched. This is the
        // criterion the migration's semi-join protects.
        g.calculateGroupSharesSummaryDefault({
          'group_shares_summary': [
            {
              'paid_by': 'a@test.com',
              'paid_for': 'c@test.com',
              'share_amount': 15.0,
              'total_expenses': 15.0,
              'total_share_amount': 15.0,
              'paid_by_display_name': 'Alice',
              'paid_by_paypal_me': null,
              'paid_by_iban': null,
              'paid_for_display_name': 'Carol',
              'paid_for_paypal_me': null,
              'paid_for_iban': null,
            },
          ],
        }, 'a@test.com');

        expect(g.groupSharesSummary.keys, contains('c@test.com'));
        expect(g.groupSharesSummary['c@test.com']!.shareAmount, 15.0);
      },
    );

    // 20
    testWidgets(
      'the paid-by picker fed activeMembers omits the removed member',
      (tester) async {
        final g = Group()
          ..loadDataFromJson(groupJson(carolRemovedAt: '2026-08-15T09:30:00Z'));

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ThemeBuilder(
              colorValue: kBrandSeed.toARGB32(),
              builder: (context) => Scaffold(
                body: PaidBySheet(
                  members: g.activeMembers,
                  selectedEmail: 'a@test.com',
                  currentUserEmail: null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scoped to the row's *title*, not a bare Text lookup: PaidBySheet's
        // subtitle falls back to displayName when a member has no username, so
        // "Alice" would otherwise match both the title and the subtitle Text
        // (and find.widgetWithText double-counts the shared ListTile ancestor
        // in that case).
        bool hasTitle(Widget w, String text) =>
            w is ListTile && w.title is Text && (w.title as Text).data == text;

        expect(
          find.byWidgetPredicate((w) => hasTitle(w, 'Alice')),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) => hasTitle(w, 'Bob')),
          findsOneWidget,
        );
        expect(find.text('Carol'), findsNothing);
      },
    );
  });
}
