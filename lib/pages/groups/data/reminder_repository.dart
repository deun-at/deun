import 'package:deun/pages/users/current_user.dart';
import 'package:deun/provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'reminder_repository.g.dart';

class ReminderRepository {
  ReminderRepository(this._supabase, this._currentUser);

  final SupabaseClient _supabase;
  final CurrentUser? _currentUser;

  Future<void> sendReminder(String groupId, String toEmail) async {
    final currentEmail = _currentUser?.email;
    if (currentEmail == null || currentEmail.isEmpty) {
      throw StateError('User not authenticated');
    }
    await _supabase.from('payment_reminder').insert({
      'group_id': groupId,
      'reminder_from': currentEmail,
      'reminder_to': toEmail,
    });
  }

  Future<DateTime?> getLastReminder(String groupId, String toEmail) async {
    final currentEmail = _currentUser?.email;
    if (currentEmail == null || currentEmail.isEmpty) {
      throw StateError('User not authenticated');
    }
    final data = await _supabase
        .from('payment_reminder')
        .select('created_at')
        .eq('group_id', groupId)
        .eq('reminder_from', currentEmail)
        .eq('reminder_to', toEmail)
        .order('created_at', ascending: false)
        .limit(1);

    if (data.isEmpty) return null;
    return DateTime.parse(data.first['created_at'] as String);
  }
}

@Riverpod(keepAlive: true)
ReminderRepository reminderRepository(Ref ref) => ReminderRepository(
  ref.watch(supabaseClientProvider),
  ref.watch(currentUserProvider),
);
