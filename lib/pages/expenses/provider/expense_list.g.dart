// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExpenseListNotifier)
const expenseListProvider = ExpenseListNotifierFamily._();

final class ExpenseListNotifierProvider
    extends $AsyncNotifierProvider<ExpenseListNotifier, List<Expense>> {
  const ExpenseListNotifierProvider._({
    required ExpenseListNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'expenseListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseListNotifierHash();

  @override
  String toString() {
    return r'expenseListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ExpenseListNotifier create() => ExpenseListNotifier();

  @override
  bool operator ==(Object other) {
    return other is ExpenseListNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseListNotifierHash() =>
    r'8bc2bb3aeb8c1b6c53a16603a8b03f8ca78fbe10';

final class ExpenseListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ExpenseListNotifier,
          AsyncValue<List<Expense>>,
          List<Expense>,
          FutureOr<List<Expense>>,
          String
        > {
  const ExpenseListNotifierFamily._()
    : super(
        retry: null,
        name: r'expenseListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExpenseListNotifierProvider call(String groupId) =>
      ExpenseListNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'expenseListProvider';
}

abstract class _$ExpenseListNotifier extends $AsyncNotifier<List<Expense>> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  FutureOr<List<Expense>> build(String groupId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<List<Expense>>, List<Expense>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Expense>>, List<Expense>>,
              AsyncValue<List<Expense>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
