import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../widgets/restyle/app_segmented_control.dart';
import '../../../widgets/restyle/expense_picker_sheets.dart';
import '../../../widgets/restyle/money_text.dart';
import '../../../widgets/restyle/section_label.dart';
import '../../groups/data/group_member_model.dart';
import '../../groups/data/member_display.dart';
import '../data/expense_conversion.dart';
import '../data/expense_entry_model.dart';
import '../data/split_allocation.dart';
import '../data/split_mode.dart';
import 'expense_entry/expense_entry_allocation_summary.dart';
import 'expense_entry/expense_entry_item_row.dart';
import 'expense_entry/expense_entry_member_list.dart';

class ExpenseEntryWidget extends StatefulWidget {
  const ExpenseEntryWidget({
    super.key,
    required this.expenseEntry,
    required this.index,
    required this.onRemove,
    required this.groupMembers,
    this.currentUserEmail,
    this.currency = Currency.eur,
    this.initialName,
    this.initialAmount,
    this.initialQuantity,
    this.isSingleEntry = false,
    this.expenseLevelAmountController,
    this.onLineTotalChanged,
  });

  final int index;
  final ExpenseEntry expenseEntry;
  final Function onRemove;
  final List<GroupMember> groupMembers;

  /// The signed-in user's email: the member this entry names "You".
  final String? currentUserEmail;

  /// Currency of the enclosing group, used to format all amounts and the
  /// amount-input symbol in this itemized entry.
  final Currency currency;
  final String? initialName;
  final String? initialAmount;
  final String? initialQuantity;
  final bool isSingleEntry;

  /// In single-entry mode, the amount is entered at the expense level.
  /// This controller lets the entry widget stay in sync with that amount.
  final TextEditingController? expenseLevelAmountController;

  /// Fired whenever this item's line total (unit price × quantity) changes, so
  /// the itemized total header in the parent can recompute. The parent form's
  /// onChanged only fires once (it guards on its dirty flag), so it cannot drive
  /// a live total on its own.
  final VoidCallback? onLineTotalChanged;

  @override
  State<ExpenseEntryWidget> createState() => _ExpenseEntryWidgetState();
}

class _ExpenseEntryWidgetState extends State<ExpenseEntryWidget> {
  late MemberDisplay _display;
  late SplitMode _splitMode;
  late int _quantity;
  late double _unitPrice;
  // Item name mirrored into state so the leading auto-icon (iconForItemName)
  // updates live as the user types (F117). The FormBuilderField below stays
  // the source of truth for saving.
  late String _itemName;
  late Set<String> _enabledMembers;
  late Map<String, double> _memberAmounts;
  late Map<String, double> _memberPercentages;
  late Map<String, int> _memberParts;
  final Set<String> _lockedMembers = {};
  final Map<String, TextEditingController> _memberControllers = {};

  double get _entryTotal => _unitPrice * _quantity;

  @override
  void dispose() {
    widget.expenseLevelAmountController?.removeListener(
      _onExpenseLevelAmountChanged,
    );
    for (var controller in _memberControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _splitMode = SplitMode.fromString(
      widget.expenseEntry.expenseEntryShares.isNotEmpty
          ? widget.expenseEntry.splitMode
          : null,
    );

    _quantity = widget.initialQuantity != null
        ? (int.tryParse(widget.initialQuantity!) ?? 1)
        : (widget.expenseEntry.expenseEntryShares.isNotEmpty
              ? widget.expenseEntry.quantity
              : 1);

    String amountStr =
        widget.initialAmount ??
        (widget.expenseEntry.expenseEntryShares.isNotEmpty
            // [widget.currency] is the ENTRY currency, so the seed has to be
            // the ENTERED line, not the ledger one: on a converted expense
            // `unitPrice` is the group-currency value and feeding it in here
            // would price every split preview in the wrong currency.
            ? _seedAmountText(widget.expenseEntry)
            // Single-entry mode: seed from the expense-level amount so the
            // split previews are correct before the first keystroke.
            : (widget.expenseLevelAmountController?.text ?? "0"));
    _unitPrice = double.tryParse(amountStr) ?? 0;

    _itemName =
        widget.initialName ??
        (widget.expenseEntry.expenseEntryShares.isNotEmpty
            ? (widget.expenseEntry.name ?? '')
            : '');

    // Initialize enabled members
    if (widget.expenseEntry.expenseEntryShares.isNotEmpty) {
      _enabledMembers = widget.expenseEntry.expenseEntryShares
          .map((e) => e.email)
          .toSet();
    } else {
      _enabledMembers = widget.groupMembers.map((e) => e.email).toSet();
    }

    // Initialize per-member values from existing shares
    _memberAmounts = {};
    _memberPercentages = {};
    _memberParts = {};

    if (widget.expenseEntry.expenseEntryShares.isNotEmpty) {
      final isConverted = widget.expenseEntry.isConverted;
      for (var share in widget.expenseEntry.expenseEntryShares) {
        _memberPercentages[share.email] = share.percentage;
        // Every value in this widget is in the ENTRY currency, so an exact
        // share reloads from its entry-currency twin. `fixed_amount` alone is
        // the ledger value on a converted expense; re-saving would convert it a
        // second time and derive `percentage = fixed / entered total` across
        // two currencies. The percentage fallback is currency-free, so it also
        // covers a converted share written before `original_fixed_amount`
        // existed.
        _memberAmounts[share.email] =
            share.enteredFixedAmount(isConverted: isConverted) ??
            (_entryTotal * share.percentage / 100);
        _memberParts[share.email] = share.parts ?? 1;
        if (share.isLocked) {
          _lockedMembers.add(share.email);
        }
      }
    } else {
      // Only recalculate for new entries (no existing data to preserve)
      _recalculateIfNeeded();
    }

    // In single-entry mode, listen to the expense-level amount controller
    // so splits stay in sync when the user types the amount.
    widget.expenseLevelAmountController?.addListener(
      _onExpenseLevelAmountChanged,
    );
  }

  /// The amount-field text for [entry] in the ENTRY currency
  /// ([ExpenseEntryWidget.currency]).
  ///
  /// Goes through [unitPriceFieldTextForTotal] so a multi-unit line whose total
  /// did not divide evenly keeps the digits that multiply back to it — the save
  /// reads unit price x quantity, and a plain "9.43" stores 28.29 for a 28.30
  /// line.
  String _seedAmountText(ExpenseEntry entry) => unitPriceFieldTextForTotal(
    entry.enteredLineTotal,
    entry.quantity,
    widget.currency,
  );

  @override
  void didUpdateWidget(covariant ExpenseEntryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent re-seeds every [initialAmount] when the entry currency
    // changes: switching back to the group's currency re-converts each line at
    // the frozen rate. This widget survives that change — its
    // `ValueKey(data.index)` is unchanged — so without adopting the new seed the
    // item row would keep rendering, and every split would keep computing from,
    // the pre-switch entry-currency amount while the header and the save used
    // the converted one.
    //
    // No setState: a rebuild of this widget is already in flight, and
    // [_updateSplitState] pushes the recomputed split into the form fields so
    // the save sees the same numbers the row now shows.
    if (widget.currency == oldWidget.currency &&
        widget.initialAmount == oldWidget.initialAmount) {
      return;
    }
    final seeded = double.tryParse(widget.initialAmount ?? '');
    if (seeded == null || seeded == _unitPrice) return;
    final oldTotal = _entryTotal;
    _unitPrice = seeded;
    _scaleLockedMembers(oldTotal, _entryTotal);
    _updateSplitState();
  }

  void _onExpenseLevelAmountChanged() {
    final newPrice =
        double.tryParse(widget.expenseLevelAmountController?.text ?? '') ?? 0;
    if (newPrice != _unitPrice) {
      setState(() {
        double oldTotal = _entryTotal;
        _unitPrice = newPrice;
        _onTotalChanged(oldTotal);
      });
    }
  }

  void _recalculateIfNeeded() {
    if (_enabledMembers.isEmpty) return;

    switch (_splitMode) {
      case SplitMode.equal:
        // Equal derives everything from total / included count on the fly.
        break;
      case SplitMode.amount:
        _memberAmounts = rebalanceExactAmounts(
          total: _entryTotal,
          enabled: _enabledMembers,
          locked: _lockedMembers,
          amounts: _memberAmounts,
        );
        break;
      case SplitMode.percentage:
        _memberPercentages = rebalancePercentages(
          enabled: _enabledMembers,
          locked: _lockedMembers,
          percentages: _memberPercentages,
        );
        break;
      case SplitMode.shares:
        // Parts are always user-set, no auto-recalculation needed
        break;
    }
  }

  /// Single entry point after any split-affecting mutation.
  void _updateSplitState({bool controllersInvalid = false}) {
    _recalculateIfNeeded();
    if (!controllersInvalid) {
      _updateUnlockedControllers();
    }
    _syncFormFields();
  }

  /// Call when total (price * quantity) changed — scales locked members first.
  void _onTotalChanged(double oldTotal) {
    _scaleLockedMembers(oldTotal, _entryTotal);
    _updateSplitState();
    // Let the parent recompute the itemized total header live (BUG C).
    widget.onLineTotalChanged?.call();
  }

  void _scaleLockedMembers(double oldTotal, double newTotal) {
    final scaled = scaleLockedAmounts(
      oldTotal: oldTotal,
      newTotal: newTotal,
      locked: _lockedMembers,
      amounts: _memberAmounts,
    );
    _memberAmounts = scaled.amounts;
    // The shares / locked_members form fields hold this very Set, so the locks
    // are released in place, never by swapping the Set.
    if (scaled.releaseLocks) _lockedMembers.clear();
    // Percentages stay the same when total changes — they're relative
  }

  Map<String, dynamic> _buildShareData() {
    Map<String, dynamic> data = {};
    for (var email in _enabledMembers) {
      switch (_splitMode) {
        case SplitMode.equal:
          // Value is informational only — the save path ('equal' branch in
          // ExpenseRepository) derives percentage = 100 / member count.
          data[email] = _enabledMembers.isEmpty
              ? 0.0
              : roundCurrency(
                  _entryTotal / _enabledMembers.length,
                  widget.currency,
                );
          break;
        case SplitMode.amount:
          data[email] = _memberAmounts[email] ?? 0.0;
          break;
        case SplitMode.percentage:
          data[email] = _memberPercentages[email] ?? 0.0;
          break;
        case SplitMode.shares:
          data[email] = _memberParts[email] ?? 1;
          break;
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;
    final l10n = AppLocalizations.of(context)!;
    _display = MemberDisplay(
      currentUserEmail: widget.currentUserEmail,
      youLabel: l10n.you,
      roster: widget.groupMembers,
    );

    return Padding(
      // Itemized rows sit inside the parent's joined SoftCard and own their
      // padding via ExpenseEntryItemRow, so no outer inset (BUG D). Quick keeps the
      // split-section inset, aligned to the same 16px horizontal grid as the
      // other form sections (the end inset was 8, leaving the split section
      // offset 8px past the cards above it).
      padding: widget.isSingleEntry
          ? const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isSingleEntry) ...[
            // Itemized item row (F117): auto icon tile + inline-editable
            // name + "€ [price] each" + line total right; bottom row =
            // trash left, qty stepper right. Items are shared for claiming
            // (F118) — no per-item split UI; members claim their own units
            // on the claim page instead.
            ExpenseEntryItemRow(
              index: widget.index,
              currency: widget.currency,
              itemName: _itemName,
              initialName: widget.initialName,
              initialAmountText:
                  widget.initialAmount ??
                  (widget.expenseEntry.expenseEntryShares.isNotEmpty
                      ? _seedAmountText(widget.expenseEntry)
                      : null),
              unitPrice: _unitPrice,
              quantity: _quantity,
              lineTotal: _entryTotal,
              onRemove: () => widget.onRemove(),
              onNameChanged: (value) => setState(() => _itemName = value),
              onUnitPriceChanged: _adoptUnitPrice,
              onUnitPriceTap: _openUnitPriceKeypad,
              onQuantityChanged: _adoptQuantity,
            ),
          ] else ...[
            // Quick split keeps the full split section — label + 4-way mode
            // selector (Equal/Shares/%/Exact), per DESIGN_SPEC §8 (F105).
            SectionLabel(
              l10n.splitSectionLabel,
              trailing: Text(
                l10n.splitPeopleCount(
                  _enabledMembers.length,
                  widget.groupMembers.length,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: spacing),
            _buildSplitModeSelector(l10n),
            const SizedBox(height: spacing),
            // F161 D2/D3/D5: ONE colored bar + a single right-aligned
            // status-aware remain label, ABOVE the member-row card.
            ExpenseEntryAllocationSummary(
              index: widget.index,
              splitMode: _splitMode,
              currency: widget.currency,
              entryTotal: _entryTotal,
              groupMembers: widget.groupMembers,
              enabledMembers: _enabledMembers,
              memberAmounts: _memberAmounts,
              memberPercentages: _memberPercentages,
              memberParts: _memberParts,
              isYou: _display.isYou,
              amountPreview: _getAmountPreview,
            ),
            const SizedBox(height: spacing),
            ExpenseEntryMemberList(
              index: widget.index,
              splitMode: _splitMode,
              currency: widget.currency,
              groupMembers: widget.groupMembers,
              enabledMembers: _enabledMembers,
              lockedMembers: _lockedMembers,
              memberAmounts: _memberAmounts,
              memberPercentages: _memberPercentages,
              memberParts: _memberParts,
              shareData: _buildShareData(),
              isSplitBalanced: _isSplitBalanced,
              displayName: _display.nameOf,
              isYou: _display.isYou,
              amountPreview: _getAmountPreview,
              memberController: _getOrCreateController,
              onToggleMember: _toggleMember,
              onSetParts: _setParts,
              onSetPercentage: _setPercentage,
              onStepPercentage: _stepPercentage,
              onStepAmount: _stepAmount,
              onMemberAmountTap: _openMemberAmountKeypad,
            ),
          ],
        ],
      ),
    );
  }

  /// F158: opens the shared amount keypad for the itemized unit price. On
  /// confirm it writes the FormBuilderField (validated/saved); the field's
  /// onChanged ([_adoptUnitPrice]) moves this row's price and split math with
  /// it, so the persisted value and the row cannot disagree.
  Future<void> _openUnitPriceKeypad(FormFieldState<dynamic> field) async {
    final picked = await showAmountKeypadSheet(
      context,
      initialAmount: _unitPrice,
      currency: widget.currency,
    );
    if (picked == null || !mounted) return;
    field.didChange(amountToFieldText(picked, widget.currency));
  }

  /// Adopts the amount field's new [value] as this row's unit price, whoever
  /// wrote it: the row's own keypad, or the editor writing a rescanned total
  /// or a switch-back re-conversion into the field. The row draws its price
  /// and line total from [_unitPrice] while the itemized total and the save
  /// read the field, so a write the row missed showed one amount and saved
  /// another. [didUpdateWidget] cannot cover it: rescanning the same total
  /// leaves [ExpenseEntryWidget.initialAmount] unchanged.
  void _adoptUnitPrice(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '');
    if (price == null || price == _unitPrice) return;
    setState(() {
      final oldTotal = _entryTotal;
      _unitPrice = price;
      _onTotalChanged(oldTotal);
    });
  }

  /// Adopts the quantity field's new [value] as this row's quantity, whoever
  /// wrote it: the stepper, or the editor resetting a rescanned item to one
  /// unit. Same reason as [_adoptUnitPrice].
  void _adoptQuantity(dynamic value) {
    final qty = int.tryParse(value?.toString() ?? '');
    if (qty == null || qty < 1 || qty == _quantity) return;
    setState(() {
      final oldTotal = _entryTotal;
      _quantity = qty;
      _onTotalChanged(oldTotal);
    });
  }

  Widget _buildSplitModeSelector(AppLocalizations l10n) {
    return AppSegmentedControl<SplitMode>(
      value: _splitMode,
      segments: [
        AppSegment(value: SplitMode.equal, label: l10n.splitModeEqual),
        AppSegment(value: SplitMode.shares, label: l10n.splitModeShares),
        AppSegment(
          value: SplitMode.percentage,
          label: l10n.splitModePercentage,
        ),
        AppSegment(value: SplitMode.amount, label: l10n.splitModeExact),
      ],
      onChanged: (SplitMode selected) {
        setState(() {
          _splitMode = selected;
          _lockedMembers.clear();
          // Dispose old controllers so new ones get created for the new mode
          for (var controller in _memberControllers.values) {
            controller.dispose();
          }
          _memberControllers.clear();
          // Initialize defaults for new mode
          for (var email in _enabledMembers) {
            if (!_memberParts.containsKey(email)) {
              _memberParts[email] = 1;
            }
          }
          _updateSplitState(controllersInvalid: true);
        });
      },
    );
  }

  /// Whether the split adds up: the save-time check the shares validator reads
  /// live. [SplitAllocation.compute] is its one copy (it replaced
  /// `_isSplitValid`, which matched it in every mode).
  bool _isSplitBalanced() =>
      SplitAllocation.compute(
        mode: _splitMode,
        total: _entryTotal,
        amounts: _memberAmounts,
        percentages: _memberPercentages,
        parts: _memberParts,
        enabled: _enabledMembers,
        currency: widget.currency,
      ).status ==
      AllocationStatus.ok;

  void _syncFormFields() {
    final formState = FormBuilder.of(context);
    if (formState == null) return;
    final prefix = "expense_entry[${widget.index}]";
    formState.fields["$prefix[shares]"]?.didChange(_enabledMembers);
    formState.fields["$prefix[share_data]"]?.didChange(_buildShareData());
    formState.fields["$prefix[split_mode]"]?.didChange(_splitMode.toDbValue());
    formState.fields["$prefix[locked_members]"]?.didChange(_lockedMembers);
  }

  /// Toggle a member in/out of the split. Reuses the exact body the old
  /// Material Checkbox.onChanged ran, so the split math is unchanged.
  void _toggleMember(GroupMember member, bool include) {
    setState(() {
      if (include) {
        _enabledMembers.add(member.email);
        if (_splitMode == SplitMode.shares) {
          _memberParts[member.email] = 1;
        }
      } else {
        _enabledMembers.remove(member.email);
        _lockedMembers.remove(member.email);
      }
      _updateSplitState();
    });
  }

  void _stepPercentage(String email, double delta) {
    setState(() {
      final next = ((_memberPercentages[email] ?? 0) + delta).clamp(0.0, 100.0);
      _memberPercentages[email] = next;
      _lockedMembers.add(email);
      _updateSplitState();
    });
  }

  void _stepAmount(String email, double delta) {
    setState(() {
      final next = roundCurrency(
        ((_memberAmounts[email] ?? 0) + delta),
        widget.currency,
      );
      _memberAmounts[email] = next < 0 ? 0 : next;
      _lockedMembers.add(email);
      _updateSplitState();
    });
  }

  void _setParts(String email, int parts) {
    setState(() {
      _memberParts[email] = parts;
      _updateSplitState();
    });
  }

  void _setPercentage(String email, double percentage) {
    setState(() {
      _memberPercentages[email] = percentage;
      _lockedMembers.add(email);
      _updateSplitState();
    });
  }

  TextEditingController _getOrCreateController(
    String key,
    String initialValue,
  ) {
    _memberControllers[key] ??= TextEditingController(text: initialValue);
    return _memberControllers[key]!;
  }

  void _updateUnlockedControllers() {
    for (var email in _enabledMembers) {
      if (_lockedMembers.contains(email)) continue;
      switch (_splitMode) {
        case SplitMode.equal:
          break; // No per-member text inputs in equal mode
        case SplitMode.amount:
          String key = "amount_${widget.index}_$email";
          // Display text, not field text: this controller is never parsed, it
          // is only rendered by the tile's Text below. It must therefore use the
          // same locale formatting the tile is seeded with, or a German user
          // would see "12,50" until the first recompute and "12.50" after.
          String newVal = formatAmountOnly(
            _memberAmounts[email] ?? 0,
            widget.currency,
            Localizations.localeOf(context),
          );
          if (_memberControllers.containsKey(key) &&
              _memberControllers[key]!.text != newVal) {
            _memberControllers[key]!.text = newVal;
          }
          break;
        case SplitMode.percentage:
          String key = "pct_${widget.index}_$email";
          String newVal = (_memberPercentages[email] ?? 0).toStringAsFixed(1);
          if (_memberControllers.containsKey(key) &&
              _memberControllers[key]!.text != newVal) {
            _memberControllers[key]!.text = newVal;
          }
          break;
        case SplitMode.shares:
          break; // Parts don't auto-adjust
      }
    }
  }

  /// F158: opens the shared amount keypad for a per-member exact amount. Runs
  /// the same mutation the old inline onChanged did (set _memberAmounts, lock
  /// the member, recalc) so the persisted fixed_amount and split math are
  /// unchanged; also writes the controller text so the tile display refreshes.
  Future<void> _openMemberAmountKeypad(
    String email,
    TextEditingController controller,
  ) async {
    final current = _memberAmounts[email] ?? 0;
    final picked = await showAmountKeypadSheet(
      context,
      initialAmount: current,
      currency: widget.currency,
    );
    if (picked == null || !mounted) return;
    // Display-only controller (see _updateUnlockedControllers): locale-formatted
    // like the tile's seed, never re-parsed. _memberAmounts below stays the
    // numeric source of truth.
    controller.text = formatAmountOnly(
      picked,
      widget.currency,
      Localizations.localeOf(context),
    );
    setState(() {
      _memberAmounts[email] = picked;
      _lockedMembers.add(email);
      _updateSplitState();
    });
  }

  /// The amount [email] would owe under the current split mode, in the entry's
  /// currency. A number, not text: both callers need it numerically (one hands
  /// it to [MoneyText], the other sizes a segment with it), so formatting it
  /// here only added a parse back and a locale hazard.
  double _getAmountPreview(String email) {
    double preview = 0;
    switch (_splitMode) {
      case SplitMode.equal:
        preview = _enabledMembers.isNotEmpty
            ? _entryTotal / _enabledMembers.length
            : 0;
        break;
      case SplitMode.percentage:
        double pct = _memberPercentages[email] ?? 0;
        preview = _entryTotal * pct / 100;
        break;
      case SplitMode.shares:
        int totalParts = _enabledMembers.fold(
          0,
          (sum, e) => sum + (_memberParts[e] ?? 1),
        );
        int myParts = _memberParts[email] ?? 1;
        preview = totalParts > 0 ? _entryTotal * myParts / totalParts : 0;
        break;
      case SplitMode.amount:
        preview = _memberAmounts[email] ?? 0;
        break;
    }
    // Rounded to the entry currency's precision so the preview and the bar agree
    // with what MoneyText renders.
    return roundCurrency(preview, widget.currency);
  }
}
