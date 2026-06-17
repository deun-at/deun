import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';

import 'card_list_view_builder.dart';
import 'restyle/soft_card.dart';

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
  late final SearchController _searchController;
  ExpenseCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController = SearchController();
    _selectedCategory = widget.initialValue;

    _selectedCategory ??= ExpenseCategory.other;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSearchText();
  }

  @override
  void didUpdateWidget(CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _selectedCategory = widget.initialValue;
      _updateSearchText();
    }
  }

  void _updateSearchText() {
    // Always keep search field empty for better search experience
    _searchController.text = '';
  }

  void _selectCategory(ExpenseCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    _updateSearchText();
    widget.onChanged?.call(category);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FormBuilderField<ExpenseCategory>(
      name: widget.name,
      initialValue: widget.initialValue,
      enabled: widget.enabled,
      builder: (FormFieldState<ExpenseCategory> field) {
        return SearchAnchor(
          searchController: _searchController,
          builder: (BuildContext context, SearchController controller) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            return SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: widget.enabled
                  ? () {
                      controller.text = ''; // Clear search field when opening
                      controller.openView();
                    }
                  : null,
              child: Row(
                children: [
                  _CategoryIcon(category: _selectedCategory!),
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
                          _selectedCategory!.getDisplayName(localizations),
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
          suggestionsBuilder: (BuildContext context, SearchController controller) {
            final query = controller.text.toLowerCase();
            final filteredCategories = query.isEmpty
                ? ExpenseCategory.values.toList()
                : ExpenseCategory.values.where((category) {
                    final categoryName =
                        category.getDisplayName(localizations).toLowerCase();
                    return categoryName.contains(query);
                  }).toList();

            int categoriesLength = filteredCategories.length;

            return filteredCategories.mapIndexed((index, category) {
              bool isTop = false;
              bool isBottom = false;

              if (index == 0) {
                isTop = true;
              }

              if (index == categoriesLength - 1) {
                isBottom = true;
              }

              return CardListTile(
                  isTop: isTop,
                  isBottom: isBottom,
                  child: ListTile(
                    leading: _CategoryIcon(category: category),
                    title: Text(category.getDisplayName(localizations)),
                    onTap: () {
                      _selectCategory(category);
                      field.didChange(category);
                      controller.closeView(category.getDisplayName(localizations));
                    },
                  ));
            }).toList();
          },
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
