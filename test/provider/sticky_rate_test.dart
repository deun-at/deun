import 'dart:async';
import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:deun/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the platform preference store, plus a hook to make
/// `get_string` resolve late so hydration ordering is observable.
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

  test('an empty store yields no prefill', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(stickyRateProvider.notifier);
    await notifier.hydrated;
    expect(notifier.stickyRate('g1', Currency.chf), isNull);
  });

  test(
    'a set rate is persisted and read back per group AND currency',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(stickyRateProvider.notifier);
      await notifier.setStickyRate('g1', Currency.chf, 0.9432);

      expect(notifier.stickyRate('g1', Currency.chf), 0.9432);
      // Different currency in the same group, and the same currency in another
      // group, are separate slots.
      expect(notifier.stickyRate('g1', Currency.jpy), isNull);
      expect(notifier.stickyRate('g2', Currency.chf), isNull);
      expect(jsonDecode(prefs.values[kStickyRatesPrefKey]!), {
        'g1|CHF': 0.9432,
      });
    },
  );

  test(
    'a stored rate hydrates into a fresh container (survives app restart)',
    () async {
      prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(stickyRateProvider.notifier);
      await notifier.hydrated;
      expect(notifier.stickyRate('g1', Currency.chf), 0.9432);
    },
  );

  test(
    'the FIRST read after app start prefills — hydration is awaited, not raced',
    () async {
      // Reproduces the defect: the editor reads the prefill immediately after
      // the keepAlive provider first builds. Gate get_string so the read cannot
      // possibly have completed by then, and assert the awaited read still sees
      // the stored value.
      prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
      prefs.gate = Completer<void>();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(stickyRateProvider.notifier);
      expect(notifier.stickyRate('g1', Currency.chf), isNull); // not yet

      prefs.gate!.complete();
      await notifier.hydrated;
      expect(notifier.stickyRate('g1', Currency.chf), 0.9432);
    },
  );

  test(
    'a clear issued BEFORE hydration resolves is not resurrected by it',
    () async {
      prefs.values[kStickyRatesPrefKey] = jsonEncode({
        'g1|CHF': 0.9432,
        'g1|JPY': 0.0058,
      });
      prefs.gate = Completer<void>();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(stickyRateProvider.notifier);

      final clearing = notifier.clearStickyRate('g1', Currency.chf);
      prefs.gate!.complete();
      await clearing;

      expect(notifier.stickyRate('g1', Currency.chf), isNull);
      expect(notifier.stickyRate('g1', Currency.jpy), 0.0058);
      expect(jsonDecode(prefs.values[kStickyRatesPrefKey]!), {
        'g1|JPY': 0.0058,
      });
    },
  );

  test(
    'a set issued BEFORE hydration resolves survives it and keeps the stored siblings',
    () async {
      prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|JPY': 0.0058});
      prefs.gate = Completer<void>();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(stickyRateProvider.notifier);

      final setting = notifier.setStickyRate('g1', Currency.chf, 0.95);
      prefs.gate!.complete();
      await setting;

      expect(notifier.stickyRate('g1', Currency.chf), 0.95);
      expect(notifier.stickyRate('g1', Currency.jpy), 0.0058);
    },
  );

  test('a corrupt stored blob is inert, not fatal', () async {
    prefs.values[kStickyRatesPrefKey] = 'not json';
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(stickyRateProvider.notifier);
    await notifier.hydrated;
    expect(notifier.stickyRate('g1', Currency.chf), isNull);
    await notifier.setStickyRate('g1', Currency.chf, 1.1);
    expect(notifier.stickyRate('g1', Currency.chf), 1.1);
  });

  test('the key is namespaced by group and ISO code', () {
    expect(stickyRateKey('g1', Currency.chf), 'g1|CHF');
    expect(stickyRateKey('g1', Currency.jpy), 'g1|JPY');
  });
}
