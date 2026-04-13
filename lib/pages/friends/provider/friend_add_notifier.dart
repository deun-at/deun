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
  final List<SupaUser> contactSuggestions;
  final bool isLoading;
  final String searchText;
  final bool isAmbiguousUsername;
  final bool contactPermissionDenied;

  const FriendAddState({
    this.searchResults = const [],
    this.contactSuggestions = const [],
    this.isLoading = true,
    this.searchText = '',
    this.isAmbiguousUsername = false,
    this.contactPermissionDenied = false,
  });

  FriendAddState copyWith({
    List<SupaUser>? searchResults,
    List<SupaUser>? contactSuggestions,
    bool? isLoading,
    String? searchText,
    bool? isAmbiguousUsername,
    bool? contactPermissionDenied,
  }) {
    return FriendAddState(
      searchResults: searchResults ?? this.searchResults,
      contactSuggestions: contactSuggestions ?? this.contactSuggestions,
      isLoading: isLoading ?? this.isLoading,
      searchText: searchText ?? this.searchText,
      isAmbiguousUsername: isAmbiguousUsername ?? this.isAmbiguousUsername,
      contactPermissionDenied: contactPermissionDenied ?? this.contactPermissionDenied,
    );
  }
}

/// Runs on an isolate: filters cached contacts by search text and matches
/// them against the pre-fetched DB user map.
Future<List<SupaUser>> _filterContactMatches(Map<String, dynamic> params) async {
  final List<fc.Contact> contacts = params['contacts'];
  final Map<String, SupaUser> availableUserMap = params['availableUserMap'];
  final String searchText = params['searchText'].toLowerCase();
  List<SupaUser> matchedUsers = [];

  for (var contact in contacts) {
    // First, find the matched DB user for this contact (by email).
    SupaUser? matchedUser;
    for (var email in contact.emails) {
      final lowerCaseEmail = email.address.toLowerCase();
      if (availableUserMap.containsKey(lowerCaseEmail)) {
        matchedUser = availableUserMap[lowerCaseEmail];
        break;
      }
    }

    if (matchedUser == null) continue;

    if (searchText.isNotEmpty) {
      bool nameMatches = (contact.displayName ?? '').toLowerCase().contains(searchText);
      bool emailMatches =
          contact.emails.any((email) => email.address.toLowerCase().contains(searchText));
      bool usernameMatches = matchedUser.username != null &&
          matchedUser.username!.toLowerCase().contains(searchText);
      bool fullUsernameMatches = matchedUser.username != null &&
          matchedUser.usernameCode != null &&
          '${matchedUser.username}#${matchedUser.usernameCode}'
              .toLowerCase()
              .contains(searchText);

      if (!nameMatches && !emailMatches && !usernameMatches && !fullUsernameMatches) {
        continue;
      }
    }

    matchedUsers.add(matchedUser);
  }
  return matchedUsers.toSet().toList();
}

@riverpod
class FriendAddNotifier extends _$FriendAddNotifier {
  List<fc.Contact>? _cachedContacts;
  List<SupaUser>? _cachedContactUsers;
  List<Friendship>? _cachedFriendships;
  bool _contactPermissionDenied = false;

  @override
  FriendAddState build() {
    _init();
    return const FriendAddState();
  }

  /// Called once on page open. Loads friendships + contacts in parallel,
  /// then fetches matching DB users via a single RPC call.
  Future<void> _init() async {
    try {
      _cachedFriendships = await FriendshipRepository.getRequestedFriendships();
      await _loadContactUsers();

      if (!ref.mounted) return;
      state = state.copyWith(
        contactSuggestions: _cachedContactUsers ?? [],
        isLoading: false,
        contactPermissionDenied: _contactPermissionDenied,
      );
    } catch (e, st) {
      debugPrint('FriendAddNotifier._init error: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  /// Loads device contacts and fetches matching DB users once.
  Future<void> _loadContactUsers() async {
    if (_cachedContacts == null) {
      final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      if (status != fc.PermissionStatus.granted && status != fc.PermissionStatus.limited) {
        _contactPermissionDenied = true;
        return;
      }
      _cachedContacts = await fc.FlutterContacts.getAll(
          properties: {fc.ContactProperty.name, fc.ContactProperty.email});
    }

    if (_cachedContacts == null || _cachedContacts!.isEmpty) return;

    // Collect emails, skipping contacts that only have phone numbers.
    final contactEmails = _cachedContacts!
        .expand((c) => c.emails.map((e) => e.address.toLowerCase()))
        .toSet()
        .toList();

    if (contactEmails.isEmpty) {
      _cachedContactUsers = [];
      return;
    }

    List<String> excludeEmails =
        (_cachedFriendships ?? []).map((f) => f.user.email).toList();
    excludeEmails.add(supabase.auth.currentUser?.email ?? '');

    // Single RPC call instead of chunked inFilter queries.
    _cachedContactUsers =
        await UserRepository.fetchByEmails(contactEmails, excludeEmails);
  }

  /// Called on every debounced keystroke. Runs DB search + local contact
  /// filtering in parallel — no DB call for contacts.
  void updateSearch(String text) {
    state = state.copyWith(searchText: text, isLoading: true);
    _onSearchChanged(text);
  }

  Future<void> _onSearchChanged(String searchText) async {
    try {
      final results = await Future.wait([
        _fetchSearchResults(searchText),
        _filterCachedContacts(searchText),
      ]);

      if (!ref.mounted) return;
      state = state.copyWith(
        searchResults: results[0],
        contactSuggestions: results[1],
        isLoading: false,
        searchText: searchText,
        isAmbiguousUsername: false,
      );
    } on AmbiguousUsernameException {
      final contacts = await _filterCachedContacts(searchText);
      if (!ref.mounted) return;
      state = state.copyWith(
        searchResults: [],
        contactSuggestions: contacts,
        isLoading: false,
        searchText: searchText,
        isAmbiguousUsername: true,
      );
    } catch (e, st) {
      debugPrint('FriendAddNotifier._onSearchChanged error: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<List<SupaUser>> _fetchSearchResults(String searchText) async {
    if (searchText.isEmpty) return [];

    List<String> selectedUsers =
        (_cachedFriendships ?? []).map((f) => f.user.email).toList();
    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    return await UserRepository.fetchData(searchText, selectedUsers, 5);
  }

  /// Pure client-side filter on cached contact users — no DB call.
  Future<List<SupaUser>> _filterCachedContacts(String searchText) async {
    if (_cachedContactUsers == null || _cachedContactUsers!.isEmpty) return [];
    if (_cachedContacts == null || _cachedContacts!.isEmpty) return [];

    final availableUserMap = {
      for (var user in _cachedContactUsers!) user.email.toLowerCase(): user
    };

    final params = {
      'contacts': _cachedContacts!,
      'availableUserMap': availableUserMap,
      'searchText': searchText,
    };

    return compute(_filterContactMatches, params);
  }

  /// Called after a friend request is sent. Refreshes the exclusion list
  /// and reloads both pipelines.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      _cachedFriendships = await FriendshipRepository.getRequestedFriendships();

      // Rebuild contact users with updated exclusion list.
      _cachedContactUsers = null;
      await _loadContactUsers();

      final results = await Future.wait([
        _fetchSearchResults(state.searchText),
        _filterCachedContacts(state.searchText),
      ]);

      if (!ref.mounted) return;
      state = state.copyWith(
        searchResults: results[0],
        contactSuggestions: results[1],
        isLoading: false,
        contactPermissionDenied: _contactPermissionDenied,
      );
    } catch (e, st) {
      debugPrint('FriendAddNotifier.refresh error: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> retryContactPermission() async {
    _cachedContacts = null;
    _cachedContactUsers = null;
    _contactPermissionDenied = false;
    state = state.copyWith(isLoading: true);
    await _init();
  }
}
