import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// Mixin for Riverpod AsyncNotifiers that need Supabase real-time channel subscriptions.
///
/// Standardizes channel creation, cleanup, error handling, and disposal across all providers.
/// Supports multiple channels per provider (e.g., FriendshipListNotifier).
mixin RealtimeNotifierMixin {
  final List<RealtimeChannel> _channels = [];

  /// Subscribe to a Supabase Postgres changes channel.
  ///
  /// - [ref]: The provider's Ref for lifecycle management
  /// - [channelName]: Unique channel name (use parameters to avoid collisions)
  /// - [table]: The Supabase table to listen to
  /// - [filter]: Optional column filter for scoped listening
  /// - [onEvent]: Callback for Postgres change events (insert/update/delete)
  /// - [onSubscribed]: Called when channel is successfully subscribed (typically triggers a reload)
  void subscribeToChannel({
    required Ref ref,
    required String channelName,
    required String table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) onEvent,
    required void Function() onSubscribed,
  }) {
    final channel = supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (payload) {
            onEvent(payload);
          },
        )
        .subscribe((status, _) {
          debugPrint('---subscribe--- $channelName ${status.toString()}');
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            ref.invalidateSelf();
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            onSubscribed();
          }
        });

    _channels.add(channel);
  }

  /// Removes all channels and clears the list.
  /// Call this at the start of build() before subscribing, and register via ref.onDispose.
  void disposeChannels() {
    for (final channel in _channels) {
      supabase.removeChannel(channel);
    }
    _channels.clear();
  }
}
