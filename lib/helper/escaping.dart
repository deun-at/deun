/// Sanitize a value before interpolating it into a Supabase PostgREST filter string.
/// Strips characters that could break the filter DSL (commas, parentheses, etc.).
String sanitizeFilterValue(String value) =>
    value.replaceAll(RegExp(r'[%,()\\]'), '');

/// Escapes user input before it is embedded in the HTML email body.
String escapeHtml(String? value) => (value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
