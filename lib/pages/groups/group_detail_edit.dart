import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:split_it_supa/main.dart';

import '../../constants.dart';

class GroupBottomSheet extends StatefulWidget {
  const GroupBottomSheet({super.key, this.groupDocId});

  final int? groupDocId;

  @override
  State<GroupBottomSheet> createState() => _GroupBottomSheetState();
}

class _GroupBottomSheetState extends State<GroupBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final groupNameController = TextEditingController();

  Color groupColor = ColorSeed.baseColor.color;
  String? titleText;

  @override
  void initState() {
    super.initState();

    if (widget.groupDocId != null) {
      supabase
          .from('group')
          .select()
          .eq('id', widget.groupDocId ?? '')
          .limit(1)
          .single()
          .then((value) {
        groupNameController.text = value['name'];

        setState(() {
          titleText = value['name'];
          groupColor = Color(value['color_value']);
        });
      });
    }
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
                      Text(
                          titleText ??
                              AppLocalizations.of(context)!.createNewGroup,
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
                                isSelected: groupColor.value ==
                                    ColorSeed.values[i].color.value,
                                onPressed: () {
                                  setState(() {
                                    groupColor = ColorSeed.values[i].color;
                                  });
                                });
                          }),
                      const SizedBox(height: spacing),
                      FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Map<String, dynamic> upsertVals = {
                                'name': groupNameController.text,
                                'color_value': groupColor.value,
                                'user_id': supabase.auth.currentUser?.id
                              };

                              if (widget.groupDocId != null) {
                                upsertVals.addAll({'id': widget.groupDocId});
                              }
                              supabase
                                  .from('group')
                                  .upsert(upsertVals)
                                  .then((value) {
                                Navigator.pop(context);
                              });
                            }
                          },
                          child: Text(widget.groupDocId != null
                              ? AppLocalizations.of(context)!.update
                              : AppLocalizations.of(context)!.create))
                    ],
                  )))),
    );
  }
}
