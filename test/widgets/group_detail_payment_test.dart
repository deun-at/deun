import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail_payment.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _myEmail = 'me@test.com';

GroupMember _member(String email) {
  final m = GroupMember();
  m.groupId = 'g';
  m.email = email;
  m.displayName = email.split('@').first;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

GroupSharesSummary _summary({
  required String displayName,
  required double shareAmount,
  String? paypalMe,
  String? iban,
}) {
  final s = GroupSharesSummary();
  s.displayName = displayName;
  s.shareAmount = shareAmount;
  s.paypalMe = paypalMe;
  s.iban = iban;
  return s;
}

/// A group where the current user owes Sam €30 (PayPal only, no IBAN) and is
/// owed €20 by Priya. Overall the user owes €10.
Group _group() {
  final g = Group();
  g.id = 'g';
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = true;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = [_member(_myEmail), _member('sam@test.com'), _member('priya@test.com')];
  g.groupSharesSummary = {
    'sam@test.com': _summary(displayName: 'Sam', shareAmount: -30.0, paypalMe: 'sam'),
    'priya@test.com': _summary(displayName: 'Priya', shareAmount: 20.0),
  };
  g.totalExpenses = 0;
  g.totalShareAmount = -10.0;
  g.expenses = null;
  return g;
}

/// All balances within the settled epsilon.
Group _settledGroup() {
  final g = _group();
  g.groupSharesSummary = {};
  g.totalShareAmount = 0.0;
  return g;
}

class _FakeGroupDetailNotifier extends GroupDetailNotifier {
  _FakeGroupDetailNotifier(this._group);

  final Group _group;

  @override
  Future<Group> build(String groupId) async => _group;
}

Future<void> _pump(
  WidgetTester tester, {
  required Group group,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupDetailProvider(group.id).overrideWith(() => _FakeGroupDetailNotifier(group)),
      ],
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
            data: getThemeData(context, kBrandSeed, brightness).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(body: GroupPaymentBottomSheet(group: group)),
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
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );
    await Supabase.initialize(url: 'http://localhost:54321', anonKey: 'test-anon-key');
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('hero shows the overall amount', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, group: _group());

    // Overall balance is €10 (user owes), shown in the hero.
    expect(find.text(l10n.balanceOwe), findsOneWidget);
    expect(find.text(l10n.toCurrency(10.0)), findsWidgets);
  });

  testWidgets('you-pay row renders with a Pay action', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, group: _group());

    expect(find.text(l10n.paymentYouPay), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, l10n.paymentPay), findsOneWidget);
  });

  testWidgets('owes-you row renders with a Remind action', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, group: _group());

    expect(find.text(l10n.paymentOwesYou), findsOneWidget);
    expect(find.text('Priya'), findsOneWidget);
    // F59: Remind is a gray tonal pill (no icon), now on the SecondaryButton
    // preset with a surfaceContainer background override.
    expect(find.widgetWithText(SecondaryButton, l10n.paymentRemind), findsOneWidget);
  });

  testWidgets('method-detail sheet shows only methods the payee has (PayPal present, IBAN absent)',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, group: _group());

    await tester.tap(find.widgetWithText(PrimaryButton, l10n.paymentPay));
    await tester.pumpAndSettle();

    // Sam has PayPal but no IBAN → PayPal + Cash cards, no IBAN card.
    expect(find.text(l10n.paymentMethodPaypal), findsOneWidget);
    expect(find.text(l10n.paymentMethodCash), findsOneWidget);
    expect(find.text(l10n.paymentMethodIban), findsNothing);
    // Sticky CTA shows the per-payee amount (€30).
    expect(find.text(l10n.paymentPayAmount(30.0)), findsOneWidget);
  });

  testWidgets('all-settled empty state', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, group: _settledGroup());

    expect(find.text(l10n.paymentAllSettled), findsOneWidget);
    expect(find.text(l10n.paymentYouPay), findsNothing);
    expect(find.text(l10n.paymentOwesYou), findsNothing);
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(tester, group: _group(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Priya'), findsOneWidget);
  });

  testWidgets('sheet uses SheetScaffold (no AppBar) and shows the paymentTitle', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, group: _group());

    // SheetScaffold must be present; AppBar must NOT be present.
    expect(find.byType(SheetScaffold), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    // The title text from SheetScaffold's title row.
    expect(find.text(l10n.paymentTitle), findsOneWidget);
  });

  testWidgets('close button (Icons.close) is present and dismisses the bottom sheet', (tester) async {
    bool dismissed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupDetailProvider(_group().id).overrideWith(() => _FakeGroupDetailNotifier(_group())),
        ],
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
              data: getThemeData(context, kBrandSeed, Brightness.light)
                  .copyWith(splashFactory: NoSplash.splashFactory),
              child: Scaffold(
                body: TextButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => GroupPaymentBottomSheet(group: _group()),
                    ).then((_) => dismissed = true);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the sheet.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Close button must exist inside the sheet.
    final closeBtn = find.widgetWithIcon(IconButton, Icons.close);
    expect(closeBtn, findsOneWidget);

    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Sheet is dismissed: the future resolves and dismissed flips to true.
    expect(dismissed, isTrue);
    // The sheet is gone.
    expect(find.widgetWithIcon(IconButton, Icons.close), findsNothing);
  });
}
