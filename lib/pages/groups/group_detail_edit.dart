import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/form_loading_widget.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:deun/widgets/sliver_grab_widget.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../constants.dart';
import '../../main.dart';
import '../../widgets/search_view.dart';
import '../users/user_model.dart';
import 'group_model.dart';

class GroupEdit extends ConsumerStatefulWidget {
  const GroupEdit({super.key, this.group});

  final Group? group;

  @override
  ConsumerState<GroupEdit> createState() => _GroupEditState();
}

class _GroupEditState extends ConsumerState<GroupEdit> {
  final _formKey = GlobalKey<FormBuilderState>();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>("");

  final SearchController _searchAnchorController = SearchController();

  @override
  void dispose() {
    _searchAnchorController.dispose();
    super.dispose();
  }

  Iterable<Widget> getUserSelection(SearchController controller, FormFieldState<dynamic> field) {
    List<Map<String, dynamic>> groupMembers = Group.decodeGroupMembersString(field.value);

    int groupMembersLength = groupMembers.length;

    return groupMembers.mapIndexed((index, user) {
      String titleText = "";
      Widget iconButton;
      if (user['email'] == supabase.auth.currentUser?.email) {
        titleText = AppLocalizations.of(context)!.you;
        iconButton = IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {},
        );
      } else {
        titleText = "${user["display_name"]}";
        iconButton = IconButton.filled(
          style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError),
          icon: const Icon(Icons.delete),
          onPressed: () {
            groupMembers.removeAt(index);
            field.didChange(jsonEncode(groupMembers));

            _searchQueryNotifier.value = jsonEncode(groupMembers);
          },
        );
      }

      bool isTop = false;
      bool isBottom = false;

      if (index == 0) {
        isTop = true;
      }

      if (index == groupMembersLength - 1) {
        isBottom = true;
      }

      return CardListTile(
          isTop: isTop,
          isBottom: isBottom,
          child: ListTile(title: Text(titleText), subtitle: Text(user["email"]), trailing: iconButton));
    });
  }

  Future<Iterable<Widget>> getUserSuggestions(SearchController controller, FormFieldState<dynamic> field) async {
    final String input = controller.value.text;
    List<dynamic> nbs = Group.decodeGroupMembersString(field.value);

    List<String> selectedUsers = nbs.map(
      (element) {
        return element['email'] as String;
      },
    ).toList();

    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    List<SupaUser> result = await Friendship.fetchFriends(input, selectedUsers, 99);

    if (result.isEmpty) {
      return [
        CardListTile(
            isTop: true,
            isBottom: true,
            child: ListTile(title: Text(AppLocalizations.of(context)!.groupMemberResultEmpty)))
      ];
    }

    int resultLength = result.length;

    return result.mapIndexed((index, user) {
      bool isTop = false;
      bool isBottom = false;

      if (index == 0) {
        isTop = true;
      }

      if (index == resultLength - 1) {
        isBottom = true;
      }

      return CardListTile(
        isTop: isTop,
        isBottom: isBottom,
        child: ListTile(
          title: Text(user.displayName),
          subtitle: Text(user.email),
          onTap: () {
            nbs.add(user.toJson());
            field.didChange(jsonEncode(nbs));
            controller.text = "";
          },
        ),
      );
    });
  }

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
                            await Group.saveAll(context, widget.group?.id, _formKey.currentState!.value);
                        newGroup = await Group.fetchDetail(groupInsertId);
                        if (context.mounted) {
                          showSnackBar(
                              context, rootScaffoldMessengerKey, AppLocalizations.of(context)!.groupCreateSuccess);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showSnackBar(
                              context, rootScaffoldMessengerKey, AppLocalizations.of(context)!.groupCreateError);
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
                                    errorText: AppLocalizations.of(context)!.groupNameValidationEmpty),
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: AppLocalizations.of(context)!.addGroupTitle,
                                  contentPadding: EdgeInsets.only(left: 8, right: 8),
                                ),
                                onChanged: (value) => field.didChange(value),
                              )),
                      const SizedBox(height: spacing),
                      FormBuilderField(
                        name: "color_value",
                        builder: (FormFieldState<dynamic> field) {
                          return GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5, crossAxisSpacing: 4, mainAxisSpacing: 4),
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
                                            ColorSeed.values[i].color.toARGB32() ==
                                                ColorSeed.baseColor.color.toARGB32())),
                                    onPressed: () {
                                      field.didChange(ColorSeed.values[i].color.toARGB32());
                                    });
                              });
                        },
                      ),
                      FormBuilderField(
                        name: "group_members",
                        builder: (FormFieldState<dynamic> field) {
                          return SearchAnchor(
                            searchController: _searchAnchorController,
                            viewHintText: AppLocalizations.of(context)!.groupMemberSelectionEmpty,
                            viewLeading: IconButton(
                              icon: Icon(Icons.check),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            builder: (context, controller) {
                              List<Map<String, dynamic>> groupMembers = Group.decodeGroupMembersString(field.value);

                              List<Widget> listTiles = [];

                              if (groupMembers.isEmpty ||
                                  (groupMembers.length == 1 &&
                                      groupMembers.first['email'] == supabase.auth.currentUser?.email)) {
                              } else {
                                listTiles.addAll(groupMembers.map((groupMember) {
                                  String displayName = groupMember["display_name"];
                                  if (groupMember["email"] == supabase.auth.currentUser?.email) {
                                    displayName = AppLocalizations.of(context)!.you;
                                  }

                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(displayName),
                                    subtitle: Text(groupMember['email']),
                                    onTap: () {
                                      controller.openView();
                                    },
                                  );
                                }));
                              }

                              listTiles.add(ListTile(
                                leading: const Icon(Icons.person_add),
                                title: Text(AppLocalizations.of(context)!.groupMemberAddFriends),
                              ));

                              return CardColumn(children: listTiles);
                            },
                            suggestionsBuilder: (context, controller) {
                              if (controller.text.isEmpty) {
                                return getUserSelection(controller, field);
                              }
                              return getUserSuggestions(controller, field);
                            },
                            viewBuilder: (suggestions) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 10, left: 16),
                                    child: Text(
                                      _searchAnchorController.text.isEmpty
                                          ? AppLocalizations.of(context)!.groupMemberSelectionTitle
                                          : AppLocalizations.of(context)!.groupMemberSelectionEmpty,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    child: SearchView(
                                      searchQueryNotifier: _searchQueryNotifier,
                                      suggestions: suggestions,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
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
                      widget.group != null
                          ? Column(
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
                                  ),
                                )
                              ],
                            )
                          : const SizedBox(),
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

  void openDeleteItemDialog(BuildContext modalContext, Group group) {
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
                await group.delete();
                if (context.mounted) {
                  showSnackBar(context, rootScaffoldMessengerKey, AppLocalizations.of(context)!.groupDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(context, rootScaffoldMessengerKey, AppLocalizations.of(context)!.groupDeleteError);
                }
              } finally {
                if (context.mounted) {
                  Navigator.pop(context); //pop both dialog and edit page, because this item is not existing anymore
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
