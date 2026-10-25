import 'package:deun/helper/realtime_mixin.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test double for [RealtimeChannelFactory]. Records every channel the mixin
/// opens (name, table, filter) and closes, and lets a test fire the callbacks
/// a real channel would — on live channels and on closed ones alike, so late
/// reports from superseded channels can be simulated.
class FakeRealtimeChannelFactory implements RealtimeChannelFactory {
  /// Every channel opened, oldest first.
  final List<FakeRealtimeChannel> opened = [];

  /// Channels opened under [channelName], oldest first.
  List<FakeRealtimeChannel> named(String channelName) =>
      opened.where((c) => c.channelName == channelName).toList();

  /// The channels named [channelName] that are not closed.
  List<FakeRealtimeChannel> live(String channelName) =>
      named(channelName).where((c) => !c.isClosed).toList();

  /// The most recently opened channel named [channelName].
  FakeRealtimeChannel latest(String channelName) => named(channelName).last;

  /// Delivers [payload] to every open channel named [channelName], as the
  /// server fans a postgres change out to each subscribed channel.
  void deliver(String channelName, PostgresChangePayload payload) {
    for (final channel in live(channelName)) {
      channel.emitEvent(payload);
    }
  }

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
    final channel = FakeRealtimeChannel._(
      channelName: channelName,
      table: table,
      filter: filter,
      onEvent: onEvent,
      onStatus: onStatus,
      onPresence: onPresence,
    );
    opened.add(channel);
    return channel;
  }
}

/// One channel handed out by [FakeRealtimeChannelFactory].
class FakeRealtimeChannel implements RealtimeChannelHandle {
  FakeRealtimeChannel._({
    required this.channelName,
    required this.table,
    required this.filter,
    required void Function(PostgresChangePayload payload) onEvent,
    required void Function(RealtimeSubscribeStatus status, Object? error)
    onStatus,
    required void Function(int presentCount)? onPresence,
  }) : _onEvent = onEvent,
       _onStatus = onStatus,
       _onPresence = onPresence;

  final String channelName;
  final String table;
  final PostgresChangeFilter? filter;
  final void Function(PostgresChangePayload payload) _onEvent;
  final void Function(RealtimeSubscribeStatus status, Object? error) _onStatus;
  final void Function(int presentCount)? _onPresence;

  /// Every presence payload tracked on this channel, in order.
  final List<Map<String, dynamic>> tracked = [];

  bool _closed = false;
  bool get isClosed => _closed;

  @override
  void track(Map<String, dynamic> payload) => tracked.add(payload);

  /// Like `removeChannel`, the channel reports `closed` as it goes.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _onStatus(RealtimeSubscribeStatus.closed, null);
  }

  void emitEvent(PostgresChangePayload payload) => _onEvent(payload);

  void emitStatus(RealtimeSubscribeStatus status, [Object? error]) =>
      _onStatus(status, error);

  /// A presence sync with [presentCount] distinct keys. A channel opened
  /// without `onPresence` registers no presence listener, so nothing fires.
  void emitPresence(int presentCount) => _onPresence?.call(presentCount);
}

/// A postgres change payload of [eventType] carrying [newRecord]/[oldRecord].
PostgresChangePayload postgresChange(
  PostgresChangeEvent eventType, {
  Map<String, dynamic> newRecord = const {},
  Map<String, dynamic> oldRecord = const {},
}) => PostgresChangePayload(
  schema: 'public',
  table: 'test',
  commitTimestamp: DateTime.utc(2026),
  eventType: eventType,
  newRecord: newRecord,
  oldRecord: oldRecord,
  errors: null,
);
