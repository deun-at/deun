import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../app_state.dart';
import '../../constants.dart';
import '../../main.dart';
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

  @override
  void initState() {
    super.initState();

    group = widget.appState.groupItems.value[widget.groupId];
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
                      const SizedBox(height: spacing),
                      FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.saveAndValidate()) {
                              Map<String, dynamic> upsertVals =
                                  Map<String, dynamic>.from(
                                      _formKey.currentState!.value)
                                    ..addAll({
                                      'user_id': supabase.auth.currentUser?.id
                                    });

                              if (widget.groupId != null) {
                                upsertVals.addAll({'id': widget.groupId});
                              }
                              supabase
                                  .from('group')
                                  .upsert(upsertVals)
                                  .then((value) async {
                                await widget.appState.fetchGroupData();
                                await widget.appState.fetchExpenseData();
                                Navigator.pop(context);
                              });
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
