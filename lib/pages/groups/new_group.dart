import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:split_it_supa/main.dart';

import '../../constants.dart';

class NewGroup extends StatefulWidget {
  const NewGroup({super.key, required this.updateGroupList});

  final VoidCallback updateGroupList;

  @override
  State<NewGroup> createState() => _NewGroupState();
}

class _NewGroupState extends State<NewGroup> {
  final _formKey = GlobalKey<FormState>();
  final groupNameController = TextEditingController();

  ColorSeed groupColor = ColorSeed.baseColor;

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10;
    return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(AppLocalizations.of(context)!.createNewGroup,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: spacing),
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: groupNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!
                                .groupNameValidationEmpty;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.groupName,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      GridView.builder(
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
                                icon: const Icon(Icons.radio_button_unchecked),
                                selectedIcon:
                                    const Icon(Icons.radio_button_checked),
                                color: ColorSeed.values[i].color,
                                isSelected: groupColor == ColorSeed.values[i],
                                onPressed: () {
                                  setState(() {
                                    groupColor = ColorSeed.values[i];
                                  });
                                });
                          }),
                      const SizedBox(height: spacing),
                      FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              supabase.from('group').insert({
                                'name': groupNameController.text,
                                'color_value': groupColor.color.value,
                                'user_id': supabase.auth.currentUser?.id
                              }).then(
                                (value) {
                                  widget.updateGroupList();
                                  Navigator.pop(context);
                                },
                              );
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.create))
                    ],
                  )))),
    );
  }
}
