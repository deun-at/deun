import '../../../main.dart';

class ReminderRepository {
  static Future<void> sendReminder(String groupId, String toEmail) async {
    final currentEmail = supabase.auth.currentUser?.email;
    if (currentEmail == null) throw StateError('User not authenticated');
    await supabase.from('payment_reminder').insert({
      'group_id': groupId,
      'reminder_from': currentEmail,
      'reminder_to': toEmail,
    });
  }

  static Future<DateTime?> getLastReminder(String groupId, String toEmail) async {
    final currentEmail = supabase.auth.currentUser?.email;
    if (currentEmail == null) throw StateError('User not authenticated');
    final data = await supabase
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
