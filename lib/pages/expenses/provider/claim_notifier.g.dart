// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claim_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the claim state for a single itemized expense. Loads the expense,
/// exposes its claim units + cost math, and mutates claimer sets per unit.

@ProviderFor(ClaimNotifier)
final claimProvider = ClaimNotifierFamily._();

/// Owns the claim state for a single itemized expense. Loads the expense,
/// exposes its claim units + cost math, and mutates claimer sets per unit.
final class ClaimNotifierProvider
    extends $AsyncNotifierProvider<ClaimNotifier, Expense> {
  /// Owns the claim state for a single itemized expense. Loads the expense,
  /// exposes its claim units + cost math, and mutates claimer sets per unit.
  ClaimNotifierProvider._({
    required ClaimNotifierFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'claimProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$claimNotifierHash();

  @override
  String toString() {
    return r'claimProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ClaimNotifier create() => ClaimNotifier();

  @override
  bool operator ==(Object other) {
    return other is ClaimNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$claimNotifierHash() => r'78fc6dbff3adad2b0bf36201d3ec86b662588b79';

/// Owns the claim state for a single itemized expense. Loads the expense,
/// exposes its claim units + cost math, and mutates claimer sets per unit.

final class ClaimNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ClaimNotifier,
          AsyncValue<Expense>,
          Expense,
          FutureOr<Expense>,
          (String, String)
        > {
  ClaimNotifierFamily._()
    : super(
        retry: null,
        name: r'claimProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns the claim state for a single itemized expense. Loads the expense,
  /// exposes its claim units + cost math, and mutates claimer sets per unit.

  ClaimNotifierProvider call(String groupId, String expenseId) =>
      ClaimNotifierProvider._(argument: (groupId, expenseId), from: this);

  @override
  String toString() => r'claimProvider';
}

/// Owns the claim state for a single itemized expense. Loads the expense,
/// exposes its claim units + cost math, and mutates claimer sets per unit.

abstract class _$ClaimNotifier extends $AsyncNotifier<Expense> {
  late final _$args = ref.$arg as (String, String);
  String get groupId => _$args.$1;
  String get expenseId => _$args.$2;

  FutureOr<Expense> build(String groupId, String expenseId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Expense>, Expense>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Expense>, Expense>,
              AsyncValue<Expense>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
