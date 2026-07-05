import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../widgets/decimal_text_input_formatter.dart';
import '../../../widgets/restyle/app_segmented_control.dart';
import '../../../widgets/restyle/expense_picker_sheets.dart';
import '../../../widgets/restyle/member_avatar.dart';
import '../../../widgets/restyle/money_text.dart';
import '../../../widgets/restyle/section_label.dart';
import '../../../widgets/restyle/soft_card.dart';
import '../../../widgets/restyle/stepper_control.dart';
import '../../groups/data/group_member_model.dart';
import '../data/expense_entry_model.dart';
import '../data/item_icon.dart';
import '../data/split_allocation.dart';
import '../data/split_mode.dart';

class ExpenseEntryWidget extends StatefulWidget {
  const ExpenseEntryWidget({
    super.key,
    required this.expenseEntry,
    required this.index,
    required this.onRemove,
    required this.groupMembers,
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
    widget.expenseLevelAmountController?.removeListener(_onExpenseLevelAmountChanged);
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

    String amountStr = widget.initialAmount ??
        (widget.expenseEntry.expenseEntryShares.isNotEmpty
            ? widget.expenseEntry.unitPrice.toStringAsFixed(2)
            // Single-entry mode: seed from the expense-level amount so the
            // split previews are correct before the first keystroke.
            : (widget.expenseLevelAmountController?.text ?? "0"));
    _unitPrice = double.tryParse(amountStr) ?? 0;

    _itemName = widget.initialName ??
        (widget.expenseEntry.expenseEntryShares.isNotEmpty
            ? (widget.expenseEntry.name ?? '')
            : '');

    // Initialize enabled members
    if (widget.expenseEntry.expenseEntryShares.isNotEmpty) {
      _enabledMembers =
          widget.expenseEntry.expenseEntryShares.map((e) => e.email).toSet();
    } else {
      _enabledMembers = widget.groupMembers.map((e) => e.email).toSet();
    }

    // Initialize per-member values from existing shares
    _memberAmounts = {};
    _memberPercentages = {};
    _memberParts = {};

    if (widget.expenseEntry.expenseEntryShares.isNotEmpty) {
      for (var share in widget.expenseEntry.expenseEntryShares) {
        _memberPercentages[share.email] = share.percentage;
        _memberAmounts[share.email] =
            share.fixedAmount ?? (_entryTotal * share.percentage / 100);
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
    widget.expenseLevelAmountController?.addListener(_onExpenseLevelAmountChanged);
  }

  void _onExpenseLevelAmountChanged() {
    final newPrice = double.tryParse(
      widget.expenseLevelAmountController?.text ?? '',
    ) ?? 0;
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
        _recalculateAmounts();
        break;
      case SplitMode.percentage:
        _recalculatePercentages();
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

  void _recalculateAmounts() {
    List<String> enabled = _enabledMembers.toList();
    if (enabled.isEmpty) return;

    double lockedSum = 0;
    int unlockedCount = 0;
    for (var email in enabled) {
      if (_lockedMembers.contains(email)) {
        lockedSum += _memberAmounts[email] ?? 0;
      } else {
        unlockedCount++;
      }
    }

    double remaining = _entryTotal - lockedSum;
    double perUnlocked = unlockedCount > 0 ? remaining / unlockedCount : 0;

    for (var email in enabled) {
      if (!_lockedMembers.contains(email)) {
        _memberAmounts[email] = perUnlocked;
      }
    }
  }

  void _recalculatePercentages() {
    List<String> enabled = _enabledMembers.toList();
    if (enabled.isEmpty) return;

    double lockedSum = 0;
    int unlockedCount = 0;
    for (var email in enabled) {
      if (_lockedMembers.contains(email)) {
        lockedSum += _memberPercentages[email] ?? 0;
      } else {
        unlockedCount++;
      }
    }

    double remaining = 100 - lockedSum;
    double perUnlocked = unlockedCount > 0 ? remaining / unlockedCount : 0;

    for (var email in enabled) {
      if (!_lockedMembers.contains(email)) {
        _memberPercentages[email] = perUnlocked;
      }
    }
  }

  void _scaleLockedMembers(double oldTotal, double newTotal) {
    if (oldTotal <= 0 || newTotal <= 0 || _lockedMembers.isEmpty) {
      _lockedMembers.clear();
      return;
    }
    double ratio = newTotal / oldTotal;
    for (var email in _lockedMembers) {
      _memberAmounts[email] = (_memberAmounts[email] ?? 0) * ratio;
    }
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
              : roundCurrency(_entryTotal / _enabledMembers.length);
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

  String _getDisplayName(String email) {
    if (email == supabase.auth.currentUser?.email) {
      return AppLocalizations.of(context)!.you;
    }
    try {
      return widget.groupMembers.firstWhere((m) => m.email == email).displayName;
    } catch (_) {
      return email;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      // Itemized rows sit inside the parent's joined SoftCard and own their
      // padding via _buildItemCard, so no outer inset (BUG D). Quick keeps the
      // split-section inset.
      padding: widget.isSingleEntry
          ? const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8)
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
            _buildItemCard(spacing, l10n),
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
            _buildAllocationSummary(l10n),
            const SizedBox(height: spacing),
            _buildMemberList(spacing, l10n),
            _buildHiddenFormFields(),
          ],
        ],
      ),
    );
  }

  /// F117 item row: leading auto-icon tile, inline-editable name +
  /// "€ [price] each", line total right; bottom row = trash left, qty
  /// stepper right. Wraps the same FormBuilderFields (name / amount /
  /// quantity) so saving, the itemized total, and the claim explosion
  /// (F118/F146) stay wired to unchanged state.
  ///
  /// BUG D: renders as a FLAT row (no own SoftCard) — the parent joins all item
  /// rows inside ONE SoftCard, so wrapping here too produced a card-in-card.
  Widget _buildItemCard(double spacing, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading auto-icon tile (iconForItemName, F116) in a small
              // rounded tinted square.
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  iconForItemName(_itemName),
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              // Name (inline field) + "€ [price] each" (inline field).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(l10n),
                    const SizedBox(height: 3),
                    _buildUnitPriceField(l10n),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Line total (price × qty), right-aligned.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.toCurrency(_entryTotal),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bottom row: trash left, qty stepper right.
          Row(
            children: [
              IconButton(
                onPressed: () => widget.onRemove(),
                icon: const Icon(Icons.delete_outline),
                color: Theme.of(context).extension<SemanticColors>()!.danger,
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
              const Spacer(),
              _buildQuantityStepper(l10n),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return FormBuilderField(
      key: ValueKey("${widget.index}_name"),
      name: "expense_entry[${widget.index}][name]",
      initialValue: widget.initialName,
      builder: (FormFieldState<dynamic> field) => TextFormField(
        initialValue: field.value,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.itemNameHint,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (value) {
          field.didChange(value);
          setState(() => _itemName = value);
        },
      ),
    );
  }

  /// F158: opens the shared amount keypad for the itemized unit price. On
  /// confirm it writes back through the same channels the old inline field
  /// used — the FormBuilderField (validated/saved) plus the same _unitPrice /
  /// _onTotalChanged split-recalc — so the persisted value and split math are
  /// unchanged. Format matches the old field (toStringAsFixed(2)).
  Future<void> _openUnitPriceKeypad(FormFieldState<dynamic> field) async {
    final picked = await showAmountKeypadSheet(context, initialAmount: _unitPrice);
    if (picked == null || !mounted) return;
    final text = picked.toStringAsFixed(2);
    field.didChange(text);
    setState(() {
      double oldTotal = _entryTotal;
      _unitPrice = picked;
      _onTotalChanged(oldTotal);
    });
  }

  Widget _buildUnitPriceField(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return FormBuilderField(
      key: ValueKey("${widget.index}_amount"),
      name: "expense_entry[${widget.index}][amount]",
      initialValue: widget.initialAmount ??
          (widget.expenseEntry.expenseEntryShares.isNotEmpty
              ? widget.expenseEntry.unitPrice.toStringAsFixed(2)
              : null),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(
          errorText: l10n.expenseEntryAmountValidationEmpty,
        ),
        (value) {
          final amount = double.tryParse(value?.toString() ?? '');
          if (amount != null && amount <= 0) {
            return l10n.expenseEntryAmountValidationZero;
          }
          return null;
        },
      ]),
      builder: (FormFieldState<dynamic> field) {
        return InputDecorator(
          decoration: InputDecoration(
            errorText: field.errorText,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "€",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 4),
              // Tap-to-open keypad (F158): the unit price is money, so it routes
              // through showAmountKeypadSheet like the quick-split amount, not a
              // raw system-keyboard field. Tinted pill reads as editable.
              InkWell(
                onTap: () => _openUnitPriceKeypad(field),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40, maxWidth: 90),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _unitPrice.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.itemPriceEachSuffix,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuantityStepper(AppLocalizations l10n) {
    return FormBuilderField(
      key: ValueKey("${widget.index}_quantity"),
      name: "expense_entry[${widget.index}][quantity]",
      initialValue: _quantity.toString(),
      builder: (FormFieldState<dynamic> qtyField) {
        void updateQty(int newQty) {
          if (newQty < 1) newQty = 1;
          qtyField.didChange(newQty.toString());
          setState(() {
            double oldTotal = _entryTotal;
            _quantity = newQty;
            _onTotalChanged(oldTotal);
          });
        }

        return StepperControl(
          value: l10n.itemQtyStepperValue(_quantity),
          canDecrement: _quantity > 1,
          onDecrement: () => updateQty(_quantity - 1),
          onIncrement: () => updateQty(_quantity + 1),
        );
      },
    );
  }

  Widget _buildSplitModeSelector(AppLocalizations l10n) {
    return AppSegmentedControl<SplitMode>(
      value: _splitMode,
      segments: [
        AppSegment(value: SplitMode.equal, label: l10n.splitModeEqual),
        AppSegment(value: SplitMode.shares, label: l10n.splitModeShares),
        AppSegment(value: SplitMode.percentage, label: l10n.splitModePercentage),
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

  bool _isSplitValid() {
    if (_enabledMembers.isEmpty) return false;
    switch (_splitMode) {
      case SplitMode.equal:
        // Equal is always fully allocated over the included members.
        return true;
      case SplitMode.amount:
        double sum = _enabledMembers.fold(
            0.0, (s, email) => s + (_memberAmounts[email] ?? 0));
        // Member amounts must add up to the entry total exactly at cent
        // level — anything looser silently creates or destroys money.
        return (roundCurrency(sum) - roundCurrency(_entryTotal)).abs() < 0.005;
      case SplitMode.percentage:
        double sum = _enabledMembers.fold(
            0.0, (s, email) => s + (_memberPercentages[email] ?? 0));
        return (sum - 100).abs() < 0.01;
      case SplitMode.shares:
        int totalParts = _enabledMembers.fold(
            0, (sum, e) => sum + (_memberParts[e] ?? 1));
        return totalParts > 0;
    }
  }

  void _syncFormFields() {
    final formState = FormBuilder.of(context);
    if (formState == null) return;
    final prefix = "expense_entry[${widget.index}]";
    formState.fields["$prefix[shares]"]?.didChange(_enabledMembers);
    formState.fields["$prefix[share_data]"]?.didChange(_buildShareData());
    formState.fields["$prefix[split_mode]"]?.didChange(_splitMode.toDbValue());
    formState.fields["$prefix[locked_members]"]?.didChange(_lockedMembers);
  }

  Widget _buildMemberList(double spacing, AppLocalizations l10n) {
    return Column(
      children: [
        // Shares field with validation
        FormBuilderField(
          key: ValueKey("${widget.index}_shares"),
          name: "expense_entry[${widget.index}][shares]",
          initialValue: _enabledMembers,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            Set<String>? shares = value;
            if (shares == null || shares.isEmpty) {
              return l10n.expenseEntrySharesValidationEmpty;
            }
            if (!_isSplitValid()) {
              switch (_splitMode) {
                case SplitMode.percentage:
                  return l10n.splitPercentageError;
                case SplitMode.amount:
                  return l10n.splitAmountError;
                case SplitMode.equal:
                case SplitMode.shares:
                  return l10n.expenseEntrySharesValidationEmpty;
              }
            }
            return null;
          },
          builder: (FormFieldState<dynamic> sharesField) {
            // F161 D1: only the member rows sit in a white SoftCard (radius 18,
            // padding v6/h4). No "Split between" InputDecorator label — the
            // section heading above already names it. errorText kept below.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    children: [
                      ...widget.groupMembers.map((member) {
                        bool isEnabled = _enabledMembers.contains(member.email);
                        return _buildMemberRow(member, isEnabled, sharesField);
                      }),
                    ],
                  ),
                ),
                if (sharesField.errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      sharesField.errorText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Hidden fields for share_data, split_mode, locked_members
        Offstage(
          child: Column(
            children: [
              FormBuilderField(
                key: ValueKey("${widget.index}_share_data"),
                name: "expense_entry[${widget.index}][share_data]",
                initialValue: _buildShareData(),
                builder: (field) => const SizedBox.shrink(),
              ),
              FormBuilderField(
                key: ValueKey("${widget.index}_split_mode"),
                name: "expense_entry[${widget.index}][split_mode]",
                initialValue: _splitMode.toDbValue(),
                builder: (field) => const SizedBox.shrink(),
              ),
              FormBuilderField(
                key: ValueKey("${widget.index}_locked_members"),
                name: "expense_entry[${widget.index}][locked_members]",
                initialValue: _lockedMembers,
                builder: (field) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
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

  /// F161 D4: custom 26px round include toggle (mockup L982-988).
  /// Included = filled primary circle + white check(17); excluded = empty
  /// circle with a 2px outlineVariant border. The gesture box is padded out to
  /// a ≥48px hit target while the visual stays 26px.
  Widget _buildIncludeToggle(GroupMember member, bool isEnabled) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: isEnabled,
      label: _getDisplayName(member.email),
      child: GestureDetector(
        key: ValueKey('split_toggle_${widget.index}_${member.email}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleMember(member, !isEnabled),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnabled ? colorScheme.primary : Colors.transparent,
              border: isEnabled
                  ? null
                  : Border.all(color: colorScheme.outlineVariant, width: 2),
            ),
            child: isEnabled
                ? Icon(Icons.check, size: 17, color: colorScheme.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberRow(
    GroupMember member,
    bool isEnabled,
    FormFieldState<dynamic> sharesField,
  ) {
    String displayName = _getDisplayName(member.email);
    bool isLocked = _lockedMembers.contains(member.email);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // F161 D4: 26px round include-toggle. Included = filled primary
          // circle + white check(17); excluded = empty circle with a 2px
          // outlineVariant border. ≥48px tap target via the padded gesture box.
          _buildIncludeToggle(member, isEnabled),
          // Avatar
          Opacity(
            opacity: isEnabled ? 1 : 0.4,
            child: MemberAvatar(
              name: displayName,
              colorKey: member.email,
              radius: 16,
              isYou: member.email == supabase.auth.currentUser?.email,
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isEnabled ? null : Theme.of(context).disabledColor,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Input area — fixed width to prevent layout shifts
          isEnabled
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Exact (amount) mode keeps the editable field; shares/%
                    // use a ± stepper; equal shows just the per-head amount.
                    if (_splitMode == SplitMode.amount) ...[
                      _buildMemberInput(member.email),
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(Icons.lock_outline,
                              size: 14,
                              color: Theme.of(context).colorScheme.outline),
                        ),
                    ] else ...[
                      if (_splitMode != SplitMode.equal) ...[
                        _buildMemberStepper(member.email),
                        const SizedBox(width: 6),
                      ],
                      // € preview for equal, percentage and parts mode
                      SizedBox(
                        width: 52,
                        child: MoneyText(
                          double.parse(_getAmountPreview(member.email)),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ],
                )
              // Excluded members show a muted "Not in" instead of an amount.
              : Text(
                  AppLocalizations.of(context)!.splitNotInLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                ),
        ],
      ),
    );
  }

  /// A ± stepper for non-equal modes: ±1 part (shares), ±5% (percentage),
  /// ±€0.50 (amount). Mutates the same per-member maps the text inputs use and
  /// runs the existing recalculation path so the split math is unchanged.
  Widget _buildMemberStepper(String email) {
    switch (_splitMode) {
      case SplitMode.equal:
        // Equal has no per-member control — never reached (guarded in
        // _buildMemberRow).
        return const SizedBox.shrink();
      case SplitMode.shares:
        final parts = _memberParts[email] ?? 1;
        return StepperControl(
          value: "$parts",
          canDecrement: parts > 0,
          onDecrement: () => setState(() {
            _memberParts[email] = (parts - 1).clamp(0, 9999);
            _updateSplitState();
          }),
          onIncrement: () => setState(() {
            _memberParts[email] = parts + 1;
            _updateSplitState();
          }),
        );
      case SplitMode.percentage:
        final pct = _memberPercentages[email] ?? 0;
        return StepperControl(
          value: "${pct.toStringAsFixed(0)}%",
          canDecrement: pct > 0,
          onDecrement: () => _stepPercentage(email, -5),
          onIncrement: () => _stepPercentage(email, 5),
        );
      case SplitMode.amount:
        final amt = _memberAmounts[email] ?? 0;
        return StepperControl(
          value: AppLocalizations.of(context)!.toCurrency(amt),
          canDecrement: amt > 0,
          onDecrement: () => _stepAmount(email, -0.50),
          onIncrement: () => _stepAmount(email, 0.50),
        );
    }
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
      final next = roundCurrency(((_memberAmounts[email] ?? 0) + delta));
      _memberAmounts[email] = next < 0 ? 0 : next;
      _lockedMembers.add(email);
      _updateSplitState();
    });
  }

  TextEditingController _getOrCreateController(
      String key, String initialValue) {
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
          String newVal = (_memberAmounts[email] ?? 0).toStringAsFixed(2);
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
    final picked = await showAmountKeypadSheet(context, initialAmount: current);
    if (picked == null || !mounted) return;
    controller.text = picked.toStringAsFixed(2);
    setState(() {
      _memberAmounts[email] = picked;
      _lockedMembers.add(email);
      _updateSplitState();
    });
  }

  Widget _buildMemberInput(String email) {
    switch (_splitMode) {
      case SplitMode.equal:
        // Equal has no editable input — never reached (guarded in
        // _buildMemberRow).
        return const SizedBox.shrink();
      case SplitMode.amount:
        double val = _memberAmounts[email] ?? 0;
        String ctrlKey = "amount_${widget.index}_$email";
        TextEditingController controller =
            _getOrCreateController(ctrlKey, val.toStringAsFixed(2));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("€", style: Theme.of(context).textTheme.bodyLarge),
            // Tap-to-open keypad (F158): per-member exact amount is money, so it
            // routes through showAmountKeypadSheet instead of a raw system-keyboard
            // field. The controller stays the source of truth (so
            // _updateUnlockedControllers still syncs it); confirm runs the same
            // mutation the old onChanged did (lock member + recalc).
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => InkWell(
                key: ValueKey(ctrlKey),
                onTap: () => _openMemberAmountKeypad(email, controller),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      controller.text.isEmpty ? "0.00" : controller.text,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case SplitMode.percentage:
        double val = _memberPercentages[email] ?? 0;
        String ctrlKey = "pct_${widget.index}_$email";
        TextEditingController controller =
            _getOrCreateController(ctrlKey, val.toStringAsFixed(1));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 30, maxWidth: 60),
                child: TextFormField(
                  key: ValueKey(ctrlKey),
                  controller: controller,
                  onChanged: (value) {
                    setState(() {
                      _memberPercentages[email] = double.tryParse(value) ?? 0;
                      _lockedMembers.add(email);
                      _updateSplitState();
                    });
                  },
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalTextInputFormatter(decimalRange: 1)],
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Text(" %", style: Theme.of(context).textTheme.bodyLarge),
          ],
        );

      case SplitMode.shares:
        int val = _memberParts[email] ?? 1;
        String ctrlKey = "parts_${widget.index}_$email";
        TextEditingController controller =
            _getOrCreateController(ctrlKey, val.toString());
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 20, maxWidth: 40),
                child: TextFormField(
                  key: ValueKey(ctrlKey),
                  controller: controller,
                  onChanged: (value) {
                    setState(() {
                      _memberParts[email] = int.tryParse(value) ?? 1;
                      _updateSplitState();
                    });
                  },
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Text("x", style: Theme.of(context).textTheme.bodyLarge),
          ],
        );
    }
  }

  String _getAmountPreview(String email) {
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
            0, (sum, e) => sum + (_memberParts[e] ?? 1));
        int myParts = _memberParts[email] ?? 1;
        preview = totalParts > 0 ? _entryTotal * myParts / totalParts : 0;
        break;
      case SplitMode.amount:
        preview = _memberAmounts[email] ?? 0;
        break;
    }
    return preview.toStringAsFixed(2);
  }

  /// F161 D3: ONE 10px / radius-6 segmented bar on a [surfaceContainerHighest]
  /// track. Each INCLUDED member gets a segment sized as their share OF THE
  /// TOTAL (not of the allocated sum), colored with their avatar color (same
  /// [memberAvatarColor] the [MemberAvatar] uses; "you" uses primary). When the
  /// split under-allocates, the segments don't fill the track — the leftover
  /// track shows through as a visible empty remainder. Rebuilds with the parent
  /// [setState] as members toggle or amounts change.
  Widget _buildSplitSegments(SplitAllocation allocation) {
    final colorScheme = Theme.of(context).colorScheme;
    final youEmail = supabase.auth.currentUser?.email;

    // Fraction of the total each segment occupies. For amount mode this is the
    // per-member amount / total (so an under-allocation leaves empty track); for
    // the other modes SplitAllocation.fraction is 1.0 (equal/shares/percent-ok)
    // or <1 (percent under), and each member's slice is their share of that.
    final children = <Widget>[];
    for (final member in widget.groupMembers) {
      if (!_enabledMembers.contains(member.email)) continue;
      final amount = double.tryParse(_getAmountPreview(member.email)) ?? 0;
      final double flexOfTotal = _entryTotal > 0
          ? (amount / _entryTotal).clamp(0.0, 1.0).toDouble()
          : 0.0;
      // Positive int flex; a zero-share included member keeps a hairline so
      // their color/presence stays visible.
      final flex = (flexOfTotal * 10000).round().clamp(1, 1 << 30);
      final color = member.email == youEmail
          ? colorScheme.primary
          : memberAvatarColor(member.email);
      children.add(Expanded(
        flex: flex,
        child: Container(
          key: ValueKey('split_segment_${widget.index}_${member.email}'),
          color: color,
        ),
      ));
    }

    // Empty remainder: the unallocated slice of the track (visible when the
    // split under-allocates). Over-allocation clamps to a full bar.
    final remainderFlex =
        ((1.0 - allocation.fraction).clamp(0.0, 1.0) * 10000).round();
    if (remainderFlex > 0) {
      children.add(Expanded(flex: remainderFlex, child: const SizedBox()));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 10,
        color: colorScheme.surfaceContainerHighest,
        child: children.isEmpty ? null : Row(children: children),
      ),
    );
  }

  /// F161 D3/D5: one colored bar + a single right-aligned, status-aware remain
  /// label. Reads the same numbers the save-time validation uses (via the pure
  /// [SplitAllocation] helper) so the bar, the label color, and validity stay in
  /// sync. No ProgressBar and no left-aligned detail — matches the v3 mockup.
  Widget _buildAllocationSummary(AppLocalizations l10n) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final allocation = SplitAllocation.compute(
      mode: _splitMode,
      total: _entryTotal,
      amounts: _memberAmounts,
      percentages: _memberPercentages,
      parts: _memberParts,
      enabled: _enabledMembers,
    );

    // Single right-aligned label: grey default (fully-allocated equal/shares
    // show their per-head / parts detail), success when explicitly all set,
    // warning when under, danger when over.
    final Color labelColor;
    final String label;
    switch (allocation.status) {
      case AllocationStatus.ok:
        // Equal/shares are structurally always ok — keep their neutral detail
        // (grey) rather than a redundant "All set". Amount/percentage reaching
        // exactly 100% earn the success confirmation.
        if (_splitMode == SplitMode.equal || _splitMode == SplitMode.shares) {
          labelColor = colorScheme.onSurfaceVariant;
          label = _allocationDetail(l10n);
        } else {
          labelColor = semantic.success;
          label = l10n.splitAllocatedLabel;
        }
        break;
      case AllocationStatus.under:
        labelColor = semantic.warning;
        label = _splitMode == SplitMode.amount
            ? l10n.splitRemainingLabel(l10n.toCurrency(allocation.remaining))
            : _underLabel(l10n);
        break;
      case AllocationStatus.over:
        labelColor = semantic.danger;
        label = _splitMode == SplitMode.amount
            ? l10n.splitOverLabel(l10n.toCurrency(allocation.remaining.abs()))
            : _overLabel(l10n);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSplitSegments(allocation),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// The left-side detail of the allocation row (allocated / target).
  String _allocationDetail(AppLocalizations l10n) {
    switch (_splitMode) {
      case SplitMode.equal:
        final each = _enabledMembers.isNotEmpty
            ? _entryTotal / _enabledMembers.length
            : 0.0;
        return l10n.splitEqualSummary(l10n.toCurrency(each));
      case SplitMode.amount:
        final sum = _enabledMembers.fold<double>(
            0, (s, e) => s + (_memberAmounts[e] ?? 0));
        return "${l10n.toCurrency(sum)} / ${l10n.toCurrency(_entryTotal)}";
      case SplitMode.percentage:
        final sum = _enabledMembers.fold<double>(
            0, (s, e) => s + (_memberPercentages[e] ?? 0));
        return "${sum.toStringAsFixed(1)}% / 100%";
      case SplitMode.shares:
        final totalParts = _enabledMembers.fold<int>(
            0, (s, e) => s + (_memberParts[e] ?? 1));
        return l10n.splitSharesSummary(totalParts);
    }
  }

  String _underLabel(AppLocalizations l10n) {
    if (_splitMode == SplitMode.percentage) {
      final sum = _enabledMembers.fold<double>(
          0, (s, e) => s + (_memberPercentages[e] ?? 0));
      return "${(100 - sum).toStringAsFixed(1)}%";
    }
    return l10n.expenseEntrySharesValidationEmpty;
  }

  String _overLabel(AppLocalizations l10n) {
    final sum = _enabledMembers.fold<double>(
        0, (s, e) => s + (_memberPercentages[e] ?? 0));
    return "+${(sum - 100).toStringAsFixed(1)}%";
  }

  Widget _buildHiddenFormFields() {
    // These are already rendered inline via FormBuilderField in _buildMemberList
    // No additional hidden fields needed
    return const SizedBox.shrink();
  }
}
