import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class SupaUser with _$SupaUser {
  const factory SupaUser({
    required String email,
    String? userId,
    String? firstName,
    String? lastName,
    @Default('') String displayName,
    String? username,
    String? usernameCode,
    String? paypalMe,
    String? iban,
    String? locale,
    String? createdAt,
    @Default(false) bool isGuest,
  }) = _SupaUser;

  factory SupaUser.fromJson(Map<String, dynamic> json) => _$SupaUserFromJson(json);
}

extension SupaUserX on SupaUser {
  String get fullUsername => username != null && usernameCode != null
      ? '$username#$usernameCode'
      : displayName;

  bool get needsOnboarding => username == null || username!.isEmpty;
}