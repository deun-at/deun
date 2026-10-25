// realtime-channel-lifecycle: the RealtimeNotifierMixin lifecycle rules. One
// live channel per config, at most one pending retry, and nothing reaching a
// disposed notifier. Driven through a minimal notifier shaped like the app's
// mixin users, with channels from FakeRealtimeChannelFactory and time under
// fake_async.

import 'package:deun/helper/realtime_mixin.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_realtime_channel_factory.dart';

/// What the probe notifier's callbacks received.
class _Probe {
  _Probe({required this.channelNames, this.presencePayload});

  final List<String> channelNames;
  final Map<String, dynamic>? presencePayload;
  final List<String> events = [];
  final List<int> presence = [];
}

/// Shaped like the app's mixin users: disposes channels at the top of build
/// and on dispose, subscribes one config per name, listens for resume. Its
/// callbacks write state / notify listeners like the real notifiers, so a
/// callback that reaches it after dispose throws UnmountedRefException.
class _ProbeNotifier extends Notifier<int> with RealtimeNotifierMixin {
  _ProbeNotifier(this.probe);

  final _Probe probe;

  @override
  int build() {
    disposeChannels();
    ref.onDispose(disposeChannels);
    for (final name in probe.channelNames) {
      subscribeToChannel(
        ref: ref,
        channelName: name,
        table: 'probe_table',
        onEvent: (_) {
          probe.events.add(name);
          state = state + 1;
        },
        presencePayload: probe.presencePayload,
        onPresence: probe.presencePayload == null
            ? null
            : (count) {
                probe.presence.add(count);
                ref.notifyListeners();
              },
      );
    }
    listenForResume(ref: ref, onResume: () {});
    return 0;
  }

  /// Drives [syncInFilterChannels] under the prefix `probe_scope`.
  void syncScope(Set<String> values) => syncInFilterChannels(
    ref: ref,
    prefix: 'probe_scope',
    table: 'probe_table',
    column: 'id',
    values: values,
    onEvent: (_) {},
  );
}

/// One mounted probe notifier on its own container, under [async].
class _Harness {
  _Harness(
    this.async, {
    List<String> channelNames = const ['probe:a'],
    Map<String, dynamic>? presencePayload,
  }) : probe = _Probe(
         channelNames: channelNames,
         presencePayload: presencePayload,
       ) {
    provider = NotifierProvider.autoDispose<_ProbeNotifier, int>(
      () => _ProbeNotifier(probe),
    );
    container = ProviderContainer.test(
      overrides: [realtimeChannelFactoryProvider.overrideWithValue(channels)],
    );
    _sub = container.listen(provider, (_, _) {});
    async.elapse(Duration.zero);
  }

  final FakeAsync async;
  final _Probe probe;
  final FakeRealtimeChannelFactory channels = FakeRealtimeChannelFactory();
  late final NotifierProvider<_ProbeNotifier, int> provider;
  late final ProviderContainer container;
  late final ProviderSubscription<int> _sub;

  bool get connected => container.read(realtimeConnectionStatusProvider);

  /// One app resume: one appResumeCounterProvider bump.
  void resume() {
    container.read(appResumeCounterProvider.notifier).increment();
    async.elapse(Duration.zero);
  }

  /// Drops the only listener, so Riverpod disposes the autoDispose notifier.
  void dispose() {
    _sub.close();
    async.elapse(Duration.zero);
    expect(
      container.exists(provider),
      isFalse,
      reason: 'precondition: disposed',
    );
  }
}

void main() {
  // The mixin logs every status via debugPrint. Silence it, both for quiet
  // output and so its throttle timer never shows up in pendingTimers.
  setUp(() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  test(
    'C1 disposed while a retry is pending: nothing reopens, errs or stays scheduled',
    () {
      fakeAsync((async) {
        final h = _Harness(async);
        expect(h.connected, isTrue);
        final channel = h.channels.latest('probe:a');
        channel.emitStatus(
          RealtimeSubscribeStatus.channelError,
          Exception('join failed'),
        );

        h.dispose();
        expect(channel.isClosed, isTrue);
        expect(async.pendingTimers, isEmpty);

        async.elapse(const Duration(seconds: 8));
        expect(h.channels.opened, hasLength(1));
        expect(h.connected, isTrue);
      });
    },
  );

  test(
    'C2 resume leaves one live channel per config, with or without a pending retry',
    () {
      fakeAsync((async) {
        // Two configs, FriendshipListNotifier's shape; only probe:a has a retry pending.
        final h = _Harness(async, channelNames: const ['probe:a', 'probe:b']);
        h.channels
            .latest('probe:a')
            .emitStatus(RealtimeSubscribeStatus.channelError);
        h.resume();

        void expectOneLivePerConfig(String when) {
          for (final name in const ['probe:a', 'probe:b']) {
            expect(h.channels.live(name), hasLength(1), reason: '$name $when');
            expect(
              h.channels.live(name).single,
              same(h.channels.latest(name)),
              reason: '$name $when',
            );
          }
        }

        expectOneLivePerConfig('straight after the resume');
        async.elapse(const Duration(seconds: 8));
        expectOneLivePerConfig('once the backoff has elapsed');

        h.channels.deliver(
          'probe:a',
          postgresChange(PostgresChangeEvent.insert),
        );
        h.channels.deliver(
          'probe:b',
          postgresChange(PostgresChangeEvent.insert),
        );
        expect(h.probe.events, ['probe:a', 'probe:b']);
      });
    },
  );

  test(
    'C3 repeated error reports before the retry fires get one replacement',
    () {
      fakeAsync((async) {
        final h = _Harness(async);
        final channel = h.channels.latest('probe:a');
        channel.emitStatus(RealtimeSubscribeStatus.channelError);
        channel.emitStatus(RealtimeSubscribeStatus.timedOut);
        channel.emitStatus(RealtimeSubscribeStatus.channelError);

        async.elapse(const Duration(seconds: 1));
        expect(h.channels.named('probe:a'), hasLength(2));
        expect(h.channels.live('probe:a'), hasLength(1));
      });
    },
  );

  test('C4 a replaced or closed channel\'s late status changes nothing', () {
    fakeAsync((async) {
      final h = _Harness(async);
      final original = h.channels.latest('probe:a');
      h.resume(); // replaces original
      final resumed = h.channels.latest('probe:a');
      resumed.emitStatus(RealtimeSubscribeStatus.channelError);
      async.elapse(const Duration(seconds: 1)); // the retry replaces resumed
      final retried = h.channels.latest('probe:a');
      expect(h.channels.named('probe:a'), hasLength(3));

      // A status a stale `subscribed` could wrongly flip back.
      h.container
          .read(realtimeConnectionStatusProvider.notifier)
          .markDisconnected();
      for (final stale in [original, resumed]) {
        stale.emitStatus(RealtimeSubscribeStatus.channelError);
        stale.emitStatus(RealtimeSubscribeStatus.subscribed);
      }
      async.elapse(const Duration(seconds: 16));
      expect(h.channels.named('probe:a'), hasLength(3));
      expect(h.connected, isFalse);

      h.dispose(); // closes retried
      retried.emitStatus(RealtimeSubscribeStatus.channelError);
      retried.emitStatus(RealtimeSubscribeStatus.subscribed);
      async.elapse(const Duration(seconds: 16));
      expect(h.channels.named('probe:a'), hasLength(3));
      expect(h.connected, isFalse);
    });
  });

  test(
    'C5 after dispose no event, status or presence reaches the notifier',
    () {
      fakeAsync((async) {
        final h = _Harness(
          async,
          presencePayload: const {'email': 'a@test.com'},
        );
        h.resume(); // one replaced channel, one live channel
        h.dispose();

        for (final channel in h.channels.opened) {
          channel.emitEvent(postgresChange(PostgresChangeEvent.insert));
          channel.emitStatus(RealtimeSubscribeStatus.subscribed);
          channel.emitPresence(3);
        }
        async.elapse(Duration.zero);

        expect(h.probe.events, isEmpty);
        expect(h.probe.presence, isEmpty);
      });
    },
  );

  test(
    'C6 a live notifier retries at 1 s, 2 s and 4 s, then reports disconnected until a resume reconnects',
    () {
      fakeAsync((async) {
        final h = _Harness(async);
        var opened = 1;
        for (final seconds in const [1, 2, 4]) {
          h.channels
              .latest('probe:a')
              .emitStatus(RealtimeSubscribeStatus.channelError);
          async.elapse(Duration(milliseconds: seconds * 1000 - 1));
          expect(
            h.channels.named('probe:a'),
            hasLength(opened),
            reason: 'before the ${seconds}s backoff',
          );
          async.elapse(const Duration(milliseconds: 1));
          expect(
            h.channels.named('probe:a'),
            hasLength(++opened),
            reason: 'after the ${seconds}s backoff',
          );
          expect(h.connected, isTrue);
        }

        h.channels
            .latest('probe:a')
            .emitStatus(RealtimeSubscribeStatus.timedOut);
        expect(h.connected, isFalse);
        expect(async.pendingTimers, isEmpty);
        async.elapse(const Duration(minutes: 1));
        expect(h.channels.named('probe:a'), hasLength(4));

        h.resume();
        expect(h.channels.live('probe:a'), hasLength(1));
        h.channels
            .latest('probe:a')
            .emitStatus(RealtimeSubscribeStatus.subscribed);
        expect(h.connected, isTrue);
      });
    },
  );

  test(
    'C7 presence is tracked once per live channel and counted only from the live one',
    () {
      fakeAsync((async) {
        const me = {'email': 'a@test.com'};
        final h = _Harness(async, presencePayload: me);
        final first = h.channels.latest('probe:a');
        expect(first.tracked, isEmpty);
        first.emitStatus(RealtimeSubscribeStatus.subscribed);
        expect(first.tracked, [me]);

        h.resume();
        final resumed = h.channels.latest('probe:a');
        first.emitStatus(RealtimeSubscribeStatus.subscribed); // superseded
        resumed.emitStatus(RealtimeSubscribeStatus.subscribed);
        expect(first.tracked, [me]);
        expect(resumed.tracked, [me]);

        resumed.emitStatus(RealtimeSubscribeStatus.channelError);
        async.elapse(const Duration(seconds: 1));
        final retried = h.channels.latest('probe:a');
        resumed.emitStatus(RealtimeSubscribeStatus.subscribed); // retried away
        retried.emitStatus(RealtimeSubscribeStatus.subscribed);
        expect(resumed.tracked, [me]);
        expect(retried.tracked, [me]);

        first.emitPresence(9);
        resumed.emitPresence(9);
        retried.emitPresence(2);
        expect(h.probe.presence, [2]);
      });
    },
  );

  group('realtime-event-scope', () {
    test(
      'S1 unsubscribeFromChannel closes only that channel, cancels its retry, and a resume leaves it closed',
      () {
        fakeAsync((async) {
          final h = _Harness(async, channelNames: const ['probe:a', 'probe:b']);
          final a = h.channels.latest('probe:a');
          a.emitStatus(RealtimeSubscribeStatus.channelError); // retry pending
          final notifier = h.container.read(h.provider.notifier);

          notifier.unsubscribeFromChannel('probe:a');
          notifier.unsubscribeFromChannel('probe:unknown'); // no-op

          expect(a.isClosed, isTrue);
          expect(h.channels.live('probe:b'), hasLength(1));
          async.elapse(
            const Duration(seconds: 8),
          ); // the cancelled retry's backoff
          h.resume();
          expect(h.channels.named('probe:a'), hasLength(1));
          expect(h.channels.live('probe:a'), isEmpty);
          expect(h.channels.live('probe:b'), hasLength(1));
          h.channels.deliver(
            'probe:b',
            postgresChange(PostgresChangeEvent.insert),
          );
          expect(h.probe.events, ['probe:b']);
        });
      },
    );

    test(
      'S2 chunkForInFilter deduplicates and sorts, and no chunk exceeds the in-filter limit',
      () {
        expect(chunkForInFilter(const <String>[]), isEmpty);
        expect(chunkForInFilter(const ['b', 'a', 'b']), [
          ['a', 'b'],
        ]);
        final ids = [
          for (var i = 250; i > 0; i--) 'g${i.toString().padLeft(3, '0')}',
        ];
        final chunks = chunkForInFilter([...ids, ...ids]);
        expect(chunks.every((c) => c.length <= 100), isTrue);
        expect(chunks.expand((c) => c).toList(), [...ids]..sort());
      },
    );

    test(
      'S3 syncInFilterChannels swaps chunk channels only when the set changes and never reuses a name',
      () {
        fakeAsync((async) {
          final h = _Harness(async);
          List<FakeRealtimeChannel> scoped() => h.channels.opened
              .where((c) => c.channelName.startsWith('probe_scope:'))
              .toList();
          List<FakeRealtimeChannel> liveScoped() =>
              scoped().where((c) => !c.isClosed).toList();

          h.container.read(h.provider.notifier).syncScope({'b', 'a'});
          final first = scoped().single;
          expect(first.table, 'probe_table');
          expect(first.filter!.type, PostgresChangeFilterType.inFilter);
          expect(first.filter!.column, 'id');
          expect(first.filter!.value, ['a', 'b']);

          // Equal contents, different instance: nothing closes or reopens.
          h.container.read(h.provider.notifier).syncScope({'a', 'b'});
          expect(scoped(), [first]);
          expect(first.isClosed, isFalse);

          h.container.read(h.provider.notifier).syncScope({'a', 'b', 'c'});
          expect(first.isClosed, isTrue);
          expect(liveScoped().single.filter!.value, ['a', 'b', 'c']);

          h.container.read(h.provider.notifier).syncScope(const {});
          expect(liveScoped(), isEmpty);

          // A rebuild disposes every channel; the next sync reopens under a
          // name no earlier channel used.
          h.container.invalidate(h.provider);
          async.elapse(Duration.zero);
          h.container.read(h.provider.notifier).syncScope({'a', 'b'});
          expect(liveScoped().single.filter!.value, ['a', 'b']);
          final names = scoped().map((c) => c.channelName).toList();
          expect(names.toSet(), hasLength(names.length));

          // The notifier's own channel is never touched by a re-scope.
          expect(h.channels.live('probe:a'), hasLength(1));
        });
      },
    );
  });
}
