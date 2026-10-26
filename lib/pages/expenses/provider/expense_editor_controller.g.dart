// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The expense editor's rules, owned apart from its widgets so they can be
/// proven without one.
///
/// One controller per opened editor: an auto-dispose family keyed on
/// [ExpenseEditorArgs]. It never `watch`es — watching [stickyRateProvider]
/// would re-run [build] and wipe the session when the stored rates hydrate and
/// when the user resets a rate. It reads the notifier and awaits `hydrated`
/// before reading a rate, and after every `await` it checks `ref.mounted`
/// before touching state.

@ProviderFor(ExpenseEditorController)
final expenseEditorControllerProvider = ExpenseEditorControllerFamily._();

/// The expense editor's rules, owned apart from its widgets so they can be
/// proven without one.
///
/// One controller per opened editor: an auto-dispose family keyed on
/// [ExpenseEditorArgs]. It never `watch`es — watching [stickyRateProvider]
/// would re-run [build] and wipe the session when the stored rates hydrate and
/// when the user resets a rate. It reads the notifier and awaits `hydrated`
/// before reading a rate, and after every `await` it checks `ref.mounted`
/// before touching state.
final class ExpenseEditorControllerProvider
    extends $NotifierProvider<ExpenseEditorController, ExpenseEditorState> {
  /// The expense editor's rules, owned apart from its widgets so they can be
  /// proven without one.
  ///
  /// One controller per opened editor: an auto-dispose family keyed on
  /// [ExpenseEditorArgs]. It never `watch`es — watching [stickyRateProvider]
  /// would re-run [build] and wipe the session when the stored rates hydrate and
  /// when the user resets a rate. It reads the notifier and awaits `hydrated`
  /// before reading a rate, and after every `await` it checks `ref.mounted`
  /// before touching state.
  ExpenseEditorControllerProvider._({
    required ExpenseEditorControllerFamily super.from,
    required ExpenseEditorArgs super.argument,
  }) : super(
         retry: null,
         name: r'expenseEditorControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseEditorControllerHash();

  @override
  String toString() {
    return r'expenseEditorControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ExpenseEditorController create() => ExpenseEditorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExpenseEditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExpenseEditorState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseEditorControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseEditorControllerHash() =>
    r'01a5a14bf5cf13f7a3d48472f46bd6cf7d07e580';

/// The expense editor's rules, owned apart from its widgets so they can be
/// proven without one.
///
/// One controller per opened editor: an auto-dispose family keyed on
/// [ExpenseEditorArgs]. It never `watch`es — watching [stickyRateProvider]
/// would re-run [build] and wipe the session when the stored rates hydrate and
/// when the user resets a rate. It reads the notifier and awaits `hydrated`
/// before reading a rate, and after every `await` it checks `ref.mounted`
/// before touching state.

final class ExpenseEditorControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ExpenseEditorController,
          ExpenseEditorState,
          ExpenseEditorState,
          ExpenseEditorState,
          ExpenseEditorArgs
        > {
  ExpenseEditorControllerFamily._()
    : super(
        retry: null,
        name: r'expenseEditorControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The expense editor's rules, owned apart from its widgets so they can be
  /// proven without one.
  ///
  /// One controller per opened editor: an auto-dispose family keyed on
  /// [ExpenseEditorArgs]. It never `watch`es — watching [stickyRateProvider]
  /// would re-run [build] and wipe the session when the stored rates hydrate and
  /// when the user resets a rate. It reads the notifier and awaits `hydrated`
  /// before reading a rate, and after every `await` it checks `ref.mounted`
  /// before touching state.

  ExpenseEditorControllerProvider call(ExpenseEditorArgs args) =>
      ExpenseEditorControllerProvider._(argument: args, from: this);

  @override
  String toString() => r'expenseEditorControllerProvider';
}

/// The expense editor's rules, owned apart from its widgets so they can be
/// proven without one.
///
/// One controller per opened editor: an auto-dispose family keyed on
/// [ExpenseEditorArgs]. It never `watch`es — watching [stickyRateProvider]
/// would re-run [build] and wipe the session when the stored rates hydrate and
/// when the user resets a rate. It reads the notifier and awaits `hydrated`
/// before reading a rate, and after every `await` it checks `ref.mounted`
/// before touching state.

abstract class _$ExpenseEditorController extends $Notifier<ExpenseEditorState> {
  late final _$args = ref.$arg as ExpenseEditorArgs;
  ExpenseEditorArgs get args => _$args;

  ExpenseEditorState build(ExpenseEditorArgs args);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ExpenseEditorState, ExpenseEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ExpenseEditorState, ExpenseEditorState>,
              ExpenseEditorState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
