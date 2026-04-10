import 'package:deun/main.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'pages/users/user_model.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

@Riverpod(keepAlive: true)
class UserDetailNotifier extends _$UserDetailNotifier {
  @override
  FutureOr<SupaUser> build() async {
    return await fetchUserDetail();
  }

  Future<SupaUser> fetchUserDetail() async {
    return await UserRepository.fetchDetail(supabase.auth.currentUser!.email ?? '');
  }
}

@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale? build() => null;

  void setLocale(Locale locale) => state = locale;

  void resetLocale() => state = null;
}
