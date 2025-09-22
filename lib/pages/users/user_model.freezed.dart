// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SupaUser {

 String get email; String? get userId; String? get firstName; String? get lastName; String get displayName; String? get paypalMe; String? get iban; String? get locale; String? get createdAt; bool get isGuest;
/// Create a copy of SupaUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupaUserCopyWith<SupaUser> get copyWith => _$SupaUserCopyWithImpl<SupaUser>(this as SupaUser, _$identity);

  /// Serializes this SupaUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupaUser&&(identical(other.email, email) || other.email == email)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.paypalMe, paypalMe) || other.paypalMe == paypalMe)&&(identical(other.iban, iban) || other.iban == iban)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isGuest, isGuest) || other.isGuest == isGuest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,userId,firstName,lastName,displayName,paypalMe,iban,locale,createdAt,isGuest);

@override
String toString() {
  return 'SupaUser(email: $email, userId: $userId, firstName: $firstName, lastName: $lastName, displayName: $displayName, paypalMe: $paypalMe, iban: $iban, locale: $locale, createdAt: $createdAt, isGuest: $isGuest)';
}


}

/// @nodoc
abstract mixin class $SupaUserCopyWith<$Res>  {
  factory $SupaUserCopyWith(SupaUser value, $Res Function(SupaUser) _then) = _$SupaUserCopyWithImpl;
@useResult
$Res call({
 String email, String? userId, String? firstName, String? lastName, String displayName, String? paypalMe, String? iban, String? locale, String? createdAt, bool isGuest
});




}
/// @nodoc
class _$SupaUserCopyWithImpl<$Res>
    implements $SupaUserCopyWith<$Res> {
  _$SupaUserCopyWithImpl(this._self, this._then);

  final SupaUser _self;
  final $Res Function(SupaUser) _then;

/// Create a copy of SupaUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = null,Object? userId = freezed,Object? firstName = freezed,Object? lastName = freezed,Object? displayName = null,Object? paypalMe = freezed,Object? iban = freezed,Object? locale = freezed,Object? createdAt = freezed,Object? isGuest = null,}) {
  return _then(_self.copyWith(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,paypalMe: freezed == paypalMe ? _self.paypalMe : paypalMe // ignore: cast_nullable_to_non_nullable
as String?,iban: freezed == iban ? _self.iban : iban // ignore: cast_nullable_to_non_nullable
as String?,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,isGuest: null == isGuest ? _self.isGuest : isGuest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SupaUser].
extension SupaUserPatterns on SupaUser {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupaUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupaUser() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupaUser value)  $default,){
final _that = this;
switch (_that) {
case _SupaUser():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupaUser value)?  $default,){
final _that = this;
switch (_that) {
case _SupaUser() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String email,  String? userId,  String? firstName,  String? lastName,  String displayName,  String? paypalMe,  String? iban,  String? locale,  String? createdAt,  bool isGuest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupaUser() when $default != null:
return $default(_that.email,_that.userId,_that.firstName,_that.lastName,_that.displayName,_that.paypalMe,_that.iban,_that.locale,_that.createdAt,_that.isGuest);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String email,  String? userId,  String? firstName,  String? lastName,  String displayName,  String? paypalMe,  String? iban,  String? locale,  String? createdAt,  bool isGuest)  $default,) {final _that = this;
switch (_that) {
case _SupaUser():
return $default(_that.email,_that.userId,_that.firstName,_that.lastName,_that.displayName,_that.paypalMe,_that.iban,_that.locale,_that.createdAt,_that.isGuest);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String email,  String? userId,  String? firstName,  String? lastName,  String displayName,  String? paypalMe,  String? iban,  String? locale,  String? createdAt,  bool isGuest)?  $default,) {final _that = this;
switch (_that) {
case _SupaUser() when $default != null:
return $default(_that.email,_that.userId,_that.firstName,_that.lastName,_that.displayName,_that.paypalMe,_that.iban,_that.locale,_that.createdAt,_that.isGuest);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupaUser implements SupaUser {
  const _SupaUser({required this.email, this.userId, this.firstName, this.lastName, required this.displayName, this.paypalMe, this.iban, this.locale, this.createdAt, this.isGuest = false});
  factory _SupaUser.fromJson(Map<String, dynamic> json) => _$SupaUserFromJson(json);

@override final  String email;
@override final  String? userId;
@override final  String? firstName;
@override final  String? lastName;
@override final  String displayName;
@override final  String? paypalMe;
@override final  String? iban;
@override final  String? locale;
@override final  String? createdAt;
@override@JsonKey() final  bool isGuest;

/// Create a copy of SupaUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupaUserCopyWith<_SupaUser> get copyWith => __$SupaUserCopyWithImpl<_SupaUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupaUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupaUser&&(identical(other.email, email) || other.email == email)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.paypalMe, paypalMe) || other.paypalMe == paypalMe)&&(identical(other.iban, iban) || other.iban == iban)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isGuest, isGuest) || other.isGuest == isGuest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,userId,firstName,lastName,displayName,paypalMe,iban,locale,createdAt,isGuest);

@override
String toString() {
  return 'SupaUser(email: $email, userId: $userId, firstName: $firstName, lastName: $lastName, displayName: $displayName, paypalMe: $paypalMe, iban: $iban, locale: $locale, createdAt: $createdAt, isGuest: $isGuest)';
}


}

/// @nodoc
abstract mixin class _$SupaUserCopyWith<$Res> implements $SupaUserCopyWith<$Res> {
  factory _$SupaUserCopyWith(_SupaUser value, $Res Function(_SupaUser) _then) = __$SupaUserCopyWithImpl;
@override @useResult
$Res call({
 String email, String? userId, String? firstName, String? lastName, String displayName, String? paypalMe, String? iban, String? locale, String? createdAt, bool isGuest
});




}
/// @nodoc
class __$SupaUserCopyWithImpl<$Res>
    implements _$SupaUserCopyWith<$Res> {
  __$SupaUserCopyWithImpl(this._self, this._then);

  final _SupaUser _self;
  final $Res Function(_SupaUser) _then;

/// Create a copy of SupaUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = null,Object? userId = freezed,Object? firstName = freezed,Object? lastName = freezed,Object? displayName = null,Object? paypalMe = freezed,Object? iban = freezed,Object? locale = freezed,Object? createdAt = freezed,Object? isGuest = null,}) {
  return _then(_SupaUser(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,paypalMe: freezed == paypalMe ? _self.paypalMe : paypalMe // ignore: cast_nullable_to_non_nullable
as String?,iban: freezed == iban ? _self.iban : iban // ignore: cast_nullable_to_non_nullable
as String?,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,isGuest: null == isGuest ? _self.isGuest : isGuest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
