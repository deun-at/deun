import 'package:deun/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../widgets/decimal_text_input_formatter.dart';
import '../../groups/data/group_member_model.dart';
import '../data/expense_entry_model.dart';
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
  });

  final int index;
  final ExpenseEntry expenseEntry;
  final Function onRemove;
  final List<GroupMember> groupMembers;
  final String? initialName;
  final String? initialAmount;
  final String? initialQuantity;
  final bool isSingleEntry;

  @override
  State<ExpenseEntryWidget> createState() => _ExpenseEntryWidgetState();
}

class _ExpenseEntryWidgetState extends State<ExpenseEntryWidget> {
  late SplitMode _splitMode;
  late int _quantity;
  late double _unitPrice;
  late Set<String> _enabledMembers;
  late Map<String, double> _memberAmounts;
  late Map<String, double> _memberPercentages;
  late Map<String, int> _memberParts;
  final Set<String> _lockedMembers = {};
  final Map<String, TextEditingController> _memberControllers = {};

  double get _entryTotal => _unitPrice * _quantity;

  @override
  void dispose() {
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
            : "0");
    _unitPrice = double.tryParse(amountStr) ?? 0;

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
  }

  void _recalculateIfNeeded() {
    if (_enabledMembers.isEmpty) return;

    switch (_splitMode) {
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
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isSingleEntry) ...[
            // Row 1: Name + delete button
            _buildNameRow(spacing, l10n),
            const SizedBox(height: spacing),
            // Row 2: Amount + quantity
            _buildAmountQuantityRow(l10n),
            const SizedBox(height: spacing * 2),
            // Row 3: Split mode selector
            _buildSplitModeSelector(l10n),
            const SizedBox(height: spacing),
          ],
          // Row 4: Member list with inputs
          _buildMemberList(spacing, l10n),
          // Hidden form fields for data submission
          _buildHiddenFormFields(),
        ],
      ),
    );
  }

  Widget _buildNameRow(double spacing, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FormBuilderField(
            key: ValueKey("${widget.index}_name"),
            name: "expense_entry[${widget.index}][name]",
            initialValue: widget.initialName,
            builder: (FormFieldState<dynamic> field) => TextFormField(
              initialValue: field.value,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: l10n.expenseEntryTitle,
              ),
              onChanged: (value) => field.didChange(value),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => widget.onRemove(),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _buildAmountQuantityRow(AppLocalizations l10n) {
    return FormBuilderField(
      key: ValueKey("${widget.index}_amount"),
      name: "expense_entry[${widget.index}][amount]",
      initialValue: widget.initialAmount ??
          (widget.expenseEntry.expenseEntryShares.isNotEmpty
              ? widget.expenseEntry.unitPrice.toStringAsFixed(2)
              : null),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.required(
        errorText: l10n.expenseEntryAmountValidationEmpty,
      ),
      builder: (FormFieldState<dynamic> field) {
        return InputDecorator(
          decoration: InputDecoration(
            errorText: field.errorText,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(0),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Unit price
                  Text("€", style: Theme.of(context).textTheme.headlineMedium),
                  IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 0,
                        maxWidth: MediaQuery.of(context).size.width * 0.35,
                      ),
                      child: TextFormField(
                        initialValue: field.value ?? "0",
                        onChanged: (value) {
                          field.didChange(value);
                          setState(() {
                            double oldTotal = _entryTotal;
                            _unitPrice = double.tryParse(value) ?? 0;
                            _onTotalChanged(oldTotal);
                          });
                        },
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
                        style: Theme.of(context).textTheme.headlineMedium,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.only(right: 10, left: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Quantity with +/- buttons
                  FormBuilderField(
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

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _quantity > 1 ? () => updateQty(_quantity - 1) : null,
                            icon: const Icon(Icons.remove, size: 18),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "${_quantity}x",
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => updateQty(_quantity + 1),
                            icon: const Icon(Icons.add, size: 18),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              // Total always visible on its own line
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "= €${_entryTotal.toStringAsFixed(2)}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSplitModeSelector(AppLocalizations l10n) {
    return Center(
      child: SegmentedButton<SplitMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: SplitMode.amount,
            label: Text(l10n.splitModeAmount),
          ),
          ButtonSegment(
            value: SplitMode.percentage,
            label: Text(l10n.splitModePercentage),
          ),
          ButtonSegment(
            value: SplitMode.shares,
            label: Text(l10n.splitModeShares),
          ),
        ],
        selected: {_splitMode},
        onSelectionChanged: (Set<SplitMode> selected) {
          setState(() {
            _splitMode = selected.first;
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
      ),
    );
  }

  bool _isSplitValid() {
    if (_enabledMembers.isEmpty) return false;
    switch (_splitMode) {
      case SplitMode.amount:
        double sum = _enabledMembers.fold(
            0.0, (s, email) => s + (_memberAmounts[email] ?? 0));
        return (sum - _entryTotal).abs() < 0.01 * _enabledMembers.length.clamp(1, 10);
      case SplitMode.percentage:
        double sum = _enabledMembers.fold(
            0.0, (s, email) => s + (_memberPercentages[email] ?? 0));
        return (sum - 100).abs() < 0.05;
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
                case SplitMode.shares:
                  return l10n.expenseEntrySharesValidationEmpty;
              }
            }
            return null;
          },
          builder: (FormFieldState<dynamic> sharesField) {
            return InputDecorator(
              decoration: InputDecoration(
                label: Text(l10n.expenseEntrySharesLable),
                errorText: sharesField.errorText,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(0),
              ),
              child: Column(
                children: [
                  ...widget.groupMembers.map((member) {
                    bool isEnabled = _enabledMembers.contains(member.email);
                    return _buildMemberRow(member, isEnabled, sharesField);
                  }),
                  if (!widget.isSingleEntry) ...[
                    const SizedBox(height: 4),
                    _buildSummaryRow(),
                  ],
                ],
              ),
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
          // Checkbox
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isEnabled,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
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
              },
            ),
          ),
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
          if (!widget.isSingleEntry)
            SizedBox(
              width: 160,
              child: isEnabled
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildMemberInput(member.email),
                        if (isLocked && _splitMode != SplitMode.shares)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Icon(Icons.lock_outline,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline),
                          ),
                        // € preview for percentage and parts mode
                        if (_splitMode == SplitMode.percentage ||
                            _splitMode == SplitMode.shares) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 60,
                            child: Text(
                              "€${_getAmountPreview(member.email)}",
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.outline,
                                      ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
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

  Widget _buildMemberInput(String email) {
    switch (_splitMode) {
      case SplitMode.amount:
        double val = _memberAmounts[email] ?? 0;
        String ctrlKey = "amount_${widget.index}_$email";
        TextEditingController controller =
            _getOrCreateController(ctrlKey, val.toStringAsFixed(2));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("€", style: Theme.of(context).textTheme.bodyLarge),
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
                child: TextFormField(
                  key: ValueKey(ctrlKey),
                  controller: controller,
                  onChanged: (value) {
                    setState(() {
                      _memberAmounts[email] = double.tryParse(value) ?? 0;
                      _lockedMembers.add(email);
                      _updateSplitState();
                    });
                  },
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
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

  Widget _buildSummaryRow() {
    final l10n = AppLocalizations.of(context)!;
    String summary;
    bool isValid = _isSplitValid();

    switch (_splitMode) {
      case SplitMode.amount:
        double sum = _enabledMembers.fold(
            0.0, (s, email) => s + (_memberAmounts[email] ?? 0));
        summary =
            "${l10n.totalLabel}: €${sum.toStringAsFixed(2)} / €${_entryTotal.toStringAsFixed(2)}";
        break;
      case SplitMode.percentage:
        double sum = _enabledMembers.fold(
            0.0, (s, email) => s + (_memberPercentages[email] ?? 0));
        summary = "${l10n.totalLabel}: ${sum.toStringAsFixed(1)}%";
        break;
      case SplitMode.shares:
        int totalParts = _enabledMembers.fold(
            0, (sum, e) => sum + (_memberParts[e] ?? 1));
        summary =
            "${l10n.splitSharesSummary(totalParts)} · €${_entryTotal.toStringAsFixed(2)}";
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isValid
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(width: 4),
          Icon(
            isValid ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: isValid
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenFormFields() {
    // These are already rendered inline via FormBuilderField in _buildMemberList
    // No additional hidden fields needed
    return const SizedBox.shrink();
  }
}
