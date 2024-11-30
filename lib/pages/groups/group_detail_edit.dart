import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../app_state.dart';
import '../../constants.dart';
import '../../main.dart';
import '../../widgets/search_view.dart';
import '../users/user_model.dart';
import 'group_model.dart';

class GroupBottomSheet extends StatefulWidget {
  const GroupBottomSheet({super.key, required this.appState, this.groupId});

  final AppState appState;
  final int? groupId;

  @override
  State<GroupBottomSheet> createState() => _GroupBottomSheetState();
}

class _GroupBottomSheetState extends State<GroupBottomSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  late Group? group;
  int groupColor = ColorSeed.baseColor.color.value;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>("");

  @override
  void initState() {
    super.initState();

    group = widget.appState.groupItems.value[widget.groupId];
  }

  Iterable<Widget> getUserSelection(
      SearchController controller, FormFieldState<dynamic> field) {
    List<Map<String, dynamic>> groupMembers =
        Group.decodeGroupMembersString(field.value);

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
        iconButton = IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            groupMembers.removeAt(index);
            field.didChange(jsonEncode(groupMembers));

            _searchQueryNotifier.value = jsonEncode(groupMembers);
          },
        );
      }

      return ListTile(
          title: Text(titleText),
          subtitle: Text(user["email"]),
          trailing: iconButton);
    });
  }

  Future<Iterable<Widget>> getUserSuggestions(
      SearchController controller, FormFieldState<dynamic> field) async {
    final String input = controller.value.text;
    List<dynamic> nbs = Group.decodeGroupMembersString(field.value);

    List<String> selectedUsers = nbs.map(
      (element) {
        return element['email'] as String;
      },
    ).toList();

    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    List<User> result = await User.fetchData(input, selectedUsers, 10);

    return result.map((user) => ListTile(
          title: Text("${user.displayName}"),
          subtitle: Text(user.email),
          onTap: () {
            nbs.add(user.toJson());
            field.didChange(jsonEncode(nbs));
            controller.text = "";
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10;

    return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: FormBuilder(
                  key: _formKey,
                  clearValueOnUnregister: true,
                  initialValue: group?.toJson() ?? {},
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                          widget.groupId == null
                              ? AppLocalizations.of(context)!.createGroup
                              : AppLocalizations.of(context)!.editGroup,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: spacing),
                      FormBuilderTextField(
                        name: "name",
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: FormBuilderValidators.required(
                            errorText: AppLocalizations.of(context)!
                                .groupNameValidationEmpty),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.groupName,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      FormBuilderField(
                        name: "color_value",
                        builder: (FormFieldState<dynamic> field) {
                          return GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 5,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 4),
                              padding: const EdgeInsets.all(8),
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: ColorSeed.values.length,
                              itemBuilder: (context, i) {
                                return IconButton(
                                    icon: const Icon(
                                        Icons.radio_button_unchecked),
                                    selectedIcon:
                                        const Icon(Icons.radio_button_checked),
                                    color: ColorSeed.values[i].color,
                                    isSelected: field.value ==
                                        ColorSeed.values[i].color.value,
                                    onPressed: () {
                                      field.didChange(
                                          ColorSeed.values[i].color.value);
                                    });
                              });
                        },
                      ),
                      const Divider(),
                      FormBuilderField(
                        name: "group_members",
                        builder: (FormFieldState<dynamic> field) {
                          return SearchAnchor(
                            viewHintText: AppLocalizations.of(context)!
                                .groupMemberSelectionEmpty,
                            builder: (context, controller) {
                              List<Map<String, dynamic>> groupMembers =
                                  Group.decodeGroupMembersString(field.value);

                              if (groupMembers.isEmpty ||
                                  (groupMembers.length == 1 &&
                                      groupMembers.first['email'] ==
                                          supabase.auth.currentUser?.email)) {
                                return ListTile(
                                  leading: const Icon(Icons.people),
                                  title: Text(AppLocalizations.of(context)!
                                      .groupMemberSelectionEmpty),
                                );
                              }

                              return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 5, 5, 10),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Wrap(
                                            spacing: 8,
                                            children:
                                                groupMembers.map((groupMember) {
                                          return ActionChip(
                                            label: Text(groupMember["email"]),
                                            avatar: const Icon(Icons.person),
                                            onPressed: () {
                                              controller.openView();
                                            },
                                          );
                                        }).toList())
                                      ]));
                            },
                            suggestionsBuilder: (context, controller) {
                              if (controller.text.isEmpty) {
                                return getUserSelection(controller, field);
                              }
                              return getUserSuggestions(controller, field);
                            },
                            viewBuilder: (suggestions) {
                              return SearchView(
                                  searchQueryNotifier: _searchQueryNotifier,
                                  suggestions: suggestions);
                            },
                          );
                        },
                      ),
                      const Divider(),
                      FilledButton(
                          onPressed: () async {
                            if (_formKey.currentState!.saveAndValidate()) {
                              await Group.saveAll(
                                  widget.groupId, _formKey.currentState!.value);

                              await widget.appState.fetchGroupData();
                              await widget.appState.fetchExpenseData();
                              Navigator.pop(context);
                            }
                          },
                          child: Text(widget.groupId != null
                              ? AppLocalizations.of(context)!.update
                              : AppLocalizations.of(context)!.create))
                    ],
                  )))),
    );
  }
}
