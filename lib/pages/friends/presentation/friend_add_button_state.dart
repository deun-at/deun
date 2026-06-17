/// Whether an add-friend row shows an actionable **Add** button or a passive
/// **Requested** label (after a request has been sent in this session).
enum FriendAddButtonState { add, requested }

/// Maps a user's [email] against the set of [requestedEmails] (emails the user
/// has already sent a request to in this page session) to the button state.
///
/// Comparison is case-insensitive so it tolerates the casing differences that
/// flow through the contacts / DB pipelines.
FriendAddButtonState friendAddButtonState(
  String email,
  Set<String> requestedEmails,
) {
  final lower = email.toLowerCase();
  final isRequested =
      requestedEmails.any((e) => e.toLowerCase() == lower);
  return isRequested ? FriendAddButtonState.requested : FriendAddButtonState.add;
}
