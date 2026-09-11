import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../constants.dart';
import '../../../main.dart';
import '../../../provider.dart';
import '../../../widgets/currency_picker_sheet.dart';
import '../../../widgets/decimal_text_input_formatter.dart';
import '../../../widgets/theme_builder.dart';
import '../../groups/data/group_model.dart';
import 'expense_entry_widget.dart';
import 'receipt_scanner_sheet.dart';
import '../data/claimable_form.dart';
import '../data/editor_mode.dart';
import '../data/expense_conversion.dart';
import '../data/expense_deletion_impact.dart';
import '../data/expense_entry_model.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';
import '../data/expense_category.dart';
import '../data/itemized_totals.dart';
import '../data/receipt_scan_result.dart';
import '../../../widgets/category_selector.dart';
import '../../../widgets/restyle/app_segmented_control.dart';
import '../../../widgets/restyle/discard_sheet.dart';
import '../../../widgets/restyle/expense_picker_sheets.dart';
import '../../../widgets/restyle/soft_card.dart';
import '../../../widgets/restyle/section_label.dart';
import '../../../widgets/restyle/member_avatar.dart';
import '../../../widgets/restyle/money_text.dart';
import '../../../widgets/restyle/dashed_ghost_button.dart';
import '../../../widgets/restyle/primary_button.dart';

class ExpenseEntryData {
  final int index;
  final ExpenseEntry expenseEntry;
  final VoidCallback onRemove;
  final List<GroupMember> groupMembers;
  String? initialName;
  String? initialAmount;
  String? initialQuantity;

  ExpenseEntryData({
    required this.index,
    required this.expenseEntry,
    required this.onRemove,
    required this.groupMembers,
    this.initialName,
    this.initialAmount,
    this.initialQuantity,
  });
}

/// The editor's write, as an injectable function.
///
/// Signature-compatible with [ExpenseRepository.saveAll] so production passes
/// the repository method itself. Its point is testability: the save payload —
/// the form values AND the [ExpenseConversion] the provenance is written from —
/// is otherwise unreachable from a widget test, which is what let a
/// re-conversion on reload survive review.
typedef ExpenseSaver =
    Future<void> Function(
      BuildContext context,
      String groupId,
      String? expenseId,
      Map<String, dynamic> formResponse, {
      required Currency currency,
      ExpenseConversion? conversion,
    });

class ExpenseDetail extends ConsumerStatefulWidget {
  const ExpenseDetail({
    super.key,
    required this.group,
    this.expense,
    this.receiptResult,
    this.loadGroupPaybacks,
    this.saveExpense,
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

  @override
  ConsumerState<ExpenseDetail> createState() => _ExpenseDetailState();
}

class _ExpenseDetailState extends ConsumerState<ExpenseDetail> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: "0");
  List<GroupMember> groupMembers = [];
  ColorSeed groupColor = ColorSeed.baseColor;
  final List<ExpenseEntryData> _entries = [];
  int _newTextFieldId = 0;

  /// Drives the Quick/Itemized top toggle. The app still distinguishes the two
  /// layouts by entry count (a single entry = Quick); this override lets the
  /// toggle force the Itemized layout while only one entry exists, without
  /// inventing a parallel data model. See [resolveEditorMode].
  bool _itemizedOverride = false;

  /// Quick layout is shown only for a single entry with no itemized override.
  bool get _isSingleEntry => isSingleEntryQuick(
    entryCount: _entries.length,
    itemizedOverride: _itemizedOverride,
  );

  EditorMode get _editorMode => resolveEditorMode(
    entryCount: _entries.length,
    itemizedOverride: _itemizedOverride,
  );

  /// True when the editor was opened on an existing expense. Mirrors
  /// `group_detail_edit.dart`'s `_isEdit` — every mode-sensitive label on this
  /// screen (header title, footer CTA) branches on it so an edit never reads
  /// as an add.
  bool get _isEdit => widget.expense != null;

  /// Whether the user has touched the form (drives the discard guard).
  bool _isDirty = false;

  /// Set once a save succeeds (or the expense is deleted) so the post-action
  /// `Navigator.pop` is not intercepted by the dirty guard.
  bool _bypassDiscardGuard = false;

  /// True while the delete guard's payback probe is in flight. A slow/hanging
  /// fetch must not leave the header delete action tappable — a repeat tap
  /// would start a second probe and, once both resolve, stack a second
  /// `AlertDialog` on top of the first. The action shows progress and ignores
  /// taps for exactly this window; once the dialog appears it is itself
  /// modal, so no further guard is needed past this point.
  bool _deleteProbeInFlight = false;

  ExpenseCategory? _detectedCategory;

  /// The currency the amounts on this screen are TYPED in. Defaults to the
  /// group's; an existing converted expense opens on its frozen original.
  late Currency _entryCurrency;

  final _rateController = TextEditingController();

  /// `yyyy-MM-dd` the rate is attributed to. Stamped when a foreign currency is
  /// chosen and carried unchanged through every later edit of a non-amount
  /// field — nothing in this feature ever re-stamps a saved expense on its own.
  /// Changing the entry currency does re-stamp it: the rate then belongs to a
  /// different currency pair and is quoted today. See
  /// [rateDateForPickedCurrency].
  String? _rateDate;

  bool get _isForeignCurrency => _entryCurrency != widget.group.currency;

  double? get _rate => parseConversionRate(_rateController.text);

  /// The conversion this save will apply. Identity while the amounts are in the
  /// group's own currency.
  ExpenseConversion get _conversion => _isForeignCurrency
      ? ExpenseConversion(
          groupCurrency: widget.group.currency,
          entryCurrency: _entryCurrency,
          rate: _rate,
          rateDate: _rateDate,
        )
      : ExpenseConversion.identity(widget.group.currency);

  @override
  void initState() {
    super.initState();

    _entryCurrency = widget.expense?.originalCurrencyCode != null
        ? Currency.fromCode(widget.expense!.originalCurrencyCode)
        : widget.group.currency;
    _rateDate = widget.expense?.rateDate;
    final loadedRate = widget.expense?.conversionRate;
    if (loadedRate != null) _rateController.text = formatRate(loadedRate);

    groupMembers = widget.group.activeMembers;
    _detectedCategory = widget.expense?.category;
    _nameController.text = widget.expense?.name ?? '';
    if (widget.expense != null && widget.expense!.expenseEntries.isNotEmpty) {
      // Claim units are regrouped into one qty-N item card per item_group_id
      // (F146). Their claims ride along on the synthetic entry so a re-save
      // can preserve them.
      final editorEntries = widget.expense!.editorEntries;
      _newTextFieldId = editorEntries.length;
      // A shared claim expense is itemized by definition — keep the itemized
      // layout even when its units regroup into a single card.
      _itemizedOverride = editorEntries.any((e) => e.splitMode == 'claim');
      for (final expenseEntry in editorEntries) {
        _entries.add(
          ExpenseEntryData(
            index: expenseEntry.index,
            expenseEntry: expenseEntry,
            onRemove: () => _removeEntry(expenseEntry),
            groupMembers: groupMembers,
            initialName: expenseEntry.name,
            // Seed the item card and the itemized total header directly from
            // the loaded entry — claim units have no shares, so the widget's
            // shares-gated seeding showed €0.00 line totals before.
            //
            // The seed is the exact inverse of the save: a line whose total did
            // not divide evenly over its units keeps the digits that multiply
            // back to it. Rounding here instead would reopen a 28.30 qty-3 line
            // as "9.43" and the next name-only save would store 28.29 — the
            // same one-sided rounding the switch-back already avoids.
            initialAmount: unitPriceFieldTextForTotal(
              expenseEntry.enteredLineTotal,
              expenseEntry.quantity,
              _entryCurrency,
            ),
            initialQuantity: expenseEntry.quantity.toString(),
          ),
        );
      }
    } else if (widget.receiptResult != null &&
        widget.receiptResult!.lineItems.isNotEmpty) {
      // A scanned receipt with itemized lines opens in the Itemized layout.
      _itemizedOverride = true;
      for (final item in widget.receiptResult!.lineItems) {
        final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
        _entries.add(
          ExpenseEntryData(
            index: expenseEntry.index,
            expenseEntry: expenseEntry,
            onRemove: () => _removeEntry(expenseEntry),
            groupMembers: groupMembers,
            initialName: item.name,
            initialAmount: amountToFieldText(item.amount, _entryCurrency),
          ),
        );
      }
    } else if (widget.receiptResult != null &&
        widget.receiptResult!.total != null) {
      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(
        ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
          initialAmount: amountToFieldText(
            widget.receiptResult!.total!,
            _entryCurrency,
          ),
        ),
      );
    } else {
      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(
        ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
        ),
      );
    }

    // Initialize amount controller from first entry data
    if (widget.expense != null && widget.expense!.expenseEntries.isNotEmpty) {
      final firstEntry = widget.expense!.expenseEntries.values.first;
      _amountController.text = unitPriceFieldTextForTotal(
        firstEntry.enteredLineTotal,
        firstEntry.quantity,
        _entryCurrency,
      );
    } else if (widget.receiptResult != null &&
        widget.receiptResult!.total != null &&
        widget.receiptResult!.lineItems.isEmpty) {
      _amountController.text = amountToFieldText(
        widget.receiptResult!.total!,
        _entryCurrency,
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
          detectAndUpdateCategory(receipt.merchantName!);
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
    super.dispose();
  }

  void _removeEntry(ExpenseEntry expenseEntry) {
    setState(() {
      _entries.removeWhere((e) => e.index == expenseEntry.index);
    });
  }

  void detectAndUpdateCategory(String title) {
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

  Future<void> openDeleteItemDialog(
    BuildContext modalContext,
    Expense expense,
  ) async {
    if (_deleteProbeInFlight) return;

    // Presentation-level guard, same rule as the read view: warn, then allow.
    // A failed probe degrades to today's plain prompt.
    setState(() => _deleteProbeInFlight = true);
    final impact = await probeDeletionImpact(
      expense,
      loader: widget.loadGroupPaybacks,
    );
    if (!mounted) return;
    setState(() => _deleteProbeInFlight = false);

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(impact.confirmTitle(AppLocalizations.of(context)!)),
          content: Text(
            impact.confirmMessage(
              AppLocalizations.of(context)!,
              widget.group.currencyCode,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context)!.cancel),
              onPressed: () => Navigator.pop(context),
            ),
            PrimaryButton(
              compact: true,
              background: Theme.of(context).colorScheme.error,
              foreground: Theme.of(context).colorScheme.onError,
              label: AppLocalizations.of(context)!.delete,
              onPressed: () async {
                try {
                  await ExpenseRepository.delete(
                    widget.expense!.id,
                    widget.expense!.groupId,
                  );
                  if (context.mounted) {
                    showSnackBar(
                      context,
                      AppLocalizations.of(context)!.expenseDeleteSuccess,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showSnackBar(
                      context,
                      AppLocalizations.of(context)!.expenseDeleteError,
                    );
                  }
                } finally {
                  //pop both dialog and edit page, because this item is not existing anymore
                  if (context.mounted) {
                    _bypassDiscardGuard = true;
                    Navigator.pop(context);
                    Navigator.pop(modalContext);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<GroupMember> get _sortedMembers {
    final currentEmail = supabase.auth.currentUser?.email;
    return [...widget.group.activeMembers]..sort((a, b) {
      if (a.email == currentEmail) return -1;
      if (b.email == currentEmail) return 1;
      return a.fullUsername.compareTo(b.fullUsername);
    });
  }

  // group-member-removal: keeps searching the FULL roster (not activeMembers) —
  // a past expense paid by a since-removed member must still resolve to their
  // name in the ledger.
  GroupMember? _findMember(String? email) {
    if (email == null) return null;
    try {
      return widget.group.groupMembers.firstWhere((m) => m.email == email);
    } catch (_) {
      return null;
    }
  }

  String _memberDisplayName(GroupMember member) {
    return member.email == supabase.auth.currentUser?.email
        ? AppLocalizations.of(context)!.you
        : member.displayName;
  }

  /// The Quick / Itemized top segmented toggle. Bound to the existing
  /// entry-count mode via [_onEditorModeChanged] — no parallel state.
  Widget _buildModeToggle() {
    final l10n = AppLocalizations.of(context)!;
    return AppSegmentedControl<EditorMode>(
      value: _editorMode,
      segments: [
        AppSegment(value: EditorMode.quick, label: l10n.editorModeQuick),
        AppSegment(value: EditorMode.itemized, label: l10n.editorModeItemized),
      ],
      onChanged: _onEditorModeChanged,
    );
  }

  /// Itemized header: the live total summed from the item line totals, with a
  /// Scan action that triggers the existing receipt scanner.
  Widget _buildItemizedTotalHeader() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final ink = Theme.of(context).extension<SemanticColors>()!;
    final total = _itemizedTotalFromForm();
    // v3: unboxed total block — sits directly on the page background (no
    // SoftCard), mirroring the F103 quick-header unboxing. Small grey label +
    // big amount on the left, dark-ink Scan pill on the right.
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.itemizedTotalFromItems(_entries.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              MoneyText(
                total,
                currency: _entryCurrency,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        // v3: dark-ink solid pill labeled "Scan" (not a light indigo tint).
        PrimaryButton(
          label: l10n.expenseScanShort,
          icon: Icons.document_scanner_outlined,
          background: ink.ink,
          foreground: ink.onInk,
          onPressed: _scanReceipt,
          compact: true,
        ),
      ],
    );
  }

  /// Tinted info callout explaining itemized / claiming. Uses a primary tint,
  /// never a hard-coded hex.
  Widget _buildItemizedInfoCallout() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.itemizedInfoCallout,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    return FormBuilderField(
      name: "name",
      builder: (FormFieldState<dynamic> field) => TextFormField(
        controller: _nameController,
        validator: FormBuilderValidators.required(
          errorText: l10n.expenseNameValidationEmpty,
        ),
        decoration: InputDecoration(
          hintText: l10n.expenseDescriptionHint,
          filled: true,
          // v3: description sits on a white card surface (not the grey field).
          fillColor: colorScheme.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        onChanged: (value) {
          field.didChange(value);
          if (value.isNotEmpty) {
            detectAndUpdateCategory(value);
          }
        },
      ),
    );
  }

  /// v3 quick block: a single white card holding the Paid-by and When rows with
  /// no spacing between them (a hairline divider separates the two), replacing
  /// the two separate boxed cards.
  Widget _buildPaidWhenList() {
    final colorScheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPaidByRow(),
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          _buildDateRow(),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    final l10n = AppLocalizations.of(context)!;
    final initial = widget.expense?.expenseDate != null
        ? DateTime.parse(widget.expense!.expenseDate)
        : DateTime.now();
    return FormBuilderField<DateTime>(
      name: "expense_date",
      initialValue: initial,
      builder: (FormFieldState<DateTime?> field) {
        final value = field.value ?? initial;
        return _PaidWhenRow(
          icon: Icons.calendar_today_outlined,
          label: l10n.expenseWhen,
          value: formatDate(value.toIso8601String(), context),
          onTap: () async {
            final picked = await showDateOptionsSheet(context, current: value);
            if (picked != null) field.didChange(picked);
          },
        );
      },
    );
  }

  Widget _buildPaidByRow() {
    final initialEmail =
        widget.expense?.paidBy ?? supabase.auth.currentUser?.email;

    return FormBuilderField<String>(
      name: "paid_by",
      initialValue: initialEmail,
      builder: (FormFieldState<String?> field) {
        final l10n = AppLocalizations.of(context)!;
        final selectedMember = _findMember(field.value);
        final isYou = selectedMember?.email == supabase.auth.currentUser?.email;
        return _PaidWhenRow(
          icon: Icons.account_balance_wallet_outlined,
          label: l10n.expensePaidBy,
          value: selectedMember != null
              ? _memberDisplayName(selectedMember)
              : "",
          trailingLeading: selectedMember != null
              ? MemberAvatar(
                  name: selectedMember.displayName,
                  colorKey: selectedMember.email,
                  radius: 12,
                  isYou: isYou,
                )
              : null,
          onTap: () async {
            final picked = await showPaidBySheet(
              context,
              members: _sortedMembers,
              selectedEmail: field.value,
              currentUserEmail: supabase.auth.currentUser?.email,
            );
            if (picked != null) field.didChange(picked);
          },
        );
      },
    );
  }

  Widget _buildExpenseLevelAmount() {
    final firstIndex = _entries.first.index;
    return FormBuilderField(
      key: ValueKey("expense_level_amount_$firstIndex"),
      name: "expense_entry[$firstIndex][amount]",
      initialValue: _amountController.text != "0"
          ? _amountController.text
          : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(
          errorText: AppLocalizations.of(
            context,
          )!.expenseEntryAmountValidationEmpty,
        ),
        (value) {
          final amount = double.tryParse(value?.toString() ?? '');
          if (amount != null && amount <= 0) {
            return AppLocalizations.of(
              context,
            )!.expenseEntryAmountValidationZero;
          }
          return null;
        },
      ]),
      builder: (FormFieldState<dynamic> field) {
        final colorScheme = Theme.of(context).colorScheme;
        final amountStyle = Theme.of(
          context,
        ).textTheme.displayMedium?.copyWith(color: colorScheme.onSurface);
        final amount = double.tryParse(_amountController.text) ?? 0;
        // v3 quick block: unboxed icon+amount sit directly on the page
        // background (no SoftCard), tap opens the keypad (F100), and a
        // per-person split preview sits directly below the amount.
        final memberCount = groupMembers.isNotEmpty ? groupMembers.length : 1;
        final perHead = amount / memberCount;
        final l10n = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _openAmountKeypad(field, amount),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    errorText: field.errorText,
                    errorMaxLines: 2,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currencySymbolFor(l10n.localeName, _entryCurrency.code),
                        style: amountStyle?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatAmountOnly(
                          amount,
                          _entryCurrency,
                          Localizations.localeOf(context),
                        ),
                        textAlign: TextAlign.center,
                        style: amountStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.expenseSplitEach(
                l10n.toCurrency(perHead, _entryCurrency.code),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Opens the restyled amount keypad sheet and, on confirm, writes the value
  /// back through the same channels the inline editor used: the form field
  /// (validated/saved) and the shared [_amountController] (split-sync). The
  /// written string keeps the currency-precision field format
  /// (`amountToFieldText`), so the value round-trips and validators are
  /// unchanged.
  Future<void> _openAmountKeypad(
    FormFieldState<dynamic> field,
    double current,
  ) async {
    final picked = await showAmountKeypadSheet(
      context,
      initialAmount: current,
      currency: _entryCurrency,
    );
    if (picked == null || !mounted) return;
    final text = amountToFieldText(picked, _entryCurrency);
    setState(() {
      _amountController.text = text;
    });
    field.didChange(text);
  }

  /// Auto-open entry point for a new expense: resolves the Quick amount card's
  /// form field and opens the keypad through the same [_openAmountKeypad] path
  /// the tap uses. No-op if the form/field isn't ready.
  void _openAmountKeypadForFirstEntry() {
    if (_entries.isEmpty) return;
    final firstIndex = _entries.first.index;
    final field =
        _formKey.currentState?.fields["expense_entry[$firstIndex][amount]"];
    if (field == null) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    _openAmountKeypad(field, amount);
  }

  void _addNewEntry() {
    setState(() {
      // When transitioning from single to multi, transfer expense-level amount to first entry
      if (_isSingleEntry &&
          _amountController.text.isNotEmpty &&
          _amountController.text != "0") {
        _entries.first.initialAmount = _amountController.text;
      }

      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(
        ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
        ),
      );
    });
  }

  /// Maps the Quick/Itemized toggle onto the existing entry-count mode.
  ///
  /// Quick → Itemized: flip the override so the (possibly single) entry renders
  /// as an item card, seeding the first item's amount from the quick amount —
  /// the same hand-off [_addNewEntry] already performs.
  ///
  /// Itemized → Quick: collapses the item list into one expense-level amount.
  /// The Quick amount is seeded with the *summed* total of every item line
  /// (scan-split-even), not just the first item's — so the receipt total is
  /// preserved and can be split evenly. When 2+ items collapse into one, a
  /// snackbar warns that per-item detail is dropped as it happens.
  void _onEditorModeChanged(EditorMode mode) {
    if (mode == _editorMode) return;
    // Whether this Itemized → Quick switch drops per-item detail; the notice
    // fires after setState so the messenger sees the settled tree.
    var collapsedItems = false;
    setState(() {
      if (mode == EditorMode.itemized) {
        if (_entries.length == 1 &&
            _amountController.text.isNotEmpty &&
            _amountController.text != "0") {
          _entries.first.initialAmount = _amountController.text;
        }
        _itemizedOverride = true;
      } else {
        // Back to Quick. BUG B: with 2+ entries the toggle used to no-op
        // silently — the tab snapped back to Itemized and read as a dead,
        // unpressable control. Quick has a single expense-level amount, so
        // collapse the itemized items into one entry. scan-split-even: seed
        // the Quick amount from the SUM of every item line total (read live
        // before dropping the extras) so the full receipt value survives —
        // the old code kept only the first item's amount and silently lost
        // the rest. Now the toggle is always honored and value-preserving.
        collapsedItems = _entries.length > 1;
        final summedTotal = _itemizedTotalFromForm();
        if (_entries.length > 1) {
          _entries.removeRange(1, _entries.length);
        }
        final amount = summedTotal > 0
            ? amountToFieldText(summedTotal, _entryCurrency)
            : _formKey
                  .currentState
                  ?.fields["expense_entry[${_entries.first.index}][amount]"]
                  ?.value
                  ?.toString();
        if (amount != null && amount.isNotEmpty) {
          _amountController.text = amount;
          _entries.first.initialAmount = amount;
        }
        _itemizedOverride = false;
      }
    });
    if (collapsedItems && mounted) {
      showSnackBar(
        context,
        AppLocalizations.of(context)!.editorModeCollapseNotice,
      );
    }
  }

  /// The current item lines, read live from the form fields so everything
  /// derived from them tracks edits. THE one reader of the amount and quantity
  /// fields: the itemized header, the converted preview and the switch-back all
  /// go through it, so they cannot disagree about what is on screen.
  List<ItemLine> _formLines() {
    final lines = <ItemLine>[];
    for (final data in _entries) {
      lines.add(
        ItemLine(
          unitPrice: _unitPriceFor(data) ?? 0,
          quantity: _quantityFor(data),
        ),
      );
    }
    return lines;
  }

  /// This entry's live unit price, or null when neither the field nor the
  /// seeded value holds anything parseable (an empty or half-typed amount).
  double? _unitPriceFor(ExpenseEntryData data) {
    final seeded = double.tryParse(data.initialAmount ?? '');
    final value = _formKey
        .currentState
        ?.fields["expense_entry[${data.index}][amount]"]
        ?.value;
    if (value == null) return seeded;
    return double.tryParse(value.toString()) ?? seeded;
  }

  /// This entry's live amount-field text, falling back to the seeded value
  /// before the field registers.
  String _unitPriceTextFor(ExpenseEntryData data) {
    final value = _formKey
        .currentState
        ?.fields["expense_entry[${data.index}][amount]"]
        ?.value;
    return value?.toString() ?? data.initialAmount ?? '';
  }

  /// This entry's live quantity, defaulting to a single unit.
  int _quantityFor(ExpenseEntryData data) {
    final value = _formKey
        .currentState
        ?.fields["expense_entry[${data.index}][quantity]"]
        ?.value;
    return int.tryParse(value?.toString() ?? '') ??
        int.tryParse(data.initialQuantity ?? '') ??
        1;
  }

  /// Sum of the current item line totals in the ENTRY currency, read live from
  /// the form fields so the header tracks edits. Uses the pure [itemizedTotal]
  /// helper.
  double _itemizedTotalFromForm() => itemizedTotal(_formLines());

  Future<void> _scanReceipt() async {
    final result = await showModalBottomSheet<ReceiptScanResult>(
      context: context,
      sheetAnimationStyle: kSheetAnimationStyle,
      barrierColor: kSheetBarrierColor,
      builder: (context) => const ReceiptScannerSheet(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _itemizedOverride = true;
      if (result.merchantName != null) {
        _nameController.text = result.merchantName!;
        _formKey.currentState?.fields['name']?.didChange(result.merchantName);
        detectAndUpdateCategory(result.merchantName!);
      }
      if (result.date != null) {
        _formKey.currentState?.fields['expense_date']?.didChange(result.date);
      }
      if (result.lineItems.isNotEmpty) {
        // Replace the current items with the scanned lines.
        _entries.clear();
        for (final item in result.lineItems) {
          final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
          _entries.add(
            ExpenseEntryData(
              index: expenseEntry.index,
              expenseEntry: expenseEntry,
              onRemove: () => _removeEntry(expenseEntry),
              groupMembers: groupMembers,
              initialName: item.name,
              initialAmount: amountToFieldText(item.amount, _entryCurrency),
            ),
          );
        }
      } else if (result.total != null && _entries.isNotEmpty) {
        _entries.first.initialAmount = amountToFieldText(
          result.total!,
          _entryCurrency,
        );
      }
      _isDirty = true;
    });
  }

  /// Saves the expense. When [claimable] is true (the itemized
  /// "Add & share for claiming" CTA) every entry is flagged claimable so
  /// [ExpenseRepository.saveAll] explodes the lines into per-unit claim
  /// entries; a plain save leaves the manual-split path untouched.
  Future<void> _saveExpense(
    BuildContext context, {
    bool claimable = false,
  }) async {
    if (_formKey.currentState!.saveAndValidate()) {
      // Individual lines may be negative (discounts), but the expense total
      // must stay positive — a non-positive total collapses every member's
      // percentage share to 0% in ExpenseRepository.saveAll.
      if (_itemizedTotalFromForm() <= 0) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.expenseEntryAmountValidationZero,
        );
        return;
      }
      // No implicit rate: an expense in a currency other than the group's
      // cannot be saved without one. No 1:1 fallback, no silent substitution.
      final conversion = _conversion;
      if (!conversion.isIdentity && conversion.rate == null) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.expenseRateRequired,
        );
        return;
      }
      try {
        final formValue = claimable
            ? markEntriesClaimable(
                _formKey.currentState!.value,
                // Share with the whole group so everyone is notified that
                // there are items to claim (claim units start unclaimed).
                notifyEmails: groupMembers.map((m) => m.email).toSet(),
              )
            : _formKey.currentState!.value;
        if (claimable) {
          // Re-saving a shared expense re-explodes its items into fresh
          // claim units — thread each item's existing per-unit claims
          // through so they are preserved (F146). Positional: shrinking an
          // item's quantity drops the last units' claims.
          for (final data in _entries) {
            if (data.expenseEntry.unitClaims.isNotEmpty) {
              formValue['expense_entry[${data.index}][existing_claims]'] =
                  data.expenseEntry.unitClaims;
            }
          }
        }
        await (widget.saveExpense ?? ExpenseRepository.saveAll)(
          context,
          widget.group.id,
          widget.expense?.id,
          formValue,
          currency: widget.group.currency,
          conversion: conversion,
        );
        if (!conversion.isIdentity) {
          // Remember the rate for the next expense in this currency in this
          // group — a trip holds one agreed rate with no separate concept.
          await ref
              .read(stickyRateProvider.notifier)
              .setStickyRate(
                widget.group.id,
                conversion.entryCurrency,
                conversion.rate!,
              );
        }
        if (context.mounted) {
          showSnackBar(
            context,
            AppLocalizations.of(context)!.expenseCreateSuccess,
          );
        }
      } catch (e) {
        if (context.mounted) {
          showSnackBar(
            context,
            AppLocalizations.of(context)!.expenseCreateError,
          );
        }
      } finally {
        if (mounted) {
          if (context.mounted) {
            _bypassDiscardGuard = true;
            Navigator.pop(context);
          }
        }
      }
    }
  }

  /// Entry-currency selector plus, when it differs from the group's, the rate
  /// field and the live converted preview. This is the whole of the
  /// no-implicit-rate guard's UI surface.
  Widget _buildCurrencyAndRate() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rate = _rate;
    final stickyRates = ref.watch(stickyRateProvider);
    final hasSticky = stickyRates.containsKey(
      stickyRateKey(widget.group.id, _entryCurrency),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftCard(
          key: const ValueKey('expense_entry_currency'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: 16,
          onTap: _pickEntryCurrency,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.expenseEntryCurrencyLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _entryCurrency.pickerLabel,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (_isForeignCurrency) ...[
          const SizedBox(height: 8),
          // The rate lives in a card like every other control on this screen.
          // As a bare underlined field it was the only element with that
          // treatment and read as unfinished rather than deliberate.
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('expense_rate_field'),
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalTextInputFormatter(decimalRange: 6)],
                  onChanged: (_) => setState(() => _isDirty = true),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    labelText: l10n.expenseRateFieldLabel,
                    // InputDecorator fades prefix and suffix out whenever the
                    // label is inline — i.e. on an empty, unfocused field,
                    // which is precisely the FIRST foreign expense in a group,
                    // where nothing is remembered yet and the user has no way
                    // to know which way round to type the rate. Pinning the
                    // label keeps "1 JPY = … EUR" on screen from the start and
                    // stops the row reflowing when the field takes focus.
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    // The field reads as a sentence — "1 CHF = [0.9432] EUR" —
                    // so the direction is never ambiguous and no "?" is left
                    // standing once a rate has been typed.
                    prefixText:
                        '${l10n.expenseRatePrefix(_entryCurrency.code)} ',
                    suffixText: ' ${widget.group.currency.code}',
                    // No rate => the hint, never a "= EUR 0.00" preview. An
                    // emptied field reads back as "0" from the formatter, and
                    // parseConversionRate maps that to null, so the refusal is
                    // visible while typing rather than only on save.
                    helperText: rate == null ? l10n.expenseRateRequired : null,
                    helperMaxLines: 3,
                  ),
                ),
                if (rate != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            key: const ValueKey('expense_rate_preview'),
                            l10n.expenseRatePreview(
                              formatMoney(
                                // Per LINE, accumulated exactly as the save
                                // accumulates it — converting the summed
                                // itemized total once instead would preview a
                                // cent the ledger never stores (3 x 1.50 CHF
                                // at 0.9432 is 4.23, not 4.24).
                                ledgerTotalOfLines(_formLines(), _conversion),
                                widget.group.currency,
                                Localizations.localeOf(context),
                              ),
                            ),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        // Clearing the REMEMBERED rate, so it only exists once
                        // one is remembered — never as a companion to an empty
                        // field.
                        if (hasSticky)
                          TextButton(
                            key: const ValueKey('expense_rate_reset'),
                            onPressed: _resetStickyRate,
                            child: Text(l10n.expenseRateReset),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickEntryCurrency() async {
    final picked = await showCurrencyPicker(context, initial: _entryCurrency);
    if (picked == null || !mounted || picked == _entryCurrency) return;

    if (picked == widget.group.currency) {
      _switchBackToGroupCurrency();
      return;
    }

    // Await hydration before reading: this is a keepAlive provider and the
    // editor may be the first thing to touch it after app start.
    final sticky = ref.read(stickyRateProvider.notifier);
    await sticky.hydrated;
    final prefill = sticky.stickyRate(widget.group.id, picked);
    if (!mounted) return;

    setState(() {
      _entryCurrency = picked;
      // A rate is per source currency — a CHF rate is meaningless for JPY, so
      // the field always follows the newly picked currency's remembered rate,
      // and the date follows it too: a rate typed after switching JPY -> CHF is
      // a CHF rate quoted today, never the old JPY rate's date. Only re-picking
      // the currency the expense was loaded with keeps its frozen date.
      _rateController.text = prefill != null ? formatRate(prefill) : '';
      // The date is a fact about the RATE, so the frozen one survives only
      // while the frozen rate is what the field will hold. Gating on the
      // currency alone misdates a round trip: CHF -> EUR -> CHF clears the
      // field and refills it from the sticky rate, which may never have been
      // quoted on the loaded date.
      _rateDate = rateDateForPickedCurrency(
        picked: picked,
        loadedOriginalCurrencyCode: widget.expense?.originalCurrencyCode,
        loadedRateDate: widget.expense?.rateDate,
        loadedRate: widget.expense?.conversionRate,
        pickedRate: prefill,
        today: DateTime.now(),
      );
      _isDirty = true;
    });
  }

  Future<void> _resetStickyRate() async {
    final sticky = ref.read(stickyRateProvider.notifier);
    await sticky.clearStickyRate(widget.group.id, _entryCurrency);
    if (!mounted) return;
    setState(() => _rateController.text = '');
    if (context.mounted) {
      showSnackBar(context, AppLocalizations.of(context)!.expenseRateResetDone);
    }
  }

  /// Switches the editor back to the group's own currency.
  ///
  /// The amount fields hold amounts in the ENTRY currency, so leaving them as
  /// typed would save a 3000 JPY expense as 3000 EUR, and clearing them would
  /// silently discard the user's numbers. Each field is re-converted at the
  /// FROZEN rate the expense is already carrying, which preserves the value the
  /// ledger holds today: a converted 17.40 EUR expense switched back to EUR
  /// stays 17.40, not 3000. The provenance clears in the same step.
  ///
  /// With no rate in effect nothing was ever converted, so the typed numbers
  /// pass through untouched.
  void _switchBackToGroupCurrency() {
    final formState = _formKey.currentState;
    final rate = _rate;
    final groupCurrency = widget.group.currency;

    final texts = <String>[
      for (final data in _entries) _unitPriceTextFor(data),
    ];
    // Amount fields hold UNIT prices, so the quantities ride along: each line
    // converts once and its remainder distributes across its units, exactly as
    // the save does. Re-converting the unit price alone would drop the
    // remainder — a qty-3 10.00 CHF line at 0.9432 is 28.30 in the ledger and
    // 9.43 x3 = 28.29 without it.
    final converted = switchBackAmountTexts(
      enteredTexts: texts,
      rate: rate,
      groupCurrency: groupCurrency,
      quantities: [for (final data in _entries) _quantityFor(data)],
    );

    setState(() {
      for (var i = 0; i < _entries.length; i++) {
        _entries[i].initialAmount = converted[i];
        formState?.fields['expense_entry[${_entries[i].index}][amount]']
            ?.didChange(converted[i]);
      }
      if (converted.isNotEmpty) _amountController.text = converted.first;
      _entryCurrency = groupCurrency;
      _rateController.text = '';
      _rateDate = null;
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;

    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final l10n = AppLocalizations.of(context)!;

        Widget? headerTrailing;
        if (widget.expense != null) {
          headerTrailing = IconButton(
            onPressed: _deleteProbeInFlight
                ? null
                : () => openDeleteItemDialog(context, widget.expense!),
            icon: _deleteProbeInFlight
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSurface,
                    ),
                  )
                : Icon(Icons.delete_outline, color: colorScheme.onSurface),
            iconSize: 22,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: EdgeInsets.zero,
          );
        }

        return PopScope(
          canPop: !_isDirty || _bypassDiscardGuard,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
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
                  trailing: headerTrailing,
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
                      bottom: _isSingleEntry ? 0 : spacing * 2,
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
                                    _buildModeToggle(),
                                    // Quick layout: expense-level amount card.
                                    // Itemized layout: total-from-items header + Scan.
                                    if (_isSingleEntry) ...[
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
                                      _buildExpenseLevelAmount(),
                                      const SizedBox(height: spacing * 2),
                                      _buildCurrencyAndRate(),
                                    ] else ...[
                                      const SizedBox(height: spacing * 2),
                                      _buildItemizedTotalHeader(),
                                      const SizedBox(height: spacing * 2),
                                      _buildCurrencyAndRate(),
                                    ],
                                    // v3: inset name/description field below the
                                    // amount/category block (name stays persisted).
                                    const SizedBox(height: spacing * 2),
                                    _buildNameField(),
                                    const SizedBox(height: spacing * 2),
                                    if (_isSingleEntry) ...[
                                      // Quick block (F103): no "Details" header; a single
                                      // non-spaced Paid-by / When card.
                                      _buildPaidWhenList(),
                                    ] else ...[
                                      SectionLabel(
                                        AppLocalizations.of(
                                          context,
                                        )!.expenseDetailsLabel,
                                      ),
                                      const SizedBox(height: spacing),
                                      // Paid-by / When render as ONE connected
                                      // card with a hairline divider between
                                      // them — the same block the quick layout
                                      // uses — instead of two separate spaced
                                      // cards.
                                      _buildPaidWhenList(),
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
                                      SectionLabel(
                                        AppLocalizations.of(
                                          context,
                                        )!.itemizedItemsLabel,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: spacing),
                              // F161 D1: quick split renders the entry on the page bg
                              // (the split section owns its own SoftCard around only
                              // the member rows). Itemized joins its item rows inside a
                              // SINGLE SoftCard (the group_detail_list _DaySection
                              // pattern) — the item rows render flat (no per-row card)
                              // so there is no card-in-card nesting.
                              Builder(
                                builder: (context) {
                                  final entryWidgets = _entries
                                      .map(
                                        (data) => ExpenseEntryWidget(
                                          key: ValueKey(data.index),
                                          expenseEntry: data.expenseEntry,
                                          index: data.index,
                                          onRemove: data.onRemove,
                                          groupMembers: data.groupMembers,
                                          currency: _entryCurrency,
                                          initialName: data.initialName,
                                          initialAmount: _isSingleEntry
                                              ? null
                                              : data.initialAmount,
                                          initialQuantity: data.initialQuantity,
                                          isSingleEntry: _isSingleEntry,
                                          expenseLevelAmountController:
                                              _isSingleEntry
                                              ? _amountController
                                              : null,
                                          // Itemized total header lives in this parent; a child
                                          // price/qty edit must rebuild it. FormBuilder.onChanged
                                          // only fires the first time (it guards on _isDirty), so
                                          // wire an explicit per-edit rebuild here.
                                          onLineTotalChanged: _isSingleEntry
                                              ? null
                                              : () => setState(() {}),
                                        ),
                                      )
                                      .toList();
                                  if (_isSingleEntry) {
                                    return Column(children: entryWidgets);
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: SoftCard(
                                      padding: EdgeInsets.zero,
                                      borderRadius: 16,
                                      child: Column(
                                        children: [
                                          for (
                                            int i = 0;
                                            i < entryWidgets.length;
                                            i++
                                          ) ...[
                                            if (i > 0)
                                              Divider(
                                                height: 1,
                                                thickness: 1,
                                                indent: 16,
                                                endIndent: 16,
                                                color: colorScheme
                                                    .outlineVariant
                                                    .withValues(alpha: 0.5),
                                              ),
                                            entryWidgets[i],
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: spacing),
                              // F111: "Add item" is an Itemized-only concept — the Quick
                              // split has a single expense-level amount, so no add-item
                              // button here.
                              if (!_isSingleEntry) ...[
                                // v3 handoff: full-width DASHED ghost button (not a
                                // tonal/filled button). Muted-primary stroke, + icon.
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: DashedGhostButton(
                                    icon: Icons.add,
                                    color: colorScheme.primary,
                                    label: AppLocalizations.of(
                                      context,
                                    )!.addItemByHand,
                                    onPressed: () => _addNewEntry(),
                                  ),
                                ),
                                const SizedBox(height: spacing * 2),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: _buildItemizedInfoCallout(),
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
                // Save footer: pinned below the scrollable body on an opaque
                // surface bar. Present in BOTH modes — Quick saves the expense;
                // Itemized shares the items for claiming (F118).
                // Because it is a sibling of the Expanded list (not an overlay),
                // it always reserves its own space, so scroll content is never
                // hidden behind it.
                Builder(
                  builder: (context) => Container(
                    color: colorScheme.surface,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: PrimaryButton(
                      onPressed: _isSingleEntry
                          ? () => _saveExpense(context)
                          : () => _saveExpense(context, claimable: true),
                      // expense-editor-edit-labels: the CTA is mode-aware in
                      // BOTH axes. Quick/Itemized picks the action; new/edit
                      // picks the verb — editing must never read "Add expense".
                      // Edit reuses the shared `save` key, the same way
                      // group_detail_edit.dart's sticky footer does.
                      label: _isSingleEntry
                          ? (_isEdit ? l10n.save : l10n.expenseAddButton)
                          : (_isEdit
                                ? l10n.expenseSaveAndShareForClaimingEdit
                                : l10n.expenseSaveAndShareForClaiming),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A restyled trigger row for the Quick editor (paid-by / date). A [SoftCard]
/// with a leading icon chip (or custom [leading]), a small [label], the current
/// [value], and a trailing chevron. Tapping fires [onTap] — which opens the
/// existing picker/sheet unchanged.
/// A single-line row for the quick editor's Paid-by / When list: leading icon,
/// grey label, right-aligned value (optionally preceded by a small avatar),
/// then a chevron. Rows sit inside a shared card with no spacing between them.
class _PaidWhenRow extends StatelessWidget {
  const _PaidWhenRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailingLeading,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Optional small widget shown just before the value (e.g. a member avatar).
  final Widget? trailingLeading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 21),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingLeading != null) ...[
              trailingLeading!,
              const SizedBox(width: 8),
            ],
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colorScheme.outline, size: 20),
          ],
        ),
      ),
    );
  }
}
