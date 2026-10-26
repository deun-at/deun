import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/settings/card_fee_sheet.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants.dart';
import '../../../provider.dart';
import '../../../widgets/category_selector.dart';
import '../../../widgets/currency_picker_sheet.dart';
import '../../../widgets/motion.dart';
import '../../../widgets/restyle/app_segmented_control.dart';
import '../../../widgets/restyle/dashed_ghost_button.dart';
import '../../../widgets/restyle/discard_sheet.dart';
import '../../../widgets/restyle/expense_picker_sheets.dart';
import '../../../widgets/restyle/section_label.dart';
import '../../../widgets/theme_builder.dart';
import '../../groups/data/group_model.dart';
import '../../groups/data/member_display.dart';
import '../data/editor_mode.dart';
import '../data/expense_category.dart';
import '../data/expense_conversion.dart';
import '../data/expense_deletion_impact.dart';
import '../data/expense_draft.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';
import '../data/itemized_totals.dart';
import '../data/receipt_scan_result.dart';
import '../provider/expense_editor_controller.dart';
import '../service/rate_source.dart';
import 'editor/editor_currency_rate_section.dart';
import 'editor/editor_delete_action.dart';
import 'editor/editor_entry_list.dart';
import 'editor/editor_form_reading.dart';
import 'editor/editor_itemized_header.dart';
import 'editor/editor_name_field.dart';
import 'editor/editor_paid_when_card.dart';
import 'editor/editor_quick_amount.dart';
import 'editor/editor_save_footer.dart';
import 'receipt_scanner_sheet.dart';

/// The editor's write, as an injectable function.
///
/// Signature-compatible with [ExpenseRepository.saveAll] so production passes
/// the repository method itself. Its point is testability: the save payload —
/// the [ExpenseDraft] AND the [ExpenseConversion] the provenance is written
/// from — is otherwise unreachable from a widget test, which is what let a
/// re-conversion on reload survive review.
typedef ExpenseSaver =
    Future<void> Function(
      String groupId,
      String? expenseId,
      ExpenseDraft draft, {
      required Currency currency,
      ExpenseConversion? conversion,
      required NotificationSender notifications,
    });

/// The editor's receipt scanner, as an injectable function. Resolves to the
/// scanned receipt, or null when the scan was dismissed.
///
/// Null in production → [_showReceiptScannerSheet]. Its point is testability:
/// a rescan inside the editor is otherwise unreachable from a widget test.
typedef ReceiptScanner =
    Future<ReceiptScanResult?> Function(BuildContext context);

/// The production scanner: the [ReceiptScannerSheet] as a modal bottom sheet.
Future<ReceiptScanResult?> _showReceiptScannerSheet(BuildContext context) =>
    showModalBottomSheet<ReceiptScanResult>(
      context: context,
      sheetAnimationStyle: kSheetAnimationStyle,
      barrierColor: kSheetBarrierColor,
      builder: (context) => const ReceiptScannerSheet(),
    );

class ExpenseDetail extends ConsumerStatefulWidget {
  const ExpenseDetail({
    super.key,
    required this.group,
    this.expense,
    this.receiptResult,
    this.loadGroupPaybacks,
    this.saveExpense,
    this.lookupRate,
    this.deleteExpense,
    this.scanReceipt,
  });

  final Group group;
  final Expense? expense;
  final ReceiptScanResult? receiptResult;

  /// Test seam for the group's payback probe. Null in production →
  /// [ExpenseRepository.fetchPaybackRows].
  final GroupPaybackLoader? loadGroupPaybacks;

  /// Test seam for the expense write. Null in production →
  /// [ExpenseRepository.saveAll].
  final ExpenseSaver? saveExpense;

  /// Test seam for the historical-rate prefill. Null in production →
  /// [fetchRate].
  final RateLookup? lookupRate;

  /// Test seam for the delete write. Null in production →
  /// [ExpenseRepository.delete].
  final ExpenseDeleter? deleteExpense;

  /// Test seam for the in-editor receipt scan (the Itemized header's Scan
  /// pill). Null in production → the [ReceiptScannerSheet] bottom sheet.
  final ReceiptScanner? scanReceipt;

  @override
  ConsumerState<ExpenseDetail> createState() => _ExpenseDetailState();
}

/// The expense editor's screen: the form, its text controllers and the sheets
/// it opens. Every rule it follows (rate, entries, mode, save) lives in
/// [ExpenseEditorController]; this State reads that state and reports intents.
class _ExpenseDetailState extends ConsumerState<ExpenseDetail> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: "0");

  /// Mirrors the controller's rate text; see [_onEditorChanged].
  final _rateController = TextEditingController();

  late final ExpenseEditorArgs _args;
  late final List<GroupMember> _members;

  ExpenseEditorState get _editor =>
      ref.read(expenseEditorControllerProvider(_args));
  ExpenseEditorController get _controller =>
      ref.read(expenseEditorControllerProvider(_args).notifier);

  /// True when the editor was opened on an existing expense. Mirrors
  /// `group_detail_edit.dart`'s `_isEdit` — every mode-sensitive label on this
  /// screen (header title, footer CTA) branches on it so an edit never reads
  /// as an add.
  bool get _isEdit => widget.expense != null;

  /// Whether the user has touched the form (drives the discard guard).
  bool _isDirty = false;

  /// Set only on the success path of [_closeAfterWrite], immediately before its
  /// pop, and by the discard sheet's own confirm. A failed write never sets
  /// it, so closing after a failure still asks before dropping the form.
  bool _bypassDiscardGuard = false;

  ExpenseCategory? _detectedCategory;

  /// Ticks whenever anything the conversion sheet renders changes. The sheet
  /// is a separate route, so a `setState` here does not reach it — this does.
  final _conversionRevision = ValueNotifier<int>(0);

  /// What the conversion sheet listens to: the rate text and everything else
  /// it renders. Built once — the sheet can be opened many times.
  late final Listenable _conversionListenable = Listenable.merge([
    _rateController,
    _conversionRevision,
  ]);

  /// The date the expense carries right now — what a historical rate is asked
  /// for. Reads the live form field so a date change is visible immediately,
  /// falling back to the loaded expense and then to today.
  DateTime get _expenseDate {
    final field = _formKey.currentState?.fields['expense_date']?.value;
    if (field is DateTime) return field;
    final loaded = widget.expense?.expenseDate;
    return loaded != null ? DateTime.parse(loaded) : DateTime.now();
  }

  @override
  void initState() {
    super.initState();

    _args = ExpenseEditorArgs(
      group: widget.group,
      expense: widget.expense,
      receiptResult: widget.receiptResult,
      lookupRate: widget.lookupRate,
    );
    // The screen's own subscription: keeps this editor's controller alive for
    // exactly the screen's life, and mirrors the rate text into the field.
    ref.listenManual(
      expenseEditorControllerProvider(_args),
      _onEditorChanged,
      fireImmediately: true,
    );
    final entryCurrency = _editor.entryCurrency;

    _members = widget.group.activeMembers;
    _detectedCategory = widget.expense?.category;
    _nameController.text = widget.expense?.name ?? '';

    // Initialize amount controller from first entry data
    if (widget.expense != null && widget.expense!.expenseEntries.isNotEmpty) {
      final firstEntry = widget.expense!.expenseEntries.values.first;
      _amountController.text = unitPriceFieldTextForTotal(
        firstEntry.enteredLineTotal,
        firstEntry.quantity,
        entryCurrency,
      );
    } else if (widget.receiptResult != null &&
        widget.receiptResult!.total != null &&
        widget.receiptResult!.lineItems.isEmpty) {
      _amountController.text = amountToFieldText(
        widget.receiptResult!.total!,
        entryCurrency,
      );
    }

    // New (non-receipt) expense opens on the Quick amount card — pop the amount
    // keypad after the first frame so the amount can be typed immediately
    // (F100). Editing an existing expense, or a scanned receipt (amount already
    // filled), opens normally.
    if (widget.expense == null && widget.receiptResult == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openAmountKeypadForFirstEntry();
      });
    }

    // Apply receipt merchant name and date after first frame (form needs to be built)
    if (widget.receiptResult != null) {
      final receipt = widget.receiptResult!;
      if (receipt.merchantName != null) {
        _nameController.text = receipt.merchantName!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (receipt.merchantName != null) {
          _formKey.currentState?.fields['name']?.didChange(
            receipt.merchantName,
          );
          _detectAndUpdateCategory(receipt.merchantName!);
        }
        if (receipt.date != null) {
          _formKey.currentState?.fields['expense_date']?.didChange(
            receipt.date,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _conversionRevision.dispose();
    super.dispose();
  }

  /// Mirrors the controller into what lives outside it: the rate field's text,
  /// written only when the controller changed it (a prefill, a pick, a reset,
  /// a switch-back) so typing never moves the cursor; and the conversion
  /// sheet, which is a separate route and listens to [_conversionRevision].
  void _onEditorChanged(ExpenseEditorState? previous, ExpenseEditorState next) {
    if (_rateController.text != next.rateText) {
      _rateController.text = next.rateText;
    }
    _conversionRevision.value++;
  }

  void _detectAndUpdateCategory(String title) {
    if (title.isNotEmpty) {
      final detectedCategory = CategoryDetector.detectCategory(title);
      final currentCategory =
          _formKey.currentState?.fields['category']?.value as ExpenseCategory?;

      // Only auto-update if no category is currently selected or if the existing category is 'other'
      if (currentCategory == null || currentCategory == ExpenseCategory.other) {
        if (detectedCategory != ExpenseCategory.other) {
          setState(() {
            _detectedCategory = detectedCategory;
          });
          _formKey.currentState?.fields['category']?.didChange(
            detectedCategory,
          );
        }
      }
    }
  }

  /// Auto-open entry point for a new expense: resolves the Quick amount card's
  /// form field and opens the keypad through the same path the tap uses.
  /// No-op if the form/field isn't ready.
  void _openAmountKeypadForFirstEntry() {
    final entries = _editor.entries;
    if (entries.isEmpty) return;
    final field = _formKey
        .currentState
        ?.fields["expense_entry[${entries.first.index}][amount]"];
    if (field == null) return;
    openEditorAmountKeypad(
      context,
      field: field,
      amountController: _amountController,
      currency: _editor.entryCurrency,
      onAmountChanged: () => setState(() {}),
    );
  }

  void _addNewEntry() =>
      _controller.addEntry(quickAmountText: _amountController.text);

  /// Maps the Quick/Itemized toggle onto the controller's mode. The Quick amount
  /// field and the snackbar are the screen's; the entries are the controller's.
  void _onEditorModeChanged(EditorMode mode) {
    final editor = _editor;
    if (mode == editor.editorMode) return;
    // Whether this Itemized → Quick switch drops per-item detail; the notice
    // fires after the switch so the messenger sees the settled tree.
    final collapsedItems =
        mode == EditorMode.quick && editor.entries.length > 1;
    final amount = _controller.setMode(
      mode,
      quickAmountText: _amountController.text,
      itemizedTotal: _itemizedTotalFromForm(),
      firstAmountFieldText: editor.entries.isEmpty
          ? null
          : _formKey
                .currentState
                ?.fields["expense_entry[${editor.entries.first.index}][amount]"]
                ?.value
                ?.toString(),
    );
    if (amount != null) setState(() => _amountController.text = amount);
    if (collapsedItems && mounted) {
      showSnackBar(
        context,
        AppLocalizations.of(context)!.editorModeCollapseNotice,
      );
    }
  }

  List<ItemLine> _formLines() =>
      editorFormLines(_formKey.currentState, _editor.entries);

  /// Sum of the current item line totals in the ENTRY currency, read live from
  /// the form fields so the header tracks edits.
  double _itemizedTotalFromForm() => itemizedTotal(_formLines());

  Future<void> _scanReceipt() async {
    final result = await (widget.scanReceipt ?? _showReceiptScannerSheet)(
      context,
    );
    if (result == null || !mounted) return;
    if (result.merchantName != null) {
      _nameController.text = result.merchantName!;
      _formKey.currentState?.fields['name']?.didChange(result.merchantName);
      _detectAndUpdateCategory(result.merchantName!);
    }
    if (result.date != null) {
      _formKey.currentState?.fields['expense_date']?.didChange(result.date);
    }
    // A total-only scan writes the first item's amount field after the
    // controller moved, in the keypad's order (state first, then the field).
    FormFieldState<dynamic>? totalField;
    FormFieldState<dynamic>? quantityField;
    String? totalText;
    if (result.lineItems.isNotEmpty) {
      // A total-only scan keeps whatever layout is showing.
      _controller.replaceEntriesWithScannedLines(result.lineItems);
    } else if (result.total != null) {
      final first = _editor.entries.firstOrNull;
      if (first != null) {
        totalField = _formKey
            .currentState
            ?.fields['expense_entry[${first.index}][amount]'];
        quantityField = _formKey
            .currentState
            ?.fields['expense_entry[${first.index}][quantity]'];
      }
      totalText = _controller.applyScannedTotal(result.total!);
      _amountController.text = totalText;
    }
    setState(() => _isDirty = true);
    quantityField?.didChange('1');
    totalField?.didChange(totalText);
  }

  /// The one place a write's outcome reaches the screen: only a write that
  /// completes closes the editor.
  ///
  /// A failure shows [errorMessage] and the editor stays, with every typed
  /// value intact and the discard guard still armed, so a retry sends the same
  /// form. A success runs [onSuccess], then — only while the editor is still
  /// mounted — bypasses the guard and pops the editor's own route.
  ///
  /// The form stays live while a write is out, and its sheets (date, paid by,
  /// amount, currency) open on the same root navigator as the editor's route.
  /// A bare pop would close such a sheet instead and leave the editor stuck in
  /// flight, so whatever sits above the editor is closed first.
  Future<void> _closeAfterWrite({
    required bool succeeded,
    required String errorMessage,
    required Future<void> Function() onSuccess,
  }) async {
    if (!mounted) return;
    if (!succeeded) {
      showSnackBar(context, errorMessage);
      return;
    }
    await onSuccess();
    if (!mounted) return;
    _bypassDiscardGuard = true;
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route != null) navigator.popUntil((r) => r == route);
    navigator.pop();
  }

  /// Saves the expense. When [claimable] is true (the itemized
  /// "Add & share for claiming" CTA) every entry is flagged claimable so
  /// [ExpenseRepository.saveAll] explodes the lines into per-unit claim
  /// entries; a plain save leaves the manual-split path untouched.
  Future<void> _saveExpense({bool claimable = false}) async {
    // Single flight across both writes: no save while a delete is out. Checked
    // before the form is touched, so a refused tap leaves the CTA and the
    // header exactly as they were.
    if (_editor.deleteInFlight) return;
    if (!_formKey.currentState!.saveAndValidate()) return;
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final notifications = NotificationSender();
    final outcome = await _controller.save(
      total: _itemizedTotalFromForm(),
      write: (conversion) async {
        // Built inside the write, so an amount that does not parse ends in the
        // save error like any other failed write.
        final onScreen = editorDraftFromForm(
          _formKey.currentState!.value,
          _editor.entries,
          claimable: claimable,
        );
        final draft = claimable
            ? onScreen.markEntriesClaimable(
                // Share with the whole group so everyone is notified that
                // there are items to claim (claim units start unclaimed).
                notifyEmails: _members.map((m) => m.email).toSet(),
              )
            : onScreen;
        await (widget.saveExpense ??
            ref.read(expenseRepositoryProvider).saveAll)(
          widget.group.id,
          widget.expense?.id,
          draft,
          currency: widget.group.currency,
          conversion: conversion,
          notifications: notifications,
        );
      },
    );
    if (!mounted) return;
    switch (outcome) {
      case EditorSaveOutcome.refusedZeroTotal:
        showSnackBar(context, l10n.expenseEntryAmountValidationZero);
      case EditorSaveOutcome.refusedNoRate:
        showSnackBar(context, l10n.expenseRateRequired);
      case EditorSaveOutcome.ignoredInFlight:
        return;
      case EditorSaveOutcome.failed || EditorSaveOutcome.saved:
        await _closeAfterWrite(
          succeeded: outcome == EditorSaveOutcome.saved,
          errorMessage: l10n.expenseCreateError,
          // The confirmation is the check on the CTA, held long enough to read
          // before the route goes. No snackbar: the old one fired after the
          // pop and so was shown over the group detail behind.
          onSuccess: () => Future<void>.delayed(
            reducedIfNeeded(
              Motion.saveConfirmationHold,
              reduceMotion: reduceMotion,
            ),
          ),
        );
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    // Presentation-level guard, same rule as the read view: warn, then allow.
    // A failed probe degrades to today's plain prompt.
    final impact = await _controller.probeDeletion(
      () => probeDeletionImpact(
        expense,
        loader:
            widget.loadGroupPaybacks ??
            (groupId) =>
                ref.read(expenseRepositoryProvider).fetchPaybackRows(groupId),
      ),
    );
    if (impact == null || !mounted) return;

    final confirmed = await showEditorDeleteConfirmation(
      context,
      impact: impact,
      currencyCode: widget.group.currencyCode,
    );
    if (!confirmed || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final outcome = await _controller.delete(
      () =>
          (widget.deleteExpense ?? ref.read(expenseRepositoryProvider).delete)(
            expense.id,
            expense.groupId,
          ),
    );
    if (outcome == EditorDeleteOutcome.ignoredInFlight) return;
    await _closeAfterWrite(
      succeeded: outcome == EditorDeleteOutcome.deleted,
      errorMessage: l10n.expenseDeleteError,
      onSuccess: () async {
        // Before the pop on purpose: the messenger is an ancestor of the
        // editor route, so the confirmation outlives it and lands on the
        // screen behind. Deletes keep a SnackBar because no CTA survives the
        // confirmation (save-status-rollout).
        showSnackBar(context, l10n.expenseDeleteSuccess);
      },
    );
  }

  Future<void> _openConversionSheet() async {
    await showConversionSheet(
      context,
      entryCurrency: _editor.entryCurrency,
      groupCurrency: widget.group.currency,
      rateController: _rateController,
      rateState: _conversionListenable,
      data: () {
        final editor = _editor;
        return ConversionSheetData(
          enteredTotal: _itemizedTotalFromForm(),
          convertedTotal: editor.rate == null
              ? null
              : ledgerTotalOfLines(_formLines(), editor.conversion),
          baseRate: editor.baseRate,
          prefilledRateDate: editor.prefilledRateDate,
          rateUnavailable: editor.rateUnavailable,
          cardFeePercent: ref.read(cardFeeProvider),
          hasSavedRate: ref
              .read(stickyRateProvider)
              .containsKey(
                stickyRateKey(widget.group.id, editor.entryCurrency),
              ),
        );
      },
      onRateTyped: _onRateTyped,
      onClearSavedRate: _resetStickyRate,
      onEditCardFee: () =>
          showCardFeeSheet(context, initial: ref.read(cardFeeProvider)),
    );
    // The sheet writes through the callbacks above; this is the row catching up
    // after a dismiss.
    if (mounted) setState(() {});
  }

  /// The user has taken ownership of the rate. Lifted out of the field's
  /// `onChanged` because the field now lives in the sheet.
  void _onRateTyped() {
    _controller.rateTyped(_rateController.text);
    setState(() => _isDirty = true);
  }

  Future<void> _pickEntryCurrency() async {
    final picked = await showCurrencyPicker(
      context,
      initial: _editor.entryCurrency,
    );
    if (picked == null || !mounted || picked == _editor.entryCurrency) return;

    if (picked == widget.group.currency) {
      _switchBackToGroupCurrency();
      return;
    }

    await _controller.pickEntryCurrency(picked, expenseDate: _expenseDate);
    if (mounted) setState(() => _isDirty = true);
  }

  Future<void> _resetStickyRate() async {
    await _controller.resetStickyRate(expenseDate: _expenseDate);
    if (!mounted) return;
    showSnackBar(context, AppLocalizations.of(context)!.expenseRateResetDone);
  }

  /// Switches the editor back to the group's own currency (the rule is
  /// [ExpenseEditorController.switchBackToGroupCurrency]) and writes the
  /// converted amounts into the form.
  void _switchBackToGroupCurrency() {
    final form = _formKey.currentState;
    final entries = _editor.entries;
    final converted = _controller.switchBackToGroupCurrency(
      enteredTexts: [for (final e in entries) editorUnitPriceText(form, e)],
      quantities: [for (final e in entries) editorQuantity(form, e)],
    );
    setState(() {
      for (var i = 0; i < entries.length; i++) {
        form?.fields['expense_entry[${entries[i].index}][amount]']?.didChange(
          converted[i],
        );
      }
      if (converted.isNotEmpty) _amountController.text = converted.first;
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;

    final currentUserEmail = ref.watch(currentUserProvider)?.email;
    final editor = ref.watch(expenseEditorControllerProvider(_args));
    final fee = ref.watch(cardFeeProvider);

    // A fee change re-applies to the base rate already fetched (in the
    // controller) and issues NO new request: the rate for a pair and a date is
    // immutable, so a refetch would return the same number.
    ref.listen<double?>(cardFeeProvider, (_, next) {
      // The fee row and the fee chip refresh even when there is no prefilled
      // rate to rewrite (a typed rate still shows the current fee in the sheet).
      _conversionRevision.value++;
    });

    // The screen's own context sits above the group's theme: the sections that
    // always read the app's brand theme take it as their `screenContext`.
    final screenContext = context;
    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final display = MemberDisplay(
          currentUserEmail: currentUserEmail,
          youLabel: l10n.you,
          roster: widget.group.groupMembers,
        );

        final currencyRate = EditorCurrencyRateSection(
          screenContext: screenContext,
          entryCurrency: editor.entryCurrency,
          groupCurrency: widget.group.currency,
          convertedTotal: editor.rate == null
              ? null
              // Per LINE, accumulated exactly as the save accumulates it —
              // converting the summed itemized total once instead would state
              // a cent the ledger never stores (3 x 1.50 CHF at 0.9432 is
              // 4.23, not 4.24).
              : ledgerTotalOfLines(_formLines(), editor.conversion),
          rateOrigin: editor.rateOrigin,
          rateUnavailable: editor.rateUnavailable,
          prefilledRateDate: editor.prefilledRateDate,
          expenseDate: _expenseDate,
          cardFeePercent: fee,
          onPickCurrency: _pickEntryCurrency,
          onOpenConversion: _openConversionSheet,
        );
        final paidWhen = EditorPaidWhenCard(
          screenContext: screenContext,
          group: widget.group,
          display: display,
          initialDate: widget.expense?.expenseDate != null
              ? DateTime.parse(widget.expense!.expenseDate)
              : DateTime.now(),
          initialPaidBy: widget.expense?.paidBy,
          // THE only refetch trigger. A historical rate is a fact about the
          // expense's day, so changing the day changes the rate; changing
          // anything else does not, and any broader trigger reintroduces
          // surprise rate movement on an expense the user thought was settled.
          onDateChanged: (_) =>
              unawaited(_controller.prefillRate(expenseDate: _expenseDate)),
        );

        return PopScope(
          // A write that is out owns the route: only its success closes the
          // editor (programmatically, past this guard), so a failure can still
          // be reported on this screen.
          canPop:
              !editor.deleteInFlight &&
              editor.saveStatus == EditorSaveStatus.idle &&
              (!_isDirty || _bypassDiscardGuard),
          onPopInvokedWithResult: (didPop, result) async {
            final current = _editor;
            if (didPop ||
                current.deleteInFlight ||
                current.saveStatus != EditorSaveStatus.idle) {
              return;
            }
            final discard = await showDiscardConfirmationSheet(context);
            if (discard == true && context.mounted) {
              _bypassDiscardGuard = true;
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            body: Column(
              children: [
                DeunHeader(
                  title: _isEdit
                      ? l10n.expenseDetailTitleEdit
                      : l10n.expenseDetailTitleNew,
                  leadingIcon: Icons.close,
                  trailing: widget.expense == null
                      ? null
                      : EditorDeleteAction(
                          inFlight: editor.deleteInFlight,
                          onPressed: () => _deleteExpense(widget.expense!),
                        ),
                ),
                Expanded(
                  child: ListView(
                    // F173: kill the double status-bar inset at the TOP —
                    // DeunHeader's SafeArea already consumed MediaQuery.padding.top
                    // for its subtree; a null-padding ListView would re-apply it as
                    // list top-padding. So top stays 0.
                    // Both modes now have a pinned footer save bar below this list
                    // (a Column sibling that reserves its own space), so the list
                    // needs no bottom inset to clear a CTA. Itemized keeps a small
                    // gap so the info callout doesn't touch the footer.
                    padding: EdgeInsets.only(
                      bottom: editor.isSingleEntry ? 0 : spacing * 2,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 0),
                        child: FormBuilder(
                          key: _formKey,
                          clearValueOnUnregister: true,
                          initialValue: widget.expense?.toJson() ?? {},
                          onChanged: () {
                            if (!_isDirty) {
                              setState(() => _isDirty = true);
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // The Quick / Itemized top segmented toggle.
                                    // Bound to the controller's mode — no parallel
                                    // state.
                                    AppSegmentedControl<EditorMode>(
                                      value: editor.editorMode,
                                      segments: [
                                        AppSegment(
                                          value: EditorMode.quick,
                                          label: l10n.editorModeQuick,
                                        ),
                                        AppSegment(
                                          value: EditorMode.itemized,
                                          label: l10n.editorModeItemized,
                                        ),
                                      ],
                                      onChanged: _onEditorModeChanged,
                                    ),
                                    // Quick layout: expense-level amount card.
                                    // Itemized layout: total-from-items header + Scan.
                                    if (editor.isSingleEntry) ...[
                                      const SizedBox(height: spacing * 2),
                                      CategorySelector(
                                        name: "category",
                                        compact: true,
                                        initialValue:
                                            _detectedCategory ??
                                            widget.expense?.category,
                                        onChanged: (category) => setState(
                                          () => _detectedCategory = category,
                                        ),
                                      ),
                                      const SizedBox(height: spacing),
                                      EditorQuickAmountSection(
                                        screenContext: screenContext,
                                        firstIndex: editor.entries.first.index,
                                        amountController: _amountController,
                                        currency: editor.entryCurrency,
                                        memberCount: _members.length,
                                        onAmountChanged: () => setState(() {}),
                                      ),
                                      const SizedBox(height: spacing * 2),
                                      currencyRate,
                                    ] else ...[
                                      const SizedBox(height: spacing * 2),
                                      EditorItemizedTotalHeader(
                                        screenContext: screenContext,
                                        itemCount: editor.entries.length,
                                        total: _itemizedTotalFromForm(),
                                        currency: editor.entryCurrency,
                                        onScan: _scanReceipt,
                                      ),
                                      const SizedBox(height: spacing * 2),
                                      currencyRate,
                                    ],
                                    // v3: inset name/description field below the
                                    // amount/category block (name stays persisted).
                                    const SizedBox(height: spacing * 2),
                                    EditorNameField(
                                      screenContext: screenContext,
                                      controller: _nameController,
                                      onNameTyped: _detectAndUpdateCategory,
                                    ),
                                    const SizedBox(height: spacing * 2),
                                    if (editor.isSingleEntry) ...[
                                      // Quick block (F103): no "Details" header; a single
                                      // non-spaced Paid-by / When card.
                                      paidWhen,
                                    ] else ...[
                                      SectionLabel(l10n.expenseDetailsLabel),
                                      const SizedBox(height: spacing),
                                      // Paid-by / When render as ONE connected
                                      // card with a hairline divider between
                                      // them — the same block the quick layout
                                      // uses — instead of two separate spaced
                                      // cards.
                                      paidWhen,
                                      // itemized-expense-categories: an
                                      // expense-level Category row returns to
                                      // the itemized layout (revisits F116) so
                                      // itemized expenses carry a category for
                                      // lists and statistics instead of always
                                      // reading back as "Other". Per-item icons
                                      // (iconForItemName) are unchanged. Same
                                      // field name/detection as the quick layout.
                                      const SizedBox(height: spacing),
                                      CategorySelector(
                                        name: "category",
                                        initialValue:
                                            _detectedCategory ??
                                            widget.expense?.category,
                                        onChanged: (category) => setState(
                                          () => _detectedCategory = category,
                                        ),
                                      ),
                                      const SizedBox(height: spacing * 2),
                                      SectionLabel(l10n.itemizedItemsLabel),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: spacing),
                              EditorEntryList(
                                entries: editor.entries,
                                isSingleEntry: editor.isSingleEntry,
                                currency: editor.entryCurrency,
                                members: _members,
                                currentUserEmail: currentUserEmail,
                                amountController: _amountController,
                                onRemove: _controller.removeEntry,
                                onLineTotalChanged: () => setState(() {}),
                              ),
                              const SizedBox(height: spacing),
                              // F111: "Add item" is an Itemized-only concept — the Quick
                              // split has a single expense-level amount, so no add-item
                              // button here.
                              if (!editor.isSingleEntry) ...[
                                // v3 handoff: full-width DASHED ghost button (not a
                                // tonal/filled button). Muted-primary stroke, + icon.
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: DashedGhostButton(
                                    icon: Icons.add,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    label: l10n.addItemByHand,
                                    onPressed: _addNewEntry,
                                  ),
                                ),
                                const SizedBox(height: spacing * 2),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: EditorItemizedInfoCallout(
                                    screenContext: screenContext,
                                  ),
                                ),
                                // The itemized "Add & share for claiming" CTA is
                                // no longer the last scroll child — it is pinned
                                // in the opaque footer below (like the Quick save
                                // bar), so it stays fixed to the bottom instead
                                // of scrolling with the content.
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                EditorSaveFooter(
                  status: editor.saveStatus,
                  isSingleEntry: editor.isSingleEntry,
                  isEdit: _isEdit,
                  onSave: editor.isSingleEntry
                      ? () => _saveExpense()
                      : () => _saveExpense(claimable: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
