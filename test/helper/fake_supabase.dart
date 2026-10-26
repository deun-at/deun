// A SupabaseClient that reaches no server, for tests that build real
// repositories. `auth` answers only `currentUser`; `rpc` records the call and
// throws [SentRpc] (or the given `rpcError`), so a test reads what an RPC fetch
// or write would have sent. Anything else throws.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by [FakeSupabaseClient.rpc] once the call is recorded.
class SentRpc implements Exception {
  const SentRpc(this.function);

  final String function;
}

class FakeAuth implements GoTrueClient {
  FakeAuth(this.currentUser);

  @override
  User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeAuth: ${invocation.memberName}');
}

class FakeSupabaseClient implements SupabaseClient {
  FakeSupabaseClient({User? currentUser, this.rpcError})
    : auth = FakeAuth(currentUser);

  @override
  final FakeAuth auth;

  /// When set, [rpc] records the call and throws this instead of [SentRpc]:
  /// the error the server answered with.
  final Object? rpcError;

  /// Every RPC asked for, in order.
  final List<({String function, Map<String, dynamic>? params})> rpcs = [];

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get = false,
  }) {
    rpcs.add((function: fn, params: params));
    throw rpcError ?? SentRpc(fn);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeSupabaseClient: ${invocation.memberName}');
}

/// An auth user with [id] and [email].
User authUser(String id, String email) => User(
  id: id,
  email: email,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

/// [event] carrying a session for [user], or no session when [user] is null.
AuthState authEvent(
  AuthChangeEvent event,
  User? user, {
  String token = 'token',
}) => AuthState(
  event,
  user == null
      ? null
      : Session(accessToken: token, tokenType: 'bearer', user: user),
);
