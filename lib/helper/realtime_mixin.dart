import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

part 'realtime_mixin.g.dart';

/// Counter incremented on app resume. Providers listen to this to reload data
/// without a full rebuild (preserving pagination state, scroll position, etc.).
@riverpod
class AppResumeCounter extends _$AppResumeCounter {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Tracks whether any real-time channel has failed after exhausting retries.
/// UI can watch this to show a "live updates paused" banner.
@Riverpod(keepAlive: true)
class RealtimeConnectionStatus extends _$RealtimeConnectionStatus {
  @override
  bool build() => true; // true = connected/healthy

  void markDisconnected() => state = false;

  void markConnected() => state = true;
}

/// One open realtime channel, as [RealtimeChannelFactory.open] returns it.
/// The mixin never touches a `RealtimeChannel` directly.
abstract interface class RealtimeChannelHandle {
  /// Tracks [payload] as this client's presence on the channel.
  void track(Map<String, dynamic> payload);

  /// Unsubscribes and removes the channel.
  void close();
}

/// The one place a realtime channel is created. [onEvent] receives every
/// postgres change on [table] (narrowed by [filter]), [onStatus] every
/// subscribe status report, and [onPresence], when set, the distinct
/// presence-key count on every presence sync/join/leave.
abstract interface class RealtimeChannelFactory {
  RealtimeChannelHandle open({
    required String channelName,
    required String table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) onEvent,
    required void Function(RealtimeSubscribeStatus status, Object? error)
    onStatus,
    void Function(int presentCount)? onPresence,
  });
}

/// [RealtimeChannelFactory] over the app's Supabase client.
class SupabaseRealtimeChannelFactory implements RealtimeChannelFactory {
  const SupabaseRealtimeChannelFactory();

  @override
  RealtimeChannelHandle open({
    required String channelName,
    required String table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) onEvent,
    required void Function(RealtimeSubscribeStatus status, Object? error)
    onStatus,
    void Function(int presentCount)? onPresence,
  }) {
    late final RealtimeChannel channel;
    var builder = supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: filter,
          callback: onEvent,
        );
    final presence = onPresence;
    if (presence != null) {
      // Distinct present members = distinct presence keys (one key per member;
      // a member open on two devices still counts once).
      void emitPresence() => presence(channel.presenceState().length);
      builder = builder
          .onPresenceSync((_) => emitPresence())
          .onPresenceJoin((_) => emitPresence())
          .onPresenceLeave((_) => emitPresence());
    }
    channel = builder.subscribe(onStatus);
    return _SupabaseChannelHandle(channel);
  }
}

class _SupabaseChannelHandle implements RealtimeChannelHandle {
  _SupabaseChannelHandle(this._channel);

  final RealtimeChannel _channel;

  @override
  void track(Map<String, dynamic> payload) =>
      unawaited(_channel.track(payload));

  @override
  void close() => unawaited(supabase.removeChannel(_channel));
}

/// The channel factory every [RealtimeNotifierMixin] opens through. Tests
/// replace it with `realtimeChannelFactoryProvider.overrideWithValue(...)`.
@Riverpod(keepAlive: true)
RealtimeChannelFactory realtimeChannelFactory(Ref ref) =>
    const SupabaseRealtimeChannelFactory();

/// The most values one realtime `in` filter accepts (Supabase postgres_changes).
const int kRealtimeInFilterMaxValues = 100;

/// [values] deduplicated, sorted, and cut into chunks of at most
/// [kRealtimeInFilterMaxValues] — one `in` filter each. Empty input, no chunks.
List<List<String>> chunkForInFilter(Iterable<String> values) {
  final sorted = values.toSet().toList()..sort();
  return [
    for (
      var start = 0;
      start < sorted.length;
      start += kRealtimeInFilterMaxValues
    )
      sorted.sublist(
        start,
        min(start + kRealtimeInFilterMaxValues, sorted.length),
      ),
  ];
}

/// Stored channel configuration for replay after app resume.
class _ChannelConfig {
  final String channelName;
  final String table;
  final PostgresChangeFilter? filter;
  final void Function(PostgresChangePayload payload) onEvent;

  /// Optional presence hook. When set, the channel also registers
  /// presence sync/join/leave listeners and `track`s [presencePayload] right
  /// after it reaches `subscribed`; [onPresence] fires with the live distinct
  /// presence-key count on every presence change. Omitted for every non-claim
  /// consumer, leaving their postgres-changes behavior untouched.
  final void Function(int presentCount)? onPresence;
  final Map<String, dynamic>? presencePayload;

  /// Read once per subscribe from [realtimeChannelFactoryProvider], so a retry
  /// never touches a Ref.
  final RealtimeChannelFactory factory;

  _ChannelConfig({
    required this.channelName,
    required this.table,
    this.filter,
    required this.onEvent,
    this.onPresence,
    this.presencePayload,
    required this.factory,
  });
}

/// The one live channel of a config. [generation] advances whenever that
/// channel is replaced or closed; each callback carries the generation it was
/// opened under and is dropped once that is no longer current.
class _ChannelSlot {
  _ChannelSlot(this.config);

  final _ChannelConfig config;
  RealtimeChannelHandle? handle;
  int generation = 0;

  /// Retries spent in the current chain. Reset by a resubscribe.
  int attempt = 0;

  /// The pending retry, if any — at most one per config.
  Timer? retryTimer;
}

/// The chunk channels one [RealtimeNotifierMixin.syncInFilterChannels] prefix
/// has open, and the values they cover.
class _InFilterScope {
  Set<String> values = const {};
  List<String> channelNames = const [];

  /// Never reset — not by [RealtimeNotifierMixin.disposeChannels] either — so
  /// no chunk channel name is ever reused, not even across a rebuild.
  int version = 0;
}

/// Mixin for Riverpod AsyncNotifiers that need Supabase real-time channel subscriptions.
///
/// Standardizes channel creation, cleanup, error handling, and disposal across all providers.
/// Supports multiple channels per provider (e.g., FriendshipListNotifier).
///
/// A channel lives exactly as long as its notifier's subscription: one live
/// channel and at most one pending retry per config, and once
/// [disposeChannels] has run nothing a channel reports reaches the notifier.
///
/// On app resume, channels are automatically re-subscribed from stored configs
/// before calling the reload callback. This fixes the issue where
/// `supabase.removeAllChannels()` on pause kills channels that were never
/// re-established for providers using `listenForResume` instead of `ref.invalidate`.
mixin RealtimeNotifierMixin {
  final Map<String, _ChannelSlot> _slots = {};
  final Map<String, _InFilterScope> _inFilterScopes = {};
  bool _isResubscribing = false;
  static const int _maxRetries = 3;

  /// Set in subscribeToChannel() via the required `ref` parameter.
  /// Used to update the global connection status on failure/recovery; only a
  /// live channel's callback reaches it, so it is never read after dispose.
  Ref? _ref;

  /// Subscribe to a Supabase Postgres changes channel.
  ///
  /// - [channelName]: Unique channel name (use parameters to avoid collisions)
  /// - [table]: The Supabase table to listen to
  /// - [filter]: Optional column filter for scoped listening
  /// - [onEvent]: Callback for Postgres change events (insert/update/delete)
  ///
  /// [onPresence] + [presencePayload] opt into Realtime Presence on the same
  /// channel: when both are set, the channel tracks [presencePayload] once
  /// subscribed and calls [onPresence] with the live distinct presence-key
  /// count on every sync/join/leave. Leave both null (the default) for a plain
  /// postgres-changes channel.
  void subscribeToChannel({
    required Ref ref,
    required String channelName,
    required String table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) onEvent,
    void Function(int presentCount)? onPresence,
    Map<String, dynamic>? presencePayload,
  }) {
    _ref = ref;
    // Prevent duplicate configs for the same channel
    if (_slots.containsKey(channelName)) return;

    final slot = _ChannelSlot(
      _ChannelConfig(
        channelName: channelName,
        table: table,
        filter: filter,
        onEvent: onEvent,
        onPresence: onPresence,
        presencePayload: presencePayload,
        factory: ref.read(realtimeChannelFactoryProvider),
      ),
    );
    _slots[channelName] = slot;
    _open(slot);
  }

  /// Closes [channelName]'s live channel, cancels its pending retry and forgets
  /// its config, so a resume does not reopen it. An unknown name is a no-op.
  void unsubscribeFromChannel(String channelName) {
    final slot = _slots.remove(channelName);
    if (slot != null) _retire(slot);
  }

  /// Keeps one channel per [chunkForInFilter] chunk of [values] open on
  /// [table], each filtered `column=in.(chunk)` and named
  /// `<prefix>:s<version>:<index>`. A call whose [values] equal (by contents)
  /// what [prefix] already covers closes and opens nothing — re-joining drops
  /// the events that arrive in the gap. Otherwise the prefix's previous chunk
  /// channels close and the new ones open under the next version, so a topic
  /// whose leave may still be in flight is never reopened. Other channels are
  /// never touched.
  void syncInFilterChannels({
    required Ref ref,
    required String prefix,
    required String table,
    required String column,
    required Set<String> values,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final scope = _inFilterScopes.putIfAbsent(prefix, _InFilterScope.new);
    if (setEquals(scope.values, values)) return;
    scope.channelNames.forEach(unsubscribeFromChannel);
    final version = ++scope.version;
    final chunks = chunkForInFilter(values);
    scope.values = Set.unmodifiable(values);
    scope.channelNames = [
      for (var i = 0; i < chunks.length; i++) '$prefix:s$version:$i',
    ];
    for (var i = 0; i < chunks.length; i++) {
      subscribeToChannel(
        ref: ref,
        channelName: scope.channelNames[i],
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: column,
          value: chunks[i],
        ),
        onEvent: onEvent,
      );
    }
  }

  /// Opens [slot]'s channel under its current generation. Every callback
  /// returns before touching the notifier, its Ref or the connection status
  /// unless the slot is still its config's live slot on that generation, so
  /// superseded, retried-away and disposed channels are all dropped here.
  void _open(_ChannelSlot slot) {
    final config = slot.config;
    final generation = slot.generation;
    bool isLive() =>
        identical(_slots[config.channelName], slot) &&
        slot.generation == generation;
    final onPresence = config.onPresence;

    slot.handle = config.factory.open(
      channelName: config.channelName,
      table: config.table,
      filter: config.filter,
      onEvent: (payload) {
        if (isLive()) config.onEvent(payload);
      },
      onStatus: (status, error) {
        if (isLive()) _onStatus(slot, status, error);
      },
      onPresence: onPresence == null
          ? null
          : (count) {
              if (isLive()) onPresence(count);
            },
    );
  }

  /// Closes [slot]'s channel and cancels its pending retry. The generation
  /// advances first, so anything the closing channel still reports is stale.
  void _retire(_ChannelSlot slot) {
    slot.generation++;
    slot.retryTimer?.cancel();
    slot.retryTimer = null;
    slot.handle?.close();
    slot.handle = null;
  }

  void _onStatus(
    _ChannelSlot slot,
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    final config = slot.config;
    debugPrint('---subscribe--- ${config.channelName} $status');
    switch (status) {
      case RealtimeSubscribeStatus.channelError ||
          RealtimeSubscribeStatus.timedOut:
        debugPrint('---subscribe error--- ${config.channelName}: $error');
        // realtime_client 2.7.1 can report one failure twice (its _onError
        // hook and the join push's error reply): one pending retry per config.
        if (slot.retryTimer != null) return;
        if (slot.attempt < _maxRetries) {
          final delay = Duration(
            seconds: 1 << slot.attempt,
          ); // exponential backoff
          slot.retryTimer = Timer(delay, () {
            slot.attempt++;
            _retire(slot);
            _open(slot);
          });
        } else {
          debugPrint(
            '---subscribe give up--- ${config.channelName} after $_maxRetries retries',
          );
          _ref
              ?.read(realtimeConnectionStatusProvider.notifier)
              .markDisconnected();
        }
      case RealtimeSubscribeStatus.subscribed:
        _ref?.read(realtimeConnectionStatusProvider.notifier).markConnected();
        final payload = config.presencePayload;
        if (payload != null) slot.handle?.track(payload);
      case RealtimeSubscribeStatus.closed:
        debugPrint('---subscribe closed--- ${config.channelName}');
    }
  }

  /// Re-subscribe all channels from stored configs.
  /// Called automatically on app resume to restore channels killed by
  /// removeAllChannels(). Each config's channel and pending retry are replaced
  /// by one fresh channel with a fresh retry budget.
  void resubscribeChannels() {
    if (_isResubscribing) return;
    _isResubscribing = true;

    for (final slot in _slots.values) {
      _retire(slot);
      slot.attempt = 0;
      _open(slot);
    }

    // Reset on next microtask so rapid resume events within the same
    // event-loop turn are coalesced rather than triggering duplicate work.
    Future.microtask(() => _isResubscribing = false);
  }

  /// Listen for app resume events. Automatically re-subscribes channels,
  /// then calls [onResume] to reload data.
  /// Call this in build() after subscribeToChannel().
  void listenForResume({required Ref ref, required void Function() onResume}) {
    ref.listen(appResumeCounterProvider, (_, _) {
      resubscribeChannels();
      onResume();
    });
  }

  /// Closes every channel, cancels every pending retry and forgets the
  /// configs and what each in-filter prefix covers (its version survives).
  /// Call this at the start of build() before subscribing, and register it via
  /// ref.onDispose.
  void disposeChannels() {
    final slots = _slots.values.toList();
    _slots.clear();
    for (final slot in slots) {
      _retire(slot);
    }
    for (final scope in _inFilterScopes.values) {
      scope
        ..values = const {}
        ..channelNames = const [];
    }
  }
}
