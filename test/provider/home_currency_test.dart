import 'package:deun/helper/helper.dart';
import 'package:deun/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acceptance tests for the home-currency preference (multi-currency-home-
/// aggregates): default EUR, only curated codes accepted, and the choice is
/// written to persistent storage so it survives an app restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    // AsyncPreferences talks over its own `async_preferences` channel (methods
    // like get_string / set_string), not the shared_preferences channel.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('async_preferences'), (
          call,
        ) async {
          calls.add(call);
          if (call.method.startsWith('get')) return null;
          return true;
        });
  });

  test('defaults to EUR', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(homeCurrencyProvider), 'EUR');
    expect(kDefaultCurrencyCode, 'EUR');
  });

  test('setHomeCurrency accepts a curated code and persists it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(homeCurrencyProvider.notifier).setHomeCurrency('USD');

    expect(container.read(homeCurrencyProvider), 'USD');
    // Persisted (written to storage) so the choice survives a restart.
    expect(calls.any((c) => c.method.toLowerCase().contains('set')), isTrue);
  });

  test('setHomeCurrency rejects codes outside the curated list', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(homeCurrencyProvider.notifier).setHomeCurrency('XYZ');

    expect(container.read(homeCurrencyProvider), 'EUR');
  });
}
