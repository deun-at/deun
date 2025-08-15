import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/expense_category.dart';

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
            return InkWell(
              onTap: widget.enabled
                  ? () {
                      controller.text = ''; // Clear search field when opening
                      controller.openView();
                    }
                  : null,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: localizations.expenseCategory,
                  labelStyle: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(0),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedCategory != null && widget.enabled)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _selectCategory(null);
                            field.didChange(null);
                          },
                        ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                child: _selectedCategory != null
                    ? Row(
                        children: [
                          Icon(
                            _selectedCategory!.getIcon(),
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedCategory!.getDisplayName(localizations),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
              ),
            );
          },
          suggestionsBuilder: (BuildContext context, SearchController controller) {
            final query = controller.text.toLowerCase();
            final filteredCategories = query.isEmpty
                ? ExpenseCategory.values.toList()
                : ExpenseCategory.values.where((category) {
                    final categoryName = category.getDisplayName(localizations).toLowerCase();
                    return categoryName.contains(query);
                  }).toList();

            return filteredCategories.map((category) {
              return ListTile(
                leading: Icon(
                  category.getIcon(),
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(category.getDisplayName(localizations)),
                onTap: () {
                  _selectCategory(category);
                  field.didChange(category);
                  controller.closeView(category.getDisplayName(localizations));
                },
              );
            }).toList();
          },
        );
      },
    );
  }
}
