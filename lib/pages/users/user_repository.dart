import 'dart:math';
import 'package:deun/pages/users/current_user.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'user_repository.g.dart';

class AmbiguousUsernameException implements Exception {
  const AmbiguousUsernameException();
}

class UserRepository {
  UserRepository(this._supabase, this._currentUser);

  final SupabaseClient _supabase;
  final CurrentUser? _currentUser;

  /// Fetch users by exact email, username#code, or unique username.
  /// Supports formats: "user@email.com", "john#1234", or "john" (only if unique).
  /// Excludes [selectedUsers] (already friends / self).
  Future<List<SupaUser>> fetchData(
    String searchString,
    List<String> selectedUsers,
    int? limit,
  ) async {
    final trimmed = searchString.trim().toLowerCase();
    if (trimmed.isEmpty) return [];

    final excludeSet = selectedUsers.toSet();
    List<dynamic> data;

    if (trimmed.contains('#')) {
      final parts = trimmed.split('#');
      final username = parts[0];
      final code = parts.length > 1 ? parts[1] : '';

      var query = _supabase
          .from('user')
          .select('*')
          .eq('username', username)
          .eq('username_code', code)
          .neq('is_guest', true)
          .order('email');

      if (limit != null) query = query.limit(limit);
      data = await query;
    } else if (trimmed.contains('@')) {
      var query = _supabase
          .from('user')
          .select('*')
          .eq('email', trimmed)
          .neq('is_guest', true)
          .order('email');

      if (limit != null) query = query.limit(limit);
      data = await query;
    } else {
      var query = _supabase
          .from('user')
          .select('*')
          .eq('username', trimmed)
          .neq('is_guest', true)
          .order('email');

      if (limit != null) query = query.limit(limit);
      data = await query;

      // If username is not unique, require the #code to disambiguate
      if (data.length > 1) throw const AmbiguousUsernameException();
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(SupaUser.fromJson)
        .where((u) => !excludeSet.contains(u.email))
        .toList();
  }

  /// Fetch users whose email is in [emails], excluding [excludeEmails].
  /// Uses a Supabase RPC function to handle large email lists in a single call.
  Future<List<SupaUser>> fetchByEmails(
    List<String> emails,
    List<String> excludeEmails,
  ) async {
    if (emails.isEmpty) return [];

    final data = await _supabase.rpc(
      'match_contacts_by_email',
      params: {'_emails': emails, '_exclude_emails': excludeEmails},
    );

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(SupaUser.fromJson)
        .toList();
  }

  /// Fetch a single user by email.
  Future<SupaUser> fetchDetail(String email) async {
    final Map<String, dynamic> data = await _supabase
        .from('user')
        .select('*')
        .eq('email', email)
        .single();
    return SupaUser.fromJson(data);
  }

  /// Save profile-related fields for the currently authenticated user.
  Future<void> saveProfileData(Map<String, dynamic> formResponse) async {
    final Map<String, dynamic> upsertVals = {
      'first_name': formResponse['first_name'],
      'last_name': formResponse['last_name'],
      'display_name': formResponse['display_name'],
      'locale': formResponse['locale'],
      'paypal_me': formResponse['paypal_me'],
      'iban': formResponse['iban'],
    };

    final email = _currentUser?.email;
    if (email != null && email.isNotEmpty) {
      await _supabase.from('user').update(upsertVals).eq('email', email);
    } else {
      throw Exception('User email is empty');
    }
  }

  /// Save username and display name during onboarding or settings update.
  /// Generates a random 4-digit code and retries on collision.
  Future<String> saveUsername(String username, String displayName) async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) {
      throw Exception('User email is empty');
    }

    final sanitized = username.toLowerCase().trim();

    for (int attempt = 0; attempt < 5; attempt++) {
      final code = (Random().nextInt(9000) + 1000).toString(); // 1000–9999

      try {
        await _supabase
            .from('user')
            .update({
              'username': sanitized,
              'username_code': code,
              'display_name': displayName,
            })
            .eq('email', email);

        return code;
      } on PostgrestException catch (e) {
        // Only retry on unique constraint violation (23505)
        if (e.code != '23505' || attempt == 4) rethrow;
      }
    }

    throw Exception('Could not generate unique username after 5 attempts');
  }

  /// Fetch a single user by username and code (e.g. "john" + "1234").
  Future<SupaUser> fetchByUsername(String username, String code) async {
    final Map<String, dynamic> data = await _supabase
        .from('user')
        .select('*')
        .eq('username', username)
        .eq('username_code', code)
        .single();
    return SupaUser.fromJson(data);
  }

  /// Create a guest user with a generated placeholder email.
  Future<SupaUser> createGuest(String displayName) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(999999);
    final email = 'guest+$ts$rand@guest.invalid';

    final Map<String, dynamic> insertVals = {
      'email': email,
      'display_name': displayName,
      'is_guest': true,
    };

    final Map<String, dynamic> data = await _supabase
        .from('user')
        .insert(insertVals)
        .select('*')
        .single();

    return SupaUser.fromJson(data);
  }

  /// The signed-in user's spending per group and month between [start]
  /// (inclusive) and [end] (exclusive), as `get_user_spending_summary` returns
  /// it.
  Future<List<Map<String, dynamic>>> fetchSpendingSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _supabase.rpc(
      'get_user_spending_summary',
      params: {
        'p_user_email': _currentUser?.email ?? '',
        'p_start': _toDateOnly(start),
        'p_end': _toDateOnly(end),
      },
    );
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static String _toDateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) => UserRepository(
  ref.watch(supabaseClientProvider),
  ref.watch(currentUserProvider),
);
