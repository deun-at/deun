import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../constants.dart';
import '../data/group_model.dart';
import 'group_member_search.dart';

class GroupEdit extends ConsumerStatefulWidget {
  const GroupEdit({super.key, this.group});

  final Group? group;

  @override
  ConsumerState<GroupEdit> createState() => _GroupEditState();
}

class _GroupEditState extends ConsumerState<GroupEdit> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;

    return ThemeBuilder(
      colorValue: widget.group?.colorValue ?? ColorSeed.blue.color.toARGB32(),
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState!.saveAndValidate()) {
                      Group? newGroup;
                      try {
                        String groupInsertId =
                            await GroupRepository.saveAll(context, widget.group?.id, _formKey.currentState!.value);
                        newGroup = await GroupRepository.fetchDetail(groupInsertId);
                        if (context.mounted) {
                          showSnackBar(context, AppLocalizations.of(context)!.groupCreateSuccess);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showSnackBar(context, AppLocalizations.of(context)!.groupCreateError);
                        }
                      } finally {
                        if (mounted) {
                          if (context.mounted) {
                            if (newGroup != null) {
                              GoRouter.of(context).go("/group");
                              GoRouter.of(context).push("/group/details", extra: {'group': newGroup});
                            }
                          }
                        }
                      }
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.save),
                ),
              )
            ],
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 40),
                child: FormBuilder(
                  key: _formKey,
                  clearValueOnUnregister: true,
                  initialValue: widget.group?.toJson() ?? {},
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FormBuilderField(
                        name: "name",
                        builder: (FormFieldState<dynamic> field) => TextFormField(
                          initialValue: field.value,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(color: Theme.of(context).colorScheme.primary),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: FormBuilderValidators.required(
                            errorText: AppLocalizations.of(context)!.groupNameValidationEmpty,
                          ),
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: AppLocalizations.of(context)!.addGroupTitle,
                            contentPadding: EdgeInsets.only(left: 8, right: 8),
                          ),
                          onChanged: (value) => field.didChange(value),
                        ),
                      ),
                      const SizedBox(height: spacing),
                      _buildColorPicker(),
                      FormBuilderField(
                        name: "group_members",
                        builder: (FormFieldState<dynamic> field) {
                          return GroupMemberSearch(field: field);
                        },
                      ),
                      SizedBox(height: 12),
                      CardListTile(
                        isTop: true,
                        isBottom: true,
                        child: FormBuilderSwitch(
                          name: "simplified_expenses",
                          title: Text(AppLocalizations.of(context)!.groupSimplifiedExpensesTitle),
                          contentPadding: EdgeInsets.only(right: 10, left: 10, top: 5, bottom: 5),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(left: 8, right: 8),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      if (widget.group != null) _buildGroupActions(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorPicker() {
    return FormBuilderField(
      name: "color_value",
      builder: (FormFieldState<dynamic> field) {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: ColorSeed.values.length,
          itemBuilder: (context, i) {
            return IconButton(
              icon: const Icon(Icons.radio_button_unchecked),
              selectedIcon: const Icon(Icons.radio_button_checked),
              color: ColorSeed.values[i].color,
              isSelected: (field.value == ColorSeed.values[i].color.toARGB32() ||
                  (field.value == null &&
                      ColorSeed.values[i].color.toARGB32() == ColorSeed.baseColor.color.toARGB32())),
              onPressed: () {
                field.didChange(ColorSeed.values[i].color.toARGB32());
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupActions(BuildContext context) {
    return Column(
      children: [
        CardListTile(
          isTop: true,
          isBottom: true,
          child: ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(AppLocalizations.of(context)!.groupInviteTitle),
            onTap: () {
              GoRouter.of(context).push("/group/share", extra: {'group': widget.group});
            },
          ),
        ),
        SizedBox(height: 12),
        CardListTile(
          isTop: true,
          isBottom: true,
          child: ListTile(
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            leading: Icon(Icons.delete),
            title: Text(AppLocalizations.of(context)!.groupDeleteItemTitle),
            onTap: () => _showDeleteDialog(context),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext modalContext) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.groupDeleteItemTitle),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
            onPressed: () async {
              try {
                await GroupRepository.delete(widget.group!.id);
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.groupDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.groupDeleteError);
                }
              } finally {
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(modalContext);
                  Navigator.pop(modalContext);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
