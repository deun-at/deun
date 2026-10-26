/// The app's shared helpers, re-exported from their single-concern modules so
/// every existing `package:deun/helper/helper.dart` import keeps working.
///
/// Each module is also importable on its own. Modules import each other
/// directly and never import this file.
library;

export 'contact_mail.dart';
export 'currency.dart';
export 'error_predicates.dart';
export 'escaping.dart';
export 'formatting.dart';
export 'money.dart';
export 'navigation_helpers.dart';
export 'ui_feedback.dart';
