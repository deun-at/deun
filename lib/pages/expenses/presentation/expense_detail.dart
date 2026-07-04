import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../constants.dart';
import '../../../main.dart';
import '../../../widgets/theme_builder.dart';
import '../../groups/data/group_model.dart';
import 'expense_entry_widget.dart';
import 'receipt_scanner_sheet.dart';
import '../data/claimable_form.dart';
import '../data/editor_mode.dart';
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

class ExpenseDetail extends ConsumerStatefulWidget {
  const ExpenseDetail({super.key, required this.group, this.expense, this.receiptResult});

  final Group group;
  final Expense? expense;
  final ReceiptScanResult? receiptResult;

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
  bool get _isSingleEntry =>
      isSingleEntryQuick(
        entryCount: _entries.length,
        itemizedOverride: _itemizedOverride,
      );

  EditorMode get _editorMode => resolveEditorMode(
        entryCount: _entries.length,
        itemizedOverride: _itemizedOverride,
      );

  /// Whether the user has touched the form (drives the discard guard).
  bool _isDirty = false;

  /// Set once a save succeeds (or the expense is deleted) so the post-action
  /// `Navigator.pop` is not intercepted by the dirty guard.
  bool _bypassDiscardGuard = false;

  ExpenseCategory? _detectedCategory;

  @override
  void initState() {
    super.initState();

    groupMembers = widget.group.groupMembers;
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
        _entries.add(ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
          initialName: expenseEntry.name,
          // Seed the item card and the itemized total header directly from
          // the loaded entry — claim units have no shares, so the widget's
          // shares-gated seeding showed €0.00 line totals before.
          initialAmount: expenseEntry.unitPrice.toStringAsFixed(2),
          initialQuantity: expenseEntry.quantity.toString(),
        ));
      }
    } else if (widget.receiptResult != null && widget.receiptResult!.lineItems.isNotEmpty) {
      // A scanned receipt with itemized lines opens in the Itemized layout.
      _itemizedOverride = true;
      for (final item in widget.receiptResult!.lineItems) {
        final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
        _entries.add(ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
          initialName: item.name,
          initialAmount: item.amount.toStringAsFixed(2),
        ));
      }
    } else if (widget.receiptResult != null && widget.receiptResult!.total != null) {
      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(ExpenseEntryData(
        index: expenseEntry.index,
        expenseEntry: expenseEntry,
        onRemove: () => _removeEntry(expenseEntry),
        groupMembers: groupMembers,
        initialAmount: widget.receiptResult!.total!.toStringAsFixed(2),
      ));
    } else {
      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(ExpenseEntryData(
        index: expenseEntry.index,
        expenseEntry: expenseEntry,
        onRemove: () => _removeEntry(expenseEntry),
        groupMembers: groupMembers,
      ));
    }

    // Initialize amount controller from first entry data
    if (widget.expense != null && widget.expense!.expenseEntries.isNotEmpty) {
      final firstEntry = widget.expense!.expenseEntries.values.first;
      _amountController.text = firstEntry.unitPrice.toStringAsFixed(2);
    } else if (widget.receiptResult != null && widget.receiptResult!.total != null && widget.receiptResult!.lineItems.isEmpty) {
      _amountController.text = widget.receiptResult!.total!.toStringAsFixed(2);
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
          _formKey.currentState?.fields['name']?.didChange(receipt.merchantName);
          detectAndUpdateCategory(receipt.merchantName!);
        }
        if (receipt.date != null) {
          _formKey.currentState?.fields['expense_date']?.didChange(receipt.date);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
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
      final currentCategory = _formKey.currentState?.fields['category']?.value as ExpenseCategory?;

      // Only auto-update if no category is currently selected or if the existing category is 'other'
      if (currentCategory == null || currentCategory == ExpenseCategory.other) {
        if (detectedCategory != ExpenseCategory.other) {
          setState(() {
            _detectedCategory = detectedCategory;
          });
          _formKey.currentState?.fields['category']?.didChange(detectedCategory);
        }
      }
    }
  }

  void openDeleteItemDialog(BuildContext modalContext, Expense expense) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.expenseDeleteItemTitle),
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
                await ExpenseRepository.delete(widget.expense!.id, widget.expense!.groupId);
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.expenseDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.expenseDeleteError);
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
    );
  }

  List<GroupMember> get _sortedMembers {
    final currentEmail = supabase.auth.currentUser?.email;
    return [...widget.group.groupMembers]
      ..sort((a, b) {
        if (a.email == currentEmail) return -1;
        if (b.email == currentEmail) return 1;
        return a.fullUsername.compareTo(b.fullUsername);
      });
  }

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
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: colorScheme.onSurface),
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
            errorText: l10n.expenseNameValidationEmpty),
        decoration: InputDecoration(
          hintText: l10n.expenseDescriptionHint,
          filled: true,
          // v3: description sits on a white card surface (not the grey field).
          fillColor: colorScheme.surfaceContainerLowest,
          border: OutlineInputBorder(
              borderRadius: radius, borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: radius, borderSide: BorderSide.none),
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
    final initialEmail = widget.expense?.paidBy ?? supabase.auth.currentUser?.email;

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
          value: selectedMember != null ? _memberDisplayName(selectedMember) : "",
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
      initialValue: _amountController.text != "0" ? _amountController.text : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(
          errorText: AppLocalizations.of(context)!.expenseEntryAmountValidationEmpty,
        ),
        (value) {
          final amount = double.tryParse(value?.toString() ?? '');
          if (amount != null && amount <= 0) {
            return AppLocalizations.of(context)!.expenseEntryAmountValidationZero;
          }
          return null;
        },
      ]),
      builder: (FormFieldState<dynamic> field) {
        final colorScheme = Theme.of(context).colorScheme;
        final amountStyle = Theme.of(context)
            .textTheme
            .displayMedium
            ?.copyWith(color: colorScheme.onSurface);
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
                        "€",
                        style: amountStyle?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        amount.toStringAsFixed(2),
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
              l10n.expenseSplitEach(l10n.toCurrency(perHead)),
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
  /// written string keeps the `toStringAsFixed(2)` format the inline editor
  /// produced, so the value round-trips and validators are unchanged.
  Future<void> _openAmountKeypad(
    FormFieldState<dynamic> field,
    double current,
  ) async {
    final picked = await showAmountKeypadSheet(context, initialAmount: current);
    if (picked == null || !mounted) return;
    final text = picked.toStringAsFixed(2);
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
    final field = _formKey.currentState?.fields["expense_entry[$firstIndex][amount]"];
    if (field == null) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    _openAmountKeypad(field, amount);
  }

  void _addNewEntry() {
    setState(() {
      // When transitioning from single to multi, transfer expense-level amount to first entry
      if (_isSingleEntry && _amountController.text.isNotEmpty && _amountController.text != "0") {
        _entries.first.initialAmount = _amountController.text;
      }

      final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
      _entries.add(ExpenseEntryData(
        index: expenseEntry.index,
        expenseEntry: expenseEntry,
        onRemove: () => _removeEntry(expenseEntry),
        groupMembers: groupMembers,
      ));
    });
  }

  /// Maps the Quick/Itemized toggle onto the existing entry-count mode.
  ///
  /// Quick → Itemized: flip the override so the (possibly single) entry renders
  /// as an item card, seeding the first item's amount from the quick amount —
  /// the same hand-off [_addNewEntry] already performs.
  ///
  /// Itemized → Quick: only collapses cleanly when a single entry exists. With
  /// multiple entries the layout is inherently itemized, so the toggle keeps the
  /// override on (no data is dropped) — the user removes items to collapse.
  void _onEditorModeChanged(EditorMode mode) {
    if (mode == _editorMode) return;
    setState(() {
      if (mode == EditorMode.itemized) {
        if (_entries.length == 1 &&
            _amountController.text.isNotEmpty &&
            _amountController.text != "0") {
          _entries.first.initialAmount = _amountController.text;
        }
        _itemizedOverride = true;
      } else {
        // Back to Quick: only the single-entry case can collapse. Copy the
        // entry amount back to the expense-level controller so it is preserved.
        if (_entries.length == 1) {
          final firstIndex = _entries.first.index;
          final amount = _formKey.currentState
              ?.fields["expense_entry[$firstIndex][amount]"]?.value
              ?.toString();
          if (amount != null && amount.isNotEmpty) {
            _amountController.text = amount;
            _entries.first.initialAmount = amount;
          }
          _itemizedOverride = false;
        }
      }
    });
  }

  /// Sum of the current item line totals, read live from the form fields so the
  /// header tracks edits. Uses the pure [itemizedTotal] helper.
  double _itemizedTotalFromForm() {
    final formState = _formKey.currentState;
    final lines = <ItemLine>[];
    for (final data in _entries) {
      double unitPrice = double.tryParse(data.initialAmount ?? '') ?? 0;
      int quantity = int.tryParse(data.initialQuantity ?? '') ?? 1;
      if (formState != null) {
        final amountVal =
            formState.fields["expense_entry[${data.index}][amount]"]?.value;
        if (amountVal != null) {
          unitPrice = double.tryParse(amountVal.toString()) ?? unitPrice;
        }
        final qtyVal =
            formState.fields["expense_entry[${data.index}][quantity]"]?.value;
        if (qtyVal != null) {
          quantity = int.tryParse(qtyVal.toString()) ?? quantity;
        }
      }
      lines.add(ItemLine(unitPrice: unitPrice, quantity: quantity));
    }
    return itemizedTotal(lines);
  }

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
          _entries.add(ExpenseEntryData(
            index: expenseEntry.index,
            expenseEntry: expenseEntry,
            onRemove: () => _removeEntry(expenseEntry),
            groupMembers: groupMembers,
            initialName: item.name,
            initialAmount: item.amount.toStringAsFixed(2),
          ));
        }
      } else if (result.total != null && _entries.isNotEmpty) {
        _entries.first.initialAmount = result.total!.toStringAsFixed(2);
      }
      _isDirty = true;
    });
  }

  /// Saves the expense. When [claimable] is true (the itemized
  /// "Add & share for claiming" CTA) every entry is flagged claimable so
  /// [ExpenseRepository.saveAll] explodes the lines into per-unit claim
  /// entries; a plain save leaves the manual-split path untouched.
  Future<void> _saveExpense(BuildContext context, {bool claimable = false}) async {
    if (_formKey.currentState!.saveAndValidate()) {
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
        await ExpenseRepository.saveAll(context, widget.group.id, widget.expense?.id, formValue);
        if (context.mounted) {
          showSnackBar(context, AppLocalizations.of(context)!.expenseCreateSuccess);
        }
      } catch (e) {
        if (context.mounted) {
          showSnackBar(context, AppLocalizations.of(context)!.expenseCreateError);
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
            onPressed: () => openDeleteItemDialog(context, widget.expense!),
            icon: Icon(Icons.delete_outline, color: colorScheme.onSurface),
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
                  title: widget.expense == null
                      ? l10n.expenseDetailTitleNew
                      : l10n.expenseDetailTitleEdit,
                  leadingIcon: Icons.close,
                  trailing: headerTrailing,
                ),
                Expanded(
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 0),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                    _detectedCategory ?? widget.expense?.category,
                              ),
                              const SizedBox(height: spacing),
                              _buildExpenseLevelAmount(),
                            ] else ...[
                              const SizedBox(height: spacing * 2),
                              _buildItemizedTotalHeader(),
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
                              SectionLabel(AppLocalizations.of(context)!
                                  .expenseDetailsLabel),
                              const SizedBox(height: spacing),
                              SoftCard(
                                padding: EdgeInsets.zero,
                                child: _buildPaidByRow(),
                              ),
                              const SizedBox(height: spacing),
                              SoftCard(
                                padding: EdgeInsets.zero,
                                child: _buildDateRow(),
                              ),
                              // F116: no expense-level Category row on itemized —
                              // items carry auto-derived per-item icons instead
                              // (iconForItemName). Category saves as null → reads
                              // back as ExpenseCategory.other.
                              const SizedBox(height: spacing * 2),
                              SectionLabel(AppLocalizations.of(context)!.itemizedItemsLabel),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: spacing),
                      // F161 D1: quick split renders the entry on the page bg
                      // (the split section owns its own SoftCard around only
                      // the member rows). Itemized keeps the CardColumn wrap.
                      Builder(builder: (context) {
                        final entryWidgets = _entries.map((data) =>
                          ExpenseEntryWidget(
                            key: ValueKey(data.index),
                            expenseEntry: data.expenseEntry,
                            index: data.index,
                            onRemove: data.onRemove,
                            groupMembers: data.groupMembers,
                            initialName: data.initialName,
                            initialAmount: _isSingleEntry ? null : data.initialAmount,
                            initialQuantity: data.initialQuantity,
                            isSingleEntry: _isSingleEntry,
                            expenseLevelAmountController: _isSingleEntry ? _amountController : null,
                          ),
                        ).toList();
                        return _isSingleEntry
                            ? Column(children: entryWidgets)
                            : CardColumn(children: entryWidgets);
                      }),
                      const SizedBox(height: spacing),
                      // F111: "Add item" is an Itemized-only concept — the Quick
                      // split has a single expense-level amount, so no add-item
                      // button here.
                      if (!_isSingleEntry) ...[
                        // v3 handoff: full-width DASHED ghost button (not a
                        // tonal/filled button). Muted-primary stroke, + icon.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DashedGhostButton(
                            icon: Icons.add,
                            color: colorScheme.primary,
                            label:
                                AppLocalizations.of(context)!.addItemByHand,
                            onPressed: () => _addNewEntry(),
                          ),
                        ),
                        const SizedBox(height: spacing * 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildItemizedInfoCallout(),
                        ),
                        const SizedBox(height: spacing * 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          // Single itemized CTA: items are always shared for
                          // claiming (F118) — no diverging plain-save path.
                          child: PrimaryButton(
                            onPressed: () => _saveExpense(context, claimable: true),
                            label: AppLocalizations.of(context)!
                                .expenseSaveAndShareForClaiming,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
                    ],
                  ),
                ),
                // Save footer: pinned below the scrollable body. Quick mode
                // only — the itemized tab has a single share-for-claiming CTA
                // inline (F118), so no second, diverging save path.
                if (_isSingleEntry)
                  Builder(
                    builder: (context) => Container(
                      color: colorScheme.surface,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: PrimaryButton(
                        onPressed: () => _saveExpense(context),
                        // F112: quick CTA reads "Add expense" (create + edit).
                        label: AppLocalizations.of(context)!.expenseAddButton,
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

