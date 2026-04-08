// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SupaUser _$SupaUserFromJson(Map<String, dynamic> json) => _SupaUser(
  email: json['email'] as String,
  userId: json['user_id'] as String?,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  displayName: json['display_name'] as String? ?? '',
  username: json['username'] as String?,
  usernameCode: json['username_code'] as String?,
  paypalMe: json['paypal_me'] as String?,
  iban: json['iban'] as String?,
  locale: json['locale'] as String?,
  createdAt: json['created_at'] as String?,
  isGuest: json['is_guest'] as bool? ?? false,
);

Map<String, dynamic> _$SupaUserToJson(_SupaUser instance) => <String, dynamic>{
  'email': instance.email,
  'user_id': instance.userId,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'display_name': instance.displayName,
  'username': instance.username,
  'username_code': instance.usernameCode,
  'paypal_me': instance.paypalMe,
  'iban': instance.iban,
  'locale': instance.locale,
  'created_at': instance.createdAt,
  'is_guest': instance.isGuest,
};
