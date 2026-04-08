import 'dart:async';

import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../main.dart';

part 'friend_add_notifier.g.dart';

class FriendAddState {
  final List<SupaUser> searchResults;
  final List<Map<String, dynamic>> pendingRequests;
  final List<SupaUser> contactSuggestions;
  final List<SupaUser> requestedFriendships;
  final bool isLoading;
  final String searchText;

  const FriendAddState({
    this.searchResults = const [],
    this.pendingRequests = const [],
    this.contactSuggestions = const [],
    this.requestedFriendships = const [],
    this.isLoading = true,
    this.searchText = '',
  });

  FriendAddState copyWith({
    List<SupaUser>? searchResults,
    List<Map<String, dynamic>>? pendingRequests,
    List<SupaUser>? contactSuggestions,
    List<SupaUser>? requestedFriendships,
    bool? isLoading,
    String? searchText,
  }) {
    return FriendAddState(
      searchResults: searchResults ?? this.searchResults,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      contactSuggestions: contactSuggestions ?? this.contactSuggestions,
      requestedFriendships: requestedFriendships ?? this.requestedFriendships,
      isLoading: isLoading ?? this.isLoading,
      searchText: searchText ?? this.searchText,
    );
  }
}

Future<List<SupaUser>> _findContactMatches(Map<String, dynamic> params) async {
  final List<fc.Contact> contacts = params['contacts'];
  final Map<String, SupaUser> availableUserMap = params['availableUserMap'];
  final String searchText = params['searchText'].toLowerCase();
  List<SupaUser> matchedUsers = [];

  for (var contact in contacts) {
    bool nameMatches = (contact.displayName ?? '').toLowerCase().contains(searchText);
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
  return matchedUsers.toSet().toList();
}

@riverpod
class FriendAddNotifier extends _$FriendAddNotifier {
  List<fc.Contact>? _cachedContacts;

  @override
  FriendAddState build() {
    _loadAll('');
    return const FriendAddState();
  }

  void updateSearch(String text) {
    state = state.copyWith(searchText: text, isLoading: true);
    _loadAll(text);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadAll(state.searchText);
  }

  Future<void> _loadAll(String searchText) async {
    try {
      final friendships = await FriendshipRepository.getRequestedFriendships();

      final results = await Future.wait([
        _fetchSearchResults(searchText, friendships),
        _fetchPendingRequests(searchText),
        _fetchContactSuggestions(searchText, friendships),
        _fetchRequestedUsers(friendships),
      ]);

      if (!ref.mounted) return;
      state = state.copyWith(
        searchResults: results[0] as List<SupaUser>,
        pendingRequests: results[1] as List<Map<String, dynamic>>,
        contactSuggestions: results[2] as List<SupaUser>,
        requestedFriendships: results[3] as List<SupaUser>,
        isLoading: false,
        searchText: searchText,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<List<SupaUser>> _fetchSearchResults(
      String searchText, List<Friendship> friendships) async {
    if (searchText.isEmpty) return [];

    List<String> selectedUsers = friendships.map((f) => f.user.email).toList();
    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    return await UserRepository.fetchData(searchText, selectedUsers, 5);
  }

  Future<List<Map<String, dynamic>>> _fetchPendingRequests(String searchText) async {
    final escaped = searchText.replaceAll(RegExp(r'[%,()\\]'), '');
    return supabase
        .from('friendship')
        .select('...requester(*)')
        .eq('addressee', supabase.auth.currentUser?.email ?? '')
        .eq('status', 'pending')
        .ilike('requester.display_name', '%$escaped%')
        .order('display_name', ascending: false, referencedTable: 'requester');
  }

  Future<List<SupaUser>> _fetchContactSuggestions(
      String searchText, List<Friendship> friendships) async {
    if (_cachedContacts == null) {
      final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      if (status != fc.PermissionStatus.granted && status != fc.PermissionStatus.limited) {
        return [];
      }
      _cachedContacts = await fc.FlutterContacts.getAll(
          properties: {fc.ContactProperty.name, fc.ContactProperty.email});
    }

    if (_cachedContacts == null || _cachedContacts!.isEmpty) return [];

    // Collect all emails from contacts for an exact-match DB query.
    final contactEmails = _cachedContacts!
        .expand((c) => c.emails.map((e) => e.address.toLowerCase()))
        .toSet()
        .toList();

    if (contactEmails.isEmpty) return [];

    List<String> excludeEmails = friendships.map((f) => f.user.email).toList();
    excludeEmails.add(supabase.auth.currentUser?.email ?? '');

    final matchedUsers = await UserRepository.fetchByEmails(contactEmails, excludeEmails);
    final availableUserMap = {
      for (var user in matchedUsers) user.email.toLowerCase(): user
    };

    final params = {
      'contacts': _cachedContacts!,
      'availableUserMap': availableUserMap,
      'searchText': searchText,
    };

    return compute(_findContactMatches, params);
  }

  Future<List<SupaUser>> _fetchRequestedUsers(List<Friendship> friendships) async {
    return friendships
        .where((f) => f.status == 'pending' && !f.isIncomingRequest)
        .map((f) => f.user)
        .toList();
  }
}
