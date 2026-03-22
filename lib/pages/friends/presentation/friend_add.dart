import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:deun/pages/friends/presentation/requested_friendship_list.dart';
import 'package:deun/pages/friends/presentation/search_result_list.dart';
import 'package:deun/pages/friends/presentation/pending_request_list.dart';
import 'package:deun/pages/friends/presentation/contact_suggestion_list.dart';
import 'package:flutter/foundation.dart';

Future<List<SupaUser>> _findContactMatches(Map<String, dynamic> params) async {
  final List<fc.Contact> contacts = params['contacts'];
  final Map<String, SupaUser> availableUserMap = params['availableUserMap'];
  final String searchText = params['searchText'].toLowerCase();
  List<SupaUser> matchedUsers = [];

  for (var contact in contacts) {
    bool nameMatches = contact.displayName.toLowerCase().contains(searchText);
    bool emailMatches =
        contact.emails.any((email) => email.address.toLowerCase().contains(searchText));

    if (searchText.isNotEmpty && !nameMatches && !emailMatches) {
      continue;
    }

    SupaUser? matchedUser;
    for (var email in contact.emails) {
      final lowerCaseEmail = email.address.toLowerCase();
      if (availableUserMap.containsKey(lowerCaseEmail)) {
        matchedUser = availableUserMap[lowerCaseEmail];
        break;
      }
    }

    if (matchedUser != null) {
      matchedUsers.add(matchedUser);
    }
  }
  // Remove duplicates before returning
  return matchedUsers.toSet().toList();
}

class FriendAddBottomSheet extends StatefulWidget {
  const FriendAddBottomSheet({super.key});

  @override
  State<FriendAddBottomSheet> createState() => _FriendAddBottomSheetState();
}

class _FriendAddBottomSheetState extends State<FriendAddBottomSheet> {
  String _searchText = '';
  late Future<List<Friendship>> _currentFriendshipFuture;
  List<fc.Contact>? _cachedContacts;

  @override
  void initState() {
    super.initState();
    _currentFriendshipFuture = _requestedFriendshipFuture();
  }

  Future<List<Friendship>> _requestedFriendshipFuture() async {
    return Friendship.getRequestedFriendships();
  }

  @override
  Widget build(BuildContext context) {
    final userSearchFuture = _fetchUserSearchResults();
    final userPendingFuture = _fetchPendingFriendRequests();
    final userContactFuture = _fetchContactSuggestions();
    final userRequestedFuture = _fetchRequestedUsers();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 1,
        snap: true,
        builder: (context, scrollController) {
          return RoundedContainer(
            child: Scaffold(
                appBar: AppBar(
                  title: Text(AppLocalizations.of(context)!.addFriends),
                  centerTitle: true,
                ),
                body: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: SearchBar(
                          elevation: WidgetStateProperty.all(0),
                          hintText:
                              AppLocalizations.of(context)!.addFriendshipSelectionEmpty,
                          onChanged: (value) {
                            setState(() {
                              _currentFriendshipFuture = _requestedFriendshipFuture();
                              _searchText = value;
                            });
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SearchResultList(
                        userSearchFuture: userSearchFuture,
                        onRequest: _requestFriendship,

                        searchText: _searchText,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: PendingRequestList(
                        userPendingFuture: userPendingFuture,
                        onAccept: _acceptFriendship,
                        onDecline: _declineFriendship,

                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ContactSuggestionList(
                        userContactFuture: userContactFuture,
                        onRequest: _requestFriendship,

                      ),
                    ),
                    SliverToBoxAdapter(
                      child: RequestedFriendshipList(
                        userRequestedFuture: userRequestedFuture,
                        onCancel: _cancelFriendRequest,

                      ),
                    ),
                  ],
                ),
            ),
          );
        },
      ),
    );
  }

  Future<List<SupaUser>> _fetchUserSearchResults() async {
    if (_searchText.isEmpty) {
      return List.empty(growable: true);
    }

    final friendship = await _currentFriendshipFuture;

    List<String> selectedUsers = List.empty(growable: true);
    for (var friendship in friendship) {
      selectedUsers.add(friendship.user.email);
    }
    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    return await UserRepository.fetchData(_searchText, selectedUsers, 5);
  }

  Future<List<Map<String, dynamic>>> _fetchPendingFriendRequests() async {
    return supabase
        .from('friendship')
        .select('...requester(*)')
        .eq('addressee', supabase.auth.currentUser?.email ?? '')
        .eq('status', 'pending')
        .ilike('requester.display_name', '%$_searchText%')
        .order('display_name', ascending: false, referencedTable: 'requester');
  }

  Future<List<SupaUser>> _fetchContactSuggestions() async {
    // Check cache first
    if (_cachedContacts == null) {
      if (!await fc.FlutterContacts.requestPermission()) {
        return []; // Return empty list if permission is denied
      }
      // Fetch contacts only if cache is empty and permission granted
      _cachedContacts =
          await fc.FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    }

    // If contacts are still null (e.g., error during fetch), return empty
    if (_cachedContacts == null) {
      return [];
    }

    // Fetch friendships and build selected users list (async)
    final friendship = await _currentFriendshipFuture;
    List<String> selectedUsers = friendship.map((f) => f.user.email).toList();
    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    // Fetch all available users matching the search text (async)
    final allAvailableUser = await UserRepository.fetchData("%$_searchText%", selectedUsers, null);
    final availableUserMap = {
      for (var user in allAvailableUser) user.email.toLowerCase(): user
    };

    // Prepare parameters for the isolate function using cached contacts
    final params = {
      'contacts': _cachedContacts!,
      // Use cached contacts, assert non-null
      'availableUserMap': availableUserMap,
      'searchText': _searchText,
    };

    // Run the contact matching logic in a separate isolate
    return compute(_findContactMatches, params);
  }

  Future<List<SupaUser>> _fetchRequestedUsers() async {
    final friendship = await _currentFriendshipFuture;

    List<SupaUser> requestedUsers = List.empty(growable: true);
    for (var friendship in friendship) {
      if (friendship.status == 'pending' && friendship.isRequester == false) {
        requestedUsers.add(friendship.user);
      }
    }

    return requestedUsers;
  }

  void _cancelFriendRequest(String userEmail, String displayName) async {
    await Friendship.cancel(userEmail).then((_) {
      showSnackBar(context,
          AppLocalizations.of(context)!.friendshipRequestCancel(displayName));

      setState(() {
        _currentFriendshipFuture = _requestedFriendshipFuture();
      });
    });
  }

  void _requestFriendship(String userEmail, String displayName) async {
    Friendship.request(userEmail).then((_) {
      showSnackBar(context,
          AppLocalizations.of(context)!.friendshipRequestSent(displayName));
      sendFriendRequestNotification(context, {userEmail});
      setState(() {
        _currentFriendshipFuture = _requestedFriendshipFuture();
      });
    });
  }

  void _acceptFriendship(String userEmail, String displayName) {
    Friendship.accepted(userEmail).then((_) {
      showSnackBar(context,
          AppLocalizations.of(context)!.friendshipAccept(displayName));
      sendFriendAcceptNotification(context, {userEmail});
      setState(() {
        _currentFriendshipFuture = _requestedFriendshipFuture();
      });
    });
  }

  void _declineFriendship(String userEmail, String displayName) {
    Friendship.decline(userEmail).then((_) {
      showSnackBar(context,
          AppLocalizations.of(context)!.friendshipRequestDecline(displayName));
      setState(() {
        _currentFriendshipFuture = _requestedFriendshipFuture();
      });
    });
  }
}
