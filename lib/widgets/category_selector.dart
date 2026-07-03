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
    this.compact = false,
  });

  final String name;
  final ExpenseCategory? initialValue;
  final ValueChanged<ExpenseCategory?>? onChanged;
  final bool enabled;

  /// When true, renders a centered category tile (tinted square icon + edit
  /// badge) instead of the full-width row card. Used above the amount field in
  /// the quick-split editor (v3 design_08/09).
  final bool compact;

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

        Future<void> openPicker() async {
          final picked = await showCategoryGridSheet(context, selected: current);
          if (picked != null) {
            _selectCategory(picked);
            field.didChange(picked);
          }
        }

        if (widget.compact) {
          return _CategoryTile(
            category: current,
            onTap: widget.enabled ? openPicker : null,
          );
        }

        return SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: widget.enabled ? openPicker : null,
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

/// Centered, prominent category tile for the quick-split editor: a tinted
/// 62×62 rounded square holding the category icon, with a small edit badge in
/// the bottom-right corner (v3 design_08/09).
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, this.onTap});

  final ExpenseCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Colorless: uniform primary tint for every category (v3 handoff), not the
    // per-category color.
    final color = colorScheme.primary;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(category.getIcon(), color: color, size: 30),
              ),
              if (onTap != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.outlineVariant, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.edit, size: 14, color: colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    // Colorless: uniform primary tint (v3 handoff), not the per-category color.
    final color = Theme.of(context).colorScheme.primary;
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
