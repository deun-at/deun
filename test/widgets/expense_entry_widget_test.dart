import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:deun/pages/expenses/presentation/expense_entry_widget.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/stepper_control.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

GroupMember _member(String email, String name) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  String? initialAmount = '12.00',
}) async {
  final members = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  final entry = ExpenseEntry(index: 0);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(context, kBrandSeed, brightness)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(
              body: SingleChildScrollView(
                child: FormBuilder(
                  child: ExpenseEntryWidget(
                    expenseEntry: entry,
                    index: 0,
                    onRemove: () {},
                    groupMembers: members,
                    initialAmount: initialAmount,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
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

  testWidgets('renders the 3-way SplitMode segmented control', (tester) async {
    await _pump(tester);
    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
  });

  testWidgets('renders an allocation ProgressBar and member avatars', (tester) async {
    await _pump(tester);
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.byType(MemberAvatar), findsNWidgets(2));
  });

  testWidgets('switching to Parts mode shows steppers', (tester) async {
    await _pump(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // No steppers in default (amount) mode.
    expect(find.byType(StepperControl), findsNothing);

    await tester.tap(find.text(l10n.splitModeShares));
    await tester.pumpAndSettle();

    expect(find.byType(StepperControl), findsNWidgets(2));
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
