import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';

import 'restyle/expense_picker_sheets.dart';
import 'restyle/soft_card.dart';

/// The category trigger tile for the expense editor. Renders the currently
/// selected [ExpenseCategory] (icon tint + name) inside a [SoftCard]; tapping
/// opens the restyled category grid sheet ([showCategoryGridSheet]).
///
/// Selection logic is unchanged: it writes the same [ExpenseCategory] to the
/// `FormBuilderField` and calls [onChanged].
class CategorySelector extends StatefulWidget {
  const CategorySelector({
    super.key,
    required this.name,
    this.initialValue,
    this.onChanged,
    this.enabled = true,
  });

  final String name;
  final ExpenseCategory? initialValue;
  final ValueChanged<ExpenseCategory?>? onChanged;
  final bool enabled;

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  ExpenseCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialValue ?? ExpenseCategory.other;
  }

  @override
  void didUpdateWidget(CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _selectedCategory = widget.initialValue ?? ExpenseCategory.other;
    }
  }

  void _selectCategory(ExpenseCategory category) {
    setState(() {
      _selectedCategory = category;
    });
    widget.onChanged?.call(category);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FormBuilderField<ExpenseCategory>(
      name: widget.name,
      initialValue: widget.initialValue,
      enabled: widget.enabled,
      builder: (FormFieldState<ExpenseCategory> field) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        // Keep the visible selection in sync with the form value (e.g. when the
        // category is auto-detected from the title).
        final current = field.value ?? _selectedCategory!;

        return SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: widget.enabled
              ? () async {
                  final picked = await showCategoryGridSheet(
                    context,
                    selected: current,
                  );
                  if (picked != null) {
                    _selectCategory(picked);
                    field.didChange(picked);
                  }
                }
              : null,
          child: Row(
            children: [
              _CategoryIcon(category: current),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizations.categoryLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.getDisplayName(localizations),
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.enabled)
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final color = category.getColor(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(category.getIcon(), color: color, size: 20),
    );
  }
}
