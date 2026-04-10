import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/friends/provider/friend_add_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/presentation/search_result_list.dart';
import 'package:deun/pages/friends/presentation/contact_suggestion_list.dart';

class FriendAddPage extends ConsumerStatefulWidget {
  const FriendAddPage({super.key});

  @override
  ConsumerState<FriendAddPage> createState() => _FriendAddPageState();
}

class _FriendAddPageState extends ConsumerState<FriendAddPage> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(friendAddProvider.notifier).updateSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.addFriends),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // SearchBar is outside the provider-watched subtree so it never
          // rebuilds when results change — prevents keyboard dismissal.
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0),
            child: SearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              elevation: WidgetStateProperty.all(0),
              hintText:
                  AppLocalizations.of(context)!.addFriendshipSelectionEmpty,
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _FriendAddResults(
              onRequest: _requestFriendship,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestFriendship(String userEmail, String displayName) async {
    try {
      await FriendshipRepository.request(userEmail);
      if (!mounted) return;
      showSnackBar(context,
          AppLocalizations.of(context)!.friendshipRequestSent(displayName));
      sendFriendRequestNotification(context, {userEmail});
      ref.read(friendAddProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.generalError);
    }
  }

}

/// Isolates the provider watch so that rebuilds from data loading
/// don't propagate up to the SearchBar and dismiss the keyboard.
/// Each section uses select() to only rebuild when its own data changes.
class _FriendAddResults extends StatelessWidget {
  const _FriendAddResults({
    required this.onRequest,
  });

  final Future<void> Function(String, String) onRequest;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Consumer(builder: (context, ref, _) {
            final searchResults = ref.watch(friendAddProvider.select((s) => s.searchResults));
            final searchText = ref.watch(friendAddProvider.select((s) => s.searchText));
            final isLoading = ref.watch(friendAddProvider.select((s) => s.isLoading));
            return SearchResultList(
              searchResults: searchResults,
              onRequest: onRequest,
              searchText: searchText,
              isLoading: isLoading,
            );
          }),
        ),
        SliverToBoxAdapter(
          child: Consumer(builder: (context, ref, _) {
            final contactSuggestions = ref.watch(friendAddProvider.select((s) => s.contactSuggestions));
            final isLoading = ref.watch(friendAddProvider.select((s) => s.isLoading));
            return ContactSuggestionList(
              contactSuggestions: contactSuggestions,
              onRequest: onRequest,
              isLoading: isLoading,
            );
          }),
        ),
      ],
    );
  }
}
