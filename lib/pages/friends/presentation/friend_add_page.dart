import 'dart:async';

import 'package:deun/constants.dart';
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

  /// Emails the user has requested in this session. Flips the per-row button to
  /// "Requested" immediately, before the provider's exclusion-list refresh lands.
  final Set<String> _requestedEmails = {};

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addFriends),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Search field is outside the provider-watched subtree so it never
            // rebuilds when results change — prevents keyboard dismissal.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: _SearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: l10n.addFriendshipSearchHint,
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: _FriendAddResults(
                requestedEmails: _requestedEmails,
                onRequest: _requestFriendship,
                onRequestContactPermission: () {
                  ref.read(friendAddProvider.notifier).retryContactPermission();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestFriendship(String userEmail, String displayName) async {
    try {
      await FriendshipRepository.request(userEmail);
      if (!mounted) return;
      setState(() => _requestedEmails.add(userEmail));
      showSnackBar(context, l10nOf(context).friendshipRequestSent(displayName));
      sendFriendRequestNotification(context, {userEmail});
      unawaited(ref.read(friendAddProvider.notifier).refresh());
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, l10nOf(context).generalError);
    }
  }
}

AppLocalizations l10nOf(BuildContext context) => AppLocalizations.of(context)!;

/// Restyled inset search field: a [SoftCard]-style rounded surface with a
/// leading search glyph and a borderless text field.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : kSoftCardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: hintText,
                hintStyle: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Isolates the provider watch so that rebuilds from data loading
/// don't propagate up to the search field and dismiss the keyboard.
/// Each section uses select() to only rebuild when its own data changes.
class _FriendAddResults extends StatelessWidget {
  const _FriendAddResults({
    required this.requestedEmails,
    required this.onRequest,
    this.onRequestContactPermission,
  });

  final Set<String> requestedEmails;
  final Future<void> Function(String, String) onRequest;
  final VoidCallback? onRequestContactPermission;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Consumer(builder: (context, ref, _) {
            final searchResults = ref.watch(friendAddProvider.select((s) => s.searchResults));
            final searchText = ref.watch(friendAddProvider.select((s) => s.searchText));
            final isLoading = ref.watch(friendAddProvider.select((s) => s.isLoading));
            final isAmbiguous = ref.watch(friendAddProvider.select((s) => s.isAmbiguousUsername));
            return SearchResultList(
              searchResults: searchResults,
              onRequest: onRequest,
              searchText: searchText,
              isLoading: isLoading,
              isAmbiguousUsername: isAmbiguous,
              requestedEmails: requestedEmails,
            );
          }),
        ),
        SliverToBoxAdapter(
          child: Consumer(builder: (context, ref, _) {
            final contactSuggestions = ref.watch(friendAddProvider.select((s) => s.contactSuggestions));
            final isLoading = ref.watch(friendAddProvider.select((s) => s.isLoading));
            final permissionDenied = ref.watch(friendAddProvider.select((s) => s.contactPermissionDenied));
            return ContactSuggestionList(
              contactSuggestions: contactSuggestions,
              onRequest: onRequest,
              isLoading: isLoading,
              contactPermissionDenied: permissionDenied,
              onRequestPermission: onRequestContactPermission,
              requestedEmails: requestedEmails,
            );
          }),
        ),
      ],
    );
  }
}
