import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:deun/widgets/form_loading_widget.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:deun/widgets/sliver_grab_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../constants.dart';
import '../../main.dart';
import '../../widgets/search_view.dart';
import '../users/user_model.dart';
import 'group_model.dart';

final _isLoading = StateProvider<bool>((ref) => false);
final _isMiniView = StateProvider<bool>((ref) => false);

class GroupBottomSheet extends ConsumerStatefulWidget {
  const GroupBottomSheet({super.key, this.group});

  final Group? group;

  @override
  ConsumerState<GroupBottomSheet> createState() => _GroupBottomSheetState();
}

class _GroupBottomSheetState extends ConsumerState<GroupBottomSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>("");

  final DraggableScrollableController _draggableScrollableController = DraggableScrollableController();
  final SearchController _searchAnchorController = SearchController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_isLoading.notifier).state = false); // Reset loading state
    Future.microtask(() => ref.read(_isMiniView.notifier).state = false); // Reset loading state

    _draggableScrollableController.addListener(() {
      final pixelToSize = _draggableScrollableController.pixelsToSize(kIsWeb ? 150 : 170);
      if (_draggableScrollableController.size <= pixelToSize) {
        ref.read(_isMiniView.notifier).state = true;
        _draggableScrollableController.jumpTo(pixelToSize);
      } else {
        ref.read(_isMiniView.notifier).state = false;
      }
    });
  }

  @override
  void dispose() {
    _searchAnchorController.dispose();
    super.dispose();
  }

  Iterable<Widget> getUserSelection(SearchController controller, FormFieldState<dynamic> field) {
    List<Map<String, dynamic>> groupMembers = Group.decodeGroupMembersString(field.value);

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

      return ListTile(title: Text(titleText), subtitle: Text(user["email"]), trailing: iconButton);
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

    List<User> result = await Friendship.fetchFriends(input, selectedUsers, 10);

    if (result.isEmpty) {
      return [ListTile(title: Text(AppLocalizations.of(context)!.groupMemberResultEmpty))];
    }

    return result.map((user) => ListTile(
          title: Text(user.displayName),
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
    const double spacing = 8;
    final isLoading = ref.watch(_isLoading);
    final isMiniView = ref.watch(_isMiniView);

    return DraggableScrollableSheet(
        controller: _draggableScrollableController,
        expand: false,
        initialChildSize: .8,
        minChildSize: 0,
        snap: true,
        builder: (context, scrollController) {
          return RoundedContainer(
            child: FormLoading(
              isLoading: isLoading,
              child: Scaffold(
                body: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    const SliverGrabWidget(),
                    SliverList.list(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: Padding(
                            padding: MediaQuery.of(context).viewInsets,
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
                                            readOnly: isMiniView,
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
                                            ),
                                            onChanged: (value) => field.didChange(value),
                                          )),
                                  const SizedBox(height: spacing),
                                  FormBuilderField(
                                    name: "color_value",
                                    builder: (FormFieldState<dynamic> field) {
                                      return GridView.builder(
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 4),
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
                                  const Divider(),
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
                                          List<Map<String, dynamic>> groupMembers =
                                              Group.decodeGroupMembersString(field.value);

                                          if (groupMembers.isEmpty ||
                                              (groupMembers.length == 1 &&
                                                  groupMembers.first['email'] == supabase.auth.currentUser?.email)) {
                                            return ListTile(
                                              leading: const Icon(Icons.people),
                                              title: Text(AppLocalizations.of(context)!.groupMemberAddFriends),
                                            );
                                          }

                                          return Padding(
                                              padding: const EdgeInsets.fromLTRB(10, 5, 5, 10),
                                              child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: <Widget>[
                                                    Wrap(
                                                        spacing: 8,
                                                        children: groupMembers.map((groupMember) {
                                                          String displayName = groupMember["display_name"];
                                                          if (groupMember["email"] ==
                                                              supabase.auth.currentUser?.email) {
                                                            displayName = AppLocalizations.of(context)!.you;
                                                          }
                                                          return ActionChip(
                                                            label: Text(displayName),
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
                                  FormBuilderSwitch(
                                    name: "simplified_expenses",
                                    title: Text(AppLocalizations.of(context)!.groupSimplifiedExpensesTitle),
                                  ),
                                  widget.group != null
                                      ? Center(
                                          child: TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Theme.of(context).colorScheme.error,
                                              textStyle: Theme.of(context).textTheme.bodyLarge,
                                            ),
                                            onPressed: () => openDeleteItemDialog(context, widget.group!),
                                            icon:
                                                Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                                            label: Text(AppLocalizations.of(context)!.groupDeleteItemTitle),
                                          ),
                                        )
                                      : const SizedBox(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                bottomNavigationBar: BottomAppBar(
                  child: IconTheme(
                    data: IconThemeData(color: Theme.of(context).colorScheme.surface),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Theme.of(context).colorScheme.onSurface,
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: FilledButton(
                            onPressed: () async {
                              if (_formKey.currentState!.saveAndValidate()) {
                                // Group? newGroup;
                                ref.read(_isLoading.notifier).state = true; // Set loading to true
                                try {
                                  String groupInsertId =
                                      await Group.saveAll(context, widget.group?.id, _formKey.currentState!.value);
                                  // newGroup = await Group.fetchDetail(groupInsertId);
                                  if (context.mounted) {
                                    showSnackBar(context, groupDetailScaffoldMessengerKey,
                                        AppLocalizations.of(context)!.groupCreateSuccess);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    showSnackBar(context, groupDetailScaffoldMessengerKey,
                                        AppLocalizations.of(context)!.groupCreateError);
                                  }
                                } finally {
                                  if (mounted) {
                                    ref.read(_isLoading.notifier).state = false; // Stop loading
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (widget.group != null) {
                                        Navigator.pop(context);
                                      }
                                      // if (newGroup != null) {
                                      //   debugPrint("New group: ${newGroup.toJson().toString()}");
                                      //   Future.delayed(Durations.medium1, () {
                                      //     GoRouter.of(context).go("/group");
                                      //     GoRouter.of(context).push("/group/details", extra: {'group': newGroup});
                                      //   });
                                      // }
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
                  ),
                ),
              ),
            ),
          );
        });
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
                  showSnackBar(
                      context, groupDetailScaffoldMessengerKey, AppLocalizations.of(context)!.groupDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(
                      context, groupDetailScaffoldMessengerKey, AppLocalizations.of(context)!.groupDeleteError);
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
