/// The signed-in account as the app sees it. [email] is the identity every
/// table keys on; [id] is written only where the app writes `user_id`.
///
/// Value equality on both fields is what lets a same-user token refresh change
/// nothing downstream: `currentUserProvider` notifies only when it differs.
class CurrentUser {
  const CurrentUser({required this.id, required this.email});

  final String id;

  /// `''` when the session's user carries no email (today's `?? ''`).
  final String email;

  @override
  bool operator ==(Object other) =>
      other is CurrentUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'CurrentUser($id, $email)';
}
