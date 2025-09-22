import 'dart:math';
import 'package:deun/pages/users/user_model.dart';

import '../../main.dart';

class UserRepository {
  /// Fetch a list of users filtered by [searchString] and excluding [selectedUsers].
  static Future<List<SupaUser>> fetchData(String searchString, List<String> selectedUsers, int? limit) async {
    var query =
    supabase.from('user').select('*').ilike('email', searchString).not('email', 'in', selectedUsers).order('email');

    if (limit != null) {
      query = query.limit(limit);
    }

    final List<dynamic> data = await query; // Supabase returns List<dynamic>
    return data.cast<Map<String, dynamic>>().map(SupaUser.fromJson).toList();
  }

  /// Fetch a single user by email.
  static Future<SupaUser> fetchDetail(String email) async {
    final Map<String, dynamic> data = await supabase.from('user').select('*').eq('email', email).single();
    return SupaUser.fromJson(data);
  }

  /// Save profile-related fields for the currently authenticated user.
  static Future<void> saveProfileData(Map<String, dynamic> formResponse) async {
    final Map<String, dynamic> upsertVals = {
      'first_name': formResponse['first_name'],
      'last_name': formResponse['last_name'],
      'display_name': formResponse['display_name'],
      'locale': formResponse['locale'],
      'paypal_me': formResponse['paypal_me'],
      'iban': formResponse['iban'],
    };

    final email = supabase.auth.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      await supabase.from('user').update(upsertVals).eq('email', email);
    } else {
      throw Exception('User email is empty');
    }
  }

  /// Create a guest user with a generated placeholder email.
  static Future<SupaUser> createGuest(String displayName) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(999999);
    final email = 'guest+$ts$rand@guest.invalid';

    final Map<String, dynamic> insertVals = {
      'email': email,
      'display_name': displayName,
      'is_guest': true,
    };

    final Map<String, dynamic> data = await supabase.from('user').insert(insertVals).select('*').single();

    return SupaUser.fromJson(data);
  }
}