// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_by_id.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One expense, loaded by id for a route opened from its location. Subscribes
/// to nothing; the group's realtime refresh lives on `groupDetailProvider`.

@ProviderFor(expenseById)
final expenseByIdProvider = ExpenseByIdFamily._();

/// One expense, loaded by id for a route opened from its location. Subscribes
/// to nothing; the group's realtime refresh lives on `groupDetailProvider`.

final class ExpenseByIdProvider
    extends $FunctionalProvider<AsyncValue<Expense>, Expense, FutureOr<Expense>>
    with $FutureModifier<Expense>, $FutureProvider<Expense> {
  /// One expense, loaded by id for a route opened from its location. Subscribes
  /// to nothing; the group's realtime refresh lives on `groupDetailProvider`.
  ExpenseByIdProvider._({
    required ExpenseByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'expenseByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseByIdHash();

  @override
  String toString() {
    return r'expenseByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Expense> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Expense> create(Ref ref) {
    final argument = this.argument as String;
    return expenseById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseByIdHash() => r'8e20f1311997dd4c33b899c8de43411ca0ba634e';

/// One expense, loaded by id for a route opened from its location. Subscribes
/// to nothing; the group's realtime refresh lives on `groupDetailProvider`.

final class ExpenseByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Expense>, String> {
  ExpenseByIdFamily._()
    : super(
        retry: null,
        name: r'expenseByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One expense, loaded by id for a route opened from its location. Subscribes
  /// to nothing; the group's realtime refresh lives on `groupDetailProvider`.

  ExpenseByIdProvider call(String expenseId) =>
      ExpenseByIdProvider._(argument: expenseId, from: this);

  @override
  String toString() => r'expenseByIdProvider';
}
