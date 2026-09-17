import 'dart:async';

import 'package:deun/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the platform preference store, plus a hook to make
/// `get_string` resolve late so hydration ordering is observable. Same shape as
/// `sticky_rate_test.dart`'s — the fee uses the same three channel methods.
class _FakePrefs {
  final Map<String, String> values = {};
  Completer<void>? gate;

  void install() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('async_preferences'), (
          call,
        ) async {
          final args = call.arguments as List;
          switch (call.method) {
            case 'get_string':
              if (gate != null) await gate!.future;
              return values[args[1] as String];
            case 'set_string':
              values[args[1] as String] = args[2] as String;
              return true;
            case 'remove':
              values.remove(args[1] as String);
              return true;
          }
          return null;
        });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePrefs prefs;

  setUp(() {
    prefs = _FakePrefs()..install();
  });

  CardFeeNotifier notifierIn(ProviderContainer container) =>
      container.read(cardFeeProvider.notifier);

  test('an empty store yields no fee', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = notifierIn(container);
    await notifier.hydrated;
    expect(notifier.cardFeePercent, isNull);
  });

  test('a set fee is persisted and read back', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = notifierIn(container);
    await notifier.setCardFeePercent(1.4);

    expect(notifier.cardFeePercent, 1.4);
    expect(prefs.values[kCardFeePrefKey], '1.4');
  });

  // AC: the fee survives an app restart.
  test(
    'a stored fee hydrates into a fresh container (survives app restart)',
    () async {
      prefs.values[kCardFeePrefKey] = '1.4';
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierIn(container);
      await notifier.hydrated;
      expect(notifier.cardFeePercent, 1.4);
    },
  );

  test(
    'the FIRST read after app start sees the stored fee — hydration is awaited',
    () async {
      prefs.values[kCardFeePrefKey] = '1.4';
      prefs.gate = Completer<void>();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierIn(container);
      expect(notifier.cardFeePercent, isNull); // not yet

      prefs.gate!.complete();
      await notifier.hydrated;
      expect(notifier.cardFeePercent, 1.4);
    },
  );

  test(
    'a clear issued BEFORE hydration resolves is not resurrected by it',
    () async {
      prefs.values[kCardFeePrefKey] = '1.4';
      prefs.gate = Completer<void>();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierIn(container);

      final clearing = notifier.clearCardFee();
      prefs.gate!.complete();
      await clearing;

      expect(notifier.cardFeePercent, isNull);
      expect(prefs.values.containsKey(kCardFeePrefKey), isFalse);
    },
  );

  // AC: a fee of 0 is indistinguishable from no fee saved.
  test('a fee of 0 clears the preference rather than storing a zero', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = notifierIn(container);
    await notifier.setCardFeePercent(1.4);
    await notifier.setCardFeePercent(0);

    expect(notifier.cardFeePercent, isNull);
    expect(prefs.values.containsKey(kCardFeePrefKey), isFalse);
  });

  test('a corrupt stored value is inert, not fatal', () async {
    prefs.values[kCardFeePrefKey] = 'not a number';
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = notifierIn(container);
    await notifier.hydrated;
    expect(notifier.cardFeePercent, isNull);
    await notifier.setCardFeePercent(1.4);
    expect(notifier.cardFeePercent, 1.4);
  });
}
