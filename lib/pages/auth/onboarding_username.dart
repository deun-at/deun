/// Pure username helpers for the onboarding screen (Screen 3).
///
/// Kept Flutter-free so the live-preview / sanitization / validation logic can
/// be unit-tested in isolation and shared between what the user sees while
/// typing and what eventually gets persisted by `UserRepository.saveUsername`.
library;

/// Characters that are NOT part of a stored username (anything outside
/// `[a-zA-Z0-9_]`). Used to strip the live preview down to what would be saved.
final _disallowedChars = RegExp(r'[^a-zA-Z0-9_]');

/// The validity pattern the onboarding form enforces: 3–20 of
/// `[a-zA-Z0-9_]`. Matches the screen's original validator exactly.
final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

/// Normalize [raw] to the form that would actually be stored: trimmed,
/// lowercased, with every disallowed character removed. Mirrors how
/// `UserRepository.saveUsername` lowercases/trims, plus the field's allowed
/// character set, so the live preview agrees with the saved value.
String sanitizeUsername(String raw) =>
    raw.trim().toLowerCase().replaceAll(_disallowedChars, '');

/// Whether [raw] is an acceptable username. Matches the screen's existing
/// validator, which tests the regex against the raw field value.
bool isValidUsername(String raw) => _usernameRegex.hasMatch(raw);

/// Build the `@username#code` handle preview shown live as the user types.
/// [username] is expected to be already sanitized; falls back to a generic
/// `username` placeholder when empty so the preview never reads as `@#code`.
String previewHandle({
  required String username,
  required String codePlaceholder,
}) {
  final handle = username.isEmpty ? 'username' : username;
  return '@$handle#$codePlaceholder';
}
