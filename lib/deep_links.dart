import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

final _uuidRegExp = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The route a deep link's [fragment] may open, or null when it is not on the
/// allowlist or a parameter is malformed.
String? validateDeepLink(String fragment) {
  final uri = Uri.tryParse(fragment);
  if (uri == null) return null;

  final path = uri.path;
  final params = uri.queryParameters;

  // Allowlisted routes with parameter validation
  if (path == '/group/join') {
    final groupId = params['groupId'];
    if (groupId == null || !_uuidRegExp.hasMatch(groupId)) return null;
    return fragment;
  }

  if (path == '/friend/accept') {
    final email = params['email'];
    final username = params['u'];
    final code = params['c'];
    // Accept either email or username+code
    final hasEmail = email != null && _emailRegExp.hasMatch(email);
    final hasUsername =
        username != null &&
        username.isNotEmpty &&
        code != null &&
        code.isNotEmpty;
    if (!hasEmail && !hasUsername) return null;
    return fragment;
  }

  // Safe static routes (no user-controlled parameters)
  const safeRoutes = [
    '/group',
    '/friend',
    '/setting',
    '/setting/privacy-policy',
    '/setting/contact',
  ];
  if (safeRoutes.contains(path)) return fragment;

  // Reject everything else
  return null;
}

/// Opens every allowlisted deep link the platform delivers. The caller owns
/// the subscription and cancels it.
StreamSubscription<Uri> listenToDeepLinks(
  GlobalKey<NavigatorState> rootNavigatorKey,
) {
  return AppLinks().uriLinkStream.listen((uri) {
    final route = validateDeepLink(uri.fragment);
    final context = rootNavigatorKey.currentContext;
    if (route == null || context == null || !context.mounted) return;
    GoRouter.of(context).go(route);
  });
}
