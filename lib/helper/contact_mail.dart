import 'package:deun/main.dart';

import 'escaping.dart';

/// Throws on failure so callers can show an error to the user.
Future<void> sendContactMail(Map<String, dynamic> contactInfo) async {
  final name = escapeHtml(contactInfo['name']?.toString());
  final company = escapeHtml(contactInfo['company']?.toString() ?? '-');
  final email = escapeHtml(contactInfo['email']?.toString());
  final description = escapeHtml(contactInfo['description']?.toString());

  await supabase.functions.invoke(
    'send-contact-email',
    body: {
      'message':
          "Name: $name <br>Company: $company<br>E-Mail: $email<br><br>Description: $description",
    },
  );
}
