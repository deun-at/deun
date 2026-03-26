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

/// Stored channel configuration for replay after app resume.
class _ChannelConfig {
  final String channelName;
  final String table;
  final PostgresChangeFilter? filter;
  final void Function(PostgresChangePayload payload) onEvent;

  _ChannelConfig({
    required this.channelName,
    required this.table,
    this.filter,
    required this.onEvent,
  });
}

/// Mixin for Riverpod AsyncNotifiers that need Supabase real-time channel subscriptions.
///
/// Standardizes channel creation, cleanup, error handling, and disposal across all providers.
/// Supports multiple channels per provider (e.g., FriendshipListNotifier).
///
/// On app resume, channels are automatically re-subscribed from stored configs
/// before calling the reload callback. This fixes the issue where
/// `supabase.removeAllChannels()` on pause kills channels that were never
/// re-established for providers using `listenForResume` instead of `ref.invalidate`.
mixin RealtimeNotifierMixin {
  final List<RealtimeChannel> _channels = [];
  final List<_ChannelConfig> _configs = [];

  /// Subscribe to a Supabase Postgres changes channel.
  ///
  /// - [channelName]: Unique channel name (use parameters to avoid collisions)
  /// - [table]: The Supabase table to listen to
  /// - [filter]: Optional column filter for scoped listening
  /// - [onEvent]: Callback for Postgres change events (insert/update/delete)
  void subscribeToChannel({
    required String channelName,
    required String table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final config = _ChannelConfig(
      channelName: channelName,
      table: table,
      filter: filter,
      onEvent: onEvent,
    );
    _configs.add(config);
    _createChannel(config);
  }

  void _createChannel(_ChannelConfig config) {
    final channel = supabase
        .channel(config.channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: config.table,
          filter: config.filter,
          callback: (payload) {
            config.onEvent(payload);
          },
        )
        .subscribe((status, _) {
          debugPrint('---subscribe--- ${config.channelName} ${status.toString()}');
        });

    _channels.add(channel);
  }

  /// Re-subscribe all channels from stored configs.
  /// Called automatically on app resume to restore channels killed by removeAllChannels().
  void resubscribeChannels() {
    for (final channel in _channels) {
      supabase.removeChannel(channel);
    }
    _channels.clear();
    for (final config in _configs) {
      _createChannel(config);
    }
  }

  /// Listen for app resume events. Automatically re-subscribes channels,
  /// then calls [onResume] to reload data.
  /// Call this in build() after subscribeToChannel().
  void listenForResume({
    required Ref ref,
    required void Function() onResume,
  }) {
    ref.listen(appResumeCounterProvider, (_, _) {
      resubscribeChannels();
      onResume();
    });
  }

  /// Removes all channels and clears stored configs.
  /// Call this at the start of build() before subscribing, and register via ref.onDispose.
  void disposeChannels() {
    for (final channel in _channels) {
      supabase.removeChannel(channel);
    }
    _channels.clear();
    _configs.clear();
  }
}
